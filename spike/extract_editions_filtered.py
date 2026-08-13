#!/usr/bin/env python3
"""
Editions stream, filtered to the selected works.

The unfiltered version was parse-bound at ~3.5k rec/s because it fully decoded
every one of ~55M edition records. Here a byte-level regex pulls the work key
out of the raw line and a set lookup rejects it before any JSON is parsed, so
only the fraction we keep pays decode cost.
"""
import sys, gzip, json, subprocess, time, re
import orjson

OUT = "editions.jsonl"
SRC = "editions.gz"

kept = set(json.load(open("kept_works.json")))
print(f"filter: {len(kept):,} work keys", file=sys.stderr)

WORK_RE = re.compile(rb'/works/(OL\d+W)')


def first_key(v):
    if isinstance(v, dict):
        for f in ("key", "author"):
            if f in v:
                return first_key(v[f])
        return None
    if isinstance(v, list):
        return first_key(v[0]) if v else None
    if isinstance(v, str):
        return v
    return None


def all_keys(v):
    if not isinstance(v, list):
        v = [v]
    out = []
    for item in v:
        k = first_key(item)
        if k:
            out.append(k)
    return out


gz = gzip.open(SRC, "rb")

n_in = n_out = 0
t0 = time.time()
dumps, loads, search = orjson.dumps, orjson.loads, WORK_RE.search

with open(OUT, "wb") as fh:
    for raw in gz:
        n_in += 1
        m = search(raw)
        if m is None or m.group(1).decode() not in kept:
            continue
        try:
            d = loads(raw.split(b"\t", 4)[4])
        except Exception:
            continue
        works = [k.rsplit("/", 1)[-1] for k in all_keys(d.get("works") or [])]
        if not works:
            continue
        ser, ddc, pubs = d.get("series"), d.get("dewey_decimal_class"), d.get("publishers")
        rec = {
            "k": d.get("key", "").rsplit("/", 1)[-1],
            "w": works[0],
            "t": d.get("title") or "",
            "st": d.get("subtitle") or "",
            "i13": [s for s in (d.get("isbn_13") or []) if isinstance(s, str)][:4],
            "i10": [s for s in (d.get("isbn_10") or []) if isinstance(s, str)][:4],
            "pd": d.get("publish_date") or "",
            "lang": [k.rsplit("/", 1)[-1] for k in all_keys(d.get("languages") or [])][:4],
            "pg": d.get("number_of_pages"),
            "ser": ser[0] if isinstance(ser, list) and ser else "",
            "cv": (d.get("covers") or [None])[0],
            "fmt": d.get("physical_format") or "",
            "pub": pubs[0] if isinstance(pubs, list) and pubs else "",
            "ddc": ddc[0] if isinstance(ddc, list) and ddc else "",
            "au": [k.rsplit("/", 1)[-1] for k in all_keys(d.get("authors") or [])][:12],
            "ctr": [c.get("name", "") for c in (d.get("contributors") or []) if isinstance(c, dict)][:8],
            "desc": 1 if d.get("description") else 0,
        }
        if not rec["k"]:
            continue
        fh.write(dumps(rec)); fh.write(b"\n")
        n_out += 1
        if n_in % 10_000_000 == 0:
            el = time.time() - t0
            print(f"[editions] in={n_in:,} kept={n_out:,} {el:.0f}s {n_in/el:,.0f} rec/s",
                  file=sys.stderr, flush=True)

el = time.time() - t0
print(f"[editions] DONE in={n_in:,} kept={n_out:,} {el:.0f}s", file=sys.stderr, flush=True)
