# Letterboxd → Dewey Feature Map

Grounded in the live film page for *The Odyssey (2026)* plus the iOS title-detail experience. The point is to translate **mechanics**, never expression: no dark-teal palette, no green/orange/blue rating dots, no borrowed layout, no copied copy.

**Column 4 key:** **SLICE** = in this vertical slice · **LATER** = real, deferred · **NEVER** = incompatible with Dewey.

---

## 1. The object page

| Letterboxd mechanic | Why it works | Dewey equivalent | When |
|---|---|---|---|
| Poster-led hero, title · year · director on one line | Instant identification; the poster *is* the brand | Cover-led hero, title · author · year, series line | **SLICE** |
| Action row: watch / like / watchlist / rate, always visible | One tap to log. No menu-diving. The row is the product | Explicit controls: state, rating, Favorite, reflect, list, recommend | **SLICE** |
| Tabs: Cast · Crew · Details · Genres · Releases | Depth without scroll-death; the page feels *complete* | Tabs: People · Details · Editions | **SLICE** |
| Synopsis, short | Enough to decide, never marketing | Two-sentence description, editorial voice | **SLICE** |
| Rating histogram | Shows *distribution*, not just an average — disagreement is visible | Distribution bars, deliberately quieter than friend ratings | **SLICE** |
| "Popular reviews" vs "Recent reviews" | Two different needs: the best take, and what's happening now | Reflections, filterable: Friends · Popular · Recent · Positive · Critical | **SLICE** |
| Spoiler-blurred reviews | Lets people write honestly without policing | Spoiler flag → blurred until tapped | **SLICE** |
| "N fans", "watched by N" | Social proof at a glance | Friend counts named, not totalled; community count present but quiet | **SLICE** |
| Lists containing this film | The best rabbit hole on the site | Lists containing this book | **SLICE** |
| Similar films | Lateral movement, endless | Related works, author's other books | **SLICE** |
| 173-country release schedule | Completist depth for the obsessive | Editions/formats — a real books analogue | **LATER** |
| Cast of 80+ with characters | Film is collaborative; books mostly aren't | Author, translator, narrator, illustrator, editor | **SLICE** |
| Trailer embed | — | No equivalent worth having | **NEVER** |

## 2. Logging

| Letterboxd mechanic | Why it works | Dewey equivalent | When |
|---|---|---|---|
| The log sheet: date, rating, like, review, rewatch, tags, spoiler | One sheet does five-second and considered logging | One sheet: state, dates, 0.1–10.0 rating, Favorite, reflection, spoiler, tags, format, reread, visibility | **SLICE** |
| **Rating ≠ like** | A 5★ you admire vs a 3★ you love. The single smartest thing on Letterboxd | **Rating ≠ "Favorite"** | **SLICE** |
| Rewatch flag | Re-viewing is a distinct act | Reread flag, multiple entries per book | **SLICE** |
| Nothing is required | You can log with no rating and no review | Same. No forced rating, no forced reflection | **SLICE** |
| Diary date defaults to today, editable | Removes all friction | Same | **SLICE** |
| Draft reviews | Lets you write badly first | Draft state on reflections | **SLICE** |

## 3. Diary & profile

| Letterboxd mechanic | Why it works | Dewey equivalent | When |
|---|---|---|---|
| Chronological diary, month-grouped | The single most-loved feature. A record, not a scoreboard | Reading Diary, month-grouped | **SLICE** |
| Favourite films — exactly four | Scarcity forces a real choice and reads as identity | Favorite Books — exactly four, chosen by hand | **SLICE** |
| Profile: recent, diary, reviews, lists, watchlist, stats | A profile is a *body of work* | Same shape, books | **SLICE** |
| Rating distribution on profile | Shows how you rate — a harsh 3★ rater is legible | Same | **SLICE** |
| Year in Review | The annual moment | — conflicts with the no-stats position | **LATER** |
| Follower counts prominent | Status | Deliberately absent | **NEVER** |
| Streaks / challenges | — | Anti-goal | **NEVER** |

## 4. Lists

| Letterboxd mechanic | Why it works | Dewey equivalent | When |
|---|---|---|---|
| Ranked & unranked lists | Ranking is an argument | Both | **SLICE** |
| Title + description + notes per entry | The note is where the personality lives | Same | **SLICE** |
| Public / private | Draft in private, publish deliberately | Same | **SLICE** |
| Poster-grid list covers | A list looks like an object | Cover-grid | **SLICE** |
| Funny/obsessive list culture | The reason people browse lists at all | Seeded with jokes, not only solemn curation | **SLICE** |
| Drag to reorder | Ranking must be physical | Same | **SLICE** |

## 5. Search & discovery

| Letterboxd mechanic | Why it works | Dewey equivalent | When |
|---|---|---|---|
| One search across films, people, lists, members | Everything is an object you can fall into | Books, authors, readers, lists, series | **SLICE** |
| Every entity is a page you can leave from sideways | The rabbit hole | Same | **SLICE** |

## 6. What Dewey keeps that Letterboxd has no answer to

Not a translation — this is the differentiation, and it stays at the top of the page.

*Revised 2026-08-10.* "Why it reached you" and the multi-hop provenance chain were reassessed and removed as a universal book-page concept — see `docs/dewey-app-overview.md`'s amendment above §1 and `Provenance`'s own doc comment. Dewey cannot honestly answer "why did this reach you" for a self-found book, which is most of them, and a chain that draws a diagram of nobody for the common case taught readers to skip it. What survives, below, is the part that was always true: a direct recommendation, with a name and a real reason.

| Dewey mechanic | Why Letterboxd can't copy it |
|---|---|
| **Direct recommendation with a required reason** | Netflix built and killed friend recs; nobody does the reason |
| **Recommendation closure** — *"Ana started it"* | The only notification that is a gift |
| **Taste overlap by named books, no percentage** | Letterboxd shows a number; Dewey shows evidence |
| **The finite Weekly Edition** | Structurally opposed to an infinite feed |

## 7. The resulting page hierarchy

*Revised 2026-08-10 — see the note above §6.* Steps 2 and 3 below described a "Your relationship" wrapper and a universal "human context" section that no longer exist as named concepts. The current hierarchy:

1. **The book as a cultural object** — cover, title, author, series, genres
2. **A concrete recommendation, if Dewey has one** — a name and a reason, no heading, no chain
3. **The Dewey Score**
4. **Personal state and actions** — status, Your Score, Your Ranking, Favorite, review, Log — stated directly, not inside a named wrapper
5. **The community** — friends, distribution, reflections, lists

**The community average is present and never dominant.** On Letterboxd the average is the loudest number on the page. On Dewey, a named friend's rating outranks 4,000 strangers averaged.

## 8. The two honest borrowings

**Rating ≠ Like.** Letterboxd's best mechanic. Ported as **Rating ≠ Favorite** — one is a judgement of the book, one is a book you love. Ported wholesale and credited here.

**Favorite is not Favorite Books.** The mark is unlimited; the four on a profile are chosen separately and by hand. Letterboxd's four favourites map to the second, not the first — see §14 of the overview.

**Four favourites.** The constraint is the feature. Five would be worse.

## 9. Deliberately not taken

Dark teal + green/orange/blue rating dots · the poster-wall home feed · "fans" as a status number · Pro/Patron tiers · Year in Review as a stats dashboard · infinite scroll · follower counts as hierarchy.
