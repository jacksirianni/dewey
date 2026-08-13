#!/usr/bin/env python3
"""
Create and populate the Typesense collection.

Typesense holds its index in RAM, so the schema is deliberately lean: only
fields that search or rank. That constraint is itself a finding — a catalog
carrying descriptions and full subject lists would not fit the same box.
"""
import json, time, sys, urllib.request

TS = "http://127.0.0.1:8108"
KEY = "deweyspike"
BATCH = 20000

SCHEMA = {
    "name": "books",
    "fields": [
        {"name": "id", "type": "string"},
        {"name": "title", "type": "string"},
        {"name": "alt_titles", "type": "string[]", "optional": True},
        {"name": "authors", "type": "string[]", "optional": True},
        {"name": "subtitle", "type": "string", "optional": True},
        {"name": "series", "type": "string", "optional": True},
        {"name": "subjects", "type": "string[]", "optional": True},
        {"name": "isbn13", "type": "string[]", "optional": True},
        {"name": "isbn10", "type": "string[]", "optional": True},
        {"name": "year", "type": "int32", "optional": True, "facet": True},
        {"name": "edition_count", "type": "int32", "sort": True},
        {"name": "is_derivative", "type": "int32", "facet": True},
        {"name": "cover_id", "type": "int64", "optional": True},
    ],
    "default_sorting_field": "edition_count",
    "token_separators": ["'", "-", "."],
}


def http(method, path, body=None, raw=None):
    data = (raw.encode() if isinstance(raw, str) else raw) if raw is not None else \
           (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(TS + path, data=data, method=method)
    req.add_header("X-TYPESENSE-API-KEY", KEY)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=3600) as r:
        return r.read().decode()


def ts_doc(d):
    out = {"id": d["id"], "title": d["title"],
           "alt_titles": d.get("alt_titles") or [],
           "authors": d.get("authors") or [],
           "subtitle": d.get("subtitle") or "",
           "series": d.get("series") or "",
           "subjects": (d.get("subjects") or [])[:12],
           "isbn13": d.get("isbn13") or [], "isbn10": d.get("isbn10") or [],
           "edition_count": int(d.get("edition_count") or 0),
           "is_derivative": int(d.get("is_derivative") or 0)}
    if d.get("year"):
        try:
            out["year"] = int(d["year"])
        except (TypeError, ValueError):
            pass
    if d.get("cover_id"):
        try:
            out["cover_id"] = int(d["cover_id"])
        except (TypeError, ValueError):
            pass
    return out


def main():
    try:
        http("DELETE", "/collections/books")
    except Exception:
        pass
    http("POST", "/collections", SCHEMA)

    t0 = time.time()
    batch, n, errs = [], 0, 0

    def flush(b):
        nonlocal errs
        body = "\n".join(json.dumps(x, ensure_ascii=False) for x in b)
        resp = http("POST", "/collections/books/documents/import?action=create", raw=body)
        for line in resp.splitlines():
            if '"success":false' in line:
                errs += 1
                if errs < 4:
                    print("  err:", line[:200], file=sys.stderr)

    for line in open("docs.jsonl"):
        batch.append(ts_doc(json.loads(line)))
        if len(batch) >= BATCH:
            flush(batch); n += len(batch); batch = []
            if n % 200000 == 0:
                print(f"  imported {n:,}", file=sys.stderr, flush=True)
    if batch:
        flush(batch); n += len(batch)
    elapsed = time.time() - t0

    st = json.loads(http("GET", "/collections/books"))
    print(f"typesense: {st['num_documents']:,} docs in {elapsed:.1f}s ({errs} errors)",
          file=sys.stderr)
    json.dump({"engine": "typesense", "docs": st["num_documents"],
               "index_s": round(elapsed, 1), "import_errors": errs},
              open("stats_typesense.json", "w"))


if __name__ == "__main__":
    main()
