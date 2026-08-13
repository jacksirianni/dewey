# Bounded Open Library Ingestion Prototype — Report

**Date:** 2026-08-10 · **Status:** Prototype complete, catalog schema unchanged
**Code:** [`spike/ingest/`](../../../spike/ingest) — `ingest.py`,
`incremental_updates.py`, `select_ingest_corpus.py`,
`extract_ingest_editions.py`, `populate_search.sql`
**Builds on:** [catalog schema design](2026-08-10-catalog-schema-design.md) ·
[adversarial review](2026-08-10-catalog-schema-adversarial-review.md) ·
[catalog SQL](2026-08-10-catalog-sql-implementation-notes.md)

Full Open Library ingestion: not built. iOS: untouched. Search-engine
comparison: not resumed. Wikidata: not added. **`supabase/0002_catalog.sql`
is unchanged — see §7 for why nothing found here justified touching it.**

---

## 1. Corpus composition

**6,999 works, 14,318 editions, 6,663 authors** — all real Open Library
records, drawn from the already-downloaded dump data used in the search-index
spike (no redownload). Selection was deliberate, not first-N:

| Bucket | Works | How chosen |
|---|---|---|
| Named-title force-include | 136 | Every record whose title folds to one of the 9 explicitly-named books — **every duplicate, study guide, and collision kept**, not just the canonical one |
| Named-author force-include | 71 | Every work reachable from "Sayaka Murata" or "Percival Everett" through **any** name Open Library gives that author (canonical *or* alternate) — catches Murata's Japanese-canonical author record, which a canonical-name-only match would have missed exactly as the search spike did |
| Stratified fill (seed / author / rich / translation / sparse / general) | 6,792 | Proportional downsample of the spike's already-verified 104,901-work stratified corpus, preserving every category the brief asked for |

All 9 named books present, with real duplicate density: Piranesi ×41 records,
The Fifth Season ×23, Beloved ×14, James ×5, Earthlings ×16, Red Rising ×6,
Convenience Store Woman ×2, Station Eleven ×3, Wolf Hall ×1, Klara and the Sun
×1.

**Editions were re-extracted from scratch**, not reused from the search
spike's projection — the spike's extractor kept only contributor *names*,
dropping *roles*. This ingestion needed roles to test translator/narrator
separation, so `extract_ingest_editions.py` re-streamed the already-downloaded
`editions.gz` (12.5GB, on disk from the spike, not redownloaded) with a
richer projection. 172 seconds for the full 56.6M-record scan.

**The 9 named works also got real live-API enrichment** — full JSON payloads
fetched from `openlibrary.org/works/{id}.json`, retained in
`source_record.payload` under `acquisition='api'`. This exercises the
*second* acquisition path the schema was designed for (dump-derived records
get metadata only, per §7 of the SQL notes), with real description text —
812 to 2,307 characters per book, not placeholder content.

One anomaly surfaced during corpus selection itself, before any ingestion:
**"Earthlings" is not linked to Murata's canonical Open Library author
record at all.** `authors/OL6573124A/works.json` (her canonical record)
lists "Convenience store woman" but not "Earthlings" — the English
translation exists in the dump under a different, disconnected author
attribution. Reported as found, not silently worked around.

---

## 2. Ingestion architecture

Fifteen explicit stages, each its own method on an `Ingestor` class, run in
one order (`ingest.py`):

```
load_sources → normalize → resolve_authors → persist_authors/author_names
  → persist_source_records → resolve_works → persist_works/work_titles
  → persist_work_contributors → resolve_editions → persist_editions
  → persist_edition_contributors → persist_identifiers → persist_covers
  → persist_subjects → persist_work_signals → claim_canonical_fields
```

**The identity mechanism that makes re-runs idempotent is identifier-table
lookup, not an in-process cache.** `resolve_or_mint()` queries
`dewey.identifier` for every OL key before minting anything:

```python
def resolve_or_mint(self, entity_type, id_type, keys):
    # look up existing entity_id via identifier; mint uuid_v7() only for
    # keys not already known — to THE DATABASE, not to this process
```

This is the deliberate difference from a naive script that just remembers
what it inserted this run: a second invocation, in a fresh process with empty
memory, still produces zero duplicates, because idempotency lives in the
schema's `identifier` table, not in the ingestion script's state.

**Every canonical field write goes through `dewey.claim_field()`.** No stage
issues an ad-hoc `UPDATE work SET title = ...`. `claim_canonical_fields()` is
the only place that writes `work.display_title`, `.first_published_year`,
`.series_name`, `.ddc`, `.description`, and it only does so *after*
`claim_field()` has returned `true` — the precedence/lock check runs first,
in the same order the schema's design specified, every time.

**Contributors are structurally separated.** `persist_work_contributors`
writes `work_contributor` with `role='author'` only. `persist_edition_contributors`
writes `edition_contributor` from OL's `contributors` field, classified
through `classify_role()`, and the code path that would have let an
edition-level author leak into work-level credit **does not exist** — it was
written, found to be dead code building a value that can't type-check against
`edition_role`, and deleted (§6).

---

## 3. Row counts

Ground truth from `select count(*)`, not from application-level counters —
see §5 for why that distinction mattered.

| Table | Rows |
|---|---|
| work | 6,999 |
| work_title | 6,999 |
| work_contributor | 8,461 |
| work_subject | 21,843 |
| work_signal | 6,999 |
| edition | 14,318 |
| edition_isbn | 10,891 |
| edition_contributor | 60 |
| author | 6,663 |
| author_name | 9,959 |
| identifier | 27,980 |
| cover | 2,223 |
| source_record | 7,008 (6,999 dump + 9 API) |
| field_provenance | 11,175 |
| subject | 10,522 |

**Field claims: 11,175 won, 0 refused** on the first ingest (nothing existed
to refuse against yet — refusal is exercised in §5's update simulations,
where it matters).

**Throughput:** 5.28s for 6,999 works end-to-end through all fifteen stages
— **1,325 works/sec**, all fifteen stages, on a laptop, against local
Postgres. This is not a claim about production throughput (batched
`execute_values` against a local, unloaded database is close to a best case);
it is evidence that nothing in the schema itself — the 70 indexes, the
`claim_field()` per-row calls, the trigger-free design — imposes a
structural bottleneck at this scale.

---

## 4. Idempotency results

**Ran three consecutive, identical ingests. Every table's row-count delta was
zero on runs 2 and 3.**

```
table_row_delta (run2 and run3, identical):
  work: 0   work_title: 0   work_contributor: 0   work_subject: 0
  work_signal: 0   edition: 0   edition_isbn: 0   edition_contributor: 0
  author: 0   author_name: 0   identifier: 0   cover: 0
  source_record: 0   field_provenance: 0   subject: 0
```

This required fixing an instrumentation bug and a real ingestion bug along
the way — both worth reporting precisely rather than folded into a clean
summary:

**Instrumentation bug (caught before it could hide anything): `cur.rowcount`
and `RETURNING`-clause `fetchall()` after a paginated `execute_values()` call
only reflect the *last internal page*, not the true total**, once the row
count exceeds `page_size` (1,000 here). The first run reported "999 works
inserted" for a real 6,999 — the data was correct throughout; only the
report was wrong. Fixed by measuring `SELECT COUNT(*)` before and after the
whole run instead of trusting any per-call counter. This is the reason §3's
counts are stated as ground truth rather than pipeline-reported: the pipeline
self-report was demonstrated unreliable, so it is not the source of the
numbers in this document.

**Real ingestion bug, caught by the idempotency check doing its job:**
`normalize_ddc()`/`normalize_series()` picked the most-common value via
`max(set(vals), key=vals.count)`. When two values tie for most-common,
`set` iteration order in Python 3 is hash-randomized **per process** by
default — so identical source data could deterministically-in-appearance but
actually **non-deterministically** pick a different tied DDC or series value
on two separate runs. Caught directly: a `work` table content hash was
computed before and after a third run and did not match, despite zero row
deltas. Root-caused to the tie-break, fixed with `Counter.most_common()` plus
an explicit alphabetical tiebreak, and re-verified stable across three full
runs with matching content hashes. **This is a genuine idempotency defect a
single-run or two-run test would not have caught** — it required exactly the
"run at least twice" instruction the brief insisted on, and arguably shows
why three runs (not two) is the more convincing bar.

`source_record.imported_at`: **0 of 7,008 rows touched** on the idempotent
re-run — confirmed via a direct timestamp-freshness query, not inferred.
`field_provenance.set_at`: **all 11,175 rows touched**, and this is *correct*,
not a defect — the approved precedence rule explicitly makes equal-rank
reclaims win ("a monthly refresh from the same provider can update its own
value"), so a same-provider re-ingest is supposed to refresh `set_at`.
`identifier.last_seen_at`: all rows touched, also correct and by design —
that column exists specifically to detect what a dump run still mentions.

---

## 5. Update-simulation results

All eight scenarios, **13/13 checks passed**, each driving the real
`Ingestor` methods on a mutated copy of a real record — never a bypass
`UPDATE`.

| Scenario | Result |
|---|---|
| **Metadata correction** — OL "corrects" Piranesi's publish year | `claim_field` accepted the new value from the same provider; canonical `first_published_year` updated to 2021 |
| **Locked editorial value** — lock the title, then feed OL a changed value | Locked title (`"Piranesi (Editorial Title)"`) survived; the OL reclaim was refused at `claim_field()`, not filtered out afterward |
| **New edition** — add a real 2026 edition to Piranesi's work | Edition count +1; **the Dewey work UUID was byte-identical before and after** |
| **New ISBN on an existing edition** | New ISBN row added; the pre-existing one untouched, verified by exact-value query, not just count |
| **Better cover** — a licensed cover supersedes the cached OL one | `work.display_cover_id` re-pointed; **the original OL cover row was not deleted**, still independently queryable |
| **Source disappearance** — simulate a "next month's dump" that omits an unrelated work entirely | The omitted work still exists afterward — deletion-by-omission does not happen, because ingestion only ever acts on what's in the batch, never diffs against "what's missing" |
| **New author alternate name** — Murata's record gains one more alias | Author count unchanged (still 6,663); exactly one new `author_name` row landed on the *same* author id |
| **Real cross-work ISBN collision** — `9788445000724`, the actual duplicate measured in the SQL implementation notes | Ingest of the second occurrence succeeded (no rejection, no crash); `dewey.isbn_collision` reported `work_count = 2` for it |

The locked-value and metadata-correction scenarios together are the
important pair: they prove precedence and override are not merely present in
the schema (already shown in the SQL test harness with synthetic fixtures)
but **reachable by the actual ingest code path**, on real data, using the
same `claim_field()` call the bulk pipeline uses — not a parallel mechanism
built just for this test.

---

## 6. Data-quality failures discovered

Not silently dropped. Every rejection logged to `anomalies_run1.jsonl` with
a kind, a disposition, and enough context (OL keys) to look the record up.

| Kind | Count | Disposition | What it actually was |
|---|---|---|---|
| `malformed_isbn` | 40 | reject field | Real garbage: `]077103463` (stray bracket), `00201993309` (11 digits), `958060013X` (fails checksum). The field is dropped; the edition still ingests. |
| `unknown_contributor_role` | 108 | reject field | Real OL role strings with no place in `edition_role`: **"Adaptation of original work by"** (17), "Contributor" (16), "Author" (12, i.e. OL sometimes lists a work-level author *again* as an edition contributor), "Notes by" (9), "Additional Author (this edition)" (8), "Revised by", "Cover Design", "Preface", "Producer". None invented — a straight frequency count of what the dump contains. |
| `unresolved_contributor_name` | 353 | **review queue**, not rejected | Real names with a real, correctly-classified role (translator, narrator, illustrator...) that don't match any author record *already loaded in this bounded 6,663-author corpus* — e.g. "Kwame Anthony Appiah" (introduction), "Peter Francis James" (narrator). This is a genuine scope artifact of a 7,000-work prototype, not a schema or logic defect: author population was scoped to *work-level* authors of the selected works, not to every edition contributor across the whole corpus. At full scale, contributor names would resolve against the complete author table. |
| `missing_author` | 9 | reject field | A work's author key pointed at an author record outside the selected corpus (a boundary effect of sampling, same root cause as above) |
| `impossible_page_count` | 5 | reject field | Page counts outside `1..50000` |
| `impossible_date` | 0 (in this corpus) | would reject field | Guard is live (tested directly in §5); simply not triggered by this particular sample |

**Failure policy, decided per-kind, all four dispositions used exactly where
they fit:** malformed identifiers and out-of-range numbers are *rejected at
the field*, never at the record — a bad ISBN does not stop an edition from
existing. Unknown roles are rejected at the field with the raw string
preserved for later mapping. Unresolved names go to a *review queue*, not a
rejection, because the data isn't wrong — the ingest's current scope just
doesn't cover it yet. Nothing in this corpus triggered a whole-record
rejection; the closest is a dangling edition (an edition whose work failed
to ingest), for which the code path exists and is exercised in the test
harness (§03-catalog.sql) even though this run's corpus never hit it.

**The Red Rising finding — the most important one in this section, reported
precisely rather than summarized as a pass:**

The brief asked to prove "Red Rising by Renee Joiner" cannot happen. Two
separate things are true, and they are not the same claim:

1. **The edition-credit-leak path is structurally impossible.** `edition_role`
   has no `author` value; a broken early draft of `persist_edition_contributors`
   that tried to write one was caught immediately by the enum's own type
   check (confirmed against `03-catalog.sql`'s equivalent assertion,
   `22P02`). No narrator, from any edition, of any book, can become a
   work-level author through this pipeline.
2. **A genuine duplicate Open Library WORK record already has the bad
   co-authorship baked in, upstream, in the source dump itself.** Verified
   directly: `OL17076473W` (the canonical Red Rising) lists author
   `OL7621609A` (Pierce Brown) alone; a separate record, `OL26627585W`,
   lists `['OL9363988A', 'OL7621609A']` — **Renee Joiner and Pierce Brown**
   — as co-authors, at the work level, in Open Library's own data. The
   ingested Dewey catalog faithfully has four separate "Red Rising" works,
   one of which correctly shows "Pierce Brown, Renee Joiner" as its authors
   — because that is what that specific upstream record says.

Faithfully transcribing a wrong upstream record is not a bug; **silently
"fixing" it would have been** — the brief was explicit that automatic entity
resolution is out of scope, and this is exactly the case that instruction
was written for. Reconciling the two Red Rising records is `merge_works()`'s
job — already built, already tested (03-catalog.sql), deliberately not
triggered automatically by this ingestion prototype. This is precisely the
boundary the schema design drew: ingestion represents what upstream says,
even when upstream is wrong; reconciliation is a separate, auditable,
human- or heuristic-triggered operation.

**Also found, incidentally, while validating:** Open Library's author
fragmentation for Percival Everett is worse than previously documented —
**three** distinct canonical author records, not two: `OL16028469A`
("Percival Everett"), `OL34745A` ("Percival L. Everett"), and `OL14549253A`
("Percíval Everett" — a diacritic variant). All three ingested as separate,
correctly-unmerged `author` rows.

---

## 7. Schema defects discovered

**None.** No column, constraint, index, or function in `0002_catalog.sql`
needed to change to make this ingestion work. Every mechanism the design
promised was reachable from real code moving real data: `claim_field()`
precedence and locking, `resolve_or_mint`-style identifier lookup for
idempotency, the cover/work separation, the ISBN-as-identifier path, the
edition/work contributor split.

Per the brief's own standard — change the schema only if a real-data failure
requires it — nothing here cleared that bar. The two defects found (§4, §6)
were both in `ingest.py`, not in the migration, and both are fixed in the
committed version of that script.

---

## 8. Index/write-cost observations

**Database size: 73MB at rest, 74MB after `VACUUM ANALYZE`, 59MB after
`VACUUM FULL`.** For 6,999 works and their full graph (~130K total rows
across 15 tables), that is roughly **8.4KB per work**, fully indexed.
Linear extrapolation to a realistic post-dedup production corpus (2–5M
works, per the architecture review) suggests **17–42GB** — consistent with
the earlier design document's estimate, now grounded in a real measurement
rather than a guess.

**Indexes are heavier than table data at this scale.** Total dewey-schema
index size: **37MB** (post-`VACUUM FULL`), against roughly 22MB of table
data — indexes are **~63% of total size**. Three tables account for most of
it:

| Table | Table data | Indexes | Why |
|---|---|---|---|
| `work_title` | 1.3MB | 7.9MB | Two trigram GIN indexes (`title_key`, plus the base btree) over a table that's mostly short strings |
| `author_name` | 1.3MB | 6.7MB | Same pattern — trigram GIN over short strings |
| `identifier` | 8.3MB (pre-vacuum) | 9.2MB | Every OL key gets 2-3 index entries (unique constraint + entity lookup + staleness index) |

This is not a defect — GIN trigram indexes are inherently larger than the
text they index, and typo-tolerant search is the entire reason they exist —
but it is worth knowing before scaling: **at production volume, expect index
storage to meet or exceed table storage**, and size the database
accordingly rather than budgeting from table size alone.

**A real, fixable write-cost finding: repeated `ON CONFLICT DO UPDATE`
bloats tables even when the ingest is logically a no-op.** Three consecutive
idempotent runs left `identifier` at 17MB — `VACUUM FULL` reclaimed it to
7.2MB. `field_provenance` similarly: 3.9MB down to 1.6MB. The mechanism:
Postgres's MVCC writes a new tuple version on every `ON CONFLICT DO UPDATE`,
**even when the incoming values are identical to what's already stored** —
the executor doesn't skip the write just because nothing changed. This
happened even for `source_record`, where the `content_hash`-guarded `CASE`
correctly left `imported_at` untouched *logically* — the row was still
physically rewritten three times.

This is the one concrete, actionable recommendation this section produces:
**a production ingest job's `ON CONFLICT DO UPDATE` clauses should carry a
`WHERE` guard** (`WHERE excluded.content_hash IS DISTINCT FROM t.content_hash`,
or the equivalent per table) so Postgres's executor skips the write entirely
when nothing changed, rather than relying on application logic to make the
change a no-op *after* an unconditional write has already happened. Not
applied here — this is a pipeline-code recommendation, not a schema change,
and the brief's "do not optimize prematurely" instruction was heeded rather
than second-guessed.

**`claim_field()` at scale:** 11,175 calls in 5.28s total pipeline time
(well under a second of that total, based on the stage timing) — a simple
indexed PK lookup plus a conditional upsert, showing no sign of being a
bottleneck at this volume.

---

## 9. Search smoke-test result

`work_search` was populated from the ingested catalog (`populate_search.sql`)
and queried directly — **not to retune ranking**, only to confirm the
normalized rows carry what the approved Postgres FTS + trigram path needs.

**The one query that matters most in this entire report:**

```sql
select display_title, display_authors from dewey.work_search
where 'sayaka murata' = any(authors_folded);
```

**27 works returned**, all correctly authored, all showing `村田沙耶香` (her
canonical Open Library name) as `display_authors` — including *Convenience
store woman*, *Vanishing World*, *Life Ceremony*, 地球星人, and 22 others.
The romanized English query reaches every one of them, end to end, through
real ingested data — not the hand-built fixture the SQL test harness used,
and not the search spike's synthetic smoke test. This is the search spike's
original finding (4c: "Sayaka Murata" could not reach 村田沙耶香), proven
fixed, on the real pipeline, for the first time in this project.

Also confirmed: author-only search (`Kazuo Ishiguro` → 3 real books,
correctly excluding nothing that shouldn't be there), exact ISBN-13 lookup
(`resolve_isbn('978-1-5266-2242-6')` → the correct work, deterministically),
and legacy/OL identifier resolution (`resolve_external_work('ol_work',
'OL20893680W')` → the correct Dewey UUID). Full relevance re-tuning against
this corpus is explicitly deferred, per the brief.

---

## 10. Recommendation before scaling beyond the prototype

**Proceed to full-scale ingestion design. Nothing found here blocks it, and
three things should be carried forward as fixed requirements, not
optional improvements:**

1. **Apply the `WHERE`-guarded upsert pattern (§8) before any production or
   long-running ingest job.** At 7,000 works over three runs the bloat was
   cosmetic (17MB); at millions of works over dozens of monthly re-ingests
   it would not stay cosmetic. This is the one piece of ingest-code technical
   debt this prototype is knowingly leaving behind, named explicitly so it
   isn't rediscovered the hard way.
2. **Resolve/create author records for edition contributors, not only
   work-level authors, at full scale.** The 353-name review queue (§6) is a
   scope artifact of this prototype's bounded author corpus, not a design
   flaw — but a full ingest must widen author resolution to cover every
   name appearing anywhere in the source (work authors *and* edition
   contributors) or the review queue will be permanently, artificially
   large rather than reflecting genuine unresolved names.
3. **Ground-truth row counts, not application-level counters, for any
   future ingest instrumentation.** §4's `cur.rowcount` finding is a
   psycopg2/`execute_values` behavior, not specific to this schema — it will
   recur in any future ingest tooling using the same library the same way,
   and should be designed around from the start rather than rediscovered.

No schema change is recommended. `0002_catalog.sql` is validated against
real, messy, duplicate-laden Open Library data — including the exact three
hard cases the last two design documents were built around (Piranesi's
edition-count inversion, Everett's fragmented identity, Murata's
script-crossing alias) — and held without modification.
