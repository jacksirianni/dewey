#!/usr/bin/env python3
"""
~1.5M-work corpus: the already-validated 300,000-work medium corpus as a
base, plus additional stratified fill from the full 41.5M-work dump. Same
signal-based stratification as select_medium_corpus.py, just re-run with a
higher target and excluding what's already selected.
"""
import sys, os, json
from collections import defaultdict
import orjson
sys.path.insert(0, "..")
from common import stable_bucket

SRC = "../data"
TARGET_TOTAL = int(os.environ.get("TARGET_TOTAL", "1500000"))

base_keys = set(json.load(open("medium_work_keys.json")))
print(f"base (300k medium corpus): {len(base_keys):,}", file=sys.stderr)

additional_needed = max(TARGET_TOTAL - len(base_keys), 0)
RATE_RICH = int(os.environ.get("RATE_RICH", "2"))
RATE_TRANSLATION = int(os.environ.get("RATE_TRANSLATION", "1"))
RATE_SPARSE = int(os.environ.get("RATE_SPARSE", "90"))
RATE_GENERAL = int(os.environ.get("RATE_GENERAL", "14"))

kept_extra = set()
n_seen = 0
bucket_counts = defaultdict(int)
# No early break on hitting the extra-record quota: the 300k base corpus's
# own records (named titles, validated duplicates) are scattered throughout
# the 41.5M file, not clustered at the start. An early version of this
# script broke out of the loop as soon as `additional_needed` extras were
# collected and silently dropped 38,546 of 300,000 base works whose lines
# simply hadn't been reached yet -- caught only by noticing "base written"
# came in under the known base size. The scan now always runs to
# completion; only the extra-record sampling stops early.
with open(f"{SRC}/works.jsonl", "rb") as fin, open("scale_works.jsonl", "wb") as fout:
    n_base_written = 0
    for line in fin:
        n_seen += 1
        w = orjson.loads(line)
        k = w["k"]
        if k in base_keys:
            fout.write(line)
            n_base_written += 1
            continue
        if k in kept_extra or len(kept_extra) >= additional_needed:
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
        if n_seen % 10_000_000 == 0:
            print(f"  scanned {n_seen:,}, base written {n_base_written:,}, extra kept {len(kept_extra):,}",
                  file=sys.stderr, flush=True)

total = n_base_written + len(kept_extra)
print(f"scanned {n_seen:,} works total", file=sys.stderr)
print(f"base written: {n_base_written:,}  extra kept: {len(kept_extra):,}", file=sys.stderr)
for k, v in bucket_counts.items():
    print(f"  {k:12s} {v:>9,}", file=sys.stderr)
print(f"TOTAL scale corpus: {total:,}", file=sys.stderr)

json.dump(sorted(base_keys | kept_extra), open("scale_work_keys.json", "w"))
print("SELECT_SCALE_DONE", file=sys.stderr)
