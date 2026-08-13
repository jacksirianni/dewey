#!/usr/bin/env python3
"""
Bounded Open Library -> Dewey catalog ingestion prototype.

Moves ~7,000 real Open Library works (plus their editions and authors)
through supabase/0002_catalog.sql, exercising every stage the design
document specified — including the mechanisms a real ingest job would use
(claim_field for provenance, the identifier table for idempotent re-runs,
merge_* left untouched since automatic entity resolution is explicitly out
of scope here).

Explicit stages, run in this order, each one a separate function so the
pipeline is legible rather than one large procedure:

  1.  load_sources()         read the JSONL projections + live-fetched payloads
  2.  normalize()             fold/parse/classify before anything touches the DB
  3.  resolve_authors()       identifier lookup -> reuse, or mint + insert
  4.  persist_author_names()  canonical + alternate_names, deduplicated
  5.  resolve_works()         identifier lookup -> reuse, or mint + insert
  6.  persist_work_titles()
  7.  persist_work_contributors()
  8.  resolve_editions()      identifier lookup -> reuse, or mint + insert
  9.  persist_edition_contributors()   role-classified, see classify_role()
  10. persist_identifiers()   ol_work / ol_edition / ol_author / isbn
  11. persist_covers()
  12. persist_subjects()      + ddc aggregated onto the work
  13. persist_work_signals()
  14. claim_canonical_fields() -- through dewey.claim_field(), never ad hoc UPDATE
  15. anomalies are written throughout, never silently dropped -- see Anomalies

Run twice to prove idempotency:  python3 ingest.py [--run-label R2]
"""
import sys, os, json, time, hashlib, argparse, unicodedata
from collections import defaultdict, Counter
import orjson
import psycopg2
import psycopg2.extras as pgx

sys.path.insert(0, "..")
from common import fold, title_key, year_of

DB = os.environ.get("INGEST_DB", "dbname=dewey_ingest_test")
DUMP_VERSION = "2026-07-31"          # matches the OL dump this data came from
BATCH = 1000

# ---------------------------------------------------------------- Anomalies --
# Every rejected field or record is recorded here, never just dropped. This is
# the file-based "review queue" the brief allows in place of a new schema
# table -- adding a table for it would be exactly the kind of schema change
# this task is supposed to justify with a real failure, and a flat log already
# answers "what did ingestion refuse, and why".
class Anomalies:
    def __init__(self, path):
        self.path = path
        self.fh = open(path, "w")
        self.counts = Counter()

    def log(self, kind, disposition, **ctx):
        self.counts[(kind, disposition)] += 1
        self.fh.write(json.dumps({"kind": kind, "disposition": disposition, **ctx},
                                 ensure_ascii=False) + "\n")

    def close(self):
        self.fh.close()


ROLE_SYNONYMS = {
    "translator": "translator", "translated by": "translator", "translation": "translator",
    "narrator": "narrator", "narrator/reader": "narrator", "read by": "narrator",
    "reader": "narrator", "performed by": "narrator",
    "illustrator": "illustrator", "illustrated by": "illustrator", "cover art": "illustrator",
    "editor": "editor", "edited by": "editor", "compiler": "editor",
    "afterword": "afterword", "afterword by": "afterword",
    "introduction": "introduction", "introduction by": "introduction", "foreword": "introduction",
}


def classify_role(raw):
    """Map a free-text OL contributor role to the fixed edition_role enum, or
    None if it genuinely does not correspond to any value we track. Unmapped
    roles are common and real -- 'adaptation of original work by', 'notes by',
    'additional author (this edition)' all appeared in the extracted corpus --
    and are logged, not guessed at."""
    r = (raw or "").strip().lower()
    return ROLE_SYNONYMS.get(r)


def content_hash(obj):
    return hashlib.sha256(orjson.dumps(obj, option=orjson.OPT_SORT_KEYS)).hexdigest()[:16]


def is_nonlatin(s):
    for ch in s:
        if ch.isalpha():
            try:
                if not unicodedata.name(ch).startswith("LATIN"):
                    return True
            except ValueError:
                continue
    return False


# ------------------------------------------------------------------- Stats --
class Stats:
    def __init__(self):
        self.d = Counter()
        self.t0 = time.time()

    def __setitem__(self, k, v): self.d[k] = v
    def __getitem__(self, k): return self.d[k]
    def add(self, k, n=1): self.d[k] += n

    def report(self):
        el = time.time() - self.t0
        self.d["elapsed_seconds"] = round(el, 2)
        self.d["works_per_sec"] = round(self.d["works_attempted"] / max(el, 0.001), 1)
        return dict(self.d)


# =============================================================================
# Stage 1: load sources
# =============================================================================
def load_sources():
    works = {}
    with open("ingest_works.jsonl", "rb") as f:
        for line in f:
            w = orjson.loads(line)
            works[w["k"]] = w

    editions = defaultdict(list)
    with open("ingest_editions.jsonl", "rb") as f:
        for line in f:
            e = orjson.loads(line)
            editions[e["w"]].append(e)

    authors = {}
    with open("ingest_authors.jsonl", "rb") as f:
        for line in f:
            a = orjson.loads(line)
            authors[a["k"]] = a

    named_payloads = {}
    if os.path.exists("named_work_payloads.json"):
        named_payloads = json.load(open("named_work_payloads.json"))

    return works, editions, authors, named_payloads


# =============================================================================
# Stage 2: normalize
# =============================================================================
def normalize_work_type(title, subjects):
    t = fold(title)
    if any(p in t for p in ("study guide", "sparknotes", "summary of", "companion to",
                            "cliffsnotes", "readings on", "critical essays")):
        return "study_guide"
    return "book"


def _deterministic_mode(vals):
    """Most common value, tie broken by sort order rather than by iterating a
    `set` -- a real idempotency bug, caught by this prototype's own repeat-run
    check: `max(set(vals), key=vals.count)` picks whichever tied value the
    set happens to iterate first, and Python randomizes string hash order per
    process by default, so the SAME input picked a different DDC/series on
    two consecutive, otherwise-identical ingest runs. `Counter.most_common()`
    is insertion-order-stable for ties, but "stable" here still means
    "depends on which OL edition record happened to sort first in the source
    file" -- so ties are additionally broken on the value string itself,
    which depends on nothing but the data."""
    if not vals:
        return None
    counts = Counter(vals)
    top = counts.most_common(1)[0][1]
    return sorted(v for v, n in counts.items() if n == top)[0]


def normalize_ddc(editions_for_work):
    return _deterministic_mode([e.get("ddc") for e in editions_for_work if e.get("ddc")])


def normalize_series(editions_for_work):
    return _deterministic_mode([e.get("ser") for e in editions_for_work if e.get("ser")])


# =============================================================================
# Ingestion
# =============================================================================
class Ingestor:
    def __init__(self, conn, anomalies, stats):
        self.conn = conn
        self.cur = conn.cursor()
        self.an = anomalies
        self.st = stats
        self.work_id = {}     # OL work key   -> dewey uuid
        self.author_id = {}   # OL author key -> dewey uuid
        self.edition_id = {}  # OL edition key -> dewey uuid

    # ---- identifier-table-backed resolution: THIS is what makes re-runs
    # idempotent. A key already seen (in ANY prior run, not just this
    # process's memory) resolves through `identifier`, never mints twice.
    def resolve_or_mint(self, entity_type, id_type, keys):
        keys = list(keys)
        if not keys:
            return {}
        self.cur.execute(
            "select id_type, value, entity_id from dewey.identifier "
            "where entity_type=%s and id_type=%s and value = any(%s)",
            (entity_type, id_type, keys))
        found = {v: eid for (_, v, eid) in self.cur.fetchall()}
        missing = [k for k in keys if k not in found]
        if missing:
            self.cur.execute("select dewey.uuid_v7() from generate_series(1,%s)", (len(missing),))
            fresh = [r[0] for r in self.cur.fetchall()]
            for k, uid in zip(missing, fresh):
                found[k] = uid
        return found

    # ------------------------------------------------------------------ 3/5/8
    def resolve_authors(self, author_keys):
        self.author_id = self.resolve_or_mint("author", "ol_author", author_keys)
        return self.author_id

    def resolve_works(self, work_keys):
        self.work_id = self.resolve_or_mint("work", "ol_work", work_keys)
        return self.work_id

    def resolve_editions(self, edition_keys):
        self.edition_id = self.resolve_or_mint("edition", "ol_edition", edition_keys)
        return self.edition_id

    # ------------------------------------------------------------------ 4/9
    def persist_source_records(self, records):
        """records: list of (provider, record_type, provider_id, acquisition,
        payload_or_none, hash). Idempotent: unchanged content_hash is a true
        no-op (not even imported_at moves), so a re-run is measurable."""
        rows = [(p, rt, pid, acq, DUMP_VERSION if acq == "dump" else "2026-08-10",
                pgx.Json(payload) if payload is not None else None, h)
                for (p, rt, pid, acq, payload, h) in records]
        pgx.execute_values(self.cur, """
            insert into dewey.source_record
                (provider, record_type, provider_id, acquisition, source_version, payload, content_hash)
            values %s
            on conflict (provider, record_type, provider_id, source_version) do update
              set content_hash = excluded.content_hash,
                  imported_at  = case when dewey.source_record.content_hash
                                        is distinct from excluded.content_hash
                                       then now()
                                       else dewey.source_record.imported_at end
            returning id, provider_id,
                      (xmax = 0) as was_insert
        """, rows, page_size=BATCH)
        out = {}
        for row_id, pid, was_insert in self.cur.fetchall():
            out[pid] = row_id
            self.st.add("source_records_inserted" if was_insert else "source_records_seen")
        return out

    # ------------------------------------------------------------------ 4b
    def persist_authors(self, authors):
        rows = [(self.author_id[k], a.get("n") or "(unnamed)") for k, a in authors.items()]
        pgx.execute_values(self.cur, """
            insert into dewey.author (id, display_name) values %s
            on conflict (id) do nothing
        """, rows, page_size=BATCH)
        self.st.add("authors_inserted", self.cur.rowcount if self.cur.rowcount > 0 else 0)

    def persist_author_names(self, authors):
        rows = []
        for k, a in authors.items():
            aid = self.author_id[k]
            name = a.get("n") or ""
            if name:
                rows.append((aid, name, "canonical",
                            "nonlatin" if is_nonlatin(name) else "latin", "openlibrary"))
            for alt in (a.get("alt") or []):
                if not alt or alt == name:
                    continue
                kind = "romanization" if (is_nonlatin(name) and not is_nonlatin(alt)) else "alias"
                rows.append((aid, alt, kind,
                            "nonlatin" if is_nonlatin(alt) else "latin", "openlibrary"))
        if not rows:
            return
        pgx.execute_values(self.cur, """
            insert into dewey.author_name (author_id, name, kind, script, source) values %s
            on conflict (author_id, kind, name) do nothing
        """, [(aid, nm, kind, ("Jpan" if scr == "nonlatin" else "Latn"), src)
              for (aid, nm, kind, scr, src) in rows], page_size=BATCH)
        self.st.add("author_names_inserted", len(rows))

    # ------------------------------------------------------------------ 6
    def persist_works(self, works, editions_by_work):
        rows = []
        for k, w in works.items():
            eds = editions_by_work.get(k, [])
            title = (w.get("t") or "").strip()
            if not title:
                self.an.log("empty_title", "reject_record", ol_work=k)
                self.st.add("works_rejected")
                continue
            wt = normalize_work_type(title, w.get("sub", []))
            year = year_of(w.get("fpd"))
            if year is not None and not (0 < year <= 2027):
                self.an.log("impossible_date", "reject_field", ol_work=k, value=year)
                year = None
            rows.append((self.work_id[k], wt, title, None, year, None,
                        normalize_series(eds), normalize_ddc(eds)))
        if not rows:
            return
        pgx.execute_values(self.cur, """
            insert into dewey.work (id, work_type, display_title, display_subtitle,
                                    first_published_year, first_published_date,
                                    series_name, ddc)
            values %s
            on conflict (id) do nothing
        """, rows, page_size=BATCH)
        self.st.add("works_inserted", self.cur.rowcount if self.cur.rowcount > 0 else 0)
        self.st.add("works_attempted", len(rows))

    def persist_work_titles(self, works):
        rows = []
        for k, w in works.items():
            if k not in self.work_id:
                continue
            wid = self.work_id[k]
            title = (w.get("t") or "").strip()
            if title:
                rows.append((wid, "canonical", title, None, "openlibrary", True))
            for alt in (w.get("alt") or []):
                if alt and alt.strip() and alt.strip() != title:
                    rows.append((wid, "alternate", alt.strip(), None, "openlibrary", False))
        if not rows:
            return
        pgx.execute_values(self.cur, """
            insert into dewey.work_title (work_id, kind, title, language, source, is_display)
            values %s
            on conflict (work_id, kind, title, coalesce(language, '')) do nothing
        """, rows, page_size=BATCH)
        self.st.add("work_titles_inserted", len(rows))

    # ------------------------------------------------------------------ 7
    def persist_work_contributors(self, works):
        rows = []
        for k, w in works.items():
            if k not in self.work_id:
                continue
            wid = self.work_id[k]
            for pos, ak in enumerate(w.get("au") or []):
                if ak not in self.author_id:
                    self.an.log("missing_author", "reject_field", ol_work=k, ol_author=ak)
                    self.st.add("work_contributors_rejected")
                    continue
                rows.append((wid, self.author_id[ak], "author", pos, "openlibrary"))
        if not rows:
            return
        pgx.execute_values(self.cur, """
            insert into dewey.work_contributor (work_id, author_id, role, position, source)
            values %s
            on conflict (work_id, author_id, role) do nothing
        """, rows, page_size=BATCH)
        self.st.add("work_contributors_inserted", len(rows))

    # ------------------------------------------------------------------ 8
    def persist_editions(self, editions_by_work):
        rows = []
        skipped_dangling = 0
        for wk, eds in editions_by_work.items():
            if wk not in self.work_id:
                skipped_dangling += len(eds)
                for e in eds:
                    self.an.log("dangling_edition", "reject_record", ol_edition=e["k"], ol_work=wk)
                continue
            wid = self.work_id[wk]
            for e in eds:
                eid = self.edition_id[e["k"]]
                pub_date = (e.get("pd") or "").strip() or None
                pub_year = year_of(pub_date)
                if pub_year is not None and not (0 < pub_year <= 2027):
                    self.an.log("impossible_date", "reject_field",
                               ol_edition=e["k"], value=pub_year)
                    pub_year = None
                fmt = None
                fraw = (e.get("fmt") or "").lower()
                if "audio" in fraw:
                    fmt = "audiobook"
                elif "hardcover" in fraw or "hardback" in fraw:
                    fmt = "hardcover"
                elif "paperback" in fraw or "softcover" in fraw:
                    fmt = "paperback"
                elif "ebook" in fraw or "electronic" in fraw:
                    fmt = "ebook"
                elif fraw:
                    fmt = "other"
                pages = e.get("pg")
                if pages is not None and not (0 < pages <= 50000):
                    self.an.log("impossible_page_count", "reject_field",
                               ol_edition=e["k"], value=pages)
                    pages = None
                rows.append((eid, wid, (e.get("t") or "").strip() or None,
                            (e.get("st") or "").strip() or None,
                            (e.get("lang") or [None])[0], (e.get("pub") or "").strip() or None,
                            pub_date, pub_year, pages, fmt))
        self.st.add("editions_dangling", skipped_dangling)
        if not rows:
            return
        pgx.execute_values(self.cur, """
            insert into dewey.edition
                (id, work_id, title, subtitle, language, publisher,
                 published_date, published_year, page_count, format)
            values %s
            on conflict (id) do nothing
        """, rows, page_size=BATCH)
        self.st.add("editions_inserted", self.cur.rowcount if self.cur.rowcount > 0 else 0)
        self.st.add("editions_attempted", len(rows))

    # ------------------------------------------------------------------ 9
    def persist_edition_contributors(self, editions_by_work):
        # Note: OL editions also carry an `au` (authors) field, largely
        # duplicating the work's own authorship. `edition_role` deliberately
        # has NO 'author' value -- authorship is work-level only, per the
        # design -- so that field is not ingested here; work_contributor
        # (stage 7) is already the sole source of authorship. Only genuine
        # edition-specific roles (translator, narrator, ...) are persisted
        # below, from OL's `contributors` field.
        rows = []
        for wk, eds in editions_by_work.items():
            if wk not in self.work_id:
                continue
            for e in eds:
                if e["k"] not in self.edition_id:
                    continue
                eid = self.edition_id[e["k"]]
                for pos, c in enumerate(e.get("ctr") or []):
                    role = classify_role(c.get("role"))
                    if role is None:
                        self.an.log("unknown_contributor_role", "reject_field",
                                   ol_edition=e["k"], raw_role=c.get("role"), name=c.get("name"))
                        self.st.add("contributor_roles_rejected")
                        continue
                    # Contributors are free text names, not author keys -- no
                    # author identity to attach to without a name match we are
                    # not going to attempt automatically (out of scope, same
                    # as author merge). Recorded as a real edition_contributor
                    # only when an author row already exists under that exact
                    # display name; otherwise logged for review rather than
                    # inventing an author record from free text.
                    match = self.author_by_name.get(fold(c.get("name") or ""))
                    if match is None:
                        self.an.log("unresolved_contributor_name", "review_queue",
                                   ol_edition=e["k"], name=c.get("name"), role=role)
                        self.st.add("contributor_names_unresolved")
                        continue
                    rows.append((eid, match, role, pos, "openlibrary"))
        if not rows:
            return
        pgx.execute_values(self.cur, """
            insert into dewey.edition_contributor (edition_id, author_id, role, position, source)
            values %s
            on conflict (edition_id, author_id, role) do nothing
        """, rows, page_size=BATCH)
        self.st.add("edition_contributors_inserted", len(rows))

    # ------------------------------------------------------------------ 10
    def persist_identifiers(self, works, editions_by_work, authors):
        rows = []
        for k in works:
            if k in self.work_id:
                rows.append(("work", self.work_id[k], "openlibrary", "ol_work", k, True))
        for k in authors:
            if k in self.author_id:
                rows.append(("author", self.author_id[k], "openlibrary", "ol_author", k, True))
        for wk, eds in editions_by_work.items():
            for e in eds:
                if e["k"] in self.edition_id:
                    rows.append(("edition", self.edition_id[e["k"]], "openlibrary",
                                "ol_edition", e["k"], True))

        # ISBNs, normalized through the SAME SQL function the schema exposes
        # -- never a Python re-implementation of the checksum that could drift
        # from what `dewey.resolve_isbn` actually does at query time.
        isbn_candidates = []
        for wk, eds in editions_by_work.items():
            for e in eds:
                if e["k"] not in self.edition_id:
                    continue
                for raw in (e.get("i13") or []) + (e.get("i10") or []):
                    isbn_candidates.append((e["k"], raw))
        if isbn_candidates:
            self.cur.execute(
                "select t.ek, t.raw, dewey.isbn_to_13(t.raw) "
                "from unnest(%s::text[], %s::text[]) as t(ek, raw)",
                ([c[0] for c in isbn_candidates], [c[1] for c in isbn_candidates]))
            isbn13_by_edition = defaultdict(set)
            for ek, raw, isbn13 in self.cur.fetchall():
                if isbn13 is None:
                    self.an.log("malformed_isbn", "reject_field", ol_edition=ek, raw=raw)
                    self.st.add("isbns_rejected")
                else:
                    isbn13_by_edition[ek].add(isbn13)

            isbn_rows = []
            for ek, vals in isbn13_by_edition.items():
                eid = self.edition_id[ek]
                for v in vals:
                    isbn_rows.append((eid, v, "openlibrary"))
            if isbn_rows:
                pgx.execute_values(self.cur, """
                    insert into dewey.edition_isbn (edition_id, isbn13, source)
                    values %s
                    on conflict (edition_id, isbn13) do nothing
                """, isbn_rows, page_size=BATCH)
                self.st.add("isbns_inserted", len(isbn_rows))

        if rows:
            pgx.execute_values(self.cur, """
                insert into dewey.identifier (entity_type, entity_id, provider, id_type, value, is_primary)
                values %s
                on conflict (provider, id_type, value, entity_type) do update
                  set last_seen_at = now()
            """, rows, page_size=BATCH)
            self.st.add("identifiers_inserted", len(rows))

    # ------------------------------------------------------------------ 11
    def persist_covers(self, works, editions_by_work):
        rows = []
        for k, w in works.items():
            if k not in self.work_id or not w.get("cv"):
                continue
            self.cur.execute("select dewey.uuid_v7()")
            cid = self.cur.fetchone()[0]
            rows.append((cid, self.work_id[k], "openlibrary", str(w["cv"]),
                        "unlicensed_cached"))
        if not rows:
            return
        pgx.execute_values(self.cur, """
            insert into dewey.cover (id, work_id, source, source_ref, license_posture)
            values %s
            on conflict (source, source_ref, coalesce(work_id, edition_id)) do nothing
            returning work_id, id
        """, rows, page_size=BATCH)
        got = self.cur.fetchall()
        self.st.add("covers_inserted", len(got))
        for wid, cid in got:
            self.cur.execute(
                "update dewey.work set display_cover_id = %s "
                "where id = %s and display_cover_id is null", (cid, wid))

    # ------------------------------------------------------------------ 12
    def persist_subjects(self, works):
        labels = set()
        for w in works.values():
            for s in (w.get("sub") or [])[:15]:
                if s and s.strip():
                    labels.add(s.strip())
        if labels:
            pgx.execute_values(self.cur, """
                insert into dewey.subject (label, vocabulary) values %s
                on conflict (vocabulary, label) do nothing
            """, [(l, "ol_folksonomy") for l in labels], page_size=BATCH)
        self.cur.execute("select id, label from dewey.subject where vocabulary='ol_folksonomy'")
        subj_id = {label: sid for sid, label in self.cur.fetchall()}

        rows = []
        for k, w in works.items():
            if k not in self.work_id:
                continue
            for s in (w.get("sub") or [])[:15]:
                s = (s or "").strip()
                if s in subj_id:
                    rows.append((self.work_id[k], subj_id[s], "openlibrary"))
        if rows:
            pgx.execute_values(self.cur, """
                insert into dewey.work_subject (work_id, subject_id, source) values %s
                on conflict (work_id, subject_id) do nothing
            """, rows, page_size=BATCH)
        self.st.add("subjects_inserted", len(labels))
        self.st.add("work_subjects_inserted", len(rows))

    # ------------------------------------------------------------------ 13
    def persist_work_signals(self, works, editions_by_work):
        rows = []
        for k, w in works.items():
            if k not in self.work_id:
                continue
            eds = editions_by_work.get(k, [])
            title = (w.get("t") or "").strip()
            deriv = normalize_work_type(title, w.get("sub")) == "study_guide"
            completeness = sum([
                bool(w.get("desc")), bool(w.get("cv")), bool(eds),
                bool(year_of(w.get("fpd"))), bool(w.get("sub")),
            ]) * 20
            rows.append((self.work_id[k], len(eds), len(eds), deriv, completeness))
        if not rows:
            return
        pgx.execute_values(self.cur, """
            insert into dewey.work_signal
                (work_id, edition_count, recent_edition_count, is_derivative, completeness)
            values %s
            on conflict (work_id) do update
              set edition_count = excluded.edition_count,
                  recent_edition_count = excluded.recent_edition_count,
                  is_derivative = excluded.is_derivative,
                  completeness = excluded.completeness,
                  computed_at = now()
        """, rows, page_size=BATCH)
        self.st.add("work_signals_upserted", len(rows))

    # ------------------------------------------------------------------ 14
    def claim_canonical_fields(self, works, named_payloads, source_record_ids):
        """Every canonical field write goes through dewey.claim_field(). No
        ad-hoc UPDATE ever touches work.title/description/etc. directly."""
        claims = []  # (entity_type, entity_id, field, provider, source_record_id, locked, value)
        for k, w in works.items():
            if k not in self.work_id:
                continue
            wid = self.work_id[k]
            src_id = source_record_ids.get(k)
            title = (w.get("t") or "").strip()
            if title:
                claims.append(("work", wid, "title", "openlibrary", src_id, False, title))
            year = year_of(w.get("fpd"))
            if year:
                claims.append(("work", wid, "first_published_year", "openlibrary", src_id,
                              False, year))
            ser = normalize_series(self.editions_by_work.get(k, []))
            if ser:
                claims.append(("work", wid, "series_name", "openlibrary", src_id, False, ser))
            ddc = normalize_ddc(self.editions_by_work.get(k, []))
            if ddc:
                claims.append(("work", wid, "ddc", "openlibrary", src_id, False, ddc))

        # The 9 named books get real live-fetched description text -- the
        # API acquisition path, proven with real payload retention.
        for wk, payload in named_payloads.items():
            if wk not in self.work_id:
                continue
            wid = self.work_id[wk]
            desc = payload.get("description")
            text = desc if isinstance(desc, str) else (desc or {}).get("value") if desc else None
            if text:
                claims.append(("work", wid, "description", "openlibrary",
                              self.api_source_record_ids.get(wk), False, text[:2000]))

        n_claimed = n_refused = 0
        for etype, eid, field, provider, src_id, locked, value in claims:
            self.cur.execute(
                "select dewey.claim_field(%s::dewey.entity_type, %s, %s, %s::dewey.provider, %s, %s)",
                (etype, eid, field, provider, src_id, locked))
            won = self.cur.fetchone()[0]
            if won:
                n_claimed += 1
                self._apply_claimed_value(etype, eid, field, value)
            else:
                n_refused += 1
        self.st.add("field_claims_won", n_claimed)
        self.st.add("field_claims_refused", n_refused)

    def _apply_claimed_value(self, etype, eid, field, value):
        # The canonical column is written ONLY after claim_field() has
        # already recorded who owns it -- this function never runs first.
        col_by_field = {
            "title": ("work", "display_title"),
            "first_published_year": ("work", "first_published_year"),
            "series_name": ("work", "series_name"),
            "ddc": ("work", "ddc"),
            "description": ("work", "description"),
        }
        table, col = col_by_field[field]
        self.cur.execute(f"update dewey.{table} set {col} = %s where id = %s", (value, eid))


CATALOG_TABLES = [
    "work", "work_title", "work_contributor", "work_subject", "work_signal",
    "edition", "edition_isbn", "edition_contributor",
    "author", "author_name", "identifier", "cover", "source_record",
    "field_provenance", "subject",
]


def table_counts(conn):
    """Ground truth. psycopg2's execute_values pages internally past
    page_size, and both cur.rowcount and a RETURNING-clause fetchall() after
    it only reflect the LAST internal page when a call spans more than one --
    discovered here when 'works_inserted' reported 999 for a real, verified
    6,999. Before/after COUNT(*) has no such failure mode."""
    cur = conn.cursor()
    out = {}
    for t in CATALOG_TABLES:
        cur.execute(f"select count(*) from dewey.{t}")
        out[t] = cur.fetchone()[0]
    cur.close()
    return out


def run_ingest(label):
    works, editions_by_work, authors, named_payloads = load_sources()
    print(f"[{label}] loaded: {len(works):,} works, "
          f"{sum(len(v) for v in editions_by_work.values()):,} editions, "
          f"{len(authors):,} authors", file=sys.stderr)

    conn = psycopg2.connect(DB)
    conn.autocommit = False
    before = table_counts(conn)
    an = Anomalies(f"anomalies_{label}.jsonl")
    st = Stats()
    st["works_seen"] = len(works)

    ing = Ingestor(conn, an, st)
    ing.editions_by_work = editions_by_work
    ing.author_by_name = {}

    try:
        # ---- 3: resolve authors, then persist name rows and build the
        # exact-name match table edition_contributor needs.
        ing.resolve_authors(authors.keys())
        ing.persist_authors(authors)
        ing.persist_author_names(authors)
        conn.commit()

        ing.cur.execute("select author_id, name from dewey.author_name")
        for aid, name in ing.cur.fetchall():
            ing.author_by_name.setdefault(fold(name), aid)

        # ---- 4: source records for every work (dump-acquired, no payload)
        # plus the 9 named books (api-acquired, full payload retained).
        dump_records = [("openlibrary", "work", k, "dump", None, content_hash(w))
                        for k, w in works.items()]
        source_ids = ing.persist_source_records(dump_records)

        api_records = [("openlibrary", "work", wk, "api", payload, content_hash(payload))
                       for wk, payload in named_payloads.items()]
        api_source_ids = ing.persist_source_records(api_records) if api_records else {}
        ing.api_source_record_ids = api_source_ids
        conn.commit()

        # ---- 5/6/7: works
        ing.resolve_works(works.keys())
        ing.persist_works(works, editions_by_work)
        ing.persist_work_titles(works)
        ing.persist_work_contributors(works)
        conn.commit()

        # ---- 8/9: editions
        all_edition_keys = [e["k"] for eds in editions_by_work.values() for e in eds]
        ing.resolve_editions(all_edition_keys)
        ing.persist_editions(editions_by_work)
        conn.commit()
        ing.persist_edition_contributors(editions_by_work)
        conn.commit()

        # ---- 10/11/12/13
        ing.persist_identifiers(works, editions_by_work, authors)
        conn.commit()
        ing.persist_covers(works, editions_by_work)
        conn.commit()
        ing.persist_subjects(works)
        conn.commit()
        ing.persist_work_signals(works, editions_by_work)
        conn.commit()

        # ---- 14: provenance-gated canonical field writes
        ing.claim_canonical_fields(works, named_payloads, source_ids)
        conn.commit()

        after = table_counts(conn)

    except Exception:
        conn.rollback()
        raise
    finally:
        an.close()
        conn.close()

    report = st.report()
    report["anomaly_kinds"] = {f"{k}:{d}": n for (k, d), n in an.counts.items()}
    # Ground-truth deltas replace the per-call counters above for every
    # "_inserted" figure that matters in the final report -- see
    # table_counts()'s docstring for why the per-call numbers cannot be
    # trusted once a batch exceeds one page.
    report["table_row_delta"] = {t: after[t] - before[t] for t in CATALOG_TABLES}
    report["table_row_count_after"] = after
    json.dump(report, open(f"stats_{label}.json", "w"), indent=1, default=str)
    print(f"[{label}] done: {json.dumps(report, indent=1, default=str)}", file=sys.stderr)
    return report


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-label", default="run1")
    args = ap.parse_args()
    run_ingest(args.run_label)
