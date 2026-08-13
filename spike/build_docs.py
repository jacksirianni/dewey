#!/usr/bin/env python3
"""
Turn selected works+editions+authors into ONE search document per work.

This is the spike's central proposition: the indexed unit is the WORK, with
editions collapsed into it, so 'Piranesi Susanna Clarke' yields one strong row
rather than twenty edition duplicates.

Two collapses happen here, and they are different problems:
  1. EDITION collapse — many editions -> one work doc (aggregate their fields)
  2. WORK merge       — OL holds duplicate *work* records for one book (Red
                        Rising twice, Checkout 19 twice). Union-find on
                        article-less title + (shared author id OR shared author
                        name), which is the client prototype's rule moved
                        server-side, where it runs once instead of per device.
"""
import json, sys, os, statistics
from collections import defaultdict
import orjson
from common import fold, title_key, year_of, looks_derivative

NO_EDITIONS = os.environ.get("NO_EDITIONS") == "1"

author_name = {}
with open("authors_sel.jsonl", "rb") as fh:
    for line in fh:
        a = orjson.loads(line)
        author_name[a["k"]] = a.get("n", "")
print(f"authors: {len(author_name):,}", file=sys.stderr)

works = {}
with open("works_sel.jsonl", "rb") as fh:
    for line in fh:
        w = orjson.loads(line)
        works[w["k"]] = w
print(f"works: {len(works):,}", file=sys.stderr)

eds = defaultdict(list)
n_ed = 0
if not NO_EDITIONS and os.path.exists("editions.jsonl"):
    with open("editions.jsonl", "rb") as fh:
        for line in fh:
            try:
                e = orjson.loads(line)
            except Exception:
                continue
            if e.get("w") in works:
                eds[e["w"]].append(e); n_ed += 1
print(f"editions attached: {n_ed:,} across {len(eds):,} works", file=sys.stderr)

# ---- work merge (union-find) ----------------------------------------------
parent = {k: k for k in works}


def find(x):
    while parent[x] != x:
        parent[x] = parent[parent[x]]
        x = parent[x]
    return x


def union(a, b):
    ra, rb = find(a), find(b)
    if ra != rb:
        parent[rb] = ra


by_title = defaultdict(list)
for k, w in works.items():
    tk = title_key(w.get("t", ""))
    if tk:
        by_title[tk].append(k)

n_merged = 0
for tk, keys in by_title.items():
    if len(keys) < 2 or len(keys) > 300:      # skip pathological buckets ('poems')
        continue
    info = []
    for k in keys:
        w = works[k]
        aset = set(w.get("au", []))
        names = {fold(author_name.get(a, "")) for a in w.get("au", [])} - {""}
        info.append((k, aset, names))
    for i in range(len(info)):
        for j in range(i + 1, len(info)):
            if (info[i][1] & info[j][1]) or (info[i][2] & info[j][2]):
                union(info[i][0], info[j][0]); n_merged += 1
print(f"work-merge: {n_merged:,} pairwise unions", file=sys.stderr)

groups = defaultdict(list)
for k in works:
    groups[find(k)].append(k)
print(f"groups: {len(groups):,} (from {len(works):,} work records)", file=sys.stderr)

out = open("docs.jsonl", "wb")
n_docs = 0
stats = defaultdict(int)

for root, keys in groups.items():
    canon = max(keys, key=lambda k: (len(eds.get(k, [])), works[k].get("rev", 0), k))
    w = works[canon]
    all_eds = []
    for k in keys:
        all_eds.extend(eds.get(k, []))

    title = (w.get("t") or "").strip()
    if not title:
        continue
    subtitle = w.get("st") or ""
    alts = set()
    for k in keys:
        for a in works[k].get("alt", []):
            alts.add(a)
        ot = works[k].get("t")
        if ot and title_key(ot) != title_key(title):
            alts.add(ot)
    for e in all_eds:
        et = e.get("t", "")
        if et and title_key(et) != title_key(title):
            alts.add(et)
        if not subtitle and e.get("st"):
            subtitle = e["st"]
    alts = [a for a in alts if a][:12]

    akeys, anames = [], []
    for k in keys:
        for ak in works[k].get("au", []):
            if ak not in akeys:
                akeys.append(ak)
                nm = author_name.get(ak, "")
                if nm:
                    anames.append(nm)
    contributors = []
    for e in all_eds:
        for c in e.get("ctr", []):
            if c and c not in contributors:
                contributors.append(c)

    isbn13, isbn10, langs, pages, years, series, ddc, covers = set(), set(), set(), [], [], [], [], []
    for e in all_eds:
        isbn13.update(e.get("i13") or [])
        isbn10.update(e.get("i10") or [])
        langs.update(e.get("lang") or [])
        if e.get("pg"):
            pages.append(e["pg"])
        y = year_of(e.get("pd"))
        if y:
            years.append(y)
        if e.get("ser"):
            series.append(e["ser"])
        if e.get("ddc"):
            ddc.append(e["ddc"])
        if e.get("cv"):
            covers.append(e["cv"])

    first_year = year_of(w.get("fpd")) or (min(years) if years else None)
    cover = w.get("cv") or (max(set(covers), key=covers.count) if covers else None)
    ser = max(set(series), key=series.count) if series else ""
    dd = max(set(ddc), key=ddc.count) if ddc else ""

    subjects = []
    for k in keys:
        for s in works[k].get("sub", []):
            if s not in subjects:
                subjects.append(s)
    subjects = subjects[:30]

    derivative = looks_derivative(title) or looks_derivative(subtitle)
    has_desc = any(works[k].get("desc") for k in keys) or any(e.get("desc") for e in all_eds)

    doc = {
        "id": canon,
        "ol_work_ids": keys,
        "title": title,
        "title_key": title_key(title),
        "title_folded": fold(title),
        "subtitle": subtitle,
        "alt_titles": alts,
        "authors": anames,
        "authors_folded": [fold(a) for a in anames],
        "author_ids": akeys,
        "contributors": contributors[:8],
        "series": ser,
        "isbn13": sorted(isbn13)[:12],
        "isbn10": sorted(isbn10)[:12],
        "year": first_year,
        "edition_count": len(all_eds),
        "work_record_count": len(keys),
        "languages": sorted(langs)[:6],
        "pages": int(statistics.median(pages)) if pages else None,
        "subjects": subjects,
        "ddc": dd,
        "cover_id": cover,
        "has_description": 1 if has_desc else 0,
        "has_cover": 1 if cover else 0,
        "is_derivative": 1 if derivative else 0,
        "why": w.get("why", ""),
    }
    out.write(orjson.dumps(doc)); out.write(b"\n")
    n_docs += 1
    stats["derivative"] += doc["is_derivative"]
    stats["merged_groups"] += 1 if len(keys) > 1 else 0
    stats["with_editions"] += 1 if all_eds else 0
    stats["with_isbn"] += 1 if (isbn13 or isbn10) else 0
    stats["with_cover"] += doc["has_cover"]
    stats["with_ddc"] += 1 if dd else 0
    stats["with_series"] += 1 if ser else 0
    stats["with_year"] += 1 if first_year else 0

out.close()
print(f"docs: {n_docs:,}", file=sys.stderr)
for k, v in sorted(stats.items()):
    print(f"  {k:16s} {v:>9,}  ({100*v/max(n_docs,1):.1f}%)", file=sys.stderr)
json.dump({"docs": n_docs, **{k: v for k, v in stats.items()}}, open("corpus_stats.json", "w"))
