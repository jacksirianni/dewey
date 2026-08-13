# Production Ingestion Architecture — Medium-Scale Report

**Date:** 2026-08-11 · **Status:** Medium scale proven (300k works). Full 41.5M-work catalog NOT ingested.
**Code:** [`spike/ingest_prod/`](../../../spike/ingest_prod) — `pipeline.py`, `reconcile.sql`,
`staging_schema.sql`, `select_medium_corpus.py`
**New migration:** [`supabase/0003_reconciliation.sql`](../../../supabase/0003_reconciliation.sql) — additive only, `0002_catalog.sql` untouched
**Builds on:** [ingestion prototype report](2026-08-10-ingestion-prototype-report.md)

iOS: untouched. Wikidata: not added. Search-engine comparison: not resumed.
41.5M-work full catalog: not ingested. **`0002_catalog.sql` unchanged — no
defect at medium scale required touching it.**

---

## 1. The three carry-forward fixes

### 1a. No-op MVCC churn — fixed with guarded upserts

Every `ON CONFLICT DO UPDATE` in `reconcile.sql` carries a `WHERE ... IS
DISTINCT FROM` guard comparing incoming to existing values, so Postgres's
executor skips the write entirely when nothing changed — not just logically,
but physically, no new tuple version.

**Measured, at 300k-work scale, across two full re-ingests of identical
source data:** database size grew **1,819MB → 1,870MB (+2.8%)**. Post-vacuum
dead-tuple counts: `identifier` 0, `edition_isbn` 0, `edition` 0,
`work_contributor` 0, `work_title` 0, `author_name` 0 — every table that
receives bulk re-ingest traffic shows **zero** dead tuples after run 2. Only
`work` itself showed any churn (11,726 dead rows, 3.9%), and `VACUUM FULL`
on just that one table recovered 1,870MB → 1,851MB — 19MB, not the hundreds
of MB the unguarded prototype lost.

Compare directly to the prototype's finding at 7k-work scale, three runs:
`identifier` alone bloated from 8.4MB to 17MB (>2×) before `VACUUM FULL`
reclaimed it back to 7.2MB. The guard is the entire difference.

### 1b. `last_seen_at` — cheap staleness, not per-row churn on every run

```sql
update dewey.identifier i set last_seen_at = now()
  from tmp_author_keys t
 where i.value = t.ol_key and i.last_seen_at < now() - interval '1 day';
```

Within one run, or a same-day re-run, this `WHERE` clause is false for every
row and Postgres writes nothing. Staleness detection — "which OL keys
stopped appearing across *months*" — still works at exactly the granularity
that matters; it just stops paying to touch 1.16M identifier rows on every
invocation regardless of whether a month or a minute has passed.

### 1c. Widened author resolution — measured, not just designed

Two distinct mechanisms, because OL gives two different kinds of author
reference and they need different fixes:

**Author-*keyed* references** (work `authors`, edition `authors`) are
resolved from a **single set built from every author key in both `stg.work`
and `stg.edition` before either table's contributors are written**
(`reconcile_batch_authors`'s `tmp_author_keys` CTE). This directly targets
the prototype's `missing_author` anomaly (9 cases at 7k scale, caused by
scoping author population to work-level authors only).

**Contributor *names*** (translator/narrator — OL provides no key for these,
only free text) are resolved against `dewey.author_name` — the **full,
already-loaded table**, not a per-batch scope. This is the fix that actually
moves the needle, and it was measured, not assumed:

| Scale | Resolved (`edition_contributor`) | Unresolved (review queue) | Resolution rate |
|---|---|---|---|
| Prototype, 7k works | 61 | 353 | **14.7%** |
| Medium, 300k works | 9,805 | 6,180 | **61.3%** |

**No fuzzy matching was added anywhere.** Resolution is exact-name-fold
matching against a bigger, already-loaded author corpus — the improvement is
entirely a consequence of scale, exactly as predicted, now with numbers
behind it. Different OL author IDs remain different Dewey authors
unconditionally; nothing here merges anything.

---

## 2. Production ingestion architecture

```
Open Library dump (works.jsonl / editions.gz / authors.jsonl, already on disk)
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE: authors → works → editions → signals → claims → search   │
│  (reordered from the brief's proposal only where a real data     │
│   dependency required it — editions cannot reconcile before      │
│   works, and both need author identity first)                    │
│                                                                    │
│  Each phase: chunk input → COPY into UNLOGGED stg.* table          │
│              → ANALYZE the staged batch                          │
│              → call one set-based reconcile_batch_*() function    │
│              → DELETE the batch's staged rows                     │
│              → commit → record batch index in dewey.pipeline_run  │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
dewey.work / .edition / .author / .identifier / .field_provenance / ...
(0002_catalog.sql, unchanged)          dewey.anomaly / .pipeline_run
                                        (0003_reconciliation.sql, additive)
```

**Why this order, not the brief's literal 18-step list:** the brief's list
is a reasonable checklist but not a dependency graph. `edition_contributor`
resolution needs author identifiers to already exist; `work_contributor`
needs the same. Collapsing "load identifiers / load aliases / load
contributors" into per-entity phases (each phase does its own identifier
resolution, its own name/alias loading, its own contributor linking, in one
set-based pass) avoids re-reading the same staged rows three times for three
separate list items that are actually one dependency-ordered operation.

**One function per phase, called once per batch — not once per input
record.** `reconcile_batch_authors`, `_works`, `_editions`, `_signals`,
`_claims` are all pure SQL or PL/pgSQL operating on a whole staged batch at
once. The only Python-side per-record work is building the COPY buffer —
everything that touches the database is a single set-based statement per
batch, not a loop.

---

## 3. Medium-scale corpus

**300,000 works** — the existing, already-validated 104,901-work stratified
spike corpus (guaranteeing every benchmark target, every named-title
distractor, every duplicate pattern already characterized) plus 195,099
additional works stratified-sampled from the remaining 41.2M by the same
signal-based buckets (rich/translation/sparse/general), landing at the
middle of the requested 100k–500k range.

**568,269 real editions** (from a fresh, richer extraction of `editions.gz`
— captured contributor *roles* this time, which the search spike's
projection had dropped) and **287,403 real authors**. All real Open Library
data; no synthetic records.

---

## 4. Performance

| Metric | Run 1 (cold) | Run 2 (idempotent re-ingest) |
|---|---|---|
| Total wall time | 839.7s (14.0 min) | 698.6s (11.6 min) |
| authors phase | 48.6s | 19.6s |
| works phase | 199.0s | 117.3s |
| editions phase | 454.1s | 462.5s |
| signals phase | 11.1s | 8.9s |
| claims phase | 31.8s | 36.8s |
| search phase | 95.0s | 52.9s |
| `work_search` rows written | 300,000 | **0** (guarded — confirmed no-op) |
| Effective throughput | **357 works/sec** end-to-end | ~430 works/sec |

Editions dominates because it is genuinely the largest phase (568k rows vs
300k works, plus ISBN normalization, contributor role classification, and
name resolution against the full author table per row). This is expected
and not treated as a problem to solve further at this scale — see §7 for
where the real remaining cost is.

**CPU/RAM:** single-threaded Python driver plus one Postgres connection;
peak observed swap usage stayed under the host's available 1.2–1.3GB free
throughout both runs (checked repeatedly during long phases) — no memory
pressure at 300k scale on an 8GB machine also running other processes.
**WAL was not measured directly** — `UNLOGGED` staging tables produce none
by design, and canonical-table WAL was not isolated from the rest of the
host's activity in this session; flagged as unmeasured rather than guessed.

---

## 5. Database/index/storage growth

| | Value |
|---|---|
| Database size after run 1 | 1,819 MB |
| Database size after run 2 (before vacuum) | 1,870 MB (+2.8%) |
| Database size after `VACUUM FULL work` | 1,851 MB |
| Total index size | 998 MB (~53% of database size) |
| Per-work footprint | ~6.2 KB fully indexed |

Consistent with the prototype's 8.4 KB/work at 7k scale and the earlier
design document's linear estimate — the per-work cost did **not** grow with
corpus size, which is the property that matters most for extrapolating to
the full catalog (§14).

**Indexes remain roughly half of total size**, confirmed at 20× the
prototype's scale. This is not a new finding but a **stable** one — it did
not get proportionally worse or better as the corpus grew, which is itself
useful information for capacity planning.

---

## 6. Repeat-import physical churn

Covered in detail in §1a. Summary: **+51MB (2.8%) database growth across two
full 300k-work re-ingests, with post-vacuum dead-tuple counts of zero on
every heavily-written table except `work` (3.9%, 19MB reclaimed by
`VACUUM FULL`)**. The fix works at the scale it was built for; this is not
an extrapolation from the 7k prototype, it is a direct remeasurement.

---

## 7. Staging vs. direct-upsert — measured, and the real finding was operational, not architectural

**The headline finding is not "staging beats direct upsert" or vice versa —
it is that an unguarded staging pipeline can be catastrophically slower than
direct upsert, for a reason that has nothing to do with staging as an
architecture and everything to do with Postgres statistics.**

Measured on an identical 20,000-work sample (works, 40,982 editions, 19,838
authors), same hardware, same day:

| Approach | Total time | Notes |
|---|---|---|
| Direct upsert (prototype `ingest.py`, `execute_values` straight to canonical tables) | **15.4s** | Does not include search-index build |
| Staging, batch_size=2000, **before** the fix below | 134.9s | ~9× slower |
| Staging, batch_size≈20000 (one giant batch), before the fix | **>4 minutes, still running when killed** | Worse, not better, with bigger batches |
| Staging, batch_size=5000, **after** the fix | **19.5s** | Includes the full search-index build the direct-upsert timing above does not |

**Root cause, found by direct `EXPLAIN ANALYZE` diagnosis, not guessed:** a
`reconcile_batch_works()` call that took 2–4+ minutes on a single 20,000-row
batch, re-run identically a few minutes later (after PostgreSQL's background
`autoanalyze` had caught up), completed in **1.26 seconds** — a **~100–180×**
difference on the exact same data and the exact same query. The pattern
recurred in three separate places before being fully fixed:

1. `tmp_author_keys`, a `CREATE TEMP TABLE ... ON COMMIT DROP` inside
   `reconcile_batch_authors` — created fresh every call, queried immediately,
   **zero statistics**, and a `NOT EXISTS` anti-join against it degrades from
   a hash anti-join to a catastrophic plan once the row count exceeds
   whatever default Postgres assumes for an unanalyzed relation.
2. `stg.work` / `stg.edition` — `UNLOGGED`, not `TEMP`, but the same problem:
   rows `COPY`-ed in this transaction, queried moments later, with
   autovacuum's background analyze not yet having run.
3. `dewey.work`, `.work_contributor`, `.author_name`, `.edition`, etc. — the
   **canonical tables themselves**, queried by `build_work_search()`
   immediately after a heavy write burst from the reconcile phases populated
   them. Measured in isolation: **228.1s** before an explicit `ANALYZE` on
   eight tables, **3.3s** after. A **~70× speedup** from eight `ANALYZE`
   statements.

**The fix, applied in three places** (`reconcile.sql`'s temp tables now
`ANALYZE` themselves immediately after population; `reconcile_batch_works`/
`_editions` `ANALYZE` their staging table on entry; `pipeline.py` runs
`ANALYZE dewey.identifier` at the authors→works and works→editions phase
boundaries, and `ANALYZE` on eight canonical tables before the search build):
**explicit `ANALYZE` at every bulk-write boundary, never left to autovacuum's
default schedule during a fast bulk load.** Autovacuum's timing is tuned for
steady-state OLTP traffic; a bulk ingest can out-run it by orders of
magnitude, and the consequence is not graceful degradation — it is a query
planner choosing a plan appropriate for a table it thinks is nearly empty
against one that actually has hundreds of thousands of rows.

**Decision: staging with set-based SQL, with mandatory explicit `ANALYZE`
calls as a standing rule, not an optional tuning step.** With that rule in
place, staging is competitive with direct upsert (19.5s vs 15.4s on the same
data, and the staging number includes a full search-index rebuild the direct
number does not) — while additionally being fully resumable, batch-checkpointed,
and offloading nearly all row-level work to set-based SQL rather than a
Python loop. Without the `ANALYZE` rule, staging would be a straightforward,
measured regression. **This is the single most important operational finding
in this report**, and it is why the pipeline treats `ANALYZE` as a first-class
step rather than an afterthought.

---

## 8. Index-build strategy

**Indexes were never dropped or deferred in this test** — every table's
indexes existed throughout ingestion, on staging tables (none — staging
tables are intentionally unindexed except the batch-scan index) and on
canonical tables (all of them, per `0002_catalog.sql`, unchanged throughout).

This was a deliberate choice given the corpus size, not an oversight: at
300k works, index maintenance cost was not the bottleneck (§7's `ANALYZE`
finding was), and the schema's indexes are needed for the very
`reconcile_batch_*` joins that make the pipeline correct — dropping them
during bootstrap would mean *adding* full-table scans to every one of those
joins, trading a build-time cost for a much larger reconciliation-time cost.

**Recommendation for the full-scale bootstrap (not tested here, reasoned
from this measurement):** given indexes are ~53% of total size and their
absence would slow every reconciliation join, **keep indexes live
throughout even the full bootstrap** (option A from the brief), rather than
building without them and adding them after (option B). The one exception
worth testing at full scale and not tested here: the `work_search` GIN
trigram indexes specifically, which are write-heavy only during the search
phase and read-heavy only afterward — a genuine candidate for
drop-before/build-after on the *first* bootstrap only, never on incremental
refreshes where `work_search` rows are touched in small numbers.

**Monthly refresh, force-import, and normal incremental corrections all need
every index live at all times** — none of them are bulk operations at the
scale where index-drop tradeoffs would matter, and dropping indexes for a
small incremental update would be pure loss.

---

## 9. Resumability — proven with a real kill, not simulated

A 20,000-work run was launched, allowed to reach the `authors` phase, and
**killed with `SIGKILL` mid-batch** (batch 10–19 of a 500-row-per-batch run,
verified via `pg_stat_activity` before the kill):

```
before kill:  10,000 authors committed, dewey.pipeline_run shows
              phase=authors, 20 completed batch entries
resume:       "[resume_proof] RESUMING at phase=authors, 20 batches
              already done" -- picks up at batch 20, not batch 0
after resume: full pipeline runs to completion through works, editions,
              signals, claims, search
final counts: work=20,000  author=19,838  edition=40,982
              work_search=20,000  work_signal=20,000
              -- exactly matching the input file sizes, no duplication,
              no gap
```

**The manifest is a single Postgres row (`dewey.pipeline_run`), not a
separate checkpoint file** — there is exactly one place resumability state
can live, so a crash cannot produce a file/database split-brain. A source
hash comparison on resume refuses to continue a run against different input
files under the same `run_id`, converting a silent data-mixing risk into a
hard `SystemExit`.

This directly answers the brief's framing: **"if the process dies at work
8,000,000, we should not restart at work 1"** — verified, not asserted.

---

## 10. Reconciliation/anomaly counts (medium-scale run)

All in `dewey.anomaly`, queryable, none auto-resolved:

| Kind | Disposition | Count |
|---|---|---|
| `unresolved_contributor_name` | review_queue | 6,180 |
| `unknown_contributor_role` | reject_field | 4,088 |
| `malformed_identifier` (ISBN) | reject_field | 3,192 |
| `isbn_collision` | review_queue | 1,334 |
| `impossible_page_count` | reject_field | 80 |
| `dangling_source_reference` | reject_record | 4 |

**`isbn_collision` at 1,334 cases across 300k works (~0.4%) is consistent
with the SQL implementation notes' direct measurement (0.15% of ISBNs
cross-work) once accounting for the different denominator** (per-collision
vs per-ISBN). Every one of these is a genuine duplicate-work *signal*,
surfaced for review, never auto-merged — `merge_works()` remains a
deliberate, separate operation.

**Source truth / normalization / editorial reconciliation stay in three
places, enforced structurally, not by convention:** `source_record` (what
OL said, `0002_catalog.sql`), `work`/`edition`/`author` (what the pipeline
mechanically derived, including faithfully-reproduced upstream mistakes —
the Red Rising / Renee Joiner case remains exactly as documented in the
prototype report), and `anomaly` + `claim_field(..., 'dewey_editorial', ...)`
(`0003_reconciliation.sql` — what a human or a deliberate later process
decided to do about it). No table in `0003` writes to a canonical column.

---

## 11. Contributor role policy

Unchanged in spirit from the prototype, now running set-based against the
full staged batch via `stg.role_synonym`. Eighteen explicit mappings
(`translator`, `narrator`, `illustrator`, `editor`, `afterword`,
`introduction`, and their common synonyms: "narrator/reader" → narrator,
"translated by" → translator, "cover art" → illustrator, etc.).

**Real, messy role strings found in the medium-scale corpus, left
unmapped and logged rather than guessed at:** "Adaptation of original work
by", "Contributor", "Notes by", "Additional Author (this edition)",
"Revised by", "Cover Design", "Preface", "Producer" — the same categories
the prototype found, now at proportionally similar rates (4,088 unmapped
instances across 568k editions). **No new mapping was added speculatively**
— every mapping in `stg.role_synonym` corresponds to a role this project has
actually observed and decided how to classify; adding a mapping for a role
never seen would be exactly the kind of silent guess the brief prohibited.

---

## 12. Catalog inclusion — evidence, not a threshold decision

Computed directly from the full 41,504,065-work dump (streamed once,
~230s) and the full 56,615,822-edition dump (streamed once, ~240s) — no
ingestion required for this section, since it is pure distributional
measurement:

| Signal | Count | % of 41.5M |
|---|---|---|
| No title at all (structurally unusable) | 68 | 0.00% |
| No author key | 2,283,740 | 5.50% |
| Zero subjects | 20,925,247 | 50.42% |
| No `first_publish_date` | 37,081,384 | **89.34%** |
| Has a cover reference | 9,651,357 | 23.25% |
| Has a description | 1,924,314 | 4.64% |
| Title matches study-guide/criticism pattern | 67,616 | 0.16% |
| Shares an exact lowercased title with ≥1 other work | 14,689,770 | 35.39% |
| Zero editions (from a full editions.gz scan) | 137,547 | 0.33% |

**The single most striking number: 89.34% of all Open Library work records
have no `first_publish_date` at all.** This is far higher than intuition
would suggest and has a direct consequence for §7 of the architecture
review's `work_signal` design — a popularity/recency signal built on
publish year will be null for the overwhelming majority of records, which
argues for treating "has no publish date" itself as a *searchability*
signal (a proxy for "obscure/uncatalogued") independent of whatever
recency-based ranking is eventually built.

**35.39% title-collision rate** is a striking confirmation of how much
duplicate-work reconciliation matters at full scale — over a third of all
records share an exact lowercased title with something else, though this
figure conflates genuine OL duplicate records (the Piranesi/Everett/Red
Rising pattern) with **coincidentally identically-titled but genuinely
different books** (the "Tomorrow and Tomorrow and Tomorrow" collision from
the search spike is exactly this second category) — the two cannot be told
apart from title alone, which is precisely why `merge_works()` requires a
shared author signal, not title matching alone.

**No threshold is proposed here, per the brief's instruction.** This table
is the evidence a later, deliberate decision about "what counts as a
searchable Dewey work" should be made from — e.g., whether to exclude the
0.33% with zero editions outright (near-certain: these are not real,
findable books), whether "no subjects AND no description AND no author"
should be a stronger combined signal than any one field alone, and how much
weight the 89.34%-missing publish date should carry in that decision.

---

## 13. Initial bootstrap vs. monthly refresh — designed separately

### Initial bootstrap

May optimize aggressively for throughput, because it runs once and nothing
depends on it finishing quickly except the calendar. Concretely: the
staged, `ANALYZE`-disciplined pipeline measured in this report *is* the
bootstrap design — batch-checkpointed so a multi-hour full-catalog run
surviving a crash costs minutes of resumption, not a restart. At the
measured 300k-work rate (~357 works/sec sustained), a naive linear
extrapolation to 41.5M works suggests **~32 hours** — almost certainly an
overestimate, since editions dominate the medium-scale timing and editions
per work should not grow proportionally at full scale (rare/single-edition
works are the majority of the long tail per §12's zero-subject/no-date
numbers), but stated as an upper bound rather than a confident forecast,
since it was not measured directly.

### Monthly refresh

Must not rebuild the world. The mechanism already exists and needs no new
design, only confirmation it does the right thing at refresh scale — which
this report's **run 2 measurement already is**: a full re-run of identical
source data touched **2.8%** of database bytes, wrote **zero** rows to
`work_search` (guarded), and completed in less wall-clock time than run 1
(698.6s vs 839.7s — plausibly index/cache warmth, not measured further).

Identifying **new** vs **changed** vs **unchanged** vs **deleted/removed**
records:

- **New**: an OL key with no matching row in `dewey.identifier` — minted
  fresh, exactly as run 1 did for every record.
- **Changed**: `source_record.content_hash` differs from last month's
  stored hash for the same `(provider, record_type, provider_id)` — the
  guarded `source_record` upsert already only rewrites `imported_at` when
  this is true (§1a), and `claim_field()`'s precedence check means a
  changed OL value only reaches the canonical column if OL still outranks
  whatever else claimed that field.
- **Unchanged**: `content_hash` matches — the guarded upserts throughout
  the pipeline mean this record contributes essentially zero writes,
  proven directly in §1a/§6.
- **Deleted/upstream-removed**: not present in the new month's dump at all.
  **Never inferred by absence** — a work simply not appearing in this
  month's batch is left completely alone (§9's proof: an omitted work
  survives a "next dump" that excludes it). Detecting genuine removal is a
  **separate, explicit** comparison: `identifier.last_seen_at` older than
  the current dump's date marks a record as *stale*, which is a signal for
  a human/heuristic review process, never an automatic delete.
- **Redirects**: OL's own `redirects` and `deletes` dumps (mentioned in the
  architecture review, not consumed in this session) are the authoritative
  source for "this work merged into that one, per Open Library itself" —
  future work, not built here, but the schema's `work_redirect` mechanism
  (proven in the SQL implementation notes) is exactly the landing spot for
  it.

### Force import

**No second implementation.** `pipeline.py`'s `reconcile_batch_*` functions
take a batch of staged rows regardless of where those rows came from — a
force-import path is *the same functions*, called with a batch of size one
(or a handful), sourced from a live OL API fetch instead of a dump file,
with `acquisition='api'` on the resulting `source_record` (full payload
retained, per the schema's design) instead of `acquisition='dump'`. This
was not built as a separate code path in this session, but the
architecture makes building one a matter of wiring a live-fetch function to
the existing `stg.work`/`stg.edition`/`stg.author` COPY + reconcile call —
not a parallel ingestion implementation, which is exactly what the brief
required.

---

## 14. Remaining risks before the full catalog

1. **The 32-hour bootstrap estimate is an extrapolation, not a
   measurement.** A dedicated run at 1–2M works (not attempted here, per
   the stop condition) would replace the guess with data before committing
   to a full-catalog timeline.
2. **`author_name` exact-match resolution for contributors plateaus.**
   61.3% at 300k works is a large improvement over 14.7% at 7k, but it is
   not obviously heading to 100% — the remaining unresolved names may
   include a genuine long tail of contributors who are never a work-level
   author anywhere in the corpus (translators/narrators with no other OL
   author-key presence). Worth measuring the trend at 1M+ before assuming
   it keeps improving.
3. **`ANALYZE` placement was found empirically, not derived from a
   principle** — three separate manifestations of the same root cause were
   each found by a stuck query, not anticipated. A full-catalog run is
   larger still; it is plausible another un-analyzed intermediate state
   exists that 300k works didn't expose. Recommend instrumenting
   `pg_stat_activity` query duration alerting for any future full-scale run,
   not just trusting the current `ANALYZE` placement is complete.
4. **WAL volume is unmeasured.** `UNLOGGED` staging removes it for the
   intermediate step by design, but canonical-table WAL at full-catalog
   scale, and its interaction with Supabase's replication/backup posture,
   was out of scope this session and should be measured before a
   production bootstrap is scheduled.
5. **The catalog-inclusion evidence in §12 is descriptive, not a filter.**
   Every one of the 41.5M works would currently be ingested if pointed at
   the full dump; no work here excludes the ~50% with zero subjects or the
   ~89% with no publish date. That decision remains explicitly deferred,
   per the brief, and the full-catalog bootstrap should not proceed without
   it being made first — ingesting 41.5M works including several million
   near-empty stub records is a materially different storage and quality
   commitment than ingesting a curated subset.

---

## 15. Recommendation for the searchable Dewey corpus

**Not a threshold — the shape of the decision, informed by §12's numbers.**

The zero-edition works (0.33%, ~137,500 records) are the clearest
candidates for exclusion: an OL work record with no edition attached has no
ISBN, no publisher, no page count, nothing a reader could hold or search
for by any concrete detail — these are very likely catalog artifacts
(placeholder records, abandoned entries) rather than real findable books.

Beyond that, the evidence argues for a **combined-signal** approach rather
than any single field threshold: the 50.42% with zero subjects and the
89.34% with no publish date are each, alone, too common to use as an
exclusion filter (excluding either would remove genuinely real, findable
books — the search spike's own corpus had real, correctly-catalogued
sparse records). But a record with **no subjects AND no description AND no
author AND zero editions** is a much stronger signal of a non-book or
placeholder entry than any single field — worth measuring as a joint
distribution (not done in this session; a natural next step) before setting
a concrete rule.

**Recommendation: do not filter at bootstrap.** Ingest broadly (subject to
the zero-edition exclusion above, which is close to unambiguous), and let
`work_signal.completeness` plus, eventually, `dewey_saves` (real usage) do
the *ranking* work of keeping thin records out of search results, rather
than making an irreversible *ingestion*-time decision using only the weak
per-field signals available today. The schema already supports this
(`work_signal.completeness`, `is_derivative`, the eventual `dewey_saves`
column) without requiring a curation gate before a record can exist in the
catalog at all — consistent with the earlier architecture review's
principle that popularity/quality should be a *ranking* signal, not a
*visibility* gate.

---

**Stop condition met:** the no-op bloat issue is fixed and measured (§1a,
§6); the full-scale architecture is documented (§2); resumability is proven
with a real kill (§9); 300,000 real works have been ingested twice (§3–§4);
repeated medium-scale import physical churn is measured (§6); storage/index
growth is understood and shown to hold constant per-work at 20× the
prototype's scale (§5); bootstrap vs. refresh strategy is designed (§13);
anomaly/reconciliation reporting exists and is populated with real findings
(§10); and no schema contradiction emerged — `0002_catalog.sql` is
unchanged. **Not proceeding to the full 41.5M-work catalog in this session,
per the explicit stop condition.**
