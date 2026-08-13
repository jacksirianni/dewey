#!/usr/bin/env python3
"""Create and populate the Meilisearch index."""
import json, time, sys, urllib.request

MEILI = "http://127.0.0.1:7700"
KEY = "deweyspikemasterkey1234"
BATCH = 20000


def http(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(MEILI + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {KEY}")
    with urllib.request.urlopen(req, timeout=3600) as r:
        return json.loads(r.read() or b"{}")


def wait(task_uid, label=""):
    while True:
        t = http("GET", f"/tasks/{task_uid}")
        if t["status"] in ("succeeded", "failed", "canceled"):
            if t["status"] != "succeeded":
                print(f"  !! {label} {t['status']}: {t.get('error')}", file=sys.stderr)
            return t
        time.sleep(0.5)


def main():
    try:
        wait(http("DELETE", "/indexes/books")["taskUid"])
    except Exception:
        pass
    wait(http("POST", "/indexes", {"uid": "books", "primaryKey": "id"})["taskUid"], "create")

    settings = {
        # order here IS the attribute-ranking priority
        "searchableAttributes": ["title", "alt_titles", "authors", "subtitle",
                                 "series", "subjects"],
        "filterableAttributes": ["isbn13", "isbn10", "year", "languages",
                                 "is_derivative", "edition_count"],
        "sortableAttributes": ["edition_count", "year"],
        # relevance first, then demote derivatives, then let popularity nudge
        "rankingRules": ["words", "typo", "proximity", "attribute", "exactness",
                         "nonderivative:desc", "edition_count:desc"],
        "typoTolerance": {"enabled": True,
                          "minWordSizeForTypos": {"oneTypo": 5, "twoTypos": 9}},
        "displayedAttributes": ["id", "title", "authors", "year", "edition_count",
                                "is_derivative", "cover_id", "series"],
    }
    wait(http("PATCH", "/indexes/books/settings", settings)["taskUid"], "settings")

    t0 = time.time()
    batch, n, tasks = [], 0, []
    for line in open("docs.jsonl"):
        d = json.loads(line)
        d["nonderivative"] = 1 - d.get("is_derivative", 0)
        for k in ("ol_work_ids", "author_ids", "authors_folded", "title_folded",
                  "title_key", "why", "contributors"):
            d.pop(k, None)
        batch.append(d)
        if len(batch) >= BATCH:
            tasks.append(http("POST", "/indexes/books/documents", batch)["taskUid"])
            n += len(batch); batch = []
            if n % 200000 == 0:
                print(f"  queued {n:,}", file=sys.stderr, flush=True)
    if batch:
        tasks.append(http("POST", "/indexes/books/documents", batch)["taskUid"])
        n += len(batch)
    print(f"queued {n:,} docs, waiting for indexing…", file=sys.stderr)
    for t in tasks:
        wait(t, "docs")
    elapsed = time.time() - t0

    st = http("GET", "/indexes/books/stats")
    print(f"meilisearch: {st['numberOfDocuments']:,} docs indexed in {elapsed:.1f}s",
          file=sys.stderr)
    json.dump({"engine": "meilisearch", "docs": st["numberOfDocuments"],
               "index_s": round(elapsed, 1)}, open("stats_meilisearch.json", "w"))


if __name__ == "__main__":
    main()
