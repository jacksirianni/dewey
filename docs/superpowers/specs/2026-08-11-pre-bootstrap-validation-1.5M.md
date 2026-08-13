# Final Pre-Bootstrap Validation — 1.5M Works

**Date:** 2026-08-11 · **Status:** Scale validation complete. Full 41.5M bootstrap NOT run.
**Code:** [`spike/ingest_prod/`](../../../spike/ingest_prod) — `pipeline.py`, `reconcile.sql`, `build_search_v2.sql`
**Builds on:** [medium-scale report](2026-08-11-production-ingestion-medium-scale-report.md)

iOS: untouched. Wikidata: not added. Search engine: not revisited. Full
catalog: not ingested.

**Schema status: `0002_catalog.sql` unchanged.** One additive change to
`0003_reconciliation.sql` (a new `oversized_subject` anomaly kind) was
required by a concrete structural failure — documented in §5.

---

## 1. Ingestion runtime at 1.5M works

**Corpus:** 1,499,999 works · 2,571,319 editions · 1,239,382 authors — the
validated 300k medium corpus plus 1.2M additional stratified-sampled works
from the full 41.5M dump.

| Phase | 300k run | 1.5M run | Scaling vs 5× data |
|---|---|---|---|
| authors | 48.6s | ~180s (1.24M authors) | ~3.7× — **sublinear** |
| works | 199.0s | ~1,900s | ~9.5× — **superlinear** |
| editions | 454.1s | ~3,900s | ~8.6× — **superlinear** |
| signals | 11.1s | ~90s | ~8× |
| claims | 31.8s | ~250s | ~8× |
| **search (v1)** | **95.0s** | **>1,400s, terminated incomplete** | **>14×** |
| **search (v2, rewritten)** | — | **440s** | see §7 |

Phase timings for the 1.5M run are approximate because the run was
interrupted twice by genuine bugs (§5) and resumed; the wall-clock totals
below are the trustworthy figures. **Total reconcile phases (authors →
claims): ~6,300s (105 min).** Plus search: **440s with v2**, versus >1,400s
and still unfinished with v1.

**Effective throughput: ~1,500,000 works / ~6,740s ≈ 222 works/sec** end to
end (v2 search), against **357 works/sec** at 300k. **Throughput dropped
~38% for 5× the data** — real superlinearity, and precisely what this run
existed to detect.

**Editions:** 2,571,319 / ~3,900s ≈ **659 editions/sec** (vs ~1,250/sec at
300k).

**CPU/RAM:** single-threaded driver, one Postgres connection. Peak swap
usage stayed within the host's 1.0–1.4GB free throughout; no OOM, no
thrashing at any point. **WAL was not measured** — same limitation as the
medium-scale report, still unresolved and still flagged (§13).

---

## 2. Comparison with the 300k run

| Metric | 300k | 1.5M | Ratio (data = 5×) |
|---|---|---|---|
| Works | 300,000 | 1,499,999 | 5.0× |
| Editions | 568,269 | 2,571,319 | 4.5× |
| Authors | 287,403 | 1,239,382 | 4.3× |
| Database size | 1,851 MB | 9,177 MB | **4.96×** — **linear** |
| Index size | 998 MB | 4,664 MB | **4.67×** — **linear** |
| Per-work footprint | 6.2 KB | 6.1 KB | **flat** |
| Index share of DB | 53% | 51% | **flat** |
| Throughput | 357 w/s | 222 w/s | **0.62× — degraded** |

**The critical split: storage scales linearly and cleanly; throughput does
not.** Per-work footprint held at ~6.1KB across a 5× increase, and index
share stayed at ~51%. Storage extrapolation to the full catalog is
therefore trustworthy. Runtime extrapolation is not, and §3 treats it
accordingly.

---

## 3. Revised full-catalog runtime estimate

**The medium-scale report's ~32-hour figure was based on 357 works/sec and
is now known to be optimistic.** At the measured 1.5M rate of 222 works/sec,
41.5M works would take **~52 hours** — but that number assumes throughput
stops degrading, which is exactly the assumption this run disproved.

Extrapolating the observed degradation (357 → 222 works/sec, a 0.62 factor
per 5× data) forward two more 5× steps to 41.5M suggests throughput could
fall to **~85–140 works/sec**, giving a range of **~82–135 hours** — 3.5 to
5.5 days of continuous ingestion.

**Recommendation: treat any full-catalog runtime estimate as unreliable
until the specific superlinear component is identified and fixed.** The
degradation is not uniform across phases (authors scaled *sublinearly* at
3.7×; works and editions at ~9×), which strongly suggests a small number of
specific queries — not a general "everything gets slower" effect — and
therefore that it is fixable rather than fundamental. Identifying which
statements inside `reconcile_batch_works`/`_editions` degrade is the single
highest-value piece of work remaining before bootstrap (§13).

---

## 4. Revised storage estimate

Storage is the trustworthy extrapolation. At a flat **6.1 KB/work**:

| Corpus | Projected total size | Of which indexes (~51%) |
|---|---|---|
| 41.5M works (everything) | **~253 GB** | ~129 GB |
| ~20M works (post-curation, §9) | **~122 GB** | ~62 GB |
| ~10M works (aggressive curation) | **~61 GB** | ~31 GB |

Editions scale at ~1.7 per work, and the medium/scale runs bracket that
consistently (1.89 and 1.71), so these figures already include edition
storage.

**This materially changes the infrastructure conversation.** 253GB for the
full catalog on a managed Postgres is a real monthly cost; ~61GB for a
curated ~10M-work catalog is not. §9's search-eligibility work is therefore
not merely a relevance concern — it is the main lever on storage cost.

---

## 5. Nonlinear planner/index behaviour and structural failures

Three distinct problems, all first observed at this scale, all fixed:

### 5a. Phase-boundary ANALYZE was insufficient (fixed)

The medium-scale fix ran `ANALYZE dewey.identifier` once per phase
*boundary*. At 300k that was 60 batches per phase; at 1.5M it is ~300
batches, and `identifier` grows continuously throughout a phase (every
work/edition batch mints new rows). A `reconcile_batch_works` call was
observed running **1m42s and climbing** partway through the works phase.

**Fix:** `ANALYZE dewey.identifier` every 20 batches *within* each phase,
not only at boundaries. This is the third distinct manifestation of the same
root cause (after temp tables and staging tables at 300k), and the pattern
is now unambiguous: **any table that grows during a bulk phase and is joined
against within that phase needs periodic re-ANALYZE, sized to the phase's
batch count, not the phase's existence.**

### 5b. Oversized subject strings exceeded the btree index limit (fixed)

**A hard `ProgramLimitExceeded` error stopped the pipeline outright:**

```
index row size 3032 exceeds btree version 4 maximum 2704 for index "subject_unique"
```

Real OL data: some `subjects` entries are not subject headings at all. Three
observed examples — a 592-char semicolon-joined list of Thai author names
with birth/death years; a 1,009-char Arabic spam hashtag string; a 698-char
bilingual real-estate glossary paragraph.

**This is the one finding that required a schema change**, and it is
additive-only: a new `oversized_subject` value in `0003_reconciliation.sql`'s
`anomaly_kind` enum, plus a 250-character guard in `reconcile.sql` that
rejects the field and logs it. `0002_catalog.sql` was **not** modified —
`dewey.subject.label` remains unconstrained `text`; the guard lives in the
ingestion layer where a data-quality rule belongs. 111 such subjects were
rejected across 1.5M works (0.07 per 1k works).

**Notably: never observed at 7k or 300k works.** A guard nobody would have
written speculatively, found only by running at scale against real data.

### 5c. `build_work_search()` is pathologically superlinear (fixed, §7)

---

## 6. Repeat-import churn at 1.5M

A 300,000-work representative subset (504,356 editions, 300,922 authors)
re-imported into the fully-loaded 1.5M database:

| Metric | Before | After | Delta |
|---|---|---|---|
| Database size | 9,178 MB | 9,214 MB | **+37 MB (+0.40%)** |
| Index size | 4,664 MB | 4,672 MB | **+8 MB (+0.17%)** |

Dead tuples after the repeat, on every catalog table: **≤0.33%**
(`identifier` 0.15%, `work_contributor` 0.32%, `work_title` 0.33%,
`source_record` 0.33%, `subject` 0.10%).

**The guarded-upsert fix holds at 1.5M scale.** Re-importing 20% of the
catalog cost 0.4% growth — the same behaviour measured at 300k, now
confirmed at 5× the data. `last_seen_at` churn remains near-zero thanks to
the 1-day threshold. Search-projection churn was not measured on this repeat
because the run reached the v1 search build and was terminated (v1 being
known-pathological); at 300k the equivalent measurement was **0 rows
written**, and v2 preserves the same guarded upsert clause.

---

## 7. `build_work_search` — the dominant superlinear component, and its fix

**v1 (correlated subqueries):** 95s at 300k → **>23 minutes at 1.5M without
completing**, CPU-bound the whole time, before being terminated. The
function computes each work's authors, alt-titles, ISBNs, languages and
subject blob via six correlated subqueries in the SELECT list, each
re-executed per work row against tables that are themselves growing.

Confirmed **not** a stale-statistics problem — an explicit `ANALYZE` of all
eight input tables runs immediately before it.

**v2 (set-based aggregation, [`build_search_v2.sql`](../../../spike/ingest_prod/build_search_v2.sql)):**
each aggregate computed **once** for the whole catalog as a grouped CTE,
then hash-joined onto `work`. Same output columns, same guarded upsert, zero
correlated subqueries.

**Result: 7m20s (440s) for all 1,499,999 rows** — versus v1 unfinished at
23+ minutes. At least **3.2× faster**, and the true ratio is larger since v1
never completed. v2's profile is also different in kind: I/O-bound (hash
aggregates spilling to disk on an 8GB machine) rather than CPU-bound, which
means it benefits directly from more RAM — a much better scaling property
for a production box.

**Recommendation: v2 replaces v1 for bootstrap and any full-catalog
rebuild.** v1's shape is acceptable only for small incremental updates where
the per-row cost is bounded by a handful of rows.

---

## 8. Publication-date coverage — correcting the previous report

**The medium-scale report's "89.34% of OL works have no publish date" was
interpretation A (no work-level field), and quoting it without that
qualifier was misleading.** Measured properly at 1.5M, after edition
aggregation:

| Category | Works | % |
|---|---|---|
| Work-level publication year present | 207,557 | **13.84%** |
| Missing at work level, **recoverable from editions** | 1,266,400 | **84.43%** |
| **No usable publication information anywhere** | 26,042 | **1.74%** |

**The real figure is 1.74%, not 89.34%.** Edition aggregation recovers a
publication year for the overwhelming majority of works. This substantially
weakens the previous report's suggestion that missing publish dates should
serve as an obscurity signal — they mostly aren't missing, they're just not
at the work level.

**Conflicting/implausible edition histories** (checked before recommending a
rule, as instructed):

| Check | Works | % of dated |
|---|---|---|
| Edition-date span > 100 years | 8,300 | 0.56% |
| Span > 200 years | 1,563 | 0.11% |
| Earliest edition before 1450 (pre-printing-press) | 61 | 0.004% |
| Pre-1800 min **and** post-1980 max | 951 | 0.06% |

Inspecting the worst cases rather than assuming they are errors:

- **"Bible"** — min 1200, max 2025, across **5,973 editions**. Not a data
  error. A genuinely correct earliest date for a work with a 800-year
  edition history.
- **"De fato et fortuna"** — min 1400, max 1985, 3 editions. A real medieval
  text.
- **"Warka--Gülşa"** — min 1111, max 2005, 2 editions. Plausibly a real
  historical work, possibly a data error; indistinguishable without
  case-by-case review.

**Recommendation: derive `first_published_year` as the minimum edition year,
but only when the span is plausible.** Concretely: use `min(published_year)`
when the span ≤ 100 years (99.44% of cases); when the span exceeds 100
years, flag for review rather than silently taking the minimum, since those
are the cases where the minimum may be either genuinely correct (Bible) or
a transcription error, and the two cannot be distinguished automatically.
**Do not blindly take the earliest edition** — but note that the failure
mode affects well under 1% of works.

---

## 9. Canonical catalog vs consumer search eligibility

### Canonical catalog eligibility — broad, essentially unrestricted

A record stays in the Dewey catalog if it exists upstream, because:
identifiers must keep resolving; a user may already reference it; it may be
merged later; metadata may improve; force-import may create it; and
historical user data must remain durable. **The only records worth refusing
outright are structurally unusable ones** — 1 work with an empty title
across 1.5M (0.00007%). Everything else gets a row.

### Consumer search eligibility — stricter, derived, reversible

Measured signal distribution at 1.5M:

| Signal | Works | % |
|---|---|---|
| Zero editions | 4,938 | 0.33% |
| No resolvable author | 58,490 | 3.90% |
| No ISBN | 550,524 | 36.70% |
| No publication year (after edition aggregation) | 1,292,442 | 86.16%* |
| No cover | 993,225 | 66.22% |
| Flagged derivative (study guide etc.) | 2,490 | 0.17% |
| Completeness ≤ 20 | 158,599 | 10.57% |
| Completeness ≥ 60 | 574,641 | 38.31% |
| **Thin on every axis** (≤1 edition, no author, no ISBN, no cover) | **31,612** | **2.11%** |

\* *This is the `work.first_published_year` column, which the pipeline does
not currently backfill from editions — §8 shows the data exists. Backfilling
it is a prerequisite to using year as a search signal.*

**Recommendation:**

1. **Suppress from search, don't delete:** works with zero editions (0.33%)
   and works thin on every axis (2.11%). Combined, roughly **2.4%** of the
   catalog — a genuinely small suppression set, which is reassuring: it means
   the corpus is mostly real books, not junk.
2. **Implement suppression as a derived, reversible column** —
   `work_search.suppressed boolean` computed at projection time from
   signals, never a deletion and never a flag written on `dewey.work`.
   Rebuilding `work_search` re-derives it; changing the rule is one rebuild,
   not a migration.
3. **Do not suppress on any single weak signal.** No-ISBN (36.7%),
   no-cover (66.2%), and no-year (86.2%, and mostly recoverable) are each
   far too common to filter on — suppressing on any one would remove
   hundreds of thousands of real, findable books.

---

## 10. Study guides / summaries / criticism

**Title patterns are the only signal that works. Everything else measured
was useless.**

| Signal | Result |
|---|---|
| Title pattern (current classifier) | 2,490 works flagged (0.17%) |
| — branded series (SparkNotes/CliffsNotes) | 163 |
| — literal "study guide" | 720 |
| — "Summary of…" / "Summary and analysis" | 862 |
| — "Companion to" / "Critical essays" / "Readings on" | 702 |
| **Edition count** | study_guide **1.47** vs book **1.71** — *not usefully different* |
| **Completeness** | study_guide **44.1** vs book **46.8** — *not usefully different* |

**The negative result is the finding.** Study guides are statistically
indistinguishable from ordinary books on the structural signals available
(edition count, completeness). They do not have systematically fewer
editions or sparser metadata. Any classifier must work from **text** —
title patterns now, and the publisher-denylist approach recommended in the
prototype report (BookCaps, Trivium, Instaread, Everest Media) as the
strongest untested addition, since publisher is a field we already ingest.

**Not building a production classifier**, per instruction. The current
title-pattern rule catches 2,490 works; the prototype report already
documented it missing a plainly-titled companion volume, so recall is
certainly imperfect. Given they are only 0.17% of the corpus, this is a
relevance-tuning concern, not a bootstrap blocker.

---

## 11. Duplicate-like works

Measured at 1.5M, with the legitimate/duplicate distinction the brief asked
for:

| Signal | Count | Interpretation |
|---|---|---|
| Titles shared by **different** authors | 57,701 | **Legitimate collisions — do NOT merge.** Different books that happen to share a title |
| Same normalized title **AND** shared author | 13,522 | **Probable bibliographic duplicates** — merge candidates |
| Same ISBN across **different** works | 4,015 | **Strongest duplicate signal** — an ISBN identifies one physical product |

**Only 19% of title collisions (13,522 of 71,223 total) share an author.**
The other 81% are legitimately different books — which is exactly why
`merge_works()` requires a shared author signal and never operates on title
alone, and why the previous report's raw "35.39% title-collision rate" badly
overstated the duplicate problem.

Cross-work ISBN collisions (4,015) are the highest-confidence queue and the
natural place for a human/heuristic merge process to start. **Nothing is
auto-merged**, per instruction.

---

## 12. Reconciliation queue scaling

| Queue | 300k | 1.5M | Per 1k works (1.5M) | Scaling |
|---|---|---|---|---|
| `malformed_identifier` (ISBN) | 3,192 | 10,214 | 6.81 | 3.2× — **sublinear** |
| `unresolved_contributor_name` | 6,180 | 9,625 | 6.42 | 1.6× — **strongly sublinear** |
| `unknown_contributor_role` | 4,088 | 7,276 | 4.85 | 1.8× — **sublinear** |
| `isbn_collision` | 1,334 | 5,463 | 3.64 | 4.1× — **~linear** |
| `impossible_page_count` | 80 | 209 | 0.14 | 2.6× |
| `oversized_subject` | — | 111 | 0.07 | new (§5b) |
| `dangling_source_reference` | 4 | 8 | 0.01 | 2.0× |

**No queue grows disproportionately. Every one scales sublinearly or
linearly against 5× data — none require pipeline changes before bootstrap.**

The standout is `unresolved_contributor_name` at **1.6× for 5× data** —
strong confirmation of the widened-author-resolution hypothesis: as the
author corpus grows, a larger fraction of free-text contributor names find
an exact match. Contributor resolution improved from 61.3% at 300k to
**72.4%** at 1.5M (25,325 resolved vs 9,625 queued), with no fuzzy matching
anywhere.

Extrapolated to 41.5M, total open anomalies would be roughly **600k–900k** —
large but manageable as a reviewable queue, and dominated by field-level
rejections that need no human action.

---

## 13. Remaining blockers before the 41.5M bootstrap

**Blocking:**

1. **Identify the superlinear component in `reconcile_batch_works` /
   `_editions`.** Throughput fell 38% for 5× data, and the degradation is
   phase-specific (authors scaled *sub*linearly), which means it is a small
   number of statements, not a general effect. Without this, no full-catalog
   runtime estimate is trustworthy (§3). This is the single highest-value
   remaining task.
2. **Decide the search-eligibility rule and implement `suppressed` as a
   derived column** (§9). At 253GB projected for the full catalog versus
   ~61GB curated, this is a cost decision as much as a relevance one.
3. **Backfill `work.first_published_year` from editions** (§8). The data
   exists for 84.43% of works that currently show NULL; until it is
   populated, year is unusable as either a ranking or eligibility signal.

**Non-blocking but should be resolved:**

4. **WAL volume remains unmeasured** — flagged in the medium-scale report,
   still unmeasured here. Needs measuring on production-shaped hardware
   before a multi-day bootstrap is scheduled, particularly for its
   interaction with Supabase's replication and backup posture.
5. **Disk headroom on the test host is exhausted** (~12–16GB free
   throughout; the 1.5M database alone is 9.2GB). Full-catalog work cannot
   happen on this machine at all — 253GB projected. Not a code problem, but
   a hard constraint on where the bootstrap runs.
6. **v2 search build is I/O-bound and spills to disk** on 8GB. It will
   benefit substantially from more RAM; `work_mem` tuning should be part of
   bootstrap configuration rather than left at defaults.

**Explicitly not blockers:** the anomaly queues (§12, all scale sublinearly);
duplicate-work volume (§11, only 19% of collisions are real candidates);
study-guide classification (§10, 0.17% of corpus); repeat-import churn (§6,
+0.40%); and storage *predictability* (§2, per-work footprint flat across
5×).

---

**Stop condition met.** ~1.5M real works ingested; repeat import measured;
storage/index growth characterised as linear and per-work-flat; the
publication-date question answered correctly and the previous report's
figure corrected; canonical-catalog and consumer-search eligibility
separated with measured signal distributions; study-guide and duplicate-work
findings reported with their negative results intact; queue scaling
measured. **`0002_catalog.sql` unchanged; one additive `0003` enum value
added in response to a concrete, reproducible structural failure.** Full
41.5M catalog not ingested.
