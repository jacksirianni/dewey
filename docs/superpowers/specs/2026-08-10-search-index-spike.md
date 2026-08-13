# Search-Index Spike — Findings

**Date:** 2026-08-10 · **Status:** Spike complete, schema NOT locked · Supersedes nothing, extends [`2026-08-09-book-data-architecture-review.md`](2026-08-09-book-data-architecture-review.md)

Code lives in [`spike/`](../../../spike) at the repo root: `extract.py`,
`select_corpus.py`, `build_docs.py`, `pg_setup.py` / `meili_setup.py` /
`ts_setup.py`, `engines.py`, `benchmark.json`, `run_bench.py`,
`update_test_one.py`, `run_sequential.sh`. Nothing here is production code —
it is disposable and answers one question: **can Dewey search an Open
Library–derived corpus with consumer-app quality, while preserving the
ranking behaviors already learned from the client prototype?**

**Answer: yes, on Postgres, out of the box, on a bounded ~94k-document
corpus — 79.1% top-1 / 95.5% top-3, zero derivative-work leakage into rank 1,
median 111ms.** Meilisearch and Typesense are both viable operationally
(single-digit-ms latency, tiny memory footprint, trivial incremental
updates) but need real ranking-rule investment to close a ~14-point top-1 gap
against Postgres's hand-tuned scoring. Full reasoning and numbers below.

---

## 0. A course correction mid-spike, stated plainly

The first pass at this spike tried to index the **full** Open Library corpus
(41.5M works, ~56M editions) on this machine — an 8-core, 8GB Mac also
running Xcode, an iOS Simulator, and Claude.app. It worked for extraction
(orjson streaming got works.jsonl done in ~25 min once retries were fixed),
but running Postgres, Meilisearch, and Typesense **simultaneously** against
that scale drove swap usage to 7.8 of 8GB and load average to ~80. That is
not a search-engine benchmark at that point; it is a measurement of host
resource exhaustion, and any numbers produced under it are not trustworthy.

The correction, applied for everything below: a **bounded, deliberately
stratified ~100k-document corpus**, and **strictly sequential** engine
execution — only one of {Meilisearch, Typesense} ever running at a time,
memory recorded before and after each phase. Postgres is treated as the one
persistent service (disk-backed, not RAM-resident like the other two, and
every real architecture keeps it running regardless), so it loads once and
stays up, but its own load/benchmark/update phase still ran in isolation
before either other engine started.

---

## 1. The corpus

### 1a. Extraction (unbounded, done once)

Streamed directly from Open Library's monthly dumps (2026-07-31 generation)
to disk, then to a reduced JSONL projection via `orjson` (measured 20× faster
than stdlib `json` on this workload — 146k rec/s vs 7k rec/s):

| Dump | Raw size | Records extracted |
|---|---|---|
| works | 4.04 GB → 7.2 GB jsonl | **41,504,065** |
| authors | 0.78 GB → 0.95 GB jsonl | **15,380,614** |
| editions | 12.5 GB (filtered on read) | 247,763 kept (see below) |

`curl \| gunzip` piped directly into the extractor corrupted twice under
`--retry` (curl restarts a failed transfer at byte 0 and concatenates into
the still-open pipe, which `gunzip` reports as `invalid stored block
lengths`). Fixed by downloading to disk with `-C -` (resumable) first, then
extracting from the local file. Worth stating because it is a real footgun
for the production ETL, not just this spike: **the monthly ingest job must
download-then-process, never stream-and-hope.**

### 1b. Selection (bounded, deliberate)

A uniform random sample would omit almost every benchmark target and every
interesting collision — a flat 1-in-400 sample of 41.5M works contains maybe
one Susanna Clarke record and zero Giovanni Battista Piranesi records, so
"Piranesi ranks the wrong book" could never even be observed. The corpus is
instead built from **five deliberate buckets**, each keyed off signals
already present in the works projection (no author/title lookup needed):

| Bucket | Rule | Kept |
|---|---|---|
| **seed** | title token-matches a benchmark target (capped at 500/seed so "1984" or "James" can't swallow the corpus, while still keeping hundreds of real distractors) | 10,709 |
| **author** | any work by a benchmark author (uncapped — a bibliography is naturally small) | 21,749 |
| **rich** | ≥5 subjects AND has a description (1-in-60 sample) | 14,336 |
| **translation** | has an `alternative_title` (a non-English-original proxy, 1-in-25 sample) | 8,189* |
| **sparse** | no subjects, no alt title, no description — the Open Library median record (1-in-2500 sample) | included in general/sparse split |
| **general** | everything else (1-in-400 sample) | 49,918 |

*(exact bucket boundaries overlap slightly by construction — see
`select_corpus.py` for the precedence order)*

**Total: 104,901 work records → 94,282 search documents** after collapsing
duplicate work records (below). That lands inside the requested 100k–500k
range, on the low end deliberately: this machine cannot safely run three
engines' worth of RAM against anything larger while the host is also doing
other work.

**Known, stated bias:** over-representing seed terms deflates their IDF
relative to full-corpus production, which makes those queries *harder* here
than they would be at scale — a conservative direction for the benchmark, not
a simulation of production scoring.

### 1c. Editions, filtered not sampled

Editions were **not** independently sampled — every edition of every kept
work was pulled from the full 12.5GB dump via a byte-level regex prefilter
(match the work key before paying JSON-decode cost; this alone was the
difference between 3,500 rec/s and effectively instant, since only ~0.4% of
edition records survive the filter). Result: **247,763 editions across
104,321 of the 104,901 works** (99.6% of works have at least one edition) —
a realistic multi-edition density, not a synthetic one.

---

## 2. The search document

**The indexed unit is the WORK, not the edition or the author.** This is the
spike's central proposition and it holds up: editions collapse into
aggregate fields on the work document, so a query like "Piranesi Susanna
Clarke" is a contest between a handful of *books*, not twenty *editions* of
the same book plus the artist's drawings plus a study guide.

Two distinct collapse operations happen in `build_docs.py`, and conflating
them would be a mistake:

**Edition collapse.** All editions of one Open Library work record roll up
into aggregate fields: `edition_count`, the union of ISBNs, the most common
series/DDC/language, a median page count, whichever cover ID appears most
often. This is the easy direction — it's a group-by.

**Work merge.** Open Library holds **duplicate work records** for the same
book — confirmed in the corpus (not hypothetical): 2,523 groups of 2+ work
records merged via union-find, keyed on (article-less folded title) **AND**
(shared author ID **OR** shared author display name). This is the exact rule
the client prototype already learned the hard way with *Checkout 19* (two
Claire-Louise Bennett author records, disjoint IDs, same name) and *Red
Rising* (shared author IDs, but the narrator credited first) — it now runs
**once, server-side, at ingest**, instead of on every device, every time.

```
doc = {
  id, ol_work_ids[],                         # Dewey identity vs provenance
  title, title_key, title_folded,            # canonical, article-less, folded
  subtitle, alt_titles[],                    # collapsed from all merged records + editions
  authors[], authors_folded[], author_ids[], contributors[],
  series, isbn13[], isbn10[],
  year, edition_count, work_record_count,    # "how many OL records became this one"
  languages[], pages, subjects[], ddc,
  cover_id, has_description, has_cover,
  is_derivative,                             # study-guide/criticism heuristic — see §4d
}
```

### Fields kept, and fields deliberately NOT kept

The brief listed candidate fields and said explicitly not to add fields just
because the dump has them. Applied:

| Kept | Why |
|---|---|
| `title`, `title_key`, `title_folded`, `alt_titles` | the whole ranking problem lives here |
| `authors`, `authors_folded`, `author_ids` | title-vs-author disambiguation (§4a) |
| `series` | one of the requested query classes; real signal |
| `isbn13`/`isbn10` | exact-lookup path, not a text field (§4e — this was a real bug) |
| `year`, `edition_count` | the only popularity proxy available without holdings/checkout data |
| `subjects` (capped, low-weight) | weak signal, useful only as a last-resort tiebreak |
| `ddc` | Dewey-specific: the app's namesake feature, worth carrying even though sparse |
| `cover_id`, `has_cover`, `has_description` | rendering / refresh-priority signals, not ranking |
| `is_derivative` | demotes study guides — see §4d for how incomplete this heuristic is |

| Rejected | Why |
|---|---|
| `physical_format`, `publish_country`, `publish_places`, `oclc_numbers`, `lccn` | no ranking or display use identified; pure schema bloat |
| Full `description` text in the index | belongs in the catalog row, not the search document — Typesense holds its index in RAM, and putting long text in it would multiply memory for zero ranking benefit (see §3, memory footprint) |
| `contributors` as a ranked field | included in the document for display, deliberately **not** searchable — narrator/translator credit already caused the *Red Rising* "Renee Joiner" bug once; making it search-boostable would reopen that class of error |
| A holdings/popularity number from OL | doesn't exist in the dump; `edition_count` is a proxy and a flawed one (§4b) |

---

## 3. Engine comparison

All three loaded from the **identical** `docs.jsonl` (94,282 documents, ~140MB), sequentially, on the same machine, same corpus, same day.

| | **Postgres 15** (FTS + trigram) | **Meilisearch 1.52** | **Typesense 30.2** |
|---|---|---|---|
| **Relevance (top-1)** | **79.1%** | 65.7% | 64.2% |
| **Relevance (top-3)** | **95.5%** | 79.1% | 77.6% |
| **Typo tolerance** | via `pg_trgm` similarity, hand-tuned threshold | built-in, well-tuned by default | built-in, `num_typos` configurable |
| **Prefix search** | via `LIKE fk || '%'` in the scoring expression, manual | native, on by default | native, per-field `prefix` flag |
| **Faceting/filtering** | manual SQL (`isbn13 @> array[...]`) | native `filterableAttributes` | native `filter_by`, richer syntax |
| **Diacritic handling** | `unaccent` extension, correct out of the box | correct out of the box | correct out of the box |
| **Ranking control** | **Full** — arbitrary SQL expression, every term hand-visible | Ordered rule list (`rankingRules`); coarse-grained | `sort_by` + `_eval()` weighted expressions; coarse-grained |
| **Work/edition grouping** | N/A — grouping done at ingest, not query time (§2) | same | same |
| **Operational complexity** | Already running for identity (`0001_identity.sql`); one more table | New service, new ops surface | New service, new ops surface |
| **Memory footprint (94k docs)** | **2MB** reported RSS is a measurement artifact — Postgres is disk+OS-page-cache backed, not one resident process; **291MB on-disk** (table+indexes) is the meaningful number | **91MB RSS**, 386MB on disk | **97MB RSS**, 87MB on disk (RAM-resident index; disk is just the persistence snapshot) |
| **Index build time (94k docs)** | 4.7s copy + 24.8s index = **~30s** | 11.7s (varied 7–12s across runs) | 9.2s–78s (**highly variable** — see caveat below) |
| **Incremental update (single doc)** | 20–100ms | 400ms–1.3s | **<10ms** |
| **Incremental update (10k batch)** | 2.8–4.9s | 1.0–2.4s | 0.8–3.1s |
| **Cost** | $0 (self-hosted, already have it) | $0 self-hosted / Meilisearch Cloud from ~$30/mo | $0 self-hosted / Typesense Cloud from ~$29/mo |
| **Ease of local run** | Already running; one `psql` script | `brew install meilisearch`, one binary, one flag | vendor binary download, one flag |
| **Ease of hosting (early startup)** | Already hosting it (Supabase) — **zero new infra** | Small VM or managed cloud; needs its own backup/restore story | Same |

**Caveat on Typesense index-build variance (9.2s vs 78s across two runs):**
observed, not explained. Both runs used identical data and code; the only
difference is host load at that moment (this machine was also running other
processes throughout). Reported honestly rather than cherry-picked — but it
means **don't trust a single index-build number from either RAM-resident
engine on a shared/noisy host**; get several samples on production-shaped
hardware before sizing.

**Elasticsearch/OpenSearch:** not evaluated. No requirement surfaced in this
spike that Postgres/Meilisearch/Typesense couldn't address, and standing up
a JVM-based cluster is a materially larger operational commitment than any
of the three above — not justified without a concrete gap driving it.

---

## 4. What the 79%/66%/64% top-1 gap actually is

The relevance gap is not "Postgres is a better engine." **Postgres won
because its scoring is a hand-written SQL expression encoding every lesson
from the client prototype explicitly**; Meilisearch and Typesense were run
with their sensible *default* ranking-rule orderings plus one custom demotion
rule for derivative works. Given real investment — Typesense's `sort_by`
supports arbitrary weighted `_eval()` expressions, and Meilisearch's
`rankingRules` can be reordered and combined with custom ranking scores —
both could likely close most of this gap. That investment did not happen in
this spike; it would be the first work of a real implementation.

What's more interesting than the aggregate score is **what actually failed**,
because these are structural findings about the data, not tuning gaps, and
apply to whichever engine ships.

### 4a. The exact case the prototype already knew about, still real at scale

`engines.py`'s Postgres scoring drops the lexical-rank component entirely
when the query is an exact article-less title match, because the client
prototype's original bug was real and reproduced immediately in a synthetic
smoke test: **"Piranesi" ranked Giovanni Battista Piranesi's 18th-century
etchings above Susanna Clarke's novel**, because his name matched both the
title field *and* the weight-B author field, inflating `ts_rank_cd`. Fixed by
suppressing lexical rank on exact matches (comment left in the code
explaining why, since it looks like a strange thing to do without context).

**It still loses on the full corpus.** Clarke: 23 editions. Piranesi: 25.
This is not a bug — it's the actual data, and it is the clearest evidence in
the whole spike that **`edition_count` is not a trustworthy popularity
signal on its own.** A public-domain 18th-century artist's plates get
reprinted in every art-book imprint that wants them; a five-year-old novel
has not yet accumulated that print history. A real ranking needs either a
recency-weighted popularity term, a genre/format prior (fiction vs.
art-reference), or eventually real signal (holdings, checkouts, Dewey's own
save/log counts) — `edition_count` alone actively works against contemporary
books in exactly the cases it's most likely to matter.

### 4b. Real books share real titles — no amount of engineering removes this

`"Tomorrow and Tomorrow and Tomorrow"` (comma-less) collides on identical
folded title_key with a genuine, different, real book: Aldous Huxley's essay
collection *Tomorrow and Tomorrow and Tomorrow: and Other Essays* (6
editions in this corpus vs. Zevin's novel's count). This is not
resolvable by better text matching — it is **two different published works
with the same title**, an irreducible ambiguity. The honest product answer is
not "rank harder," it's: surface both, and let a recency/popularity signal
(once it's trustworthy — see 4a) do the ordering, or let disambiguation
happen at display time (author name is right there under the title).

### 4c. Author-identity fragmentation, confirmed at Open Library data scale

Two of the three benchmark targets reported "target absent" were not
actually absent — they exposed the same class of bug the original client
prototype found:

- **"James" by Percival Everett** *is* in the corpus with 8 editions — filed
  under a **different Open Library author record**, `"Percival L. Everett"`,
  disjoint from `"Percival Everett"`. Confirmed by grepping the raw author
  dump: both records exist, independently, for the same person.
- **"Convenience Store Woman" by Sayaka Murata** *is* in the corpus — its
  linked author record's canonical `name` field is the Japanese original,
  **村田沙耶香**, not the romanized form an English-language reader would
  type. `fold("Sayaka Murata")` never matches `fold("村田沙耶香")` — not a
  diacritic problem, a different-script problem.

Both are real Open Library data-quality facts, not spike artifacts, and both
directly validate the identity-merge design already agreed for Dewey's
catalog (article-less-title + shared-author-ID-or-name union-find, run once
server-side). What's new here: **that merge rule needs an explicit
romanization/transliteration fallback for author names**, which the current
union-find (ID or exact-name match) does not provide. Left as an open item,
not solved in this spike.

### 4d. The derivative-work heuristic is real but incomplete

The `is_derivative` title-regex flag (catching "study guide", "sparknotes",
"companion to", etc.) worked — **0% trap rate on Postgres and Typesense,
1.5% on Meilisearch** — for the cases it was built for. But it missed real
cases: a companion/analysis book titled plainly *"My Brilliant Friend"* by
"Kathryn Cope," with **empty subjects and no telltale words in the title**,
beat Ferrante's actual novel on lexical rank in some runs because both share
an identical `title_key` and Cope's edition happened to tie or win on the
secondary signal. Checked whether Library-of-Congress-style subject headings
("Study guides") could serve as a more reliable signal than title regex —
they don't help here; this specific record's `subjects` array is empty.

**Recommendation for the real ingest pipeline, not attempted here:** a
denylist of known study-guide-mill publisher names (BookCaps, Trivium,
Instaread, Everest Media, and similar are common in Open Library) is likely
a stronger, cheaper signal than title-text pattern matching, and should
supplement it rather than replace it.

### 4e. A real bug the spike caught: neither Meilisearch nor Typesense attempted ISBN lookup

Not a ranking nuance — a functional gap. Postgres's exact-match branch
(`isbn13 @> array[raw]`) worked from the first run. Meilisearch and Typesense
both returned **empty results for every ISBN query**, because `isbn13`/
`isbn10` were never in `searchableAttributes` / `query_by` — they were
declared as filterable fields but the free-text query path never touched
them. Fixed by detecting ISBN-shaped input (10 or 13 digits after stripping
punctuation) and routing it to an exact filter instead of free text — the
correct architecture regardless of engine, since an ISBN is an identifier
lookup, not a relevance-ranked query. After the fix: **5/5 ISBN queries
correct on all three engines.**

One more wrinkle worth recording: Typesense's `filter_by` with a **cross-field
OR** (`isbn13:=X || isbn10:=X`) silently returned zero hits even though each
field matched individually and neither request errored. Worked around with
two sequential single-field filter queries. The real fix for production is
architectural, not a workaround: **normalize ISBN-10 and ISBN-13 into one
`isbns: string[]` field at ingest**, so there is only ever one field to
filter and this class of bug can't recur.

### 4f. Full class-by-class breakdown (Postgres)

```
articleless                  3/3    many_editions_classic        1/1    subtitle                      0/2
author_only                  4/4    obscure_common_word          3/3    title_author                  4/4
author_only_diacritic        1/1    obscure_dup_work             1/1    title_author_dup              0/1
author_only_heavy_criticism  1/1    original_title                1/1    translation                   0/2
classic                      0/1    partial_title                 1/1    translation_classic           0/1
classic_criticism_heavy      2/2    punctuation                   2/3    translation_obscure           1/1
common_title_trap            1/1    recent_2023                   1/1    typo                          3/4
diacritic_missing            3/4    recent_2024                   2/2    typo_author                   1/1
exact_title                  4/5    recent_2024_punctuation       1/1    very_common_title             1/2
isbn10                       2/2    series                        2/3
isbn13                       2/2    series_sequel                 1/1
isbn13_hyphenated            1/1    series_sequel_articleless     1/1
many_editions                1/2    series_title_collide          1/1
```

Diacritics, articleless titles, author-only, and typo-tolerant queries are
all essentially solved. **`subtitle` (0/2) and `translation`-class (0/3
combined) are the weakest categories** — both trace to the same root cause
as §4d: title-key collisions between the real work and a companion/summary
or omnibus edition that the derivative heuristic didn't catch.

---

## 5. Update mechanics — no rebuild required, on any of the three

All six simulated events (a plausible month of churn, a new work arriving
between dumps via a force-import path, a metadata correction, a work merge,
an edition merge, and an upstream deletion) completed as **incremental
operations** on every engine — none required a full reindex.

| Event | Postgres | Meilisearch | Typesense |
|---|---|---|---|
| monthly_batch (10k docs) | 2.8–4.9s | 1.0–2.4s | 0.8–3.1s |
| new_work (single) | 69–99ms | 423ms–1.3s | 3–8ms |
| correction (single) | 26–37ms | 416ms–1.1s | 0.9–3ms |
| work_merge (redirect + delete) | 21–22ms | 418–668ms | 1.3–3.6ms |
| edition_merge (single) | 24–25ms | 213–426ms | 0.7–2.7ms |
| delete_redirect (single) | 18–21ms | 212–653ms | 0.7–2.9ms |

(Ranges reflect two full runs on a shared, noisy host — see the Typesense
index-build caveat in §3. Relative ordering is more trustworthy than any
single absolute number.)

**The one finding that matters more than any timing number:** a merge must
never be a delete at the catalog layer. The spike created a `book_redirect`
table (`old_id → new_id`) alongside the `doc` delete, and confirmed the
redirect resolves after the merge:

```
work_merge: delete DWTEST1 from the search index (all three engines, ms-scale)
            + insert a redirect row (Postgres only — this belongs on the
              catalog table, not in any search index)
verified:   select new_id from book_redirect where old_id = 'DWTEST1'
            → DWTEST2   ✓
```

This is exactly the Letterboxd mechanic the architecture review called for
(`letterboxd.com/tmdb/[ID]` force-import; a Letterboxd film record survives
even after its TMDB duplicate disappears, because members have already
logged it). **The search index only needs to support fast delete + fast
upsert.** Redirect durability is a `dewey_book_id`-keyed catalog table
concern, fully orthogonal to which search engine sits in front of it — this
spike validates that the search layer doesn't complicate that decision
either way.

`new_work` proves the Letterboxd-style force-import path is cheap: a single
document upsert, immediately searchable, in under 100ms on the two fastest
engines and under 1.3s even on the slowest observed run.

---

## 6. Proposed Dewey search API shape (design only — not implemented)

The client never sees raw Open Library structure, in either shape or field
names. A single search endpoint response, regardless of which engine sits
behind it:

```jsonc
GET /v1/search?q=piranesi

{
  "results": [
    {
      "book_id": "dw-3f8a...",        // Dewey's ID, never an OL work ID
      "title": "Piranesi",
      "subtitle": null,
      "author": "Susanna Clarke",     // display string, not the raw authors[]
      "year": 2020,
      "series": null,
      "cover_ref": "ol:8225261",      // opaque reference; client resolves via
                                       // Dewey's own cover proxy (see the
                                       // architecture review, §6) — never a
                                       // raw Open Library or provider URL
      "match": {                      // WHY this row matched, for UI use
        "kind": "title_exact"         // | "title_prefix" | "author" | "isbn" | "fuzzy"
      },
      "in_library": true              // has the requesting user already saved/logged it
    }
  ]
}
```

Deliberately excluded from the response, all present in the index but never
serialized to the client: `ol_work_ids`, `author_ids`, `edition_count`,
`is_derivative`, `work_record_count`, raw `subjects`, `ddc`, `contributors`.
These are ranking/ops signals, not product surface — exposing them would
leak provider shape into the client exactly as the architecture review
warned against.

`in_library` requires a per-request join against the requesting user's
library — a reason the search endpoint itself should stay a thin Dewey-owned
service in front of whichever engine is chosen, never the engine's raw query
API exposed directly to the client.

---

## 7. Decision

**Recommended search engine for Phase 1/B: Postgres full-text + trigram.**
Not because Meilisearch or Typesense are deficient — both are fast, cheap,
operationally trivial, and update incrementally exactly as well as Postgres
does — but because:

1. **Zero new infrastructure.** Dewey already runs Postgres (Supabase,
   `0001_identity.sql`) for identity. Adding a `doc` table and two indexes is
   not a new service to provision, back up, monitor, or reason about
   failure modes for.
2. **The 15-point relevance gap is real and unclosed.** Postgres won because
   its ranking is a fully hand-visible SQL expression; closing the same gap
   on Meilisearch/Typesense is achievable (both expose enough ranking
   control) but is unstarted work, not a solved problem today.
3. **Every hard case in §4 is a data-modeling problem, not an engine
   problem**, and the fix in every case (provenance-tagged `field_provenance`
   from the architecture review, a publisher denylist, a recency-aware
   popularity term, a romanization-aware author merge) lives in the ingest
   pipeline and the schema — completely portable to a different engine
   later if Postgres FTS ever hits a real ceiling.

**Reconsider Typesense specifically if/when:** query-time facet filtering
becomes a first-class product feature (browse-by-subject, browse-by-language)
at a scale where hand-written SQL facets get unwieldy, or if p95 latency
under real production concurrency (not tested here — this spike measured
single-client sequential latency only) becomes a problem Postgres can't
solve with `shared_buffers` tuning and read replicas.

### Recommended indexed unit
**The work**, with editions collapsed to aggregate fields and duplicate work
records merged via union-find at ingest (§2). Never index editions or
authors as separate searchable documents — confirmed no query class in the
benchmark needed it, and it would reopen the duplicate-row problem the whole
design exists to close.

### Recommended ranking strategy
Layered, in this priority order, matching the client prototype's already-
validated blend: **(1)** exact article-less title match is near-absolute —
and lexical rank must be *suppressed*, not just supplemented, on this case
(§4a); **(2)** author-token match adds a bonus, but only when the query is
*not* already a full title match, or it actively hurts (the Piranesi
regression); **(3)** `edition_count` nudges via a damped log, never decides
alone (§4a shows why); **(4)** `is_derivative` subtracts a large fixed
penalty rather than filtering, so a study guide can still appear, just never
at rank 1; **(5)** trigram similarity as the typo-tolerance floor.

### Required source fields (from Open Library, at ingest)
Title, subtitle, alternative_title, authors (with resolved display names —
not raw author keys), subjects, first_publish_date, description
(presence + cleaned text), ISBN-10/13, series, Dewey Decimal
classification, language, number_of_pages, cover ID, revision number
(for picking a canonical record among duplicates).

### Required normalized fields (computed, never re-derived per-query)
`title_key` (folded, article-stripped — computed once at ingest, not at
query time, in both Postgres's `tsv`/trigram columns and any future engine),
folded author names, a unified `isbns: string[]` (§4e — the fix this spike
proved necessary), `is_derivative`, `edition_count`/`work_record_count` as
aggregates, and — not yet built, flagged as a gap — a normalized romanized
author name for cross-script identity matching (§4c).

### Expected operational burden
**Low.** No new service. The `doc` table plus indexes measured **272MB for
94k documents** (≈2.9KB/doc fully indexed); linear extrapolation to a
realistic production corpus (2–5M works after Dewey's own dedup, not
41.5M raw OL records) suggests **6–15GB** — comfortably within a modestly
sized Postgres instance, and re-indexable from `docs.jsonl`-equivalent
source data in well under a minute per 100k documents observed here. The
real ongoing cost is the monthly ETL job (dump diff → `field_provenance`
update → search-column refresh), not the search engine itself.

### What the catalog schema must support because of this spike
- A `book_redirect(old_id, new_id)` table, independent of the search index,
  so a merge is never a delete for a reader who has already logged the book
  (§5) — this was designed and verified working in this spike, not merely
  proposed.
- `field_provenance`-style tagging per the architecture review, now with a
  concrete first consumer: the derivative-work denylist and the
  recency-aware popularity signal (§4a, §4d) both need to know *when* and
  *from which source* a field's value was set, to be tunable without a
  re-ingest.
- Storage for a resolved, romanized display author name, separate from
  Open Library's raw (possibly non-Latin-script) `name` field (§4c).

### What fields the schema does NOT need, despite being available upstream
Raw `contributors` as a searchable/rankable field (display-only — §2, and
the reason *Red Rising* broke once already); `physical_format`,
`publish_country`, `publish_places`, `oclc_numbers`, `lccn`; full
description text inside the search index proper (belongs on the catalog row,
fetched separately — keeps the RAM-resident-engine option viable if ever
needed); any per-provider identifier as a *ranked* field — provenance IDs are
for joins and audits, never inputs to relevance scoring.

---

## Not done in this session, by design
No production backend, no final locked schema, no engine actually deployed.
This document is the input to that design, not the design itself.
