#!/usr/bin/env python3
"""
Update mechanics for ONE engine, invoked while only that engine is running.

Usage: update_test_one.py {postgres|meilisearch|typesense}

Six events:
  1. monthly_batch   10k changed docs re-upserted (a plausible month of churn)
  2. new_work        one brand-new doc arrives mid-month (Letterboxd's
                      force-import path: /tmd/[id] equivalent)
  3. correction      one doc's author is fixed
  4. work_merge      two docs collapse; the loser must REDIRECT, not vanish
  5. edition_merge   an edition moves between works; edition_count shifts
  6. delete_redirect a doc withdrawn upstream must stop appearing in search

The redirect case is the one that matters: a Dewey book id a reader has
logged against must stay resolvable forever, so 'merge' can never mean
'delete' in the catalog. That's a catalog-table concern (a redirect table),
not a search-index one — this script measures only whether the *index* can be
told about a merge/delete cheaply, per engine, in isolation.
"""
import json, time, subprocess, urllib.request, sys, random

ENGINE = sys.argv[1]
PSQL = "/opt/homebrew/opt/postgresql@15/bin/psql"
DB = "dewey_spike"
MEILI, MEILI_KEY = "http://127.0.0.1:7700", "deweyspikemasterkey1234"
TS, TS_KEY = "http://127.0.0.1:8108", "deweyspike"

results = []


def http(method, url, body=None, headers=None, raw=None):
    data = raw.encode() if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    with urllib.request.urlopen(req, timeout=1800) as r:
        return r.read().decode()


def meili_wait(task_uid):
    while True:
        t = json.loads(http("GET", f"{MEILI}/tasks/{task_uid}",
                            headers={"Authorization": f"Bearer {MEILI_KEY}"}))
        if t["status"] in ("succeeded", "failed", "canceled"):
            return t
        time.sleep(0.2)


def record(event, seconds, note=""):
    results.append({"event": event, "engine": ENGINE,
                    "seconds": round(seconds, 4), "note": note})
    print(f"  {event:16s} {ENGINE:12s} {seconds*1000:9.1f} ms  {note}", file=sys.stderr)


def _arr(xs):
    # Array-syntax escaping (backslash before quote), THEN this whole result
    # gets COPY-text-format escaping in cell() below — two escaping layers,
    # applied in the right order. A single-layer version breaks on any name
    # with an embedded quote (e.g. 'Julia "Joy" Clayton'): "malformed array
    # literal" from Postgres, because the array parser sees an unescaped `"`.
    if not xs:
        return "{}"
    return "{" + ",".join('"' + str(x).replace("\\", "\\\\").replace('"', '\\"') + '"'
                          for x in xs) + "}"


def _cell(v):
    return str(v).replace("\\", "\\\\").replace("\t", " ").replace("\n", " ").replace("\r", " ")


def pg_upsert(docs):
    rows = []
    for d in docs:
        rows.append("\t".join([
            _cell(d["id"]), _cell(d["title"]), _cell(d["title_key"]), _cell(d["title_folded"]),
            _cell(_arr(d.get("authors", []))),
            str(d.get("edition_count", 0)), str(d.get("is_derivative", 0)),
        ]))
    sql = """
create temp table stage(id text, title text, title_key text, title_folded text,
                        authors text[], edition_count int, is_derivative int);
copy stage from stdin;
%s
\\.
insert into doc (id,title,title_key,title_folded,authors,authors_blob,
                 edition_count,is_derivative,tsv)
select id,title,title_key,title_folded,authors,
       lower(array_to_string(authors,' ')),edition_count,is_derivative,
       setweight(to_tsvector('simple', unaccent(coalesce(title,''))),'A')
    || setweight(to_tsvector('simple', unaccent(coalesce(array_to_string(authors,' '),''))),'B')
  from stage
on conflict (id) do update set
  title=excluded.title, title_key=excluded.title_key,
  title_folded=excluded.title_folded, authors=excluded.authors,
  authors_blob=excluded.authors_blob, edition_count=excluded.edition_count,
  is_derivative=excluded.is_derivative, tsv=excluded.tsv;
""" % "\n".join(rows)
    t0 = time.perf_counter()
    p = subprocess.run([PSQL, "-d", DB, "-v", "ON_ERROR_STOP=1", "-q"],
                       input=sql, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(p.stderr[:600])
    return time.perf_counter() - t0


def meili_doc(d):
    m = dict(d)
    m["nonderivative"] = 1 - d.get("is_derivative", 0)
    for k in ("ol_work_ids", "author_ids", "authors_folded", "title_folded",
              "title_key", "why", "contributors"):
        m.pop(k, None)
    return m


def ts_doc(d):
    out = {"id": d["id"], "title": d["title"], "authors": d.get("authors", []),
           "alt_titles": d.get("alt_titles", []), "subtitle": d.get("subtitle", ""),
           "series": d.get("series", ""), "subjects": (d.get("subjects") or [])[:12],
           "isbn13": d.get("isbn13", []), "isbn10": d.get("isbn10", []),
           "edition_count": int(d.get("edition_count", 0)),
           "is_derivative": int(d.get("is_derivative", 0))}
    if d.get("year"):
        out["year"] = int(d["year"])
    return out


def meili_upsert(docs):
    t0 = time.perf_counter()
    r = json.loads(http("POST", f"{MEILI}/indexes/books/documents",
                        [meili_doc(d) for d in docs],
                        headers={"Authorization": f"Bearer {MEILI_KEY}"}))
    meili_wait(r["taskUid"])
    return time.perf_counter() - t0


def ts_upsert(docs):
    body = "\n".join(json.dumps(ts_doc(d), ensure_ascii=False) for d in docs)
    t0 = time.perf_counter()
    http("POST", f"{TS}/collections/books/documents/import?action=upsert",
         raw=body, headers={"X-TYPESENSE-API-KEY": TS_KEY})
    return time.perf_counter() - t0


def upsert(docs):
    return {"postgres": pg_upsert, "meilisearch": meili_upsert, "typesense": ts_upsert}[ENGINE](docs)


def delete_doc(doc_id):
    t0 = time.perf_counter()
    if ENGINE == "postgres":
        subprocess.run([PSQL, "-d", DB, "-q", "-c", f"delete from doc where id='{doc_id}';"],
                       capture_output=True, text=True)
    elif ENGINE == "meilisearch":
        meili_wait(json.loads(http("DELETE", f"{MEILI}/indexes/books/documents/{doc_id}",
                                   headers={"Authorization": f"Bearer {MEILI_KEY}"}))["taskUid"])
    else:
        http("DELETE", f"{TS}/collections/books/documents/{doc_id}",
             headers={"X-TYPESENSE-API-KEY": TS_KEY})
    return time.perf_counter() - t0


def search_one(q):
    from engines import ENGINES
    hits, _ = ENGINES[ENGINE](q, 3)
    return hits


def main():
    docs = [json.loads(l) for l in open("docs.jsonl")]
    random.seed(42)

    print(f"\n-- 1. monthly_batch ({ENGINE}) --", file=sys.stderr)
    batch = random.sample(docs, min(10000, len(docs)))
    for d in batch:
        d["edition_count"] = d.get("edition_count", 0) + 1
    record("monthly_batch", upsert(batch), "10k upserts")

    print(f"\n-- 2. new_work ({ENGINE}) --", file=sys.stderr)
    nw = {"id": "DWTEST1", "title": "The Spike Test Novel", "title_key": "spike test novel",
          "title_folded": "the spike test novel", "authors": ["Aurelia Testwright"],
          "authors_folded": ["aurelia testwright"], "alt_titles": [], "subjects": [],
          "isbn13": ["9780000000001"], "isbn10": [], "edition_count": 1,
          "is_derivative": 0, "year": 2026, "subtitle": "", "series": ""}
    record("new_work", upsert([nw]), "single upsert")
    hits = search_one("Spike Test Novel")
    ok = any(h["id"] == "DWTEST1" for h in hits)
    print(f"    findable: {ok}", file=sys.stderr)
    results.append({"event": "new_work_findable", "engine": ENGINE, "seconds": 0, "note": f"findable={ok}"})

    print(f"\n-- 3. correction ({ENGINE}) --", file=sys.stderr)
    corr = dict(nw); corr["authors"] = ["Aurelia Testwright-Corrected"]
    record("correction", upsert([corr]), "single update")

    print(f"\n-- 4. work_merge ({ENGINE}) --", file=sys.stderr)
    nw2 = dict(nw); nw2["id"] = "DWTEST2"; nw2["edition_count"] = 3
    upsert([nw2])
    t = delete_doc("DWTEST1")
    if ENGINE == "postgres":
        subprocess.run([PSQL, "-d", DB, "-q", "-c",
                        "create table if not exists book_redirect("
                        "old_id text primary key, new_id text not null, merged_at timestamptz default now());"
                        "insert into book_redirect(old_id,new_id) values ('DWTEST1','DWTEST2') "
                        "on conflict do nothing;"], capture_output=True, text=True)
    record("work_merge", t, "redirect row (catalog) + index delete")

    print(f"\n-- 5. edition_merge ({ENGINE}) --", file=sys.stderr)
    nw2b = dict(nw2); nw2b["edition_count"] = 4
    record("edition_merge", upsert([nw2b]), "count update")

    print(f"\n-- 6. delete_redirect ({ENGINE}) --", file=sys.stderr)
    record("delete_redirect", delete_doc("DWTEST2"), "delete")

    hits = search_one("Spike Test Novel")
    gone = not any(h["id"].startswith("DWTEST") for h in hits)
    print(f"    withdrawn: {gone}", file=sys.stderr)
    results.append({"event": "withdrawn_verified", "engine": ENGINE, "seconds": 0, "note": f"gone={gone}"})

    if ENGINE == "postgres":
        r = subprocess.run([PSQL, "-d", DB, "-tAc",
                            "select new_id from book_redirect where old_id='DWTEST1'"],
                           capture_output=True, text=True)
        print(f"    redirect DWTEST1 -> {r.stdout.strip() or '(none)'}", file=sys.stderr)
        results.append({"event": "redirect_resolves", "engine": "postgres",
                        "seconds": 0, "note": f"DWTEST1->{r.stdout.strip()}"})

    out = f"update_results_{ENGINE}.json"
    json.dump(results, open(out, "w"), indent=1)
    print(f"wrote {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
