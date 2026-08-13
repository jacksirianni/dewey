# Reviews, and Controls for Screens Full of Books

**Date:** 2026-08-06 · **Status:** Approved

## Premise

Three complaints, one underlying shape.

A profile's writing section is called *Reflections* and shows a book title over
six lines of prose and nothing else — no cover, no rating, no date — while the
same object on a book page carries all three. A list detail view opens with a
fan of overlapping covers before it will show you the list. And no screen in
the app that shows a column of books lets you reorder or narrow it, which means
a reader whose taste matches yours and who has read a thousand books is a wall
you cannot search.

All three are surfaces that under-serve data the app already holds.

## 1. Reflections become Reviews

`Reflection` was named against `Review` on purpose — the type's own comment says
*"Dewey wants what a book did to you, not a verdict rendered for an audience."*
That register is being retired. The word is **Review**, everywhere.

Partial renames are specifically what §13.3 forbids: *"One name per state,
everywhere."* The rule was written after a reader marked a book Paused and went
looking for a Paused filter that did not exist. A profile saying *Reviews* over
a book page saying *Reflections* reproduces exactly that failure.

### Surfaces

| File | Current | Becomes |
|---|---|---|
| `SearchView:1418` profile | `SectionHead(kicker: "Reflections")` | `"Reviews"` |
| `BookDetailView:1016` §7 | `Text("Reflections")` | `"Reviews"` |
| `LogSheet:494` writing field | `Text("Reflection")` | `"Review"` |
| `LogSheet:845` spoiler line | `"Reflection hidden — spoilers."` | `"Review hidden — spoilers."` |
| `RootView:492` provenance | `"From \(name)'s reflection"` | `"From \(name)'s review"` |
| `Provenance:35` provenance | `"from their reflection"` | `"from their review"` |
| `EditionCardViews` | `ReflectionCard` | `ReviewCard` |

The two provenance strings are the ones a partial rename would most easily
miss: they are the only place the word appears in lowercase mid-sentence, and
they say where a book on your shelf *came from* — a library row reading "From
Marcus's reflection" under a section headed Reviews is the §13.3 failure in its
smallest possible form.

`Provenance.Via.reflection` (the enum case driving both) renames to `.review`.
It is `Codable` and persisted inside `LibraryEntry.provenance`, so it takes the
same `CodingKeys` treatment as everything else below — the stored raw value
stays `"reflection"`.

### The word gets registered

`Vocabulary` (`Models/OpinionModel.swift:164`) is where this codebase writes
down the words it has settled on — it currently holds Library, Status and Lists,
each with a comment naming what it must never be called. Review belongs there
for the same reason:

```swift
/// A reader's published writing about a book. Never "reflection" — the word
/// this replaced, retired 2026-08-06.
static let review = "Review"
static let reviews = "Reviews"
```

Registering it is what makes the next surface that needs the word find the
right one instead of guessing.

### Types

- `Reflection` → `Review` (file renamed `Models/Review.swift`)
- `ReflectionFilter` → `ReviewFilter` — the five cases and their titles
  (Friends / Popular / Recent / Positive / Critical) are unchanged; only the
  type name moves
- `DiaryEntry.reflection` → `.review`
- `DiaryEntry.reflectionIsSpoiler` → `.reviewIsSpoiler`
- `DiaryEntry.reflectionIsDraft` → `.reviewIsDraft`
- `DiaryEntry.hasPublishedReflection` → `.hasPublishedReview`
- `DeweyStore.allReflections` → `.allReviews`; `reflections(for:)` →
  `reviews(for:)`; `reflections(for:filter:)` → `reviews(for:filter:)`
- `SeedData.reflections` → `.reviews`

### Persistence must not break

`DiaryEntry` and `Reflection` are `Codable` and persisted to disk. Renaming
stored properties changes the encoded keys, so every review already written on
a device would fail to decode and vanish.

**Every renamed type gets an explicit `CodingKeys` pinning the new Swift names
to the old wire strings** — `review = "reflection"`,
`reviewIsSpoiler = "reflectionIsSpoiler"`, `reviewIsDraft = "reflectionIsDraft"`
— and `Provenance.Via.review` keeps the raw value `"reflection"`. The on-disk
format is untouched; no migration runs; nothing is lost. Each mapping is
documented at its declaration so a future reader does not "tidy" it away.

**This is the one part of the rename that fails silently.** A missed
`CodingKeys` does not fail to compile and does not throw at launch — it decodes
to `nil`, and a reader's written reviews are simply gone. Verification is
therefore explicit and comes before anything else ships: write a review, force
quit, relaunch, confirm the text, the rating, the spoiler flag and the
provenance line all survive.

## 2. The review card on a profile

The book page's card (`BookDetailView.reflectionCard`) already renders a byline
(avatar, name, favorite mark, rating), a spoiler-blurred body, and a footer with
date and appreciation count. The profile's card renders a title and prose. They
are the same object drawn twice, once well.

**The principle:** on a book page you know the book and need to know *who*; on a
profile you know the reader and need to know *which book*. One card, with the
identity line swapped.

The profile card becomes:

```
┌───────────────────────────────────┐
│ ███  Bluets               ♥   8.8 │
│ ███  Maggie Nelson · 2009         │
│                                   │
│ I kept it by the bed for a year   │
│ and read the same eleven          │
│ propositions most nights…         │
│                                   │
│ 14 March · 6 found this useful    │
└───────────────────────────────────┘
```

- **Book-line** replaces the byline: `BookCoverView` (small), title, then
  `book.subtitleLine` (author · year · series), the favorite mark, and the
  rating at the trailing edge via `RatingMark(size: .tiny)`
- **Body** reuses the book page's spoiler blur and reveal-on-tap verbatim
- **Footer** reuses the book page's date + `N found this useful`

This reverses the standing decision documented on `reflectionCard`, which
removed the rating on the grounds that *"there is nothing here to compare
against."* On a profile there is: a reader's reviews are read as a run, and the
numbers down the right edge are the fastest read of their taste on the page. The
argument held for a card that had nothing else on it; it does not hold for a card
with a cover and a book-line.

**Data:** `Review` already carries `rating`, `date`, `isFavorite`, `isSpoiler`
and `appreciations`; own-profile cards read the equivalents off `DiaryEntry`.
Nothing new is stored. `reflectionTexts` — the tuple feed that currently drops
everything but text — is replaced by a small view model carrying the full set.

Reread and format are deliberately **not** shown: they exist on `DiaryEntry` but
not on `Review`, so they would appear on your own cards and silently vanish from
everyone else's.

## 3. The cover fan

`ListDetailView.coverFan` and `fanBooks` are deleted. Five covers overlapping at
a rotation, already `accessibilityHidden`, standing between a list's premise and
its books. The header now flows into the book column directly.

## 4. Sort and filter

### Where it appears

| Screen | Source | Default order |
|---|---|---|
| `ListDetailView` | `list.items` | **List order** — never overridden until asked |
| `LibraryView` → Books | `entries(withStatus:)` | Date added, newest first |
| `ReaderShelfView` (new) | see §5 | Rating, high → low |

The diary is **excluded**. It is a dated record grouped by month; re-sorting it
by title makes it something other than a diary. Search results are excluded —
they are relevance-ordered.

### The control

One toolbar item, trailing, opening a menu of sorts and filters. Zero vertical
cost when unused.

**It appears at 8 or more books, on every screen, same rule.** Below that every
sort produces a near-identical screen and the control is furniture.

When any filter is active, a line sits between the header and the books:

```
Thriller · 1960s–1980s · 9 of 24 · Clear
```

The count is not decoration. It is the guarantee that a filter can never quietly
hide books — a reader must always be able to see that they are looking at part
of a shelf, and leave in one tap.

### Sorts

Re-tapping the active sort reverses it. This is why the menu lists "Title" and
not "Title A–Z" and "Title Z–A": the user's *"oldest to youngest, youngest to
oldest"* is one row tapped twice.

| Sort | Where | Default direction | Key |
|---|---|---|---|
| List order | Lists only (default there) | — | `items` index |
| Date added | Library only | Newest first | `LibraryEntry.savedAt` |
| Title | Everywhere | A–Z | `book.title`, localized, case- and diacritic-insensitive |
| Author | Everywhere | A–Z | `book.author`, same collation |
| Rating | Everywhere | High → low | the mark *that screen displays* |
| Dewey Score | Everywhere | High → low | `store.communityAverage(bookID)` |

**Date added is offered on the Library only.** `BookList.Item` stores an id, a
bookID and a note — no date. A list cannot answer "when did this get added"
without inventing an answer, so it does not offer to.

**"Rating" means the mark on screen.** Yours on your own shelves; theirs on
another reader's list or shelf, which the existing `"Marks are Mara's"`
attribution kicker already states. Dewey Score is the separate, unambiguous,
platform-wide number.

### Filters

A screen offers only the filters that mean something on it, so no screen shows
more than four.

| Filter | Shape | Where |
|---|---|---|
| Decade | Multi-select | Everywhere |
| Genre | Multi-select | Everywhere |
| Dewey Score | Threshold: Any / 6+ / 7+ / 8+ / 9+ | Everywhere |
| Read / not read | Everything / read / not read | Other people's lists and shelves |
| Rated / not rated | Everything / rated / not rated | Your own shelves |

- **Decade** offers only decades present in the books on screen, each with a
  count. Selecting 1960s + 1970s + 1980s is the "1960 to 1990" range.
- **Genre** draws from the ~19-term controlled vocabulary in
  `CatalogImport.genreMap`, again only offering terms present on screen. Free
  text never reaches this filter.
- **Read / not read** answers *"which of these haven't I read?"* — the question
  that turns a matched reader's shelf into a to-read pile. Absent from your own
  shelves, where the status chips already answer it.

### Missing data — one rule, everywhere

Optionality is real here and each case has a documented source: `Book.year` is
nil where Open Library has no `first_publish_year`; `genres` is empty for
imported books whose subjects were all noise; and `communityAverage` is nil for
**every** imported book, since `ratingDistribution` reads
`SeedData.distributions` and only the 41 seed books have one.

- **In filters:** unknown matches nothing. No year matches no decade, no genre
  matches no genre, no Dewey Score matches no threshold.
- **In sorts:** unknowns sink to the bottom. They are never treated as zero,
  which would rank an unrated book below the worst-rated one.
- **In the menu:** each facet states its own gap — `"4 books have no genre
  recorded"` — so a reader can tell a filter that found nothing from data that
  was never there.

### Shape

One `BookQuery` value (sort, direction, active filters) plus a pure
`apply(to:context:)`. The `context` supplies what varies per surface: which
rating to sort by, whether `savedAt` exists, which facets to offer. The view
owns a `@State BookQuery` and renders `query.apply(to: books, context: …)`.

Filtering and sorting are pure functions over an array — they are testable
without a view, and that is where the tests go.

## 5. `ReaderShelfView` — a full shelf, for anyone

The profile's Read section shows twelve covers and stops. Another reader's
complete shelf is not reachable from anywhere in the app, which is precisely the
reader the sort and filter work exists to serve.

- The Read section gains a **See all**, on your profile and everyone else's
- `ReaderShelfView` is a column of book rows with the §4 control on it
- **Source, matching the count the strip already states:** yours is the distinct
  bookIDs of `store.diaryEntries`; theirs is `profile.ratings.keys` — the same
  two branches `readCount` already uses, so "See all" can never disagree with
  the number above it
- Title: `"Everything Mara's read"` / `"Everything you've read"`
- Carries the `"Marks are Mara's"` attribution when the shelf is not yours
- Default sort: Rating, high → low — the same claim the strip makes today

## Out of scope

- Sorting or filtering the diary
- Sorting search results
- Saved or persisted filter state — a query lives for the life of the screen
- Per-item `addedAt` on `BookList.Item` (would make Date added work on lists;
  a schema change, not this)
- Backfilling Dewey Scores for imported books
- Page-count and language sorts; reading-time or "shortest first" filters

## What this delivers

A reader whose taste matches yours, with a thousand books on their shelf, can be
asked: *thrillers, 1960s through 1980s, ones I haven't read, best-scored first.*
Eleven books come back, and the screen says it is showing eleven of two hundred
and eighty-four.

That sentence is not answerable in the app today at any length.
