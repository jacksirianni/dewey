#!/usr/bin/env python3
"""
Editions for the ingestion corpus, extracted fresh from the already-downloaded
editions.gz (no redownload) — filtered to the 7,000 chosen works, same
byte-regex prefilter as the search spike.

Captures MORE than the spike's search-index projection did: contributor
ROLE (translator vs narrator), not just name. The spike's extract.py kept
only `c.get("name")` and dropped `c.get("role")` — harmless for a search
document, but this ingestion explicitly needs to prove a translator and a
narrator land in different places, and that requires the role.
"""
import sys, gzip, json, subprocess, time, re
import orjson

SRC = "../data/editions.gz"
OUT = "scale_editions.jsonl"

kept = set(json.load(open("scale_work_keys.json")))
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
loads, dumps, search = orjson.loads, orjson.dumps, WORK_RE.search

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
        contributors = []
        for c in (d.get("contributors") or []):
            if isinstance(c, dict) and c.get("name"):
                contributors.append({"name": c["name"], "role": (c.get("role") or "").strip()})
        rec = {
            "k": d.get("key", "").rsplit("/", 1)[-1],
            "w": works[0],
            "t": d.get("title") or "",
            "st": d.get("subtitle") or "",
            "i13": [s for s in (d.get("isbn_13") or []) if isinstance(s, str)][:6],
            "i10": [s for s in (d.get("isbn_10") or []) if isinstance(s, str)][:6],
            "pd": d.get("publish_date") or "",
            "lang": [k.rsplit("/", 1)[-1] for k in all_keys(d.get("languages") or [])][:4],
            "pg": d.get("number_of_pages"),
            "ser": ser[0] if isinstance(ser, list) and ser else "",
            "cv": (d.get("covers") or [None])[0],
            "fmt": d.get("physical_format") or "",
            "pub": pubs[0] if isinstance(pubs, list) and pubs else "",
            "ddc": ddc[0] if isinstance(ddc, list) and ddc else "",
            "au": [k.rsplit("/", 1)[-1] for k in all_keys(d.get("authors") or [])][:8],
            "ctr": contributors[:8],   # now name+role, not name alone
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

# Quick sanity: did we actually capture any roles?
from collections import Counter
roles = Counter()
for line in open(OUT, "rb"):
    e = orjson.loads(line)
    for c in e.get("ctr", []):
        roles[c["role"].lower() or "(blank)"] += 1
print("role distribution (top 10):", roles.most_common(10), file=sys.stderr)
