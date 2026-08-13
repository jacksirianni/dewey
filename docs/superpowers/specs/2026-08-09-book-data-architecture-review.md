# Book Data Architecture — First-Principles Review

**Date:** 2026-08-09 · **Status:** Research and architecture correction · **Supersedes the reasoning in** [`2026-08-06-open-library-catalog-design.md`](2026-08-06-open-library-catalog-design.md)

---

## Headline finding

**The premise was wrong. The provider choice was right anyway — for a different reason, and the difference matters enormously.**

The 2026-08-06 design reasoned:

> Dewey stores imported books on device permanently → therefore the provider must
> permit permanent device storage → Open Library is the only one that does →
> choose Open Library.

That inverted the dependency. "Permanent device-local metadata" is not a
requirement; it is one *implementation* of the real requirement, which is
**"a reader's library and diary render with no network."** Elevating it to a
premise did three things:

1. It filtered the provider field on a clause most providers were never going
   to grant to an uncontrolled fleet of client devices — which made the field
   look artificially narrow.
2. It forced every architectural question through the device, so the server —
   which Dewey already has, for identity — was never considered as the place
   the catalog lives.
3. It quietly gave Open Library's data model, quirks, and uptime a permanent
   seat in the iOS client, where they are hardest to replace.

Correcting the premise does **not** dislodge Open Library. It is still the
right provider for Phase 1 and 2. But the reason changes from *"it is the only
one that permits what we're doing"* to *"it is the only corpus that can be
brought inside Dewey's own boundary without a contract"* — and that reason
survives scale, whereas the old one degraded with every new device.

The architectural change is real and worth making:

```
BEFORE   Open Library API → each iPhone → permanent device-local metadata
AFTER    OL monthly dumps → Dewey Postgres catalog → Dewey API → iPhone cache
              ↑ live OL API for gap-fill only
```

---

## Evidence convention

The brief asked for a clean separation between what terms actually say and
what is assumed. Every material claim below is tagged:

| Tag | Meaning |
|---|---|
| **[Doc]** | Quoted or closely paraphrased from a primary source, linked |
| **[Obs]** | Measured directly today, 2026-08-09, command shown or described |
| **[Inf]** | My reasoning from the above — argued, not authoritative |
| **[Unk]** | Could not verify this session; stated as unknown, not assumed |

Nothing here is legal advice. Several conclusions turn on how a clause would
be read in practice, and those are tagged **[Inf]** without exception.

---

## 1. The Letterboxd model, verified

The brief's description of Letterboxd is accurate, and the primary sources
are more specific than expected.

**[Doc]** All Letterboxd film metadata — "actor, director and studio names,
synopses, release dates, trailers and poster art" — is supplied by TMDB.
Letterboxd is not endorsed or certified by TMDB.

**[Doc]** TMDB changes appear on Letterboxd **within 30 hours**. It is an
import cycle, not a passthrough.

**[Doc]** New TMDB IDs can be force-imported by visiting
`https://letterboxd.com/tmdb/[TMDB_ID]`, which "will force a data import for
films not already in our database, then redirect you to the film's page."

**[Doc]** Letterboxd applies **import criteria** — entries marked Video, TV,
or non-qualifying Adult are excluded — and accepts manual import requests at
`data@letterboxd.com`. Letterboxd's catalog is a *filtered, curated* view of
TMDB, not a mirror.

**[Doc]** When a duplicate is removed from TMDB, **Letterboxd retains its own
record**, because members may have logged or reviewed it. Duplicates are
merged by Letterboxd moderators via a Report function, and member activity is
moved onto the surviving entry.

**[Doc]** Activity attached to films that *did* disappear is preserved in an
`orphaned` folder inside the user's data export. Letterboxd never destroys a
member's writing because upstream changed its mind.

### The one thing that does not transfer

**[Doc]** TMDB's public API terms prohibit caching "for longer than 6 months,"
require the TMDB logo plus a non-endorsement notice, and state that commercial
use "is only permitted under a separate written agreement between You and
TMDB."

**[Inf]** Letterboxd is unambiguously commercial (paid subscription tiers,
advertising deals) and retains film records indefinitely — well past six
months. Both facts are incompatible with the free public terms. The
overwhelmingly likely explanation is a negotiated agreement with TMDB. The
terms of that agreement are **[Unk]** and almost certainly not public.

**This is the load-bearing lesson, and it cuts against a naive copy of
Letterboxd.** Letterboxd's architecture is right, but its *rights posture* was
purchased. Dewey cannot assume the same latitude from a provider whose public
terms don't grant it. What Dewey can do is pick an upstream where the latitude
is already in the public terms — which is exactly what Open Library is, and is
a better position than Letterboxd's, not a worse one.

**[Inf]** Note also what the server-side shape does to the licensing problem
itself: it converts *"may every one of our users' phones hold your data?"* into
*"may our one service hold your data?"* The second question is the one every
commercial metadata vendor is set up to answer, price, and sign. The current
client-side design is close to unlicensable at Phase 3; the server-side design
is routine.

---

## 2. Decomposing the offline requirement

This is the centre of the correction. The brief's five layers, made concrete:

| # | Layer | Lives where | Authoritative? | Evictable? | Size |
|---|---|---|---|---|---|
| 1 | **Canonical catalog** | Dewey Postgres | Yes — for what a book *is* in Dewey | No | 10s of GB |
| 2 | **Provider metadata cache** | Dewey Postgres, separate tables | No — disposable, re-derivable | Yes, wholesale | 10s of GB |
| 3 | **Device cache** | iOS, bounded LRU | No | Yes, any time | ~50–100 MB cap |
| 4 | **User-generated Dewey data** | Dewey Postgres + full device mirror | Yes — Dewey owns it outright | **Never** | KBs per user |
| 5 | **Offline display snapshot** | Embedded *inside* layer 4 rows | Yes, for rendering | **Never** | ~200 B/book |

### Layer 5 is the whole trick

A diary entry does not store a foreign key into a cache that may be evicted.
It stores its own denormalized copy of the handful of fields needed to render
a row:

```
diary_entry {
  id, user_id, dewey_book_id, rating, logged_on, review_text, …

  // display snapshot — written at log time, refreshed opportunistically,
  // never evicted, never null
  snap_title, snap_authors[], snap_year, snap_cover_ref, snap_palette_seed
}
```

**[Inf]** The consequences are large and mostly good:

- **Offline is solved without the device owning a catalog.** The diary renders
  from its own rows. There is no lookup that can miss, so the entire class of
  bug that produced `Book.missing` and the SwiftUI render-path crash
  disappears structurally rather than being defended against.
- **The volume collapses.** A 2,000-book power user's snapshots are well under
  1 MB of text. Compare that to mirroring catalog records.
- **What sits on device changes legal character.** The device holds *Dewey's*
  user records with a few denormalized display fields — the same shape as any
  social app's offline cache — rather than a mirror of a provider's database.
  **[Inf]** This is materially easier to defend under any provider's terms,
  and it is why Letterboxd's app works on a plane while TMDB caps caching at
  six months.
- **It makes an `orphaned` export possible.** If a catalog record is ever
  merged away or withdrawn, the reader's entry still knows what it was about.
  Letterboxd solved this the same way and it is not a coincidence.

**[Inf]** The counter-cost is real and should be stated: snapshots go stale.
A corrected author name won't propagate to old diary rows until they're
refreshed. Mitigation: refresh snapshots opportunistically whenever the client
syncs and the catalog's `updated_at` is newer. Staleness in a *display copy*
is a cosmetic bug; a missing lookup in a render path is a crash. That trade is
strongly favourable.

### What the device caches beyond snapshots

Layer 3 is genuinely a cache with no durability promise: search results,
recently browsed books, list contents, covers. Bounded LRU, dropped under
pressure, refetched on demand. **[Inf]** Nothing in Dewey's product should
ever depend on layer 3 surviving.

---

## 3. Provider evaluation

### 3a. Rights and terms — the dimensions that decide

| | Open Library API | **OL monthly dumps** | Google Books | NielsenIQ BookData | Bowker Book Data | ISBNdb | Hardcover |
|---|---|---|---|---|---|---|---|
| **Commercial use** | Permitted **[Doc]** | Permitted **[Doc]** | Permitted, but no fees without written permission **[Doc]** | Yes, licensed | Yes, licensed | Yes, subscription | Restricted **[Unk]** |
| **Server-side persistence** | "Cache responses whenever possible" **[Doc]** | **Yes — this is the sanctioned path** **[Doc]** | **Prohibited** — no "permanent copies" **[Doc]** | Yes, per contract | Yes, per contract | Yes, *while subscribed* **[Doc]** | **[Unk]** |
| **Device caching** | Yes **[Doc]** | Yes | Bound by cache header; covers = **30 s** **[Obs]** | Per contract **[Unk]** | Per contract **[Unk]** | Yes, while subscribed **[Doc]** | **[Unk]** |
| **Reordering results** | No restriction found **[Doc]** | N/A — own index | **"You may not reorder or otherwise alter the results"** **[Doc]** | N/A — own index | N/A — own index | No restriction found | **[Unk]** |
| **Attribution** | None required (CC0 / no rights asserted); courtesy link requested for covers **[Doc]** | Same | "powered by Google" logo + **link back on every result** **[Doc]** | Per contract | Per contract | **[Unk]** | **[Unk]** |
| **Rate limits** | 1/s anon, **3/s identified** **[Doc]** | N/A | Keyless → **429** **[Obs]**; keyed quota per project | Per contract; On Demand up to 250k ISBN/wk **[Doc]** | Per contract | Per tier | 60/min, depth 3 **[Doc]** |
| **Bulk feed** | Prohibited via API **[Doc]** | **Monthly, free, public** **[Doc]** | None | FTP daily/weekly **[Doc]** | ONIX 2.1/3.0, ASCII, XML **[Doc]** | Bulk endpoints, 1000/call **[Doc]** | No |
| **Backend use** | **"Not… a bulk data backend or high-traffic commercial infrastructure"** **[Doc]** | Explicitly the alternative **[Doc]** | Permitted within other limits | Yes | Yes | Yes | **[Unk]** |
| **Cost** | Free | Free (your compute/storage) | Free | Quote-only **[Doc]** | Quote-only **[Doc]** | ~$15–$300/mo **[Doc]** | Free |
| **SLA / support** | None | None | None | Commercial | Commercial | Commercial-ish | None |
| **Dependency risk** | Medium — nonprofit, has had outages | **Low** — you hold the data | **High** — terms hostile to the design | Low, contractual | Low, contractual | Medium — deletion on cancel | High |

### 3b. Data quality

| | Open Library | Google Books | NielsenIQ | Bowker | ISBNdb | Hardcover |
|---|---|---|---|---|---|---|
| **Scale** | ~40M+ works/editions | Very large, opaque | **50M+ titles** **[Doc]** | **~60M titles** **[Doc]** | 33M+ **[Doc]** | Small, growing |
| **New releases** | **Weak** — library-MARC + member driven **[Inf]** | Good | **Excellent** — pre-pub ONIX from 60k publishers **[Doc]** | **Excellent** — US/AU ISBN agency **[Doc]** | Good | Moderate |
| **Work vs edition** | **Explicit, first-class** **[Doc]** — but duplicate works exist **[Obs, prior]** | Volume-centric, weak work concept | Title/product-centric | Work & author disambiguation offered **[Doc]** | ISBN/edition-centric | Work-centric |
| **Search quality** | **Poor** — documented failures on `hobbit`, `beloved`, one-word titles | **Strong** | Lookup-oriented | Lookup-oriented | ISBN-first | Decent |
| **Contributors** | Present; **credit order unreliable** (narrator-first on *Red Rising*) | Basic | Full, with roles | Full + author bios **[Doc]** | Basic | Good |
| **Series** | `series` field, **inconsistent** **[Obs]** | Rare | Yes **[Doc]** | Yes, in book profiles **[Doc]** | Sometimes | Yes |
| **ISBNs** | `isbn_10`/`isbn_13`, **inconsistent** **[Obs]** | Yes | Authoritative | **Authoritative — is the agency** **[Doc]** | Authoritative | Yes |
| **Languages** | `languages` per edition, aggregated `language` on search **[Obs]** | Yes | 93 countries, English-language focus **[Doc]** | Global **[Doc]** | Yes | Yes |
| **Page counts** | `number_of_pages`, plus `number_of_pages_median` at work level **[Obs]** | Usually | Yes | Yes | Yes | Yes |
| **Descriptions** | Present, **user-edited, needs sanitising** (pirate-link spam found in production) | Publisher-supplied, clean | Publisher-supplied **[Doc]** | Annotations, TOC, first chapters **[Doc]** | Thin | Community |
| **Subjects/genres** | `subjects`, folksonomic and noisy | BISAC-ish | **Thema, BIC, UKSLC** **[Doc]** | BISAC | Some | Tags |
| **Dewey Decimal** | **Yes — `dewey_decimal_class` on editions, `ddc` on search** **[Obs]** | No | **Yes, explicitly** **[Doc]** | Available | Sometimes | No |
| **Audiobooks** | Patchy; audiobook editions pollute credits | Weak via API | **Yes** **[Doc]** | **Yes** **[Doc]** | Yes | Yes |
| **Covers** | Large corpus, free to hotlink | Available, **30 s cache** **[Obs]** | Yes, licensed **[Doc]** | **64M+ images, licensed** **[Doc]** | Yes | Via OL/others |

### 3c. What the empirical check showed

**[Obs]** Two Open Library edition records fetched today, field-by-field:

- `OL26331930M` — carries `dewey_decimal_class`, `series`, `subjects`,
  `isbn_10`, `isbn_13`, `contributors`, `table_of_contents`, `pagination`,
  `publish_places`.
- `OL37027359M` — carries **none** of those. No ISBN, no subjects, no DDC,
  no series.

**[Obs]** Work-level search aggregates are better than either: *Piranesi*
returns `ddc: ["823.92"]`, `number_of_pages_median: 272`,
`language: ["eng","ita","spa"]`, `edition_count: 23`.

**[Inf]** This is the single most important data finding in the review. Open
Library's *per-record* completeness is a lottery, but its *per-work aggregate*
across editions is decent — and **aggregating across editions is something you
can only do if you hold the corpus.** A client hitting the API one book at a
time gets whichever edition it landed on. A server holding the dumps can pick
the best value for each field across all 23 editions of a work. Dewey's data
quality problem is partly an *architecture* problem, and the server-side move
fixes a chunk of it for free.

**[Inf]** The same logic applies to Dewey Decimal classification specifically —
which, for an app called Dewey, is not a minor field. DDC coverage per edition
is sparse, but roll it up across a work's editions and it becomes usable.
The current design throws that away.

### 3d. Per-provider notes

**Open Library API.** **[Doc]** 1 req/s anonymous, 3 req/s identified.
Permitted: "Make useful, time-sensitive requests on behalf of human users,"
"Cache responses whenever possible," identify yourself with `User-Agent` and
email. Prohibited: "Harvest data in bulk," "Make hundreds of single-book
requests," "Distribute traffic across 5+ IPs," and "Use Open Library as a
backend for high-traffic services." The APIs are "**not** intended to serve as
a bulk data backend or high-traffic commercial infrastructure."

**[Inf]** Two of those clauses deserve attention because the *current*
client-side design sits awkwardly against them. A shipped iOS app with any
real user base is, quite literally, traffic distributed across thousands of
IPs, and it is a high-traffic service using Open Library as its backend. The
intent of "distribute across 5+ IPs" is plainly anti-evasion and Dewey isn't
evading anything — but the honest reading is that the per-device design gets
*less* compliant as Dewey succeeds, which is a bad property for an
architecture to have. The server-side design gets *more* compliant as Dewey
succeeds, because API calls per user trend to zero once the corpus is local.

**Open Library monthly dumps.** **[Doc]** Generated every month. Current files
as of today: `ol_dump_works_2026-07-31.txt.gz` at **4.04 GB**, last modified
2026-08-02 **[Obs]**; editions ~9.2 GB, authors ~0.5 GB, complete ~29.6 GB,
plus ratings, reading-log, redirects, deletes, lists, and a covers-metadata
dump. **[Doc]** Open Library's own developer index routes explicitly: Web APIs
for "book services which need to make infrequent, real-time searches for
specific books"; Data Dumps "for projects which require importing books,
authors, or covers **in bulk**."

**[Doc]** Licensing: the Internet Archive "does not assert any new copyright or
other proprietary rights over any of the material in the Open Library
database," and contributions are requested under CC0 1.0. **[Doc]** With the
caveat, stated by Open Library: "There may be existing rights issues on some
contributions and in some jurisdictions."

**Google Books.** Analysed separately in §4. Ruled out.

**NielsenIQ BookData.** **[Doc]** 50M+ titles from 60,000+ publishers across
93 countries; **825 data fields**; classifications include Thema, BIC, UK
Standard Library Categories **and Dewey Decimal**; descriptions, author
biographies, TOC, reviews, cover images, "Look Inside," audiobook and ebook
formats. Delivery: Record Supply Service (FTP feeds), Web Service API
(SOAP/REST, XML), On Demand (up to 250k ISBNs weekly), BookData Online.
Daily updates. **[Doc]** Pricing is quote-only; "packages to suit any budget"
and reduced rates for Booksellers Association members. **[Unk]** Actual cost,
device-caching terms, and termination obligations.

**Bowker Book Data (ProQuest/Clarivate).** **[Doc]** ~60M titles; Bowker is
the ISBN agency for the US and Australia, which is why its ISBN and new-release
data is authoritative rather than derived. Book Metadata Service API plus a
separate **Image Service**; feeds in ONIX 2.1/3.0, ASCII, and LibraryThing XML;
Syndetics Unbound offers **64M+ cover images**. Rich extras: annotations,
author bios, first chapters, awards, bestseller citations spanning 100+ years,
review citations, reading levels, series, characters, settings, LibraryThing
tags. **[Doc]** Pricing quote-only. **[Unk]** Cost and terms.

**ISBNdb.** **[Doc]** 33M+ books; ~$15–$300/month across tiers; bulk endpoints
up to 1,000 books per call. **[Doc]** Subscribers "are permitted to download
and store or cache the data locally with a current subscription," but data
"must be deleted if the subscription expires or is cancelled." **[Inf]** That
deletion clause makes it structurally unfit as a store of record — a lapsed
card would oblige Dewey to gut its own catalog — but perfectly fit as
*enrichment*, where every ISBNdb-derived field is provenance-tagged and can be
dropped without taking the record with it. Its real strength is ISBN-keyed
lookup and pricing, not discovery.

**Hardcover.** **[Doc]** Free read-only GraphQL API; 60 requests/minute,
30-second timeout, max query depth 3. **[Unk]** Its terms page returned 403 to
automated fetch today, so the previously recorded restriction on competing
commercial use **could not be re-verified this session** and should be treated
as unconfirmed. **[Inf]** Regardless of terms: Hardcover is a direct product
competitor with a catalog it assembled the same way this document recommends.
It is an existence proof that the approach works for a small team — not a
supplier Dewey should depend on.

---

## 4. Google Books, specifically

The brief asked whether Google's restrictions rule it out *even with a
server-side architecture*. They do, and server-side doesn't help with a single
one of them.

**Permanent copies.** **[Doc]** Google APIs ToS §5.e.1 prohibits you from
"Scrape, build databases, or otherwise create permanent copies of such
content, or keep cached copies longer than permitted by the cache header."
**[Inf]** "Build databases" is not ambiguous, and a Dewey-side catalog is
precisely a database built from such content. Moving from device to server
does not soften this — it is a cleaner, more visible violation, since it is
one durable corpus rather than diffuse client caches. §8.b compounds it: on
termination you must "delete any cached or stored content."

**Cache limits.** **[Obs]** Measured today, a Google Books cover returns
`cache-control: private, max-age=30`. **Thirty seconds**, and `private`
forbids shared/CDN caching. **[Inf]** A thirty-second cover TTL is
irreconcilable with any offline experience whatsoever, on device or on a
server. For contrast, **[Obs]** an Open Library cover returns
`cache-control: public` with `expires` in **2126** — the upstream is
affirmatively inviting indefinite caching.

**Reordering results.** **[Doc]** "You may not reorder or otherwise alter the
results returned by the Google Books API Family." **[Inf]** This alone would
be disqualifying. Dewey's search is only usable *because* of client-side
re-ranking: the prior session documented that raw provider ordering buried
*The Hobbit* at position seven behind one-edition records, and pushed *Cry,
the Beloved Country* out of the visible twenty entirely. Dewey's blended
ranking, de-duplication, and the collapsing of narrator-first credit sets are
all "altering the results." Under Google's terms Dewey would be obliged to
ship the search it already proved is broken.

**Branding and links.** **[Doc]** The "powered by Google" logo must appear
adjacent to results; "Every book result displayed in your application must
have a prominent link to either (1) a page on your site featuring Google
Preview capabilities, or (2) the Google Books page for that book"; and "The
Google logo may never appear next to or on the same page with the logos of
competing web or other search services. There are no exceptions to this rule."
**[Inf]** A link off every book result to Google Books is not a footnote — it
is a second exit from the page Dewey most wants readers to stay on, and the
no-competing-logos rule constrains Dewey's future ability to show any other
source alongside.

**Charging users.** **[Doc]** "You may not charge users any fee for the use of
your application, unless you have entered into a separate agreement with
Google or obtained Google's written permission." **[Inf]** Dewey is a
prospective subscription product. This clause makes the business model
contingent on Google's permission.

**Google's own disclaimer.** **[Doc]** From Google's Books API overview: "The
API is not intended to be used as a replacement for commercial services," and
"we license much of the data that we use to power Google Books, so it's not
ours to distribute however we choose." **[Inf]** This is the honest heart of
it. Google is telling you the restrictions exist because Google itself is a
licensee — the terms are strict because they *have to be*, which means they
will not loosen and there is no informal accommodation to hope for.

**Quota.** **[Obs]** A keyless call to `googleapis.com/books/v1/volumes`
returns **429** today. The free-tier-without-credentials path is gone.

**Verdict: unsuitable as Dewey's primary catalog under any architecture.**
Server-side changes nothing, because Google's binding restrictions are not
about *where* you put the data — they are about building databases at all,
about reordering, about branding, and about charging. **[Inf]** A narrow
legitimate use survives: Google Books as a *live, uncached, unranked* lookup
of last resort, displayed with required branding, for a book Dewey's catalog
cannot find. Even that is probably not worth the compliance surface.

---

## 5. Open Library dumps → Dewey Postgres vs. the current client-side API

**Verdict: yes, materially better, and better on the axis that matters most —
it is the only one of the two that gets *more* correct as Dewey grows.**

| | Current: client → OL API | Proposed: dumps → Dewey catalog |
|---|---|---|
| Alignment with OL's stated policy | Degrades with scale **[Inf]** | **The sanctioned path** **[Doc]** |
| OL outage | Search dies for everyone | Search unaffected; gap-fill degrades |
| Search ranking | Client-side patch over a weak index | Dewey's own index, tunable, measurable |
| Cross-edition aggregation | Impossible | **Free** — best DDC/pages/ISBN per work **[Obs]** |
| Duplicate works | Patched per-device, forever | Merged once, centrally, permanently |
| Description sanitising | Must run on every client | Runs once at ingest |
| Data corrections | Not possible | **Dewey can fix its own records** |
| New releases | Live, current | Up to ~30 days stale, unless gap-filled |
| Provider swap | Touches the iOS client | Server-only; client never learns the name |
| Cost | £0 | Postgres + ETL + storage |
| Complexity | Low | **Genuinely higher** — an ETL pipeline to own |

### Freshness, and the mechanic that fixes it

**[Inf]** The monthly cadence is the proposal's one real weakness, and
Letterboxd already published the answer: **on a search miss, call the live OL
API and import the work into Dewey's catalog on the spot** — Dewey's own
`letterboxd.com/tmdb/[ID]`. This converts dump staleness from a hard ceiling
into a latency blip on rare books, and it uses the live API for precisely what
Open Library says it is for: "infrequent, real-time searches for specific
books." API volume per user trends toward zero as the corpus fills.

### The costs, stated honestly

**[Inf]**, all estimates, none measured:

- **Ingest.** ~14 GB compressed across works/editions/authors, expanding to
  perhaps 60–90 GB of raw JSON lines. A first full load is hours, not minutes,
  and needs a machine with real disk. Monthly re-ingest should be a diff
  against `redirects` and `deletes` dumps, not a rebuild.
- **Storage.** A Dewey-shaped projection — works, a chosen display edition,
  authors, ISBN index, search vectors — should land in the low tens of GB with
  indexes. **This exceeds Supabase Pro's included disk**; budget for a larger
  instance or a separate Postgres.
- **Search.** This is the actual project. Postgres FTS plus `pg_trgm` will get
  a long way, and Dewey's existing ranking function ports over with better
  inputs. Do not underestimate it: it is the difference between the proposal
  and the status quo, and it is where the weeks go.
- **A new obligation.** Serving descriptions from Dewey's own domain is a
  different posture than proxying them. OL descriptions are user-edited and
  have already been found carrying pirate-PDF link spam in production. The
  existing `CatalogText` sanitiser becomes mandatory at ingest, and Dewey needs
  a report/moderation path — the same Report function Letterboxd runs.

### Do not let Open Library's schema become Dewey's schema

**[Inf]** This is the single most important structural instruction in the
document, because getting it wrong turns Phase 2 back into a rebuild.

The dumps are OL-shaped, with OL's quirks baked in — duplicate work records,
narrator-first credit ordering, lottery-grade field completeness. If those
tables *are* Dewey's catalog, then swapping in Nielsen later means rewriting
everything above them.

Instead:

```
catalog_book      ← Dewey-shaped, Dewey-owned. dewey_book_id is the identity.
                    Fields chosen for Dewey's UI, not OL's model.
catalog_edition   ← Dewey-shaped.
catalog_author    ← Dewey-shaped.

source_record     ← provider-shaped, append-only, provenance-tagged
                    (provider, provider_id, payload, fetched_at, dump_version)
field_provenance  ← which provider supplied each resolved field, and when
```

**[Inf]** With `field_provenance`, Phase 2 is not a migration at all — it is
adding a second row source and changing a precedence rule. Nielsen wins on
ISBN, contributors, and new releases; Open Library keeps subjects and its
long tail; every `dewey_book_id`, rating, diary entry, list, and ranking is
untouched. That is exactly the phasing the brief asked about, and the answer
is **yes, it works — but only if the provenance layer is built in Phase 1**,
when it costs almost nothing. Retrofitting it later is the expensive version.

---

## 6. Cover art, separately

The brief was right to isolate this. **Cover rights and metadata rights are
not the same question and do not resolve the same way.**

**[Doc]** Open Library asserts nothing over cover images. The CC0 request and
the "no new proprietary rights" statement are about the *database*. The covers
API page states no licence for the images at all — it asks only for "a
courtesy link back to Open Library" when displaying them publicly.

**[Inf]** The plain reading: **nobody in the free tier is licensing cover art
to Dewey, because nobody in the free tier owns it.** Covers are publisher
artwork. Open Library is not granting rights it does not hold, and its silence
is not a grant. This is unchanged from the earlier review and it is still the
largest unpriced risk in the product.

What *is* newly clear:

**[Obs]** Open Library covers return `cache-control: public` with an `expires`
date in **2126**, and redirect to archive.org zip-backed storage. **[Inf]** An
HTTP cache that honours those headers — which is all an iOS image cache is —
is doing exactly what the origin instructed. That is a meaningfully more
comfortable position than storing images under a header that forbids it, and
it is the strongest single argument for device-side cover caching.

**[Doc]** Bulk cover images exist on archive.org as tar files (items of 100
tars × 10k images, named by cover ID range), but there are **no rolling
monthly cover dumps** the way there are for metadata.

**[Inf]** Recommended posture, and it differs by phase:

- **Addressing.** Keep using CoverID/OLID, never ISBN. **[Doc]** The
  100-req/IP/5-min throttle applies only to "ids other than CoverID and OLID."
- **Device.** Cache aggressively, honouring the origin's own headers. Bounded
  LRU. This is ordinary and defensible.
- **Server, Phase 1–2.** A **bounded proxy/CDN cache**, not a mirror. Do not
  bulk-download the cover corpus. Keep `source_url` and `fetched_at` on every
  cached image so any subset can be purged on request, quickly, by publisher.
  **[Inf]** The distinction between "we cache what our users look at" and "we
  built a copy of your image library" is the one that matters if anyone ever
  asks.
- **The typeset cover is not a fallback — it is the asset.** Dewey already
  derives a deterministic palette from the work ID. **[Inf]** That is the only
  cover artwork Dewey unambiguously has the right to display, it works
  offline with zero bytes fetched, and it is the reason a cover-rights problem
  would be survivable rather than fatal. Treat it as product, keep it
  first-class, and make sure every surface renders correctly with covers
  entirely absent.
- **Phase 3.** Licensed covers are the fix, and they come bundled: **[Doc]**
  Syndetics Unbound carries 64M+ images and Nielsen supplies cover images with
  its metadata. **[Inf]** This is a strong argument for eventually licensing
  *one* vendor for both rather than solving covers separately — the covers may
  be the larger half of the value.

---

## 7. The three architectures

### A. Cheapest credible prototype

| | |
|---|---|
| **Providers** | Open Library live API only |
| **Canonical records** | Nowhere central — the device, effectively |
| **Server-side** | Identity only (today's `0001_identity.sql`) |
| **On device** | Imported books in full, permanently |
| **Updates** | 7-day TTL per book, per device |
| **Offline** | Works, because the device owns everything |
| **Covers** | Hotlinked from OL, cached by the image loader |
| **Burden** | ~£0/mo. No pipeline, no ops |

**This is what exists today.** It is a genuinely good prototype and should not
be apologised for. Its ceiling is that every weakness — search, duplicates,
corrections, provider swap — is stuck inside a shipped binary, and its policy
alignment worsens as users are added.

### B. Public beta / early startup — **recommended**

| | |
|---|---|
| **Providers** | OL monthly dumps as the base; live OL API for gap-fill and force-import |
| **Canonical records** | **Dewey Postgres**, `dewey_book_id` as identity |
| **Server-side** | Dewey-shaped `catalog_*` tables; `source_record` + `field_provenance`; search index; all user data; bounded cover proxy cache |
| **On device** | Full mirror of *user* data (layer 4) with embedded display snapshots (layer 5); bounded LRU for browsed books and covers |
| **Updates** | Monthly dump diff; on-demand import on search miss; snapshot refresh on sync |
| **Offline** | Library and diary render from snapshots. Search falls back to what's cached. Logging works offline and syncs later |
| **Covers** | OL CoverID/OLID via Dewey CDN proxy, provenance-tracked, purgeable; typeset palette always available |
| **Burden** | ~$50–200/mo **[Inf, estimate]** for Postgres + object storage + CDN; one monthly ETL job; the search index is the real work |

### C. Mature commercial Dewey

| | |
|---|---|
| **Providers** | Licensed primary (**NielsenIQ BookData** or **Bowker**) + OL retained for long tail and out-of-print; ISBNdb optional for ISBN/pricing enrichment |
| **Canonical records** | Same Dewey Postgres, **same `dewey_book_id`s, unchanged** |
| **Server-side** | Identical shape to B, with a second source and a precedence rule; licensed cover corpus |
| **On device** | Unchanged from B |
| **Updates** | Daily/weekly ONIX feeds; pre-publication records for new releases |
| **Offline** | Unchanged from B |
| **Covers** | **Licensed** (Syndetics 64M+ images, or Nielsen's) — the risk is retired |
| **Burden** | Licensing quote-only **[Unk]**, plausibly five figures annually **[Inf]**; contract, compliance, and vendor management become real |

---

## 8. Recommendation

**Adopt B now. Design B so that C is a configuration change.**

The reasoning in one line: **B is the only option that makes Dewey's data
quality problems solvable rather than permanent**, and the phasing the brief
proposed is not just viable but is *the* right sequence — provided the
provenance layer is built in Phase 1.

Specifically:

1. **Keep Open Library.** The provider was right; the premise underneath it
   was wrong. Under a server-side architecture Open Library goes from "the only
   one whose terms tolerate our design" to "the only corpus we can bring inside
   our own boundary without signing anything" — a much stronger position, and
   the only one where Dewey can *correct* its own data.

2. **Move the catalog to the server, and stop treating device permanence as a
   requirement.** Replace it with display snapshots embedded in user records.
   Offline gets *better*, not worse: it stops depending on a lookup that can
   miss.

3. **Rule out Google Books permanently.** Not because its search is weak — it
   is the best of the free options — but because "may not reorder or otherwise
   alter the results" forbids the one thing that made Dewey's search work,
   "build databases… or create permanent copies" forbids the architecture, and
   charging users needs Google's written permission. Server-side rescues none
   of it.

4. **Build `field_provenance` in Phase 1.** It is nearly free now and it is
   what makes Phase 2 an additive change instead of a rewrite. This is the
   highest-leverage line item in the document.

5. **Treat covers as a separate, unresolved risk with a known fix.** Proxy and
   cache, never mirror. Keep provenance so any subset can be purged. Keep the
   typeset cover first-class so the product survives if covers must go. Plan to
   solve it properly by licensing one vendor for metadata *and* images at
   Phase 3 — that bundling is a real argument for Nielsen or Bowker beyond
   metadata quality alone.

6. **Do not buy a licensed feed yet.** Nothing in the research suggests
   urgency. The trigger is not user count — it is **new-release coverage
   complaints**, which is where Open Library is weakest and where a
   publisher-fed provider is worth paying for. Watch the search-miss rate on
   books published in the last 90 days; when that metric hurts, get quotes.

### What survives from the 2026-08-06 design, unchanged

Three constraints from the original design get *stronger* under this
architecture, not weaker, and should carry forward verbatim:

- **`dewey_book_id` is Dewey's alone**, with provider IDs as attributes. This
  is what makes every phase transition a data-plane change.
- **Import on durable action only.** Now expressed server-side: browsing
  doesn't create user data; saving, logging, rating, listing, or ranking does.
- **Never refresh on page open.** Render from local, refresh past TTL in the
  background. Unchanged, and now applies to snapshot refresh too.

### Open questions this review could not close

- **[Unk]** Nielsen and Bowker pricing, device-caching terms, and termination
  obligations. All quote-only. Worth a no-commitment enquiry to both purely to
  learn the shape of the contract before it is needed.
- **[Unk]** Hardcover's current terms — its page blocked automated fetch today.
  Low stakes, since it is not a recommended dependency.
- **[Unk]** Whether Open Library would object to a service-side ingest at
  Dewey's eventual scale. Their published position invites exactly this, but
  **[Inf]** a short introductory email to `openlibrary@archive.org` before
  Phase B goes live is cheap insurance and good citizenship.
- **[Inf]** The search index design is the largest unestimated piece of work
  in Architecture B and deserves its own spike before a plan is written.

---

## Sources

Open Library — [APIs and rate limits](https://openlibrary.org/developers/api) ·
[Developer centre](https://openlibrary.org/developers) ·
[Data dumps](https://openlibrary.org/developers/dumps) ·
[Licensing](https://openlibrary.org/developers/licensing) ·
[Using Open Library data](https://openlibrary.org/help/faq/using) ·
[Covers API](https://openlibrary.org/dev/docs/api/covers)

Google — [Books API Terms of Service](https://developers.google.com/books/terms) ·
[Books API branding guidelines](https://developers.google.com/books/branding) ·
[Books API overview](https://developers.google.com/books/docs/overview) ·
[Google APIs Terms of Service](https://developers.google.com/terms)

Letterboxd / TMDB — [Film data](https://letterboxd.com/about/film-data/) ·
[Where does Letterboxd get its film data from?](https://support.letterboxd.com/hc/en-us/articles/15269025512847-Where-does-Letterboxd-get-its-film-data-from) ·
[I see a film entry on TMDb, why isn't it on Letterboxd?](https://letterboxd.zendesk.com/hc/en-us/articles/15269062752783-I-see-a-film-entry-on-TMDb-why-isn-t-it-on-Letterboxd) ·
[TMDB API Terms of Use](https://www.themoviedb.org/api-terms-of-use)

Commercial providers — [NielsenIQ BookData](https://nielseniq.com/global/en/landing-page/nielseniq-bookdata/) ·
[NielsenIQ BookData Metadata](https://nielseniq.com/global/en/landing-page/nielseniq-bookdata-metadata/) ·
[Bowker Book Data products](https://bowkerbookdata.proquest.com/products) ·
[Syndetics Unbound](https://about.proquest.com/en/products-services/syndetic-solutions/) ·
[ISBNdb pricing](https://isbndb.com/isbn-database) ·
[ISBNdb terms](https://isbndb.com/terms-and-conditions) ·
[Hardcover API docs](https://docs.hardcover.app/api/getting-started/)
