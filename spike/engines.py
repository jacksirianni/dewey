#!/usr/bin/env python3
"""
Three search backends behind one interface: search(q, limit) -> ([hits], ms).

Ranking *intent* is identical across all three, so the comparison measures how
well each engine can express it, not three different products:

  1. an exact article-less title match is close to absolute
  2. a title match outranks an author match, but author tokens still count
  3. popularity (edition_count) nudges, it never decides
  4. derivative works (study guides, criticism) are demoted, never filtered
  5. diacritics fold; typos tolerated

THE AUTHOR-BONUS SUPPRESSION (postgres, case at 'title_key = fk') is not
decoration. Without it, the query 'Piranesi' ranked Giovanni Battista
Piranesi's book of drawings ABOVE Susanna Clarke's novel, because the author
bonus fired on an author whose *name* is the query. If the query is exactly
this title, author signal can only distort. This is the server-side form of
the prototype's "author tokens should not distort title matching".
"""
import json, subprocess, urllib.request, urllib.parse, time
from common import fold, title_key

PSQL = "/opt/homebrew/opt/postgresql@15/bin/psql"
DB = "dewey_spike"

PG_SQL = r"""
set pg_trgm.similarity_threshold = 0.35;
with p as (
  select plainto_tsquery('simple', unaccent($Q$%(q)s$Q$)) as tq,
         $Q$%(f)s$Q$                                       as f,
         $Q$%(fk)s$Q$                                      as fk
),
cand as (
  select d.*, p.tq, p.f, p.fk
    from doc d, p
   where d.tsv @@ p.tq or d.title_key %% p.fk
      or d.isbn13 @> array[$Q$%(raw)s$Q$] or d.isbn10 @> array[$Q$%(raw)s$Q$]
)
select id, title, authors, year, edition_count, is_derivative, cover_id, series,
       round((
           -- Lexical rank is DROPPED on an exact title match. Every such row is
         -- already maximally similar to the query, so the only thing left for
         -- ts_rank_cd to vary on is OTHER fields matching — which is exactly
         -- the distortion we are removing. Without this, 'Piranesi' ranks
         -- Giovanni Battista Piranesi's drawings above Clarke's novel, because
         -- his name matches the weight-B author field as well as the title.
           case when title_key = fk or title_folded = f
                then 0 else coalesce(ts_rank_cd(tsv, tq), 0) end
         + case when title_key = fk or title_folded = f then 6.0
                when title_key like fk || ' %%' then 1.6
                when position(' ' || fk || ' ' in ' ' || title_key || ' ') > 0 then 0.8
                else 0 end
         -- author bonus ONLY when the query is not already fully the title
         + case when title_key = fk or title_folded = f then 0
                when authors_blob like '%%' || f || '%%' then 2.5
                when f <> '' and exists (
                     select 1 from unnest(authors_folded) a
                      where length(a) > 6 and position(a in f) > 0) then 1.8
                else 0 end
         + least(ln(1 + edition_count) * 0.18, 0.9)
         + case when has_description = 1 then 0.05 else 0 end
         - case when is_derivative = 1 then 3.0 else 0 end
         + greatest(coalesce(similarity(title_key, fk), 0) - 0.35, 0) * 3.0
         + case when isbn13 @> array[$Q$%(raw)s$Q$]
                  or isbn10 @> array[$Q$%(raw)s$Q$] then 20.0 else 0 end
       )::numeric, 4) as score
  from cand
 order by score desc, edition_count desc
 limit %(limit)d;
"""


def pg_search(q, limit=10):
    raw = "".join(ch for ch in q if ch.isalnum() or ch == "X").upper()
    sql = PG_SQL % {"q": q.replace("$Q$", ""), "f": fold(q), "fk": title_key(q),
                    "raw": raw, "limit": limit}
    t0 = time.perf_counter()
    p = subprocess.run([PSQL, "-d", DB, "-t", "-A", "-F", "\x1f", "-c", sql],
                       capture_output=True, text=True)
    ms = (time.perf_counter() - t0) * 1000
    if p.returncode != 0:
        raise RuntimeError(p.stderr[:800])
    hits = []
    for line in p.stdout.strip().splitlines():
        f = line.split("\x1f")
        if len(f) < 9:
            continue
        hits.append({"id": f[0], "title": f[1], "authors": _pg_arr(f[2]),
                     "year": f[3], "edition_count": int(f[4] or 0),
                     "is_derivative": int(f[5] or 0), "cover_id": f[6],
                     "series": f[7], "score": float(f[8] or 0)})
    return hits, ms


def _pg_arr(s):
    s = (s or "").strip()
    if s.startswith("{") and s.endswith("}"):
        s = s[1:-1]
    out, cur, inq, i = [], "", False, 0
    while i < len(s):
        c = s[i]
        if c == '"' and (i == 0 or s[i - 1] != "\\"):
            inq = not inq
        elif c == "," and not inq:
            out.append(cur.strip('"')); cur = ""
        else:
            cur += c
        i += 1
    if cur:
        out.append(cur.strip('"'))
    return [x.replace('\\"', '"') for x in out if x]


# -------------------------------------------------------------- Meilisearch --
MEILI = "http://127.0.0.1:7700"
MEILI_KEY = "deweyspikemasterkey1234"


def _http(method, url, body=None, headers=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read() or b"{}")


def _isbn_digits(q):
    """ISBN-shaped input (10 or 13 digits, optional hyphens, optional X check
    digit) routed to an exact filter — not free text. This is not decoration:
    neither Meilisearch's searchableAttributes nor Typesense's query_by
    included isbn13/isbn10 by default, so BOTH engines silently returned
    nothing for every ISBN query until this routing was added. An ISBN is an
    identifier lookup, not a relevance-ranked text query, in any real catalog
    search — ISBN-shaped input must never fall through to fuzzy text match."""
    d = "".join(ch for ch in q if ch.isalnum())
    return d if len(d) in (10, 13) and d[:-1].isdigit() else None


def meili_search(q, limit=10):
    isbn = _isbn_digits(q)
    t0 = time.perf_counter()
    if isbn:
        r = _http("POST", f"{MEILI}/indexes/books/search",
                  {"q": "", "filter": f"isbn13 = {isbn!r} OR isbn10 = {isbn!r}", "limit": limit},
                  headers={"Authorization": f"Bearer {MEILI_KEY}"})
    else:
        r = _http("POST", f"{MEILI}/indexes/books/search",
                  {"q": q, "limit": limit},
                  headers={"Authorization": f"Bearer {MEILI_KEY}"})
    ms = (time.perf_counter() - t0) * 1000
    return [{"id": h["id"], "title": h.get("title", ""), "authors": h.get("authors", []),
             "year": h.get("year"), "edition_count": h.get("edition_count", 0),
             "is_derivative": h.get("is_derivative", 0), "cover_id": h.get("cover_id"),
             "series": h.get("series", ""), "score": None}
            for h in r.get("hits", [])], ms


# ---------------------------------------------------------------- Typesense --
TS = "http://127.0.0.1:8108"
TS_KEY = "deweyspike"


def _ts_hits(r):
    hits = []
    for h in r.get("hits", []):
        d = h["document"]
        hits.append({"id": d["id"], "title": d.get("title", ""),
                     "authors": d.get("authors", []), "year": d.get("year"),
                     "edition_count": d.get("edition_count", 0),
                     "is_derivative": d.get("is_derivative", 0),
                     "cover_id": d.get("cover_id"), "series": d.get("series", ""),
                     "score": None})
    return hits


def ts_search(q, limit=10):
    isbn = _isbn_digits(q)
    if isbn:
        # A cross-field `isbn13:=X || isbn10:=X` filter silently returns 0
        # hits on this Typesense build even though each field alone matches
        # (verified: single-field filters work, the OR combination doesn't).
        # Two sequential single-field filters sidestep it — and a normalized
        # `isbns` array merging both formats at ingest would make this whole
        # workaround unnecessary in the real schema.
        t0 = time.perf_counter()
        for field in ("isbn13", "isbn10"):
            params = {"q": "*", "filter_by": f"{field}:={isbn}", "per_page": limit,
                      "include_fields": "id,title,authors,year,edition_count,is_derivative,cover_id,series"}
            url = f"{TS}/collections/books/documents/search?" + urllib.parse.urlencode(params)
            r = _http("GET", url, headers={"X-TYPESENSE-API-KEY": TS_KEY})
            if r.get("hits"):
                return _ts_hits(r), (time.perf_counter() - t0) * 1000
        return [], (time.perf_counter() - t0) * 1000
    params = {
        "q": q,
        "query_by": "title,alt_titles,authors,subtitle,series,subjects",
        "query_by_weights": "10,6,5,3,3,1",
        "sort_by": "_eval(is_derivative:0):desc,_text_match:desc,edition_count:desc",
        "per_page": limit,
        "num_typos": "2,1,1,0,0,0",
        "prefix": "true,true,true,false,false,false",
        "include_fields": "id,title,authors,year,edition_count,is_derivative,cover_id,series",
        "drop_tokens_threshold": "1",
        "typo_tokens_threshold": "1",
    }
    url = f"{TS}/collections/books/documents/search?" + urllib.parse.urlencode(params)
    t0 = time.perf_counter()
    r = _http("GET", url, headers={"X-TYPESENSE-API-KEY": TS_KEY})
    ms = (time.perf_counter() - t0) * 1000
    return _ts_hits(r), ms


ENGINES = {"postgres": pg_search, "meilisearch": meili_search, "typesense": ts_search}
