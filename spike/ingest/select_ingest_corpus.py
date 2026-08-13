#!/usr/bin/env python3
"""
Select ~7,000 works for the ingestion prototype, from the already-selected
94,282-work spike corpus (works_sel.jsonl / authors_sel.jsonl) — no new
downloads, per the instruction not to redownload the dumps.

Guarantees, not a random sample:
  - every work whose title is one of the 9 explicitly-named benchmark books
    is kept IN FULL (every duplicate/colliding record, not just one)
  - every work by Sayaka Murata or a Percival Everett-named author is kept
  - a stratified downsample of the remaining 'seed'/'author'/'rich'/
    'translation'/'sparse'/'general' buckets fills out the rest, so every
    difficult category from the brief is still represented at 7k scale
"""
import json, sys, os
from collections import defaultdict
import orjson
sys.path.insert(0, "..")
from common import fold, title_key, stable_bucket

SRC = "../data"
TARGET_TOTAL = int(os.environ.get("TARGET_TOTAL", "7000"))

NAMED_TITLES = {title_key(t) for t in [
    "Piranesi", "The Fifth Season", "Beloved", "Wolf Hall", "Red Rising",
    "Station Eleven", "Klara and the Sun",
    # Murata's and Everett's own titles, so the ingestion sees their actual
    # books, not just their author records.
    "James", "Convenience Store Woman", "Earthlings",
]}
NAMED_AUTHORS = {fold(a) for a in ["Sayaka Murata", "Percival Everett"]}

works = {}
with open(f"{SRC}/works_sel.jsonl", "rb") as f:
    for line in f:
        w = orjson.loads(line)
        works[w["k"]] = w
print(f"source corpus: {len(works):,} works", file=sys.stderr)

# Match on EVERY name Open Library gives an author, canonical or alternate —
# the same gap the spike found for Murata (canonical name is 村田沙耶香; the
# romanized form only appears in alternate_names). Missing this here would
# silently drop her from a "named author" search the same way it did before.
author_names_all = defaultdict(list)
author_name = {}
with open(f"{SRC}/authors_sel.jsonl", "rb") as f:
    for line in f:
        a = orjson.loads(line)
        author_name[a["k"]] = a.get("n", "")
        author_names_all[a["k"]] = [a.get("n", "")] + list(a.get("alt") or [])

# ---- force-include: the 9 named titles, every colliding record -----------
named_keys = set()
for k, w in works.items():
    tk = title_key(w.get("t", ""))
    if tk in NAMED_TITLES:
        named_keys.add(k)
print(f"named-title records (all duplicates kept): {len(named_keys):,}", file=sys.stderr)

named_author_keys = set()
for k, w in works.items():
    for ak in w.get("au", []):
        if any(fold(n) in NAMED_AUTHORS for n in author_names_all.get(ak, []) if n):
            named_author_keys.add(k)
print(f"named-author records: {len(named_author_keys):,}", file=sys.stderr)

forced = named_keys | named_author_keys

# ---- stratified downsample of everything else -----------------------------
remaining_budget = max(TARGET_TOTAL - len(forced), 0)
by_bucket = defaultdict(list)
for k, w in works.items():
    if k in forced:
        continue
    by_bucket[w.get("why", "general")].append(k)

total_other = sum(len(v) for v in by_bucket.values())
kept_other = set()
for bucket, keys in by_bucket.items():
    share = round(remaining_budget * len(keys) / max(total_other, 1))
    keys_sorted = sorted(keys, key=lambda k: stable_bucket(k, 1_000_003))
    kept_other.update(keys_sorted[:share])

kept = forced | kept_other
print(f"stratified fill: {len(kept_other):,}  |  total selected: {len(kept):,}",
      file=sys.stderr)

with open("ingest_works.jsonl", "wb") as out:
    for k in kept:
        out.write(orjson.dumps(works[k])); out.write(b"\n")

needed_authors = set()
for k in kept:
    needed_authors.update(works[k].get("au", []))
with open("ingest_authors.jsonl", "wb") as out:
    n = 0
    with open(f"{SRC}/authors_sel.jsonl", "rb") as f:
        for line in f:
            a = orjson.loads(line)
            if a["k"] in needed_authors:
                out.write(line); n += 1
print(f"authors needed: {n:,}", file=sys.stderr)

json.dump(sorted(kept), open("ingest_work_keys.json", "w"))
print("SELECT_DONE", file=sys.stderr)
