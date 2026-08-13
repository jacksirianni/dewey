#!/usr/bin/env python3
"""
Medium-scale corpus: the existing 104,901-work stratified spike corpus (which
already guarantees every benchmark target, every named title, every
distractor/duplicate pattern already validated) PLUS additional stratified
fill from the full 41.5M-work dump to reach ~300,000 -- one streaming pass,
no redownload.
"""
import sys, os, json
from collections import defaultdict
import orjson
sys.path.insert(0, "..")
from common import title_key, stable_bucket

SRC = "../data"
TARGET_TOTAL = int(os.environ.get("TARGET_TOTAL", "300000"))

base_keys = set(json.load(open(f"{SRC}/kept_works.json"))) if os.path.exists(f"{SRC}/kept_works.json") else set()
if not base_keys:
    with open(f"{SRC}/works_sel.jsonl", "rb") as f:
        for line in f:
            base_keys.add(orjson.loads(line)["k"])
print(f"base (existing stratified corpus): {len(base_keys):,}", file=sys.stderr)

additional_needed = max(TARGET_TOTAL - len(base_keys), 0)
# Sample the REST of the 41.5M at a rate chosen to land near the target,
# stratified the same way as before (bucket by completeness signals visible
# in the works projection itself), excluding anything already in the base.
RATE_RICH = int(os.environ.get("RATE_RICH", "12"))
RATE_TRANSLATION = int(os.environ.get("RATE_TRANSLATION", "5"))
RATE_SPARSE = int(os.environ.get("RATE_SPARSE", "550"))
RATE_GENERAL = int(os.environ.get("RATE_GENERAL", "85"))

kept_extra = set()
n_seen = 0
bucket_counts = defaultdict(int)
with open(f"{SRC}/works.jsonl", "rb") as fin, open("medium_works.jsonl", "wb") as fout:
    # write base works first
    seen_base = 0
    with open(f"{SRC}/works_sel.jsonl", "rb") as fbase:
        for line in fbase:
            fout.write(line)
            seen_base += 1
    print(f"wrote {seen_base:,} base works", file=sys.stderr)

    for line in fin:
        n_seen += 1
        w = orjson.loads(line)
        k = w["k"]
        if k in base_keys or k in kept_extra:
            continue
        subs = w.get("sub") or []
        has_alt = bool(w.get("alt"))
        has_desc = bool(w.get("desc"))
        why = None
        if len(subs) >= 5 and has_desc:
            if stable_bucket(k, RATE_RICH) == 0:
                why = "rich"
        elif has_alt:
            if stable_bucket(k, RATE_TRANSLATION) == 0:
                why = "translation"
        elif not subs and not has_alt and not has_desc:
            if stable_bucket(k, RATE_SPARSE) == 0:
                why = "sparse"
        else:
            if stable_bucket(k, RATE_GENERAL) == 0:
                why = "general"
        if not why:
            continue
        w["why"] = why
        kept_extra.add(k)
        bucket_counts[why] += 1
        fout.write(orjson.dumps(w)); fout.write(b"\n")
        if len(kept_extra) >= additional_needed:
            break
        if n_seen % 10_000_000 == 0:
            print(f"  scanned {n_seen:,}, extra kept {len(kept_extra):,}", file=sys.stderr, flush=True)

total = len(base_keys) + len(kept_extra)
print(f"scanned {n_seen:,} additional works", file=sys.stderr)
print(f"extra kept: {len(kept_extra):,}", file=sys.stderr)
for k, v in bucket_counts.items():
    print(f"  {k:12s} {v:>8,}", file=sys.stderr)
print(f"TOTAL medium corpus: {total:,}", file=sys.stderr)

json.dump(sorted(base_keys | kept_extra), open("medium_work_keys.json", "w"))
print("SELECT_MEDIUM_DONE", file=sys.stderr)
