#!/usr/bin/env python3
"""
Build a BOUNDED, deliberately stratified spike corpus (target ~150k-250k
works) from the fully-extracted works.jsonl (41.5M records).

This replaced an earlier version that used flat hash-sampled noise and grew
past 470k works, which combined with three concurrently-running search
engines drove this 8GB dev machine into swap (load avg ~80). The fix is not
"sample less of everything" — it's sample DELIBERATELY, so a small corpus is
still a realistic one:

  1. SEED matches   — every benchmark target's title, capped per seed so a
                       common word ("james", "night", "1984") can't balloon
                       the corpus. The cap still keeps real distractors: study
                       guides, unrelated books with the same word, duplicate
                       work records.
  2. AUTHOR matches  — every work by a benchmark author, uncapped (this bucket
                       is naturally small — a person's bibliography, not a
                       search result set).
  3. Signal-stratified noise — four buckets sampled at different rates using
     properties visible in the works projection itself, so the noise is not
     just "1/N of everything" but touches every category the brief asked for:
       - rich:        subjects >= 5 AND has a description  (well-catalogued)
       - translation:  has an alternative_title             (non-English proxy)
       - sparse:       no subjects, no alt title, no description (the OL median)
       - general:      everything else

Known bias, stated up front: over-representing seed terms deflates their IDF
relative to production, which makes those queries *harder* here than against
the full corpus — a conservative direction, not a simulation of production
scoring.
"""
import json, sys, os
from collections import defaultdict
import orjson
from common import fold, title_key, stable_bucket

HERE = os.path.dirname(os.path.abspath(__file__))
BM = json.load(open(os.path.join(HERE, "benchmark.json")))

PER_SEED_CAP = int(os.environ.get("PER_SEED_CAP", "500"))
RATE_RICH = int(os.environ.get("RATE_RICH", "60"))          # 1-in-N
RATE_TRANSLATION = int(os.environ.get("RATE_TRANSLATION", "25"))
RATE_SPARSE = int(os.environ.get("RATE_SPARSE", "2500"))
RATE_GENERAL = int(os.environ.get("RATE_GENERAL", "400"))

title_seeds, author_seeds = set(), set()
for q in BM["queries"]:
    e = q["expect"]
    if e.get("title"):
        title_seeds.add(title_key(e["title"]))
    if e.get("author"):
        author_seeds.add(fold(e["author"]))
for q in BM["isbn_queries"]:
    title_seeds.add(title_key(q["book"]["title"]))
    author_seeds.add(fold(q["book"]["author"]))

title_seeds |= {title_key(t) for t in [
    "Cien años de soledad", "채식주의자", "地球星人", "De ansatte", "L'amica geniale",
    "Broken Earth", "Earthsea", "Discworld", "Red Rising", "Nineteen Eighty-Four",
    "Mrs Dalloway", "The Handmaid's Tale",
]}
author_seeds |= {fold(a) for a in [
    "Susanna Clarke", "Hilary Mantel", "Margaret Atwood", "Virginia Woolf",
    "Gabrielle Zevin", "Donna Tartt", "Han Kang", "Sayaka Murata", "Olga Ravn",
    "Elena Ferrante", "Kate Zambreno", "Hilary Leichter", "Claire-Louise Bennett",
    "Elie Wiesel", "Yuval Noah Harari", "Tara Westover", "Bessel van der Kolk",
    "Ursula K. Le Guin", "Terry Pratchett", "J. R. R. Tolkien", "Jane Austen",
    "William Shakespeare", "George Orwell", "Chinua Achebe", "Percival Everett",
    "Sally Rooney", "Kaliane Bradley", "Kaveh Akbar", "Samantha Harvey",
    "Pierce Brown", "N. K. Jemisin", "Emily St. John Mandel", "Kazuo Ishiguro",
    "Toni Morrison", "Hernan Diaz", "Gabriel Garcia Marquez", "Roberto Bolano",
    "Karl Ove Knausgard", "F. Scott Fitzgerald",
]}
print(f"seeds: {len(title_seeds)} titles, {len(author_seeds)} authors "
      f"| PER_SEED_CAP={PER_SEED_CAP} rates: rich=1/{RATE_RICH} "
      f"translation=1/{RATE_TRANSLATION} sparse=1/{RATE_SPARSE} general=1/{RATE_GENERAL}",
      file=sys.stderr)

SEED_BY_HEAD = {}
for _s in title_seeds:
    if _s:
        SEED_BY_HEAD.setdefault(_s.split(" ", 1)[0], []).append(_s)
SEED_HEADS = set(SEED_BY_HEAD)


def title_hits_seed(t_folded):
    """Token-subsequence match, so 'Beloved' also pulls in
    'A Study Guide for Toni Morrison's Beloved' — we WANT the competitors."""
    toks = t_folded.split(" ")
    if not (SEED_HEADS & set(toks)):
        return None
    padded = " " + t_folded + " "
    for tok in toks:
        for s in SEED_BY_HEAD.get(tok, ()):
            if s == t_folded or (" " + s + " ") in padded:
                return s
    return None


# ---- pass 0: which author records are benchmark authors --------------------
target_author_keys = set()
with open("authors.jsonl", "rb") as fh:
    for line in fh:
        a = orjson.loads(line)
        for n in [a.get("n", "")] + (a.get("alt") or []):
            if fold(n) in author_seeds:
                target_author_keys.add(a["k"])
                break
print(f"pass0: {len(target_author_keys)} author keys match benchmark authors", file=sys.stderr)

# ---- pass 1: select works, deliberately stratified -------------------------
kept, needed_authors = set(), set()
seed_counts = defaultdict(int)
bucket_counts = defaultdict(int)
n_seen = 0
with open("works.jsonl", "rb") as fin, open("works_sel.jsonl", "wb") as fout:
    for line in fin:
        w = orjson.loads(line)
        n_seen += 1
        why = None

        tf = title_key(w.get("t", ""))
        hit = title_hits_seed(tf) if tf else None
        if hit and seed_counts[hit] < PER_SEED_CAP:
            seed_counts[hit] += 1
            why = "seed"
        elif any(k in target_author_keys for k in w.get("au", [])):
            why = "author"
        else:
            subs = w.get("sub") or []
            has_alt = bool(w.get("alt"))
            has_desc = bool(w.get("desc"))
            b = w["k"]
            if len(subs) >= 5 and has_desc:
                if stable_bucket(b, RATE_RICH) == 0:
                    why = "rich"
            elif has_alt:
                if stable_bucket(b, RATE_TRANSLATION) == 0:
                    why = "translation"
            elif not subs and not has_alt and not has_desc:
                if stable_bucket(b, RATE_SPARSE) == 0:
                    why = "sparse"
            else:
                if stable_bucket(b, RATE_GENERAL) == 0:
                    why = "general"

        if not why:
            continue
        bucket_counts[why] += 1
        w["why"] = why
        kept.add(w["k"])
        needed_authors.update(w.get("au", []))
        fout.write(orjson.dumps(w)); fout.write(b"\n")
        if n_seen % 10_000_000 == 0:
            print(f"  seen={n_seen:,} kept={len(kept):,}", file=sys.stderr, flush=True)

print(f"pass1: seen={n_seen:,} kept={len(kept):,}", file=sys.stderr)
for k, v in sorted(bucket_counts.items()):
    print(f"  bucket {k:12s} {v:>9,}", file=sys.stderr)

json.dump(sorted(kept), open("kept_works.json", "w"))

# ---- pass 2: authors for kept works ---------------------------------------
n_auth = 0
with open("authors.jsonl", "rb") as fin, open("authors_sel.jsonl", "wb") as fout:
    for line in fin:
        a = orjson.loads(line)
        if a["k"] in needed_authors:
            fout.write(line); n_auth += 1
print(f"pass2: {n_auth:,} authors kept", file=sys.stderr)

top = sorted(seed_counts.items(), key=lambda kv: -kv[1])[:12]
print("busiest seeds: " + ", ".join(f"{k}={v}" for k, v in top), file=sys.stderr)
print("SELECT_DONE", file=sys.stderr, flush=True)
