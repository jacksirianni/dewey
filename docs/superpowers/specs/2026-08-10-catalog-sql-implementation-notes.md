# Catalog SQL Implementation — Notes

**Date:** 2026-08-10 · **Status:** Migration and test harness executed, all checks pass.
**Files:** [`supabase/0002_catalog.sql`](../../../supabase/0002_catalog.sql) ·
[`supabase/test/03-catalog.sql`](../../../supabase/test/03-catalog.sql)
**Builds on:** [schema design](2026-08-10-catalog-schema-design.md) ·
[adversarial review](2026-08-10-catalog-schema-adversarial-review.md)

Ingestion pipeline: not built. iOS: untouched. Search-engine comparison: not
resumed. Wikidata: not added.

---

## Final table count

**19 physical tables**, in schema `dewey`:

```
author  author_name  author_redirect  cover  edition  edition_contributor
edition_isbn  edition_redirect  field_provenance  identifier  source_record
subject  work  work_contributor  work_redirect  work_search  work_signal
work_subject  work_title
```

The design document listed "18 tables" as line items; `subject` +
`work_subject` was one line item there and is two physical tables here.
19 tables, exactly matching the approved design's content — noted as a
counting deviation, not a scope deviation.

**70 indexes, 17 functions** (5 helpers — `uuid_v7`, `fold`, `title_key`,
`isbn_digits`, `isbn10_valid`/`isbn13_valid`/`isbn_to_13`, `provider_rank` —
plus `claim_field`, three `resolve_*` functions, three `merge_*` functions,
and the two `isbn_collision`/`identifier_orphan` views).

---

## Key indexes

| Purpose | Index |
|---|---|
| Exact article-less title match | `work_title_key_idx` (btree on `title_key`) |
| Typo tolerance on titles | `work_title_trgm_idx`, `work_search_title_trgm_idx` (GIN trigram) |
| Typo tolerance on authors | `author_name_trgm_idx`, `work_search_authors_trgm_idx` |
| Full-text ranking | `work_search_tsv_idx` (GIN tsvector) |
| ISBN exact lookup | `edition_isbn13_idx`, `work_search_isbn_idx` (GIN on `char(13)[]`) |
| Legacy/provider id resolution | `identifier_lookup_idx` on `(id_type, value)` |
| Redirect resolution | `work_redirect`/`edition_redirect`/`author_redirect` PK on `old_id` — single-row lookup by construction |
| Non-derivative ranking | `work_signal_live_idx`, `work_search_rank_idx` — both partial on `not is_derivative` |
| "Purge every cover from source X" | `cover_source_purge_idx` on `(source, purged_at)` |
| Author's full bibliography | `work_contributor_author_idx` |

Nothing beyond what the approved design and the ten update scenarios actually
use. No index exists to prematurely optimize for a 40M-row catalog this
migration does not populate.

---

## Deviations from the approved design

Small and all in the direction of making an approved decision *executable*,
not in the direction of reopening it.

1. **`work_signal.popularity` added as a stored `real`**, computed by the
   ingest job rather than at query time. The design specified the *inputs*
   (`ol_readers`, `edition_count`, etc.); this migration adds the one output
   column search actually orders by, since `work_search_rank_idx` needs a
   single sortable value.
2. **`edition.page_count` gets a sanity CHECK** (`between 1 and 50000`) not
   explicitly specified in the design. Added because it is a one-line guard
   against a known Open Library failure mode (a stray large integer landing
   in a numeric OCR/scrape field) and costs nothing.
3. **`dewey.uuid_v7()` is a real, tested generator**, not a placeholder. The
   design flagged that Supabase's deployed Postgres predates the native
   `uuidv7()` (PG18) and said generation happens application-side "for now."
   This migration provides the SQL-side equivalent so the test harness (and
   any interim server-side backfill) has one without waiting on ecosystem
   support. When the deployed Postgres reaches 18, swapping in the native
   function is a one-line change with no stored-data migration, since the
   column type is `uuid` either way.
4. **`dewey.claim_field()` exists**; the design specified the *precedence
   rule* but not a concrete enforcement mechanism. This function is that
   mechanism: one gate every field write must pass through, so precedence and
   `locked` cannot be bypassed by application code that reimplements the
   comparison incorrectly.
5. **`identifier_orphan` view added**, not in the design. The design accepted
   the tradeoff of a polymorphic `entity_id` with no physical FK (§3.11 of the
   design doc); this view is the periodic integrity check that tradeoff
   promised, made concrete.

Nothing else deviates. The RLS posture, the three-redirect-table shape, the
one-row-per-field provenance model, the payload-retention split by
`acquisition`, and the cover/work separation all match the approved design
exactly.

---

## Decision on ISBN uniqueness (resolved empirically, as required)

**No global unique constraint on `edition_isbn.isbn13`.**

Measured directly against the spike's real 247,763-edition corpus before
writing the constraint, not assumed:

| | Count | Rate |
|---|---|---|
| Valid ISBN-13 strings | 151,711 distinct | — |
| ISBN-13 checksum/length invalid | 124 of 155,863 | 0.08% |
| ISBN-10 checksum/length invalid | 502 of 88,648 | 0.57% |
| Same ISBN-13 on **>1 edition** | 3,287 | **2.17%** |
| Same ISBN-13 on **>1 work** | 220 | **0.15%** |

A global unique index would have rejected 3,287 legitimate edition rows at
ingest time — over 2% of real coverage lost to enforce a cleanliness the
source data does not have. The 220 cross-work cases are the interesting ones:
real examples pulled from the corpus include the same ISBN-13 attached to two
distinct Open Library work records for what is very likely the same physical
book catalogued twice (`9788445000724` → `OL35109692W` / `OL35109693W`).

**What is enforced instead, all backed by an executed test:**

- The stored value must be a checksum-valid ISBN-13 (`edition_isbn13_valid`
  CHECK, using the real ISO 2108 checksum algorithm — verified against the
  spike's own valid and invalid examples).
- One edition cannot claim the same ISBN twice (`primary key
  (edition_id, isbn13)`).
- A cross-work duplicate is not silently tolerated — it is **surfaced** by
  `dewey.isbn_collision`, a view an operator works through, because a shared
  ISBN across two different works is itself a duplicate-work signal worth
  investigating, not an error to suppress.
- The identifier lookup path (`dewey.resolve_isbn`) stays deterministic even
  in the presence of a collision: ordered by popularity then id, so the same
  query always returns the same first row.

This is the schema-level realization of "prefer a design that allows
ingesting imperfect upstream data without corrupting canonical identity" —
bad ISBN data degrades to a review queue, never a blocked ingest and never a
merged-by-accident identity.

---

## The legacy-id lookup path, tested explicitly

```
'piranesi'
  → dewey.identifier (entity_type='work', provider='dewey_legacy',
                       id_type='local_book_id', value='piranesi')
  → entity_id (uuid)
  → dewey.resolve_work(uuid)     -- follows any redirect, single lookup
  → live work uuid
```

Exercised by `dewey.resolve_external_work('local_book_id', 'piranesi')` in
test section F, including the case that actually matters — a legacy id
pointing at a work that has since been merged still resolves to the survivor,
because `resolve_external_work` calls `resolve_work` rather than returning
the raw `entity_id`.

---

## Test results

**109 of 109 assertions pass**, executed against a real local Postgres 15,
using real fixture data drawn from the spike (the actual Piranesi/Piranesi
collision, the actual Percival Everett/Percival L. Everett duplicate author
records, and Open Library's actual `alternate_names` for 村田沙耶香).

```
outcome | count
--------+------
PASS    |  109

ALL CHECKS PASSED
```

Coverage against every item requested:

| # | Requirement | Section | Result |
|---|---|---|---|
| 1 | Create work/edition/author | A | ✓ |
| 2 | Multiple editions per work | A | ✓ (3 editions: print, translated print, audiobook) |
| 3 | Edition-level translator | B | ✓ |
| 4 | Edition-level narrator | B | ✓, and proven absent from work-level credit (the *Red Rising* fix) |
| 5 | Canonical + alternate author names | C | ✓ |
| 6 | Murata romanization lookup | C | ✓ — both directions (romanized→native, native→romanized) |
| 7 | Everett author merge | D | ✓ — relationships repointed, old id resolves, loser retained, tombstoned |
| 8 | Work merge + redirect | E | ✓ |
| 9 | Chained redirect prevention/resolution | E | ✓ — collapse-at-write-time verified structurally (one hop, not two), cycle refused |
| 10 | Legacy prototype ID resolution | F | ✓ — including through a merge |
| 11 | ISBN-10 → ISBN-13 normalization | G | ✓, incl. X check digit |
| 12 | Duplicate ISBN behavior | G | ✓ — accepted same-work, flagged cross-work, deterministic lookup regardless |
| 13 | Malformed ISBN rejection/handling | G | ✓ — both function-level (returns null) and storage-level (CHECK rejects) |
| 14 | Open Library identifier uniqueness | F | ✓ |
| 15 | Field provenance replacement | I | ✓ — OL → Nielsen |
| 16 | Locked editorial override | I | ✓ — survives both Nielsen and OL attempts |
| 17 | Future Nielsen override | I | ✓ — same test as #15, work id unchanged asserted explicitly |
| 18 | Cover replacement/removal | K | ✓ — including work survival after losing every external cover |
| 19 | Work signal upsert | L | ✓, plus the Piranesi popularity inversion asserted directly |
| 20 | Source-record refresh | J | ✓ — same dump-version rejected, next month's accepted |
| 21 | Cascade/restrict behavior | M | ✓ — author-with-credits delete is restricted (23503), work delete cascades to its own subordinate rows |
| 22 | No accidental deletion when source disappears | N | ✓ — the load-bearing test: work, its identifier, and its provenance all survive the source record being deleted and the OL identifier going stale |

Also verified beyond the checklist: migration re-runs idempotently (second
run, zero errors, zero unwanted side effects); stacks cleanly after
`0001_identity.sql` with no naming or extension collisions; RLS posture
matches `0001`'s discipline exactly (operational tables closed, catalog
tables readable by both API roles, zero write grants anywhere for `anon`/
`authenticated`).

---

## What was not built, on purpose

- **No ingestion pipeline.** `source_record`, `field_provenance` and the
  `claim_field`/merge functions exist and are tested against hand-built
  fixtures; nothing reads a real Open Library dump yet.
- **No search-engine reconsideration.** Postgres FTS + trigram, as decided.
- **No Wikidata.** Deferred per the adversarial review; `author_name.source`
  accepts `'wikidata'` in the enum for when that changes, and nothing else.
- **No iOS changes.** The migration path from `Book.id` values to catalog
  UUIDs (§14 of the schema design) is unimplemented; this migration only
  makes that path *possible* by giving `dewey_legacy` identifiers a home.
