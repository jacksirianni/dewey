#!/usr/bin/env python3
"""
Stream an Open Library dump from the network, decompress, and write a reduced
projection as JSONL. Never lands the .gz on disk.

Usage: extract.py {works|editions|authors} <outfile>

Dump line format is TSV: type, key, revision, last_modified, json
orjson rather than stdlib json: measured 146k rec/s vs 7k rec/s on this data.
"""
import sys, gzip, subprocess, time
import orjson

KIND = sys.argv[1]
OUT = sys.argv[2]
SRC = f"{KIND}.gz"   # local file: streaming straight from curl corrupts on retry
                     # (curl restarts at byte 0 and concatenates into the pipe,
                     #  which gunzip reports as "invalid stored block lengths")


def first_key(v):
    """OL nests refs as {"key": "/works/OL1W"} or [{"key": ...}] or {"author": {...}}"""
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


def text_of(v):
    if isinstance(v, str):
        return v
    if isinstance(v, dict):
        return v.get("value") or ""
    if isinstance(v, list) and v:
        return text_of(v[0])
    return ""


def proj_work(d):
    return {
        "k": d.get("key", "").rsplit("/", 1)[-1],
        "t": d.get("title") or "",
        "st": d.get("subtitle") or "",
        "alt": [a for a in (d.get("alternative_title") or []) if isinstance(a, str)][:8],
        "au": [k.rsplit("/", 1)[-1] for k in all_keys(d.get("authors") or [])][:12],
        "sub": [s for s in (d.get("subjects") or []) if isinstance(s, str)][:40],
        "fpd": d.get("first_publish_date") or "",
        "cv": (d.get("covers") or [None])[0],
        "desc": 1 if text_of(d.get("description")) else 0,
        "rev": d.get("revision") or 0,
    }


def proj_edition(d):
    works = [k.rsplit("/", 1)[-1] for k in all_keys(d.get("works") or [])]
    if not works:
        return None
    ser, ddc, pubs = d.get("series"), d.get("dewey_decimal_class"), d.get("publishers")
    return {
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


def proj_author(d):
    return {
        "k": d.get("key", "").rsplit("/", 1)[-1],
        "n": d.get("name") or "",
        "alt": [a for a in (d.get("alternate_names") or []) if isinstance(a, str)][:8],
        "bd": d.get("birth_date") or "",
    }


PROJ = {"works": proj_work, "editions": proj_edition, "authors": proj_author}[KIND]

gz = gzip.open(SRC, "rb")

n_in = n_out = 0
t0 = time.time()
dumps, loads = orjson.dumps, orjson.loads
with open(OUT, "wb") as fh:
    for raw in gz:
        n_in += 1
        try:
            d = loads(raw.split(b"\t", 4)[4])
        except Exception:
            continue
        try:
            rec = PROJ(d)
        except Exception:
            continue
        if rec is None or not rec.get("k"):
            continue
        fh.write(dumps(rec)); fh.write(b"\n")
        n_out += 1
        if n_in % 5_000_000 == 0:
            el = time.time() - t0
            print(f"[{KIND}] in={n_in:,} out={n_out:,} {el:.0f}s {n_in/el:,.0f} rec/s",
                  file=sys.stderr, flush=True)

el = time.time() - t0
print(f"[{KIND}] DONE in={n_in:,} out={n_out:,} {el:.0f}s", file=sys.stderr, flush=True)
