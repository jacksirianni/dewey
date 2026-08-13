# Implementation Plan: Open Library Catalog

Spec: `docs/superpowers/specs/2026-08-06-open-library-catalog-design.md`

Ordered so the app builds and behaves at every step.

## 1. Unknown-ID fallback fix (pre-req)
- `SeedData.book(_:)` → returns `Book?` (rename to `find` or make optional);
  `DeweyStore.book(_:)` owns the chain and the failure policy:
  `assertionFailure` in debug, explicit "Unknown book" placeholder in release.
- Verify no behavior change for seed IDs. **Build.**

## 2. Model: identity + provider attributes
- `Book`: `year: Int` → `Int?`; add `openLibraryWorkID`,
  `openLibraryEditionID`, `remoteCoverID`, `catalogRefreshedAt` (all optional,
  defaulted so seed literals and Codable are unaffected).
- Adapt every `year` call site (from audit). `subtitleLine` drops the year
  when absent. **Build.**

## 3. Catalog layer (new files, no UI yet)
- `Catalog/BookCatalogProvider.swift` — protocol + normalized DTOs.
- `Catalog/OpenLibraryClient.swift` — search + work fetch + cover URLs,
  User-Agent, Codable DTOs.
- Normalization: DTO → `Book` (Dewey ID minted here; palette from FNV-1a of
  work ID; Reach from edition_count; nil for the unknown). **Build.**

## 4. Store: imported + transient references
- `importedBooks: [String: Book]` (persisted, optional key) +
  `viewedRemoteBooks: [String: Book]` (transient) + work-ID index.
- Lookup chain in `book(_:)`; `register(remote:)`;
  `promoteIfRemote(_:)` called inside every durable mutation
  (`save`, `log`, `addToList`, `saveRanking`, `send`, `setNote`,
  `setStatus`, `toggleFeatured`/`setFavoriteBooks`).
- `refreshMetadataIfNeeded(_:)` — 7-day TTL / missing-fields / manual;
  non-blocking. `enrich` path shared with transient first-open. **Build.**

## 5. Covers
- `BookCoverView`: `AsyncImage` over the typeset palette when
  `remoteCoverID != nil`. Seed books pixel-identical. **Build.**

## 6. Search: the remote arm
- `SearchView`: debounced (~350 ms) cancellable task at ≥3 chars; "From Open
  Library" section below local results; rows → `NavigationLink(value: Book)`
  after `store.register(remote:)`; dedupe rows against local results by
  work-ID/ISBN so an imported book doesn't appear twice. **Build.**

## 7. Book page hooks
- `BookDetailView`: resolve the book through `store.book(id)` so enrichment
  is observed; `.task` fires enrichment (transient) or
  `refreshMetadataIfNeeded` (imported). Never blocks first paint.
- Debug menu: "Refresh catalog metadata" action. **Build.**

## 8. Verification
- Multi-lens review workflow (correctness, concurrency, empty-states, design
  voice) with adversarial verify; fix confirmed findings.
- Build clean; run on iPhone simulator; end-to-end: search "Tomorrow, and
  Tomorrow, and Tomorrow" → open → save → log+rate → add to list → rank →
  relaunch → verify persistence and cover; verify seed world untouched;
  verify fresh-world mode.
