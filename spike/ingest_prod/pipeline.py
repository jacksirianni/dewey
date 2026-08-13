#!/usr/bin/env python3
"""
Resumable, staged, batch-checkpointed production ingestion pipeline.

  python3 pipeline.py --run-id R1 --works medium_works.jsonl \
      --editions medium_editions.jsonl --authors medium_authors.jsonl \
      --source-version 2026-07-31 --batch-size 5000

Resumability contract: `dewey.pipeline_run` is the single source of truth
for what has been done. On start, the script computes a hash of its exact
input files and compares it against any existing row for `run_id` --
if they match and the row isn't 'completed', it resumes from the recorded
phase and skips every batch index already in `completed_batches`. If a
process dies mid-batch, the batch's staging rows are simply reloaded and
reconciled again on the next invocation -- every reconcile_batch_* function
is upsert-based (safe to redo), so redoing an interrupted batch is correct,
not merely convenient.

Phases, in dependency order (why this order, not the brief's literal list):
  authors -> works -> editions -> signals -> claims -> search
Editions cannot reconcile before works (edition_contributor resolution needs
identifiers). Authors run first because both works and editions reference
them, and author identity must exist before either work_contributor or
edition_contributor can be written. This is the same phase set the brief
proposed, reordered only where a real data dependency required it.
"""
import sys, os, json, time, hashlib, argparse, io
import psycopg2
import psycopg2.extras as pgx

DB = os.environ.get("PIPELINE_DB", "dbname=dewey_medium")
PHASES = ["authors", "works", "editions", "signals", "claims", "search"]


def file_hash(paths):
    h = hashlib.sha256()
    for p in paths:
        h.update(p.encode())
        with open(p, "rb") as f:
            while True:
                chunk = f.read(1 << 20)
                if not chunk:
                    break
                h.update(chunk)
    return h.hexdigest()[:24]


class Manifest:
    """Backed entirely by dewey.pipeline_run -- no separate checkpoint file,
    so there is exactly one place resumability state can live and no risk of
    a file/DB split-brain after a crash."""

    def __init__(self, conn, run_id, provider, source_version, source_hash):
        self.conn = conn
        self.run_id = run_id
        cur = conn.cursor()
        cur.execute("select phase, status, completed_batches, source_hash "
                   "from dewey.pipeline_run where run_id=%s", (run_id,))
        row = cur.fetchone()
        if row is None:
            cur.execute(
                "insert into dewey.pipeline_run (run_id, provider, source_version, "
                "source_hash, phase, status) values (%s,%s,%s,%s,%s,'running')",
                (run_id, provider, source_version, source_hash, PHASES[0]))
            conn.commit()
            self.phase = PHASES[0]
            self.completed = {p: set() for p in PHASES}
            print(f"[{run_id}] new run", file=sys.stderr)
        else:
            phase, status, completed_batches, existing_hash = row
            if existing_hash != source_hash:
                raise SystemExit(
                    f"run {run_id} exists with a DIFFERENT source hash "
                    f"({existing_hash} vs {source_hash}) -- refusing to resume "
                    f"against different input; use a new run_id")
            self.phase = phase
            self.completed = {p: set() for p in PHASES}
            for entry in completed_batches:
                p, b = entry.split(":")
                self.completed[p].add(int(b))
            print(f"[{run_id}] RESUMING at phase={phase}, "
                  f"{sum(len(v) for v in self.completed.values())} batches already done",
                  file=sys.stderr)
        cur.close()

    def batch_done(self, phase, batch):
        return batch in self.completed[phase]

    def mark_batch_done(self, phase, batch):
        self.completed[phase].add(batch)
        entries = [f"{p}:{b}" for p in PHASES for b in sorted(self.completed[p])]
        cur = self.conn.cursor()
        cur.execute("update dewey.pipeline_run set phase=%s, completed_batches=%s, "
                   "updated_at=now() where run_id=%s", (phase, entries, self.run_id))
        self.conn.commit()
        cur.close()

    def set_phase(self, phase):
        self.phase = phase
        cur = self.conn.cursor()
        cur.execute("update dewey.pipeline_run set phase=%s, updated_at=now() where run_id=%s",
                   (phase, self.run_id))
        self.conn.commit()
        cur.close()

    def finish(self, stats):
        cur = self.conn.cursor()
        cur.execute("update dewey.pipeline_run set status='completed', finished_at=now(), "
                   "stats=%s where run_id=%s", (pgx.Json(stats), self.run_id))
        self.conn.commit()
        cur.close()


def chunks(iterable, size):
    buf = []
    for x in iterable:
        buf.append(x)
        if len(buf) >= size:
            yield buf
            buf = []
    if buf:
        yield buf


def copy_rows(cur, table, columns, rows, array_cols=()):
    """COPY, not execute_values -- see the implementation notes' measured
    comparison (§ staging vs direct). Arrays are encoded in Postgres's COPY
    array literal syntax by hand since psycopg2's copy_from doesn't do it."""
    buf = io.StringIO()
    for row in rows:
        cells = []
        for col, val in zip(columns, row):
            if val is None:
                cells.append("\\N")
            elif col in array_cols:
                if not val:
                    cells.append("{}")
                else:
                    # Two escaping layers, applied in order: first the
                    # Postgres ARRAY-literal syntax (backslash then quote),
                    # then COPY's OWN text-format escaping on top of the
                    # resulting string -- omitting the second layer is the
                    # exact bug the incremental-update simulation caught
                    # earlier in the prototype ("malformed array literal"),
                    # now caught again here because it's a genuinely easy
                    # mistake to make twice.
                    arr_literal = "{" + ",".join(
                        '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'
                        for v in val) + "}"
                    cells.append(arr_literal.replace("\\", "\\\\")
                                .replace("\t", " ").replace("\n", " ").replace("\r", " "))
            elif isinstance(val, bool):
                cells.append("t" if val else "f")
            else:
                s = str(val).replace("\\", "\\\\").replace("\t", " ").replace("\n", " ").replace("\r", " ")
                cells.append(s)
        buf.write("\t".join(cells) + "\n")
    buf.seek(0)
    cur.copy_expert(f"copy {table} ({','.join(columns)}) from stdin", buf)


def run(args):
    conn = psycopg2.connect(DB)
    conn.autocommit = False
    source_hash = file_hash([args.works, args.editions, args.authors])
    mf = Manifest(conn, args.run_id, "openlibrary", args.source_version, source_hash)

    import orjson
    t0 = time.time()
    stats = {"batches": 0, "phase_seconds": {}}

    def load_jsonl(path):
        with open(path, "rb") as f:
            for line in f:
                yield orjson.loads(line)

    phase_idx = PHASES.index(mf.phase) if mf.phase in PHASES else 0

    # ---- authors -----------------------------------------------------------
    if phase_idx <= PHASES.index("authors"):
        ta = time.time()
        cur = conn.cursor()
        for i, batch in enumerate(chunks(load_jsonl(args.authors), args.batch_size)):
            if mf.batch_done("authors", i):
                continue
            cur.execute("delete from stg.author where batch_id=%s", (i,))
            rows = [(i, a["k"], a.get("n") or None, a.get("alt") or []) for a in batch]
            copy_rows(cur, "stg.author", ["batch_id", "ol_key", "name", "alt_names"], rows,
                     array_cols={"alt_names"})
            cur.execute("select * from dewey.reconcile_batch_authors(%s, %s)", (i, args.run_id))
            cur.execute("delete from stg.author where batch_id=%s", (i,))
            conn.commit()
            mf.mark_batch_done("authors", i)
            if i > 0 and i % 20 == 0:
                # PERIODIC, not just once per phase: at 1.5M-work
                # scale a single phase spans hundreds of batches, and
                # dewey.identifier keeps growing THROUGHOUT the phase
                # (each work/edition batch mints new identifiers) --
                # one ANALYZE at the phase boundary was enough at
                # 300k works (60 batches) but was measured stale
                # partway through at 1.5M (batch 17 of authors alone
                # took 1m42s+ before this fix; the phase-boundary-only
                # version had already fixed the 300k-scale case, so
                # this recurrence at a new scale is exactly the kind
                # of nonlinear behaviour a bigger validation run is for).
                cur3 = conn.cursor(); cur3.execute("analyze dewey.identifier"); conn.commit(); cur3.close()
            if i % 10 == 0:
                print(f"[authors] batch {i} done ({(i+1)*args.batch_size:,} authors)",
                      file=sys.stderr, flush=True)
        cur.close()
        stats["phase_seconds"]["authors"] = round(time.time() - ta, 1)
        # Explicit ANALYZE, not a wait for autovacuum: the medium-scale test
        # found reconcile_batch_works() taking 2-4+ MINUTES on a single
        # 20,000-row batch immediately after a heavy identifier-insert
        # burst, vs 1.3s once autovacuum's background analyze caught up
        # (confirmed by re-running the identical call after a delay). A
        # fast bulk-insert burst can outrun autovacuum's default schedule,
        # and query plans against stale statistics on a table everything
        # joins against degrade catastrophically, not gracefully.
        cur2 = conn.cursor(); cur2.execute("analyze dewey.identifier"); conn.commit(); cur2.close()
        mf.set_phase("works")

    # ---- works ---------------------------------------------------------------
    if PHASES.index(mf.phase) <= PHASES.index("works"):
        tw = time.time()
        cur = conn.cursor()
        for i, batch in enumerate(chunks(load_jsonl(args.works), args.batch_size)):
            if mf.batch_done("works", i):
                continue
            cur.execute("delete from stg.work where batch_id=%s", (i,))
            rows = [(i, w["k"], (w.get("t") or "").strip() or None, w.get("st") or None,
                    w.get("alt") or [], w.get("au") or [], w.get("sub") or [],
                    w.get("fpd") or None, w.get("cv"), bool(w.get("desc")), w.get("rev"))
                    for w in batch]
            copy_rows(cur, "stg.work",
                     ["batch_id", "ol_key", "title", "subtitle", "alt_titles", "author_keys",
                      "subjects", "first_pub_date", "cover_ol_id", "has_desc", "revision"],
                     rows, array_cols={"alt_titles", "author_keys", "subjects"})
            src_rows = [(i, "openlibrary", "work", w["k"], "dump", args.source_version,
                        hashlib.sha256(orjson.dumps(w, option=orjson.OPT_SORT_KEYS)).hexdigest()[:16])
                       for w in batch]
            pgx.execute_values(cur, """
                insert into dewey.source_record
                    (provider, record_type, provider_id, acquisition, source_version, content_hash)
                values %s
                on conflict (provider, record_type, provider_id, source_version) do update
                  set content_hash = excluded.content_hash,
                      imported_at  = now()
                 where dewey.source_record.content_hash is distinct from excluded.content_hash
            """, [(p, rt, pid, acq, sv, h) for (_, p, rt, pid, acq, sv, h) in src_rows],
                page_size=1000)
            cur.execute("select * from dewey.reconcile_batch_works(%s, %s, %s)",
                       (i, args.run_id, args.source_version))
            cur.execute("delete from stg.work where batch_id=%s", (i,))
            conn.commit()
            mf.mark_batch_done("works", i)
            if i > 0 and i % 20 == 0:
                # PERIODIC, not just once per phase: at 1.5M-work
                # scale a single phase spans hundreds of batches, and
                # dewey.identifier keeps growing THROUGHOUT the phase
                # (each work/edition batch mints new identifiers) --
                # one ANALYZE at the phase boundary was enough at
                # 300k works (60 batches) but was measured stale
                # partway through at 1.5M (batch 17 of works alone
                # took 1m42s+ before this fix; the phase-boundary-only
                # version had already fixed the 300k-scale case, so
                # this recurrence at a new scale is exactly the kind
                # of nonlinear behaviour a bigger validation run is for).
                cur3 = conn.cursor(); cur3.execute("analyze dewey.identifier"); conn.commit(); cur3.close()
            if i % 10 == 0:
                print(f"[works] batch {i} done ({(i+1)*args.batch_size:,} works)",
                      file=sys.stderr, flush=True)
        cur.close()
        stats["phase_seconds"]["works"] = round(time.time() - tw, 1)
        cur2 = conn.cursor(); cur2.execute("analyze dewey.identifier"); conn.commit(); cur2.close()
        mf.set_phase("editions")

    # ---- editions ------------------------------------------------------------
    if PHASES.index(mf.phase) <= PHASES.index("editions"):
        te = time.time()
        cur = conn.cursor()
        for i, batch in enumerate(chunks(load_jsonl(args.editions), args.batch_size)):
            if mf.batch_done("editions", i):
                continue
            cur.execute("delete from stg.edition where batch_id=%s", (i,))
            rows = []
            for e in batch:
                ctr = [{"name": c.get("name"), "role": c.get("role")} for c in (e.get("ctr") or [])]
                rows.append((i, e["k"], e["w"], (e.get("t") or "").strip() or None,
                           e.get("st") or None, e.get("i13") or [], e.get("i10") or [],
                           e.get("pd") or None, e.get("lang") or [], e.get("pg"),
                           e.get("ser") or None, e.get("cv"), e.get("fmt") or None,
                           e.get("pub") or None, e.get("ddc") or None, e.get("au") or [],
                           json.dumps(ctr), bool(e.get("desc"))))
            copy_rows(cur, "stg.edition",
                     ["batch_id", "ol_key", "work_key", "title", "subtitle", "isbn13", "isbn10",
                      "publish_date", "languages", "pages", "series", "cover_ol_id", "format_raw",
                      "publisher", "ddc", "author_keys", "contributors", "has_desc"],
                     rows, array_cols={"isbn13", "isbn10", "languages", "author_keys"})
            cur.execute("select * from dewey.reconcile_batch_editions(%s, %s)", (i, args.run_id))
            cur.execute("delete from stg.edition where batch_id=%s", (i,))
            conn.commit()
            mf.mark_batch_done("editions", i)
            if i > 0 and i % 20 == 0:
                # PERIODIC, not just once per phase: at 1.5M-work
                # scale a single phase spans hundreds of batches, and
                # dewey.identifier keeps growing THROUGHOUT the phase
                # (each work/edition batch mints new identifiers) --
                # one ANALYZE at the phase boundary was enough at
                # 300k works (60 batches) but was measured stale
                # partway through at 1.5M (batch 17 of editions alone
                # took 1m42s+ before this fix; the phase-boundary-only
                # version had already fixed the 300k-scale case, so
                # this recurrence at a new scale is exactly the kind
                # of nonlinear behaviour a bigger validation run is for).
                cur3 = conn.cursor(); cur3.execute("analyze dewey.identifier"); conn.commit(); cur3.close()
            if i % 10 == 0:
                print(f"[editions] batch {i} done ({(i+1)*args.batch_size:,} editions)",
                      file=sys.stderr, flush=True)
        cur.close()
        stats["phase_seconds"]["editions"] = round(time.time() - te, 1)
        mf.set_phase("signals")

    # ---- signals ---------------------------------------------------------------
    # reconcile_batch_signals reads stg.work (to know which works this batch
    # covers) -- and the `works` phase above already deleted those staging
    # rows once it finished with them. Every later phase that needs stg.work
    # must reload it first; this phase forgetting to was a real bug caught by
    # checking work_signal's row count after the first dry run (it was 0).
    if PHASES.index(mf.phase) <= PHASES.index("signals"):
        ts = time.time()
        cur = conn.cursor()
        for i, batch in enumerate(chunks(load_jsonl(args.works), args.batch_size)):
            if mf.batch_done("signals", i):
                continue
            cur.execute("delete from stg.work where batch_id=%s", (i,))
            rows = [(i, w["k"], (w.get("t") or "").strip() or None, w.get("st") or None,
                    w.get("alt") or [], w.get("au") or [], w.get("sub") or [],
                    w.get("fpd") or None, w.get("cv"), bool(w.get("desc")), w.get("rev"))
                    for w in batch]
            copy_rows(cur, "stg.work",
                     ["batch_id", "ol_key", "title", "subtitle", "alt_titles", "author_keys",
                      "subjects", "first_pub_date", "cover_ol_id", "has_desc", "revision"],
                     rows, array_cols={"alt_titles", "author_keys", "subjects"})
            cur.execute("select dewey.reconcile_batch_signals(%s)", (i,))
            cur.execute("delete from stg.work where batch_id=%s", (i,))
            conn.commit()
            mf.mark_batch_done("signals", i)
        cur.close()
        stats["phase_seconds"]["signals"] = round(time.time() - ts, 1)
        mf.set_phase("claims")

    # ---- claims ---------------------------------------------------------------
    if PHASES.index(mf.phase) <= PHASES.index("claims"):
        tc = time.time()
        cur = conn.cursor()
        for i, batch in enumerate(chunks(load_jsonl(args.works), args.batch_size)):
            if mf.batch_done("claims", i):
                continue
            cur.execute("delete from stg.work where batch_id=%s", (i,))
            rows = [(i, w["k"], (w.get("t") or "").strip() or None, w.get("st") or None,
                    w.get("alt") or [], w.get("au") or [], w.get("sub") or [],
                    w.get("fpd") or None, w.get("cv"), bool(w.get("desc")), w.get("rev"))
                    for w in batch]
            copy_rows(cur, "stg.work",
                     ["batch_id", "ol_key", "title", "subtitle", "alt_titles", "author_keys",
                      "subjects", "first_pub_date", "cover_ol_id", "has_desc", "revision"],
                     rows, array_cols={"alt_titles", "author_keys", "subjects"})
            cur.execute("select * from dewey.reconcile_batch_claims(%s, %s)",
                       (i, args.source_version))
            cur.execute("delete from stg.work where batch_id=%s", (i,))
            conn.commit()
            mf.mark_batch_done("claims", i)
        cur.close()
        stats["phase_seconds"]["claims"] = round(time.time() - tc, 1)
        mf.set_phase("search")

    # ---- search ----------------------------------------------------------
    # Whole-catalog, not batched: work_search reads across the fully-
    # reconciled catalog (a work's authors_folded needs every contributor
    # already loaded), so it runs once at the end rather than per input
    # batch. Marked as a single "batch 0" for the same resumability bookkeeping.
    if PHASES.index(mf.phase) <= PHASES.index("search") and not mf.batch_done("search", 0):
        tsr = time.time()
        cur = conn.cursor()
        # Same root cause as the authors/works phase fix, on the tables
        # build_work_search() reads: measured 228s for the search build on
        # this same 20k-work corpus before this line existed. The pattern
        # is now unambiguous across three separate manifestations (temp
        # tables, UNLOGGED staging tables, and now the canonical tables
        # right after a heavy write burst) -- explicit ANALYZE after any
        # bulk write, before the next read that plans against it, is a
        # standing rule for this pipeline, not a one-off patch.
        for t in ("work", "work_contributor", "author_name", "edition",
                 "edition_isbn", "work_title", "work_signal", "cover"):
            cur.execute(f"analyze dewey.{t}")
        conn.commit()
        cur.execute("select dewey.build_work_search()")
        n = cur.fetchone()[0]
        conn.commit()
        cur.close()
        stats["phase_seconds"]["search"] = round(time.time() - tsr, 1)
        stats["work_search_rows_written"] = n
        mf.mark_batch_done("search", 0)

    stats["total_seconds"] = round(time.time() - t0, 1)
    mf.finish(stats)
    conn.close()
    print(f"[{args.run_id}] PIPELINE_DONE {json.dumps(stats)}", file=sys.stderr)
    return stats


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-id", required=True)
    ap.add_argument("--works", required=True)
    ap.add_argument("--editions", required=True)
    ap.add_argument("--authors", required=True)
    ap.add_argument("--source-version", required=True)
    ap.add_argument("--batch-size", type=int, default=5000)
    run(ap.parse_args())
