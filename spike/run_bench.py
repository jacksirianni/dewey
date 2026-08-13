#!/usr/bin/env python3
"""
Run the fixed benchmark against one or more engines and score it.

  top1 / top3   expected work at rank 1 / within rank 3
  wrong_work    rank-1 is not the expected work (target WAS in corpus)
  trap          rank-1 title matches a trap phrase (study guide, criticism…)
  dup_edition   >=2 rows in the top 10 are the same work (collapse failed)
  latency       median and p95, client-side

Targets absent from the stratified corpus are reported separately and excluded
from accuracy: they measure the corpus, not the ranking.
"""
import json, sys, os, statistics
from collections import defaultdict
from common import fold, title_key
from engines import ENGINES

HERE = os.path.dirname(os.path.abspath(__file__))
BM = json.load(open(os.path.join(HERE, "benchmark.json")))
LIMIT = 10


def load_docs():
    by_tkey, by_id = defaultdict(list), {}
    for line in open("docs.jsonl"):
        d = json.loads(line)
        by_id[d["id"]] = d
        by_tkey[d["title_key"]].append(d)
        for a in d.get("alt_titles") or []:
            tk = title_key(a)
            if tk and tk != d["title_key"]:
                by_tkey[tk].append(d)
    return by_id, by_tkey


def resolve(expect, by_tkey):
    if expect["type"] == "author_any":
        return None
    tk = title_key(expect["title"])
    af = fold(expect["author"])
    cands = [d for d in by_tkey.get(tk, [])
             if any(fold(a) == af or af in fold(a) or fold(a) in af
                    for a in (d.get("authors") or []))]
    return max(cands, key=lambda d: d.get("edition_count", 0)) if cands else None


def is_author_hit(hit, author):
    af = fold(author)
    return any(fold(a) == af or af in fold(a) for a in (hit.get("authors") or []))


def dup_count(hits):
    seen, dups = set(), 0
    for h in hits:
        auths = h.get("authors") or []
        k = (title_key(h.get("title", "")), fold(auths[0]) if auths else "")
        if k in seen:
            dups += 1
        seen.add(k)
    return dups


def build_isbn_queries(by_tkey):
    out = []
    for q in BM["isbn_queries"]:
        d = resolve({"type": "work", **q["book"]}, by_tkey)
        if not d:
            continue
        if q["class"].startswith("isbn13") and d.get("isbn13"):
            raw = d["isbn13"][0]
            val = ("-".join([raw[:3], raw[3:4], raw[4:8], raw[8:12], raw[12:]])
                   if q["class"].endswith("hyphenated") and len(raw) == 13 else raw)
        elif d.get("isbn10"):
            val = d["isbn10"][0]
        elif d.get("isbn13"):
            val = d["isbn13"][0]
        else:
            continue
        out.append({"id": q["id"], "q": val, "class": q["class"],
                    "expect": {"type": "work", **q["book"]}, "trap": []})
    return out


def run(engine_name, by_tkey, isbn_queries):
    fn = ENGINES[engine_name]
    rows, lat = [], []
    for q in BM["queries"] + isbn_queries:
        expect = q["expect"]
        target = resolve(expect, by_tkey) if expect["type"] == "work" else None
        if expect["type"] == "work" and target is None:
            rows.append({"id": q["id"], "q": q["q"], "class": q["class"],
                         "status": "target_absent"})
            continue
        try:
            hits, ms = fn(q["q"], LIMIT)
        except Exception as e:
            rows.append({"id": q["id"], "q": q["q"], "class": q["class"],
                         "status": "error", "error": str(e)[:200]})
            continue
        lat.append(ms)
        top = hits[0] if hits else None
        if expect["type"] == "work":
            ids = [h["id"] for h in hits]
            top1 = bool(ids) and ids[0] == target["id"]
            top3 = target["id"] in ids[:3]
        else:
            top1 = bool(top) and is_author_hit(top, expect["author"]) and not top.get("is_derivative")
            top3 = any(is_author_hit(h, expect["author"]) and not h.get("is_derivative")
                       for h in hits[:3])
        tt = fold(top["title"]) if top else ""
        rows.append({
            "id": q["id"], "q": q["q"], "class": q["class"], "status": "ok",
            "top1": top1, "top3": top3,
            "trap": any(t and fold(t) in tt for t in q.get("trap", [])),
            "dups": dup_count(hits), "ms": round(ms, 1),
            "top1_title": (top["title"] if top else "")[:70],
            "top1_author": ((top.get("authors") or [""])[0] if top and top.get("authors") else "")[:40],
            "top1_ed": top.get("edition_count") if top else None,
            "expect_title": expect.get("title", "") or f"(any by {expect.get('author')})",
        })
    ok = [r for r in rows if r["status"] == "ok"]
    absent = [r for r in rows if r["status"] == "target_absent"]
    errs = [r for r in rows if r["status"] == "error"]
    n = len(ok) or 1
    by_class = defaultdict(lambda: [0, 0])
    for r in ok:
        by_class[r["class"]][0] += 1 if r["top1"] else 0
        by_class[r["class"]][1] += 1
    summary = {
        "engine": engine_name, "queries_scored": len(ok),
        "targets_absent": len(absent), "errors": len(errs),
        "top1": round(100 * sum(r["top1"] for r in ok) / n, 1),
        "top3": round(100 * sum(r["top3"] for r in ok) / n, 1),
        "wrong_work": round(100 * sum(not r["top1"] for r in ok) / n, 1),
        "trap_rate": round(100 * sum(r["trap"] for r in ok) / n, 1),
        "dup_rate": round(100 * sum(1 for r in ok if r["dups"] > 0) / n, 1),
        "median_ms": round(statistics.median(lat), 1) if lat else None,
        "p95_ms": round(sorted(lat)[min(int(len(lat) * 0.95), len(lat) - 1)], 1) if lat else None,
        "by_class": {k: f"{v[0]}/{v[1]}" for k, v in sorted(by_class.items())},
    }
    return summary, rows, absent


if __name__ == "__main__":
    engines = sys.argv[1:] or ["postgres"]
    by_id, by_tkey = load_docs()
    print(f"corpus: {len(by_id):,} docs", file=sys.stderr)
    isbn_qs = build_isbn_queries(by_tkey)
    print(f"isbn cases pinned: {len(isbn_qs)} -> {[q['q'] for q in isbn_qs]}", file=sys.stderr)

    all_summ = {}
    for e in engines:
        summ, rows, absent = run(e, by_tkey, isbn_qs)
        all_summ[e] = summ
        json.dump({"summary": summ, "rows": rows}, open(f"bench_{e}.json", "w"), indent=1)
        print(f"\n===== {e} =====", file=sys.stderr)
        for k, v in summ.items():
            if k != "by_class":
                print(f"  {k:16s} {v}", file=sys.stderr)
        if absent:
            print(f"  absent: {[a['q'] for a in absent]}", file=sys.stderr)
    json.dump(all_summ, open("bench_summary.json", "w"), indent=1)
