# Dewey Catalog Schema — Production Design

**Date:** 2026-08-10 · **Status:** Design only. No SQL, no ingestion, no implementation.
**Builds on:** [architecture review](2026-08-09-book-data-architecture-review.md) · [search-index spike](2026-08-10-search-index-spike.md)

Chosen architecture, now fixed:

```
Open Library dumps ──▶ Dewey normalized catalog ──▶ Postgres FTS + pg_trgm ──▶ Dewey API ──▶ iOS
        │                                                    ▲
        └── live OL API (force-import, gap-fill) ────────────┘
```

Postgres is the search engine. The spike's 95.5% top-3 says retrieval works;
the 79.1% top-1 says **ranking, normalization and identity** need the work —
and every one of those failures is something this schema has to make fixable.
That is the design constraint throughout: *the schema's job is to make the
spike's failures addressable without a rebuild.*

---

## 1. Architecture diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  INGEST                                                                     │
│                                                                             │
│   OL monthly dump ──┐                                                       │
│   OL live API ──────┼──▶ source_record ──▶ resolver ──▶ canonical tables    │
│   (future) Nielsen ─┘    (what we were     (precedence   work / edition /   │
│                           handed, as-is)    rules)        author / …)       │
│                                                  │                          │
│                                                  └──▶ field_provenance      │
│                                                       (who owns each field) │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  CATALOG (authoritative, provider-independent)                              │
│                                                                             │
│   work ◀──── work_title        work_contributor ────▶ author                │
│    │  ◀──── work_subject                              │  ◀── author_name    │
│    │  ◀──── work_signal                               │                     │
│    │                                                  │                     │
│    └──▶ edition ──▶ edition_isbn                      │                     │
│              └────▶ edition_contributor ──────────────┘                     │
│                                                                             │
│   cover ──▶ (work | edition)      identifier ──▶ (work | edition | author)  │
│   work_redirect / edition_redirect / author_redirect                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │  projection (materialized, rebuildable)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  SEARCH        work_search   (tsvector + trigram + exact-lookup columns)     │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  DEWEY API     /v1/search  ·  /v1/works/{id}  ·  /v1/works/{id}/editions    │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │  never provider-shaped
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  iOS           display projection  +  offline snapshots embedded in          │
│                user records (diary / list / ranking) — NOT the catalog       │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  SOCIAL (separate schema, separate lifecycle) — points at dewey work ids     │
│  profiles · library_entry · diary_entry · review · score · ranking · list    │
└─────────────────────────────────────────────────────────────────────────────┘
```

Two boundaries matter more than any table below:

- **Catalog never contains user data.** No score, diary, favorite, ranking,
  review, list, or follow appears in any table in the catalog block.
- **Social never contains catalog authority.** It holds `dewey_work_id` plus a
  small display snapshot (§11), and nothing else about the book.

---

## 2. Table list

| # | Table | Purpose | Rough scale (3M works) |
|---|---|---|---|
| 1 | `work` | canonical work — the thing search returns | 3M |
| 2 | `work_title` | canonical / original / alternate / translated titles + folded forms | 8M |
| 3 | `edition` | a published manifestation of a work | 12M |
| 4 | `edition_isbn` | normalized ISBN-10/13 → edition | 15M |
| 5 | `author` | canonical person | 2M |
| 6 | `author_name` | display name, aliases, romanizations, scripts | 5M |
| 7 | `work_contributor` | work ↔ author, with role | 5M |
| 8 | `edition_contributor` | edition-specific credits (translator, narrator) | 3M |
| 9 | `subject` + `work_subject` | controlled-ish subject vocabulary | 200k + 20M |
| 10 | `cover` | cover candidates, per source, independently purgeable | 4M |
| 11 | `identifier` | external IDs for work / edition / author | 20M |
| 12 | `source_record` | what a provider handed us, and when | 25M |
| 13 | `field_provenance` | which provider owns each contested field | 30M |
| 14 | `work_signal` | popularity / completeness features for ranking | 3M |
| 15 | `work_redirect` | merged work ids keep resolving | small |
| 16 | `edition_redirect` | merged edition ids keep resolving | small |
| 17 | `author_redirect` | merged author ids keep resolving | small |
| 18 | `work_search` | materialized search projection | 3M |

Eighteen tables. Nothing here exists to mirror Open Library — every table
answers a question the spike actually raised.

---

## 3. Key columns, keys, constraints, indexes

Notation: **PK** primary key · **FK** foreign key · **U** unique · **IX** index.

### 3.1 `work` — the unit search returns

| Column | Type | Notes |
|---|---|---|
| `id` | text **PK** | **Dewey work id.** See §3.2 on why text. |
| `work_type` | enum | `book` \| `collection` \| `omnibus` \| `study_guide` \| `periodical` \| `other` |
| `display_title` | text | resolved canonical title (denormalized from `work_title` for read speed) |
| `display_subtitle` | text null | |
| `first_published_year` | int null | never invented — nullable by design |
| `first_published_date` | date null | only when genuinely known |
| `series_name` | text null | v1: denormalized. A `series` entity is deferred (§13) |
| `series_position` | numeric null | numeric, not int — "2.5" novellas exist |
| `description` | text null | **cleaned** at ingest (`CatalogText` rules move server-side) |
| `original_language` | text null | BCP-47; work-level, frequently null and that's correct |
| `ddc` | text null | Dewey Decimal — the app's namesake |
| `display_cover_id` | text null **FK**→`cover.id` | nullable so a purge degrades to typeset |
| `canonical_edition_id` | text null **FK**→`edition.id` | "best" edition for display defaults |
| `merged_into` | text null **FK**→`work.id` | non-null ⇒ this row is a tombstone |
| `created_at` / `updated_at` | timestamptz | |

- **IX** `(work_type)` partial where `merged_into is null` — study-guide demotion needs it cheap
- **IX** `(series_name)` where not null
- **IX** `(updated_at)` — feeds incremental `work_search` refresh and client sync

### 3.2 Identity: why `id` is `text`, not `uuid`

Today's device model already mints Dewey ids: seed books carry slugs
(`"piranesi"`), imported books carry `"dw-" + UUID`. Those strings are already
written into diaries, lists and rankings on real devices.

**A `uuid` PK would force a rewrite of user data on day one.** A `text` PK
accepts every existing value unchanged, and new ids are minted as prefixed
ULIDs — `dw_w_01J…` (work), `dw_e_01J…` (edition), `dw_a_01J…` (author). The
prefix makes a mis-joined id obvious on sight, which is worth more in an
identity-heavy schema than the ~8 bytes a `uuid` would save.

**Provider ids are never identity.** They live in `identifier` (§3.11).

### 3.3 `work_title` — titles without destroying the originals

| Column | Type | Notes |
|---|---|---|
| `id` | bigint **PK** | |
| `work_id` | text **FK**→`work.id` | |
| `kind` | enum | `canonical` \| `original` \| `alternate` \| `translated` \| `subtitle` |
| `title` | text | **the original string, never normalized in place** |
| `language` | text null | BCP-47 where known |
| `folded` | text | lowercase, diacritics stripped, punctuation collapsed |
| `title_key` | text | `folded` with a leading article dropped |
| `is_display` | bool | exactly one true per work |

- **U** `(work_id, kind, title, language)`
- **U** partial `(work_id)` where `is_display` — enforces exactly one display title
- **IX** `(title_key)` and `(folded)` — the article-less/exact-match paths the spike's scoring depends on
- **IX** gin trigram on `title_key` — typo tolerance

Both `folded` and `title_key` are **stored, not computed per query**. The spike
computed them at ingest for exactly this reason; a query-time `unaccent(lower())`
cannot use an index.

### 3.4 `edition` — the manifestation

| Column | Type | Notes |
|---|---|---|
| `id` | text **PK** | `dw_e_…` |
| `work_id` | text **FK**→`work.id` | |
| `title` | text null | edition titles differ from work titles constantly |
| `subtitle` | text null | |
| `language` | text null | BCP-47 — the field that makes translations addressable |
| `publisher` | text null | |
| `published_date` | text null | kept as **text**: OL publish_date is free-form ("1998", "March 2003", "n.d.") |
| `published_year` | int null | parsed best-effort *alongside* the original, never replacing it |
| `page_count` | int null | |
| `format` | enum null | `hardcover` \| `paperback` \| `ebook` \| `audiobook` \| `other` |
| `cover_id` | text null **FK**→`cover.id` | edition-specific cover |
| `merged_into` | text null **FK**→`edition.id` | tombstone |

- **IX** `(work_id)`, **IX** `(work_id, language)` — "editions in my language"
- **IX** `(work_id, published_year desc nulls last)` — canonical-edition selection

`format = audiobook` is not cosmetic: the *Red Rising* narrator bug that the
prototype fixed client-side came from an audiobook edition's credits. Being
able to say "this contributor came from an audiobook edition" is how that fix
becomes structural (§3.8).

### 3.5 `edition_isbn` — ISBN as an identifier, not text

| Column | Type | Notes |
|---|---|---|
| `edition_id` | text **FK**→`edition.id` | |
| `isbn13` | char(13) | **always stored as ISBN-13**, ISBN-10 converted on ingest |
| `isbn10` | char(10) null | retained when the source supplied one |
| `source` | text | which provider asserted it |

- **PK** `(edition_id, isbn13)`
- **U** `(isbn13)` — *see the caveat below*
- **IX** `(isbn10)` where not null

**The spike's ISBN failure, designed out.** Meilisearch and Typesense both
returned nothing for every ISBN query because ISBN was configured as a
filterable field that the text-query path never touched — a *silent* failure.
Two schema-level defenses:

1. **One canonical form.** ISBN-10 is normalized to ISBN-13 at ingest, so
   there is exactly one column to look up. The Typesense cross-field
   `isbn13 || isbn10` OR-filter that silently returned zero hits has no
   analogue here, because there is no second field to forget.
2. **The API contract makes the exact path mandatory, not optional** (§15):
   ISBN-shaped input is routed to an identifier lookup *before* any text
   query runs. A text search over ISBNs is not a fallback — it is a bug.

The **U** `(isbn13)` constraint is aspirational and will need a decision: in
real data the same ISBN occasionally appears on two edition records (bad
upstream data, or a genuine reissue reusing an ISBN). Recommendation: make it
**non-unique with a uniqueness violation report**, so bad data is visible
rather than blocking ingest. Flagged rather than silently resolved.

### 3.6 `author` + `author_name` — the identity problem, storable

The spike proved this is first-class: *"James" by Percival Everett* exists with
8 editions under a second author record (`"Percival L. Everett"`, disjoint id
from `"Percival Everett"`), and *Convenience Store Woman*'s canonical author
name is `村田沙耶香`, which `fold("Sayaka Murata")` will never match.

`author`

| Column | Type | Notes |
|---|---|---|
| `id` | text **PK** | `dw_a_…` |
| `display_name` | text | the resolved, reader-facing form |
| `sort_name` | text null | "Everett, Percival" |
| `birth_date` / `death_date` | text null | free-form upstream, kept as text |
| `merged_into` | text null **FK**→`author.id` | tombstone |

`author_name` — **one row per string anyone might type or see**

| Column | Type | Notes |
|---|---|---|
| `id` | bigint **PK** | |
| `author_id` | text **FK**→`author.id` | |
| `name` | text | original string, preserved exactly |
| `kind` | enum | `display` \| `alias` \| `romanization` \| `transliteration` \| `pseudonym` \| `source_variant` |
| `script` | text null | ISO 15924 (`Latn`, `Jpan`, `Hang`, `Cyrl`) |
| `language` | text null | |
| `folded` | text | folded form — **this is what search matches** |
| `source` | text | provider that supplied it |

- **IX** `(folded)` — the join that makes "Sayaka Murata" find 村田沙耶香
- **IX** gin trigram on `folded` — author typo tolerance
- **IX** `(author_id)`
- **U** `(author_id, name, kind)`

**This schema does not do entity resolution — it stores its results.** Merging
`"Percival Everett"` and `"Percival L. Everett"` is a decision made elsewhere
(a heuristic pass, an editorial action, or a licensed provider's authority
file). What the schema guarantees is that when the decision is made, it is
*recordable and reversible*: one `author_redirect` row and a re-point of
`work_contributor`, with the losing name retained as an `author_name` row of
kind `source_variant`. Nothing is destroyed, so a wrong merge is undoable.

Romanization is the one case worth noting as **not yet solvable by merge**:
村田沙耶香 and "Sayaka Murata" are the *same* author record already — the fix
is an `author_name` row of kind `romanization`, not a merge. The schema must
support both operations because the spike surfaced both problems.

### 3.7 `work_contributor`

| Column | Type | Notes |
|---|---|---|
| `work_id` | text **FK**→`work.id` | |
| `author_id` | text **FK**→`author.id` | |
| `role` | enum | `author` \| `co_author` \| `editor` \| `illustrator` |
| `position` | int | credit order |

- **PK** `(work_id, author_id, role)`
- **IX** `(author_id)` — "everything by this person", the author-only query class (4/4 in the spike)

### 3.8 `edition_contributor` — and why it is separate

| Column | Type | Notes |
|---|---|---|
| `edition_id` | text **FK**→`edition.id` | |
| `author_id` | text **FK**→`author.id` | |
| `role` | enum | `translator` \| `narrator` \| `illustrator` \| `editor` \| `afterword` |
| `position` | int | |

- **PK** `(edition_id, author_id, role)`

**Translators and narrators belong to editions, not works** — a novel has one
author and eight translators, one per language edition. Collapsing them onto
the work is what produced *"Red Rising by Renee Joiner"*. Keeping them here
means the work-level credit used for search and display is structurally
incapable of picking up an audiobook narrator.

Translator is also a genuine product signal — it is a taste marker readers
care about and most reading apps bury it — so this table is display surface,
not just hygiene.

### 3.9 `subject` / `work_subject`

| `subject` | | |
|---|---|---|
| `id` | bigint **PK** | |
| `label` | text **U** | original string |
| `folded` | text | |
| `vocabulary` | enum | `ol_folksonomy` \| `bisac` \| `thema` \| `lcsh` \| `dewey_curated` |

| `work_subject` | | |
|---|---|---|
| `work_id` + `subject_id` | **PK** composite, both **FK** | |
| `source` | text | |

Subjects are stored relationally rather than as a `text[]` because
`vocabulary` matters the moment a licensed provider arrives with BISAC/Thema
alongside OL's folksonomy — and because "all works with subject X" is a
plausible browse feature. They stay **weight-D** in search (the spike's
setting; folksonomy noise must never drive a result).

### 3.10 `cover` — separate, and never assumed to be ours

| Column | Type | Notes |
|---|---|---|
| `id` | text **PK** | |
| `work_id` | text null **FK**→`work.id` | one of work_id/edition_id is set |
| `edition_id` | text null **FK**→`edition.id` | |
| `source` | enum | `openlibrary` \| `licensed` \| `publisher` \| `dewey_typeset` |
| `source_ref` | text | OL CoverID, vendor asset id, or URL |
| `license_posture` | enum | `unlicensed_cached` \| `licensed` \| `generated` |
| `fetched_at` | timestamptz null | |
| `cached_object_key` | text null | our CDN/object-store key, null if not cached |
| `purged_at` | timestamptz null | non-null ⇒ do not serve |

- **IX** `(work_id)`, `(edition_id)`, `(source)`
- **IX** `(source, purged_at)` — "purge every cover from source X" must be one indexed statement

**Why a table and not a column.** The architecture review's conclusion was
that no free provider licenses cover art, because none owns it. That makes
"remove one cover source without deleting the book" a hard requirement.
`work.display_cover_id` is a nullable FK: purging sets it null, and the
deterministic typeset palette (derived from the work id, stored nowhere)
becomes the cover. The book, its diary entries, and its ratings are untouched.

`license_posture` is recorded per row so a future licensed corpus and today's
cached OL references can coexist and be told apart by a single query — which
is what makes the Phase 3 cover migration a data operation rather than a
rewrite.

### 3.11 `identifier` — every external id, in one place

| Column | Type | Notes |
|---|---|---|
| `id` | bigint **PK** | |
| `entity_type` | enum | `work` \| `edition` \| `author` |
| `entity_id` | text | not a real FK — polymorphic (see note) |
| `provider` | enum | `openlibrary` \| `nielsen` \| `bowker` \| `isbndb` \| `dewey_seed` |
| `id_type` | text | `ol_work`, `ol_edition`, `ol_author`, `oclc`, `lccn`, `nielsen_isbn`… |
| `value` | text | |
| `is_primary` | bool | the id we'd use to re-fetch this entity |
| `first_seen_at` / `last_seen_at` | timestamptz | `last_seen_at` is how upstream deletions are detected |

- **U** `(provider, id_type, value, entity_type)`
- **IX** `(entity_type, entity_id)`
- **IX** `(provider, last_seen_at)` — "what did this month's dump stop mentioning?"

**Polymorphic, deliberately.** The alternative is three near-identical tables.
The tradeoff — no FK integrity on `entity_id` — is accepted because merges
already require rewriting `entity_id` in bulk, and a periodic integrity check
is cheaper than triplicating the table and every query over it. This is the
one place the schema trades referential purity for comprehensibility, and it
is called out rather than hidden.

Critically: **a work keeps every OL work id it has ever been known by.** The
spike merged 2,523 duplicate work groups; each merged record contributes its
`ol_work` identifier row to the survivor. A stale OL id in a device's cache
still resolves.

### 3.12 `source_record` — what we were handed

| Column | Type | Notes |
|---|---|---|
| `id` | bigint **PK** | |
| `provider` | enum | |
| `record_type` | text | `work` \| `edition` \| `author` |
| `provider_id` | text | e.g. `OL20893680W` |
| `acquisition` | enum | `dump` \| `api` \| `manual` |
| `source_version` | text | dump date `2026-07-31`, or API fetch date |
| `imported_at` | timestamptz | |
| `payload` | jsonb null | **null for dump-derived records** — see below |
| `payload_ref` | text null | object-store key when a payload is retained out-of-line |
| `content_hash` | text | detects "unchanged since last dump" cheaply |

- **U** `(provider, record_type, provider_id, source_version)`
- **IX** `(provider, source_version)`
- **IX** `(content_hash)`

**Do dump payloads belong in Postgres? No.** The full works+editions+authors
raw JSON is 60–90GB uncompressed, and — decisively — **it is reproducible**:
Open Library publishes monthly dumps at stable archived URLs (the spike pulled
`ol_dump_works_2026-07-31.txt.gz`, 4.04GB, directly). Storing 60GB of
re-downloadable JSON in the primary database is the definition of schema bloat.

The policy, three-way:

| Acquisition | Payload retention | Why |
|---|---|---|
| `dump` | **none** — metadata + `content_hash` only | reproducible from the archived dump by `(source_version, provider_id)` |
| `api` (force-import, gap-fill) | **full `payload` jsonb** | *not* reproducible — a live API record can change or vanish before the next dump; these are the books a user actually cared about |
| `manual` (editorial) | **full payload** | irreplaceable by definition |

One hedge: keep **the most recent dump only** in object storage (~16GB
compressed) rather than relying on archive.org retaining historical dumps
indefinitely. Not every historical dump — one.

API-acquired payloads are low-volume by construction (only books someone
searched for and imported between dumps), so retaining them fully costs
little and buys exactly the durability that matters.

### 3.13 `field_provenance` — the minimum that supports precedence

| Column | Type | Notes |
|---|---|---|
| `entity_type` | enum | `work` \| `edition` \| `author` |
| `entity_id` | text | |
| `field` | text | `title`, `subtitle`, `description`, `first_published_year`, `series_name`, `page_count`, `ddc`, `cover`, `subjects` |
| `provider` | enum | includes `dewey_editorial` |
| `source_record_id` | bigint null **FK**→`source_record.id` | |
| `set_at` | timestamptz | |
| `locked` | bool | editorial override — no ingest may overwrite |

- **PK** `(entity_type, entity_id, field)` — **one row per field, not per claim**
- **IX** `(provider, field)` — "every field still sourced from OL", the Phase-2 work queue
- **IX** partial `(entity_type, entity_id)` where `locked`

**Why one row per field and not a claims table.** A claims table (every
provider's value for every field, retained) is the academically correct
design and the wrong one here: at 3M works × 9 fields × 2 providers it is
~54M rows of mostly-identical strings, and it duplicates something we already
have — **the losing values are recoverable from `source_record`** (raw
payloads for API records, re-derivable from the archived dump for the rest).

So provenance stores only *who currently owns each field*. Re-resolution —
"Nielsen now covers descriptions, re-run precedence" — is a batch job that
reads sources and rewrites winners, not a query over stored claims. This is
the minimum that supports both precedence *and* replaceability, which is what
was asked for.

`locked` is the one non-obvious column and it earns its place: without it,
every manual correction is silently reverted by the next monthly dump.

Precedence, v1 (highest wins):
```
dewey_editorial (locked)  >  nielsen/bowker  >  isbndb  >  openlibrary  >  dewey_seed
```

### 3.14 `work_signal` — ranking features, and the Piranesi problem

| Column | Type | Notes |
|---|---|---|
| `work_id` | text **PK FK**→`work.id` | |
| `edition_count` | int | kept, but demoted — see below |
| `recent_edition_count` | int | editions published in the last 25 years |
| `ol_readers` | int null | from OL's **reading-log dump** |
| `ol_rating_count` | int null | from OL's **ratings dump** |
| `ol_rating_avg` | numeric null | |
| `dewey_saves` | int | our own users' saves/logs — the best signal, available once we have users |
| `completeness` | smallint | 0–100: has description, cover, ISBN, year, subjects |
| `is_derivative` | bool | study-guide/companion heuristic |
| `computed_at` | timestamptz | |

- **IX** `(is_derivative)` where false
- **IX** `(dewey_saves desc)`

**This table exists because of one benchmark row.** `"Piranesi"` ranks
Giovanni Battista Piranesi's 18th-century etchings (25 editions) above Susanna
Clarke's novel (23 editions). `edition_count` is not a popularity measure — it
is a *reprint-history* measure, and it systematically favours public-domain
works over contemporary ones, precisely inverting what a reading app wants.

Better signals, and their cost:

| Signal | Source | Cost | Verdict for v1 |
|---|---|---|---|
| `ol_readers` | OL **reading-log dump**, ~65MB | one more monthly file | **include** — cheap, and directly separates a read novel from an unread art folio |
| `ol_rating_count` / `avg` | OL **ratings dump**, ~5MB | trivial | **include** — same reason, near-zero cost |
| `recent_edition_count` | derivable from `edition.published_year` | free | **include** |
| `dewey_saves` | our own social schema | a periodic aggregate job | **include the column**, populate when users exist |
| Holdings / checkouts | licensed only | contract | defer to Phase 3 |

The reading-log and ratings dumps are published alongside the works dump and
were visible in the spike's dump inventory. They are small, monthly, free, and
they fix the single most embarrassing ranking failure in the benchmark. That
clears the "cheap and justified" bar the brief set.

`work_signal` is deliberately a **separate table from `work`**: it is
recomputed on a different cadence (nightly aggregates vs monthly ingest), and
separating it means a signal refresh never touches canonical catalog rows.

### 3.15–3.17 Redirects

Three narrow tables — `work_redirect`, `edition_redirect`, `author_redirect` —
all the same shape:

| Column | Type |
|---|---|
| `old_id` | text **PK** |
| `new_id` | text **FK**→ the corresponding entity table |
| `reason` | enum `duplicate` \| `upstream_merge` \| `editorial` |
| `merged_at` | timestamptz |

- **IX** `(new_id)` — "what merged into this?"

**Three tables, not one polymorphic one**, because these get real FKs to real
targets and are read on the hot resolve path. Understandable beats clever, per
the brief.

**Chains are collapsed at write time.** When B merges into C, any existing row
`A → B` is rewritten to `A → C` in the same transaction. Resolution is
therefore always a single lookup, never a loop — a property worth enforcing at
merge time rather than defending against at read time.

The spike verified this mechanic end to end: delete from the search index
(milliseconds on all three engines), insert the redirect row, and
`select new_id from book_redirect where old_id='DWTEST1'` still answers.

### 3.18 `work_search` — the materialized projection

One row per non-tombstoned work. Rebuildable from the catalog at any time;
holds no truth of its own.

| Column | Type | Notes |
|---|---|---|
| `work_id` | text **PK FK**→`work.id` | |
| `display_title` / `display_authors` | text | for rendering results without a join |
| `title_key` / `title_folded` | text | primary match paths |
| `alt_title_keys` | text[] | every alternate/original/translated title |
| `authors_folded` | text[] | **includes aliases and romanizations from `author_name`** |
| `isbns` | char(13)[] | unified, ISBN-13 normalized |
| `year` | int null | |
| `languages` | text[] | |
| `work_type` | enum | |
| `is_derivative` | bool | |
| `popularity` | real | precomputed blend from `work_signal` |
| `completeness` | smallint | |
| `cover_ref` | text null | |
| `tsv` | tsvector | weighted A=title, B=authors+alt titles, C=subtitle/series, D=subjects |
| `updated_at` | timestamptz | |

- **IX** gin `(tsv)`
- **IX** gin trigram `(title_key)`, gin trigram on `array_to_string(authors_folded,' ')` — **as a stored column**, since the spike hit `functions in index expression must be marked IMMUTABLE` trying to index `array_to_string(...)` directly
- **IX** gin `(isbns)`
- **IX** `(is_derivative, popularity desc)`

`authors_folded` carrying aliases and romanizations is the single most
important line in this table: it is what makes a search for "Sayaka Murata"
reach a work whose upstream canonical author is 村田沙耶香, without any
query-time cleverness.

---

## 4. Relationship diagram

```
                        ┌───────────────┐
                        │  source_record│──────────────┐
                        └───────┬───────┘              │
                                │ derives              │ cites
                                ▼                      ▼
   work_title ──┐        ┌─────────────┐        field_provenance
   work_subject─┼───────▶│    work     │◀────── work_signal
   cover ───────┘        └──────┬──────┘
                                │ 1:N
                                ▼
                         ┌─────────────┐
              cover ────▶│   edition   │──▶ edition_isbn
                         └──────┬──────┘
                                │
        work_contributor        │ edition_contributor
                 └──────┐       │       ┌──────┘
                        ▼       ▼       ▼
                        ┌───────────────┐
                        │    author     │◀── author_name
                        └───────────────┘

   identifier ──▶ (work | edition | author)      [polymorphic]
   *_redirect  ──▶ same-type entity               [tombstone → survivor]
   work_search ◀── projection of work + titles + authors + signals
```

---

## 5. Worked example — Piranesi across all layers

Real values, taken from the spike corpus. The two records are genuinely
different books that collide on title, and the schema must keep them apart.

```
work  dw_w_01JCLARKE
  work_type            book
  display_title        "Piranesi"
  first_published_year 2020
  original_language    en
  display_cover_id     cv_ol_8225261
  ─ work_title
      canonical  "Piranesi"          folded "piranesi"  title_key "piranesi"  is_display ✓
  ─ work_contributor
      author dw_a_01JSCLARKE  role author  position 0
  ─ identifier
      openlibrary / ol_work / OL20893680W   is_primary ✓
  ─ work_signal
      edition_count 23   recent_edition_count 23   ol_readers 41,000   dewey_saves 0
      is_derivative false   completeness 95
  ─ edition (23 of them), e.g.
      dw_e_01JC001  language en  publisher "Bloomsbury"  published_year 2020
        └ edition_isbn  isbn13 9781526622426
      dw_e_01JC017  language en  format audiobook  published_year 2020
        └ edition_contributor  author dw_a_…  role narrator     ← never reaches work credits

work  dw_w_01JGIOVANNI
  work_type            collection
  display_title        "Piranesi"
  first_published_year 1910
  ─ work_contributor
      author dw_a_01JGBPIRANESI  role author
  ─ identifier
      openlibrary / ol_work / OL2827133W
  ─ work_signal
      edition_count 25   recent_edition_count 2   ol_readers 30   dewey_saves 0
      is_derivative false   completeness 60
```

Two distinct works, correctly. **`edition_count` alone ranks the etchings
first (25 > 23) — the observed spike failure.** `ol_readers` (41,000 vs 30) and
`recent_edition_count` (23 vs 2) both invert it correctly, which is precisely
why §3.14 exists.

The study guide is a third work, `work_type = study_guide`,
`work_signal.is_derivative = true` — demoted by a large fixed penalty, still
retrievable, never rank 1.

---

## 6. Worked example — Percival Everett author merge

Before (real Open Library state, verified in the spike):

```
author dw_a_01JPE_A  display_name "Percival Everett"
   └ identifier openlibrary/ol_author/OL…A
author dw_a_01JPE_B  display_name "Percival L. Everett"
   └ identifier openlibrary/ol_author/OL…B
   └ work_contributor → dw_w_01JJAMES ("James", 2024, 8 editions)
```

A reader searching "Percival Everett" finds nothing for *James* — the spike's
observed "target absent".

The merge, one transaction:

```
1. author dw_a_01JPE_B  set merged_into = dw_a_01JPE_A         (tombstone)
2. author_redirect      insert (dw_a_01JPE_B → dw_a_01JPE_A, reason upstream_merge)
   + rewrite any existing redirect pointing at …PE_B to …PE_A  (chain collapse)
3. author_name          insert (dw_a_01JPE_A, "Percival L. Everett",
                                kind source_variant, source openlibrary)
4. work_contributor     re-point dw_w_01JJAMES → dw_a_01JPE_A
5. identifier           re-point OL…B's row to entity_id dw_a_01JPE_A
6. work_search          refresh dw_w_01JJAMES → authors_folded now contains
                        BOTH "percival everett" and "percival l everett"
```

Both spellings now find *James*. Nothing was deleted, so the merge is
reversible. No user data moved — no diary entry ever referenced an author id.

---

## 7. Worked example — Sayaka Murata romanization

**Not a merge.** One author, whose upstream canonical name is non-Latin:

```
author dw_a_01JMURATA
  display_name  "Sayaka Murata"        ← resolved for an English-reading audience
  ─ author_name
      "村田沙耶香"      kind display        script Jpan  source openlibrary
      "Sayaka Murata"  kind romanization   script Latn  source dewey_editorial
      "むらた さやか"    kind transliteration script Jpan
  ─ work_contributor → dw_w_01JCSW ("Convenience Store Woman", OL19744024W)
```

`work_search.authors_folded` for that work becomes
`["murata sayaka", "sayaka murata", ...]`, so the English query matches.

Note `display_name` is set by **`dewey_editorial` precedence overriding
Open Library's value** — a legitimate, recorded editorial decision, not a data
error, with `field_provenance(author, dw_a_01JMURATA, 'display_name',
dewey_editorial, locked=true)` ensuring the next monthly dump does not revert
it to 村田沙耶香.

This is the case that proves `locked` is not optional.

---

## 8. Worked example — Nielsen superseding Open Library

No id changes. No user data touched. One field moves provider.

Before:
```
work dw_w_01JCLARKE  description "In a strange house of endless halls…"
field_provenance (work, dw_w_01JCLARKE, description, openlibrary, src#8812)
```

After a Nielsen ingest, where Nielsen outranks OL and the field is not locked:
```
source_record  #99120  provider nielsen  record_type work
               provider_id 9781526622426  acquisition api  payload {…}

work dw_w_01JCLARKE  description "<publisher-supplied copy>"
field_provenance (work, dw_w_01JCLARKE, description, nielsen, src#99120)
```

- `work.id` unchanged ⇒ every diary entry, review, score, list and ranking
  still resolves. **This is the entire point of the identity design.**
- The OL value is not stored twice — it is re-derivable from
  `source_record #8812` (§3.12), so a rollback is a re-resolve, not a restore.
- Fields Nielsen does not cover keep their OL provenance untouched. Migration
  is **per-field**, not per-record — which is what makes Phase 2 incremental
  rather than a cutover.
- The Phase-2 work queue is one indexed query:
  `select … from field_provenance where provider='openlibrary' and field='description'`.

---

## 9. The ten update scenarios

| # | Scenario | Mechanism | Touches user data? |
|---|---|---|---|
| 1 | **Monthly OL dump** | stream dump → `content_hash` compare → upsert changed `source_record` → re-resolve fields where OL still wins precedence → refresh `work_search` rows by `updated_at` | no |
| 2 | **Force-import between dumps** | live OL API → `source_record(acquisition='api', payload retained)` → mint `dw_w_…` → insert `work`/`edition`/`author` → insert `work_search` row. Spike measured the index side at <100ms | no |
| 3 | **Metadata correction** | new winning value + `field_provenance` row updated; if editorial, `locked=true` so the next dump cannot revert it | no |
| 4 | **Work merge** | loser `merged_into` set, `work_redirect` row inserted, chains collapsed, identifiers/contributors/editions/covers re-pointed to survivor, loser's `work_search` row deleted | **no** — old id still resolves via redirect |
| 5 | **Edition merge** | same shape at edition level; `edition_isbn` rows move to survivor; `work_signal.edition_count` recomputed | no |
| 6 | **Author merge** | §6 | no |
| 7 | **New ISBN** | insert `edition_isbn`; refresh that work's `work_search.isbns` | no |
| 8 | **Better cover** | insert a new `cover` row; re-point `work.display_cover_id`. The old row stays (provenance + rollback) | no |
| 9 | **Nielsen enrichment** | §8 — per-field precedence, no id churn | no |
| 10 | **Upstream cover removal** | set `cover.purged_at`; if it was the display cover, null `work.display_cover_id` → typeset fallback renders. Purging a whole source is one indexed statement on `(source, purged_at)` | no |

**Every row of that last column is "no", and that is the design's central
claim.** Catalog churn — merges, corrections, provider swaps, cover purges —
never rewrites a diary entry, because user data points at Dewey ids and Dewey
ids never change meaning.

---

## 10. Social schema stays separate

Not in the catalog, ever:

`library_entry` · `diary_entry` · `review` · `score` · `ranking` ·
`ranking_placement` · `book_list` · `list_item` · `favorite_books` ·
`follow` · `recommendation` · `note`

Each holds `dewey_work_id text` (plus `dewey_edition_id text null` where the
edition genuinely matters — a diary entry's format, a page-count-dependent
progress note). Foreign keys to `work.id` are **advisory, not enforced**:
a hard FK would make a catalog merge cascade into user rows, which is exactly
what the redirect tables exist to avoid.

Resolution on read: `work_id` → if tombstoned, follow `work_redirect` → live
work. One lookup, because chains are collapsed at write time (§3.15).

---

## 11. Offline display snapshots — where the boundary sits

The architecture review's conclusion, made concrete:

**A snapshot lives on the user record, in the social schema. It is never a
catalog row, and the catalog never reads it.**

```
diary_entry
  id, user_id, dewey_work_id, rating, logged_on, review_text, format, …

  snap_title        text      ─┐
  snap_authors      text[]     │  written at log time,
  snap_year         int        │  refreshed opportunistically on sync,
  snap_cover_ref    text       │  NEVER null, NEVER evicted
  snap_updated_at   timestamptz┘
```

The boundary, stated three ways:

- **Authority:** the catalog is authoritative for what a book *is*; the
  snapshot is authoritative for *what this diary row renders as offline*.
  When they disagree, the catalog wins on next sync — but the snapshot renders
  in the meantime.
- **Lifecycle:** catalog rows are merged, corrected, re-provenanced and purged
  by ingest jobs. Snapshots change only when their owning user record is
  written or refreshed.
- **Failure mode:** a snapshot going stale is a cosmetic bug (an old author
  spelling on an old diary row). A missing catalog lookup in a render path is
  a crash — which is precisely the failure the current iOS `Book.missing` /
  `assertionFailure` history already taught us, recorded in the earlier design.

The current device code already has the embryo of this: `DeweyStore` at
[DeweyStore.swift:549](../../../Dewey/Dewey/Store/DeweyStore.swift#L549)
resolves `book(resolving: snapshot)` and falls back to *the snapshot in hand*
when the store no longer knows the id. That instinct was right; this schema
makes it durable and server-backed rather than incidental.

Snapshots also make Letterboxd's `orphaned` export possible: if a work is ever
withdrawn entirely, the reader's entry still knows what it was about.

---

## 12. Raw OL fields deliberately NOT normalized in v1

Retained in `source_record` (or re-derivable from the dump), not given columns:

| Field | Why not |
|---|---|
| `physical_format` (free text) | 400+ uncontrolled spellings of ~6 real values; `edition.format` enum covers the product need |
| `publish_places`, `publish_country` | no display, search or reconciliation use identified |
| `oclc_numbers`, `lccn`, `lc_classifications` | library identifiers; no Dewey feature consumes them. Cheap to promote into `identifier` later if one does |
| `by_statement` | unparsed credit prose ("as told to…"); `work_contributor` carries the structured truth |
| `table_of_contents` | large, rarely populated, no surface |
| `first_sentence`, `excerpts` | licensing ambiguity for a field with no current feature |
| `notes` | free-form cataloguer remarks, frequently internal |
| `copyright_date` | duplicates `published_date` for ~all records |
| `pagination` (string, e.g. "xii, 340 p.") | `page_count` int is the usable form; the string adds nothing |
| `subject_places` / `subject_people` / `subject_times` | fold into `subject` with a `vocabulary` tag *if* a browse feature ever needs them |
| `links`, `ocaid` / IA identifiers | Internet-Archive-specific; not a Dewey surface |
| `edition_name` ("2nd rev. ed.") | display-only nicety; revisit when an edition picker exists |
| `translated_from` | genuinely interesting, but only once translations are a product feature — `edition.language` + `edition_contributor(translator)` already carry the useful part |

The rule applied throughout: *does Dewey display, search, reconcile, identify
or update this today?* If no, it stays raw. Nothing is lost — everything above
is reachable from the archived dump by `(source_version, provider_id)`.

---

## 13. Deliberately deferred (not v1)

- **`series` as an entity.** v1 keeps `work.series_name` + `series_position`
  denormalized. A real `series` table with its own id, ordering and aliases is
  justified only when series browse/completion is a feature. The spike's
  series class scored 2/3 with the flat form.
- **A claims table for provenance** (§3.13) — one winner per field plus
  retained sources is sufficient.
- **Algorithmic entity resolution.** The schema *stores* merges and aliases;
  deciding them is a separate pipeline. Explicitly per the brief.
- **Holdings/checkout popularity** — Phase 3, licensed.
- **Edition-level provenance for every field.** v1 tracks provenance for
  work-level contested fields plus `edition.page_count`; broader coverage when
  a second provider actually contests edition data.

---

## 14. Migration from today's local `Book` model

Today ([Book.swift](../../../Dewey/Dewey/Models/Book.swift)): one flat struct,
work and edition fields mixed, persisted on-device in
`DeweyStore.importedBooks: [String: Book]`.

**The migration is a split, not a rewrite, and `Book.id` is why.** The earlier
decision that `Book.id` is Dewey's alone — seed slugs, `dw-`-prefixed UUIDs
for imports, OL ids only ever as attributes — means every existing id becomes
a `work.id` verbatim.

| Today's `Book` field | Lands in |
|---|---|
| `id` | `work.id` **unchanged** (text PK, §3.2) |
| `title` | `work.display_title` + `work_title(kind=canonical)` |
| `author` | `author` + `work_contributor` |
| `year`, `publishDate` | `work.first_published_year` / `first_published_date` |
| `blurb` | `work.description` |
| `series`, `seriesPosition` | `work.series_name` / `series_position` |
| `genres`, `themes` | `subject` / `work_subject` |
| `deweyDecimal` | `work.ddc` |
| `pageCount`, `publisher`, `language`, `isbn` | **`edition`** + `edition_isbn` |
| `translator`, `narrator`, `illustrator`, `editor` | **`edition_contributor`** (§3.8) |
| `openLibraryWorkID` / `openLibraryEditionID` | `identifier` rows |
| `remoteCoverID` | `cover(source=openlibrary, source_ref=…)` |
| `editionCount` | `work_signal.edition_count` |
| `reach` | derived from `work_signal` at render time — not stored |
| `coverPalette` | derived deterministically from `work.id` — not stored |
| `catalogRefreshedAt` | `source_record.imported_at` (server-side now) |
| `characters`, `setting`, `adaptationNote`, `relatedBookIDs` | **seed-only editorial data** — `dewey_editorial` provenance, `locked` |

Sequencing:

1. **Seed the catalog.** The 41 seed books become `work` rows with
   `provider = dewey_seed`, carrying their verified OL work ids as
   `identifier` rows — so a catalog hit for a seeded book resolves *to the
   seeded book*, ratings intact. That property already exists on device and
   must survive.
2. **Ingest OL dumps** into the same tables.
3. **Upload each device's `importedBooks`** as `work` rows if not already
   present (matched by OL work id, then by title+author), inserting a
   `work_redirect` where a device id and a catalog id turn out to be the same
   book. **No device-side id is ever discarded.**
4. **iOS `Book` becomes a display projection** of the API response (§16), plus
   the snapshot embedded in user records. `importedBooks` stops being a
   store of record and becomes an LRU cache.
5. **User data is not migrated at all** — it already points at the right ids.

---

## 15. What the search API queries

`GET /v1/search?q=…` resolves in a fixed order. The order is the contract:

```
1. ISBN path      input matches ISBN-10/13 shape (after stripping punctuation)
                  → normalize to ISBN-13 → work_search.isbns @> array[…]
                  → EXACT. No text query runs. No ranking applied.

2. Text path      plainto_tsquery over work_search.tsv
                  OR trigram similarity on title_key   (typo floor)
                  OR trigram similarity on authors_folded

3. Score          exact article-less title match      → large, near-absolute
                                                        (lexical rank SUPPRESSED
                                                         on this branch — §4a of
                                                         the spike)
                  + author-token match                → only when the query is
                                                        not already a full title
                  + popularity (damped log)           → nudges, never decides
                  − is_derivative                     → large fixed penalty
                  + trigram similarity                → typo floor

4. Resolve        follow work_redirect for any tombstoned id
```

Step 1 is a **schema-enforced contract, not a convention** — the spike's
silent ISBN failure happened because ISBN lookup was left to text
configuration. Here there is one normalized `isbns` column and one branch that
must be taken before text matching is even attempted.

---

## 16. What the iOS app receives

Never provider-shaped. Never a raw OL structure. Never an internal ranking signal.

```jsonc
// GET /v1/search?q=piranesi
{
  "results": [{
    "work_id":   "dw_w_01JCLARKE",     // Dewey id — the only id iOS ever stores
    "title":     "Piranesi",
    "subtitle":  null,
    "author":    "Susanna Clarke",      // resolved display string
    "year":      2020,
    "series":    null,
    "cover_ref": "ol:8225261",          // opaque; resolved via Dewey's cover proxy
    "match":     { "kind": "title_exact" },
    "in_library": true
  }]
}

// GET /v1/works/dw_w_01JCLARKE
{
  "work_id": "dw_w_01JCLARKE",
  "title": "Piranesi", "subtitle": null,
  "authors": [{ "author_id": "dw_a_01JSCLARKE", "name": "Susanna Clarke", "role": "author" }],
  "year": 2020, "description": "…", "series": null,
  "ddc": "823.92", "subjects": ["Fantasy fiction"],
  "cover_ref": "ol:8225261",
  "edition_summary": { "count": 23, "languages": ["en","it","es"], "median_pages": 272 }
}
```

**Withheld deliberately** — present in the schema, never serialized:
`ol_work_ids` and every other provider identifier, `author_ids` beyond the
Dewey one, `edition_count` as a raw number, `is_derivative`, `popularity`,
`completeness`, `work_record_count`, `field_provenance`, `source_record`.

These are ranking and operations signals. Shipping them would leak provider
shape and internal scoring into a client we cannot redeploy quickly — the
exact coupling this whole architecture exists to prevent. `edition_summary`
is the deliberate exception: a *reader-meaningful* summary, not the raw
ranking input.

---

## Open questions

1. **`edition_isbn` uniqueness** (§3.5) — recommend non-unique + a violation
   report, but this needs a decision before ingest is written.
2. **Author romanization coverage.** Editorial romanizations do not scale to
   every non-Latin author. Options: a transliteration library at ingest
   (imperfect, cheap), Wikidata's `ol_dump_wikidata` (~700MB, already
   published alongside the other dumps, carries multilingual labels), or
   accept partial coverage in v1. **The Wikidata dump is the most promising
   and was not evaluated in the spike** — worth a short follow-up before this
   schema is implemented.
3. **`work_type` assignment.** `study_guide` detection is currently a title
   heuristic that the spike showed to be incomplete (it missed a plainly-titled
   companion volume). A publisher denylist is the recommended supplement; the
   schema supports either, but the classifier itself is unbuilt.
4. **Snapshot refresh cadence** — on every sync, or only when
   `work.updated_at > snap_updated_at`? A product/bandwidth decision, not a
   schema one; the columns support both.

---

**Not done, by design:** no SQL, no migrations, no ingestion pipeline, no
search-engine reconsideration.
