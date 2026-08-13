# Open Library as Dewey's External Catalog

**Date:** 2026-08-06 · **Status:** Approved (with three amendments, incorporated below)

## Premise

The Letterboxd model. Letterboxd does not maintain film metadata; TMDB is the
catalog, and Letterboxd owns the users, ratings, diaries, reviews, lists, and
social graph built on top. Dewey does the same: **Open Library is the catalog;
Dewey owns everything opinionated.**

Open Library is Dewey's **first external catalog provider, not a guaranteed
permanent backbone**. Its own guidelines discourage use as a high-traffic
third-party backend. The provider sits behind a boundary
(`BookCatalogProvider`) so another source can replace or supplement it later.
Google Books and Hardcover are explicitly out of this implementation.

### Why Open Library, checked against the alternatives (2026-08-07)

The provider was chosen for openness before the terms were read closely. Read
closely, the choice is firmer than it looked, because **Dewey's architecture —
storing imported books on device so a diary survives relaunch and works
offline — is the thing most providers forbid.**

- **Open Library** is the only source that affirmatively asks for what Dewey
  does: "Cache responses whenever possible." Metadata is CC0/no-rights-
  asserted. Identified requests (a `User-Agent` with a contact address, which
  the client sends) get 3/second. The covers throttle of 100 requests per IP
  per 5 minutes applies to ISBN-keyed lookups, **not** to CoverID/OLID — which
  is how Dewey addresses covers, so it sidesteps the limit entirely. Its
  "not a backend for high-traffic services" language is satisfied by
  per-device requests plus the TTL, and forbids any centralized harvest.
- **Google Books** prohibits Dewey's design twice over: the API terms ban
  "permanent copies" and caching beyond the cache header, and a cover's
  header is `private, max-age=30` — thirty seconds. It also forbids
  *reordering results*, which is exactly the client-side re-ranking that took
  search from unusable to reliable here; requires "powered by Google"
  branding and a link back on every result; requires written permission to
  charge for the app; and its keyless quota is now literally zero.
- **Amazon** is out on both counts: PA-API 5.0 is deprecated and returns 403,
  and the Associates terms forbid storing images at all, cap other content at
  24 hours, and require the app's principal purpose be driving Amazon sales.
- **Hardcover**'s terms forbid competing commercial use and confine the API to
  a backend, not a shipped client.
- **ISBNdb** ($15–36/month) is the only paid source with an explicit grant to
  store data locally — but it is lease-shaped: cancellation obliges deletion
  of records sitting on users' devices. Viable as *enrichment*, never as the
  store of record.

**Covers are unsolved everywhere.** No free provider licenses cover art,
because none owns it. Bowker/Syndetics is the only licensed corpus and is
enterprise quote-only. This is a separate decision with its own risk, not a
rider on the metadata choice.

So the snags this document records — duplicate work records, credit ordering,
foreign-language covers, weak relevance — are the price of the only licence
that fits, and every one of them turned out to be correctable on the client.
The long-term path, if provider data or uptime ever becomes the constraint, is
Dewey's own catalog seeded from Open Library's monthly dumps plus these
corrections; the Dewey-internal identifiers already make that a migration
rather than a rebuild.

## Identity

External provider IDs never become Dewey's internal identity.

- `Book.id` stays Dewey-internal. Seed books keep their slugs; imported books
  get a generated internal ID at first sight, stable thereafter.
- Open Library identifiers are stored as attributes on `Book`:
  - `openLibraryWorkID: String?` (e.g. `"OL45883W"`) — primary external key
  - `openLibraryEditionID: String?` — pinned edition, when edition-specific
    data has been fetched
  - `isbn: String?` (already present) — where available
  - `remoteCoverID: Int?` — Open Library cover reference
  - `catalogRefreshedAt: Date?` — when metadata was last fetched
- Re-encountering a work already known (imported or transient) resolves to the
  existing Dewey ID via a work-ID index; the same work never mints two IDs
  while any reference to the first survives.
- Seed and imported books coexist under one identity model; seed books simply
  have `nil` external IDs.

## Division of responsibility

| Open Library | Dewey |
|---|---|
| Works, editions, authors | Users, follows, social activity |
| ISBNs, publication metadata | Library status, reading logs |
| Covers, descriptions, subjects | Ratings, reviews, favorites |
| | Lists, rankings, recommendations, provenance |

Dewey's activity types (`LibraryEntry`, `DiaryEntry`, list items, rankings,
`myRatings`) already key on `bookID: String` and are unchanged.

## Components

### `Catalog/BookCatalogProvider.swift`
A small protocol: `search(_:) async throws -> [CatalogSearchResult]`,
`work(_ workID: String) async throws -> CatalogWork`. Normalized DTOs, not
provider-shaped JSON, cross the boundary. One protocol, one implementation —
no speculative abstraction beyond the seam itself.

### `Catalog/OpenLibraryClient.swift`
- Search: `GET https://openlibrary.org/search.json` with explicit `fields`,
  `limit=20`
- Work detail: `GET /works/{OLID}.json` — description, subjects
- Covers: `https://covers.openlibrary.org/b/id/{cover_i}-{S|M|L}.jpg`
- Sends `User-Agent: Dewey (jacksirianni@icloud.com)` (identified tier,
  3 req/s)
- No API key. Plain `URLSession`, async/await, `Codable` DTOs.

### Normalization → `Book`
- Everything Open Library doesn't know stays honestly `nil` — never invented.
- `year` becomes `Int?` (`first_publish_year` is sometimes absent).
- `blurb` is `""` until a work fetch supplies a description; surfaces hide
  empty blurbs.
- `Reach` derives from `edition_count`: >100 ubiquitous, >15 known, else
  uncommon.
- `coverPalette` derives deterministically (FNV-1a) from the provider work ID:
  a stable typeset cover that underlies the remote jacket and stands alone
  when there is none.

### Store (`DeweyStore`)
- `importedBooks: [String: Book]` — persisted, new **optional** key in
  `Persistence.State` (old files restore unchanged; no filename bump — no
  existing key changes meaning).
- `viewedRemoteBooks: [String: Book]` — transient, in-memory only. Opening a
  remote search result registers it here; merely viewing never joins the
  catalog.
- Lookup chain: `importedBooks → seed → viewedRemoteBooks → missing`.
- **Import on durable action only**: `save`, `log`, `addToList`,
  `saveRanking`, `send`, `setNote`, `toggleFeatured`/`setFavoriteBooks`
  promote a transient book to `importedBooks` inside the store method itself —
  no view changes, no missable paths.

### Unknown-ID fallback (pre-req fix)
`SeedData.book(id)` returned `books[0]` for unknown IDs — an unresolved ID
silently rendered as the first seeded book. `SeedData.find(_:)` is now
optional and `DeweyStore.book(_:)` owns the policy: an unresolvable ID
returns an explicit `Book.missing` ("Unknown book"), logged in debug builds.

**Not an assertion, and the reason matters.** It was `assertionFailure`
first. A debug world switch then crashed the app: the switch replaced the
library, and a `LibraryRow` for a removed entry evaluated its body one last
time before SwiftUI dropped it, resolving an ID the store had just
legitimately discarded. That window is ordinary SwiftUI behaviour on any
removal — deleting a diary entry, dropping a book from a list — so trapping
in a lookup that views call *during render* converts routine view churn into
a crash while doing nothing about the real hazard. The real hazard is a
**durable record** pointing at nothing, and that is refused where it can be
refused honestly: at the write (`promoteForWrite`), which returns `false`
when Dewey can no longer answer for an ID and makes every durable mutation
decline.

### Refresh policy
Imported books render immediately from local persistence; refresh **never
blocks** opening a page. Metadata refreshes only when:
1. `catalogRefreshedAt` is older than **7 days**, or
2. a required field is missing (empty blurb / no cover) and a fetch is likely
   to resolve it, or
3. explicitly requested from debug tooling.
Triggered as a detached background task from the book page; results update
the stored reference in place.

Transient (not-yet-imported) remote books get the same non-blocking
enrichment on first open: the page renders instantly from search-result data,
and the work fetch fills description/subjects when it lands.

### Search (`SearchView`)
- Local results stay instant and first.
- A "From Open Library" section renders below them: fires at ≥3 characters,
  debounced ~350 ms, stale tasks cancelled.
- Remote rows: cover thumbnail (typeset fallback), title, author, year.
- Tapping opens the standard `BookDetailView`. Imported books exercise the
  app's honest empty states for community surfaces: no distribution, no Dewey
  Score, no reflections — the truth, not a gap.

### Covers (`BookCoverView`)
When `remoteCoverID != nil`, an async image renders over the typeset palette;
the palette shows while loading and remains the permanent cover when Open
Library has no image. Seed books are pixel-identical to today.

## What implementation added to this design

Four things the build required that the design did not anticipate. Each was
found by review or by running the app against the live catalog.

1. **The seeded forty-one carry Open Library work IDs**
   (`SeedData.openLibraryWorkIDs`). Without them a seeded book could not be
   recognised as the same book the catalog was offering: searching
   "Middlemarch" showed Dewey's copy under Books *and* Open Library's under
   the catalog section, and saving the second minted a permanent duplicate
   with its own ratings and diary. All 41 were resolved by ISBN and verified
   title-by-title against the seed's own author and year. Where a work's
   canonical record is in its original language (*De ansatte*, 채식주의자,
   地球星人) the identifier is that work's — a work is the novel, not the
   translation Dewey describes.
2. **A title-and-author fallback for identity** (`DeweyStore.knownBook`).
   Open Library holds more than one work record for some books — *Checkout
   19* exists twice — so a work ID alone cannot close the duplicate path.
   Both title and author must agree, which keeps Tolkien's *The Hobbit* and
   Charles Dixon's graphic adaptation separate. It scans the reader's own
   imports as well as the seed, since the duplicate hazard matters most for
   books they already rated.

   **Search-result de-duplication matches on the provider's author
   identifiers, not on names** (`collapsingDuplicates`). Keying on the
   displayed author was wrong in a way a reader caught immediately: *Red
   Rising*'s duplicate work record credits `["Renee Joiner", "Pierce Brown"]`
   — the audiobook's narrator first — so the two records keyed differently,
   both survived, and one of them opened a page for a Pierce Brown novel that
   said Renee Joiner under the title. Comparing credit *sets* recognises them
   as one book. Either signal suffices, because the catalog duplicates both
   kinds of record: shared credit catches *Red Rising*, matching names catches
   *Checkout 19*, where Open Library holds two **author** records for one
   Claire-Louise Bennett so the identifiers are disjoint. Requiring both would
   have fixed neither. The record with more editions wins.
3. **Descriptions are cleaned, not printed** (`CatalogText`). Open Library
   descriptions are user-edited and arrive carrying Markdown, HTML, and — on
   popular novels — pirate-PDF link spam. The live record for *Tomorrow, and
   Tomorrow, and Tomorrow* appends a bolded link to a "pdf" site, and the
   first build set it on the page verbatim. Verified against 20 real records:
   no markup, URLs, or entities survive.
4. **The remote search section derives its state from the query it answers**
   (`RemoteAnswer`), rather than storing a status flag. Two eagerly-written
   `@State` properties produced a SwiftUI fault ("onChange action tried to
   update multiple times per frame") and still allowed a section to describe
   itself as loaded while a newer request was in the air.

5. **Search results are re-ranked and de-duplicated client-side**
   (`OpenLibraryClient.ranked`, `collapsingDuplicates`). Open Library's
   relevance fails hardest on one-word titles: *Drifts* and *Temporary* did
   not appear anywhere in the first twenty rows. The client fetches 40 and
   keeps 20.

   **The first version of this made a whole class of query worse, and the
   fix is the interesting part.** It hard-ranked title matches above
   everything else and compared folded whole strings, so dropping a leading
   article stopped counting as a title match at all: `"hobbit"` put Tolkien's
   novel — 481 editions, Open Library's own first row — at position seven,
   behind two one-edition records titled "Hobbit". `"beloved"` was worse:
   two dozen prefix-matching romance titles filled all twenty slots and
   pushed *Cry, the Beloved Country* out of the results entirely, with no
   pagination to reach it. The 12/12 verification had used only full
   canonical titles — precisely the class the comparison handled.

   The ordering now **blends** the two signals instead of stacking them.
   Titles compare as tokens with a leading article dropped, so "hobbit" and
   "The Hobbit" are the same title. An exact match is the one absolute
   (best-known copy first); everything else scores
   `catalogRank − promotion − popularity`, where promotion rewards a title
   that starts with or contains the whole query and popularity is edition
   count, damped and capped so it nudges rather than decides. A weak title
   match can no longer leapfrog a strongly relevant row, and nothing the
   catalog ranked highly is displaced out of the visible twenty.

   Measured across two query classes: **canonical titles 12/12 first**
   (no regression) and **article-less/partial 8/10 first** — where the two
   exceptions are the test's expectations, not the ranking (Dostoyevsky is
   listed in Cyrillic; the other is an exact title match for what was
   typed). Every row the review proved was being deleted for `"beloved"` is
   back in the twenty: Paton at 4, Hardy at 6, Mann at 16.

Also: `enriched(with:)` backfills a cover from the work record, so a book
imported before Open Library had a jacket can gain one; and cover sizes are
chosen against physical pixels (M covers 60pt at 3×, L above that).

## Verified end to end

On an iPhone 17 Pro simulator against the live catalog:

- Search reaches Open Library, debounced, with results in Dewey's own type.
- A seeded book is recognised as itself: "Piranesi" returns **19** catalog
  rows rather than 20, the twentieth being the reader's already-rated copy,
  while an unrelated 1910 *Piranesi* correctly stays a separate book.
- An imported book carries a full Dewey page — real jacket, honest empty
  community states, cleaned description, details table omitting what the
  catalog does not know.
- Every durable action imports: **list-add alone** imports with no library
  entry (`library: 0`, list references the Dewey ID). Save, log with a
  rating, and ranking all attach to the same identity.
- After relaunch, one book, one Dewey ID, four kinds of activity: a library
  entry, a diary entry with its rating, a list, and the all-books ranking.
- The debug refresh advances `catalogRefreshedAt` and persists.
- A world switch under an open remote book page no longer crashes and writes
  nothing dangling.

## Out of scope

No provenance/ingestion pipeline, no Dewey-owned bulk catalog, no Bowker, no
edition-picker UI, no Google Books, no Hardcover. All existing Edition,
Library, Diary, Profile, List, Ranking, and provenance behavior preserved.

## The loop this delivers

Search Open Library → open a real book → save it → log it → rate it → review
it → add it to lists and rankings — with Library Match, overlap, diary, and
rankings working on imported books unchanged.
