# Dewey — What the App Is and Does

A high-level map of the prototype as built. Everything is numbered so you can mark up specifics — "fix 4.3", "kill 6.2", "5.1 is wrong".

**Status:** built and running — now the expanded, Letterboxd-complete build. §9 (the Letterboxd gap) is kept as a record of what was missing; §11 says what has since been closed.

**Amendment — 2026-08-10.** §1.3, §5, §6, §7.2/7.4 and §11.13 below describe an earlier product thesis — that Dewey should maintain and foreground a universal "how this reached you" record, rendered as a multi-hop provenance chain — that has since been reassessed and walked back. In the build as it now stands: Dewey states who sent a book **only** when it genuinely knows (an active recommendation, or a person-originated save), as a single line, with no chain and no section heading. A self-found save — most of them — states nothing. `Provenance` remains as storage (see the type's own doc comment); the multi-hop rendering, `ProvenanceHop`, and `chain(for:)` do not exist in the app anymore. The sections below are left as a historical record rather than rewritten line by line; read their provenance claims as superseded.

---

## 1. The one-sentence version

> Dewey shows you whose taste is worth trusting, helps you find your next book through a person rather than an algorithm, and lets you score, rank and write about what you read.

*Revised 2026-08-10 — see the amendment above §1.* The original line closed on "remembers who sent you there," describing Dewey as maintaining a universal record of how every book arrived. It doesn't, and was never going to be able to: most saves have no person behind them, and the app has no way to distinguish "found via search" from "heard about it at a party." What Dewey actually does — say who sent a book when somebody genuinely did — is real and stays; the universal memory it was folded into does not.

Three capabilities, in order of how much of the product they carry:

| | Capability | Why it exists |
|---|---|---|
| **1.1** | **Read a stranger's taste** from their library alone | If this fails, nothing else matters |
| **1.2** | **Find a next book through a person**, with the reason attached | The recurring need — fires ~5–6×/month |
| **1.3** | **Score, rank and write about what you read** — and see who sent a book, when someone genuinely did | Personal judgement and honest social context, not a universal arrival story |

---

## 2. Navigation

Four tabs. That's the whole map.

| | Surface | Answers |
|---|---|---|
| **2.1** | **Edition** | "What in my reading world deserves attention?" |
| **2.2** | **Search** | "Where's the thing nobody handed me?" |
| **2.3** | **Library** | "What's mine — as shelves, and as a diary?" |
| **2.4** | **You** | "What am I claiming about myself?" |

Two tabs could not carry this. Search is not a lesser edition — it is the only route to a book nobody sent you. The profile is not settings; it is the argument you're making about yourself, and an argument needs an address. Everything else pushes onto a stack: a person, a book, a list, a ranking.

**2.5** No tab has a badge or an unread count.

---

## 3. Weekly Edition

**3.1 What it is** — a finite set of five cards, published weekly, that ends.

**3.2 Why weekly** — 30 people × 20 books/year ≈ 11.5 finish-events per week and ~1.6 per day. Daily is an empty screen 63% of the time. Weekly is an edition.

**3.3 The five card types** — each carries a *different kind* of human context. If two could merge without losing meaning, one shouldn't exist.

| | Card | What it shows |
|---|---|---|
| **3.3.1** | **For you** | Someone chose this book for you, and why. The only card with a filled button. |
| **3.3.2** | **From a list** | A book plus the premise of the list it sits in |
| **3.3.3** | **Someone wrote** | A short reflection, set large — the only card that leads with prose |
| **3.3.4** | **Turning up more than once** | One book several people hold. Consolidated into one card, attribution preserved |
| **3.3.5** | **A reader** | A person, not a book. Their four Favorite Books and honest overlap |

**3.4 The ending** — "That's the week." A designed moment, not an empty state.

**3.5 What you can do** — save, decline, open a person, open a book, open a list, react, reply.

**3.6 What's absent** — infinite scroll, pull-for-more, timestamps, unread counts, trending, "popular this week", ads, follower counts, anything that could be improved by using the app more.

---

## 4. Reader profile

**4.1 Its only job** — answer "why might this person's taste matter to *me*?" from books and ratings alone.

| | Section | Contains |
|---|---|---|
| **4.2** | Identity | Name, one line on *how they read* — not what they do for work |
| **4.3** | **Between you** | The named books you share, with **both ratings** side by side |
| **4.4** | Disagreement | The one book you disagree hardest about, stated plainly |
| **4.5** | Favorite Books | Four, chosen deliberately |
| **4.6** | A list | Title, premise, covers |
| **4.7** | They wrote | One reflection |

**4.8 Library Match, as a percentage.** *Reversed 2026-08-04 — see §12.* This section previously read "no percentage anywhere," on the grounds that a single score claims precision eight ratings can't support. The percentage is now present, alongside Followers and Following, because a profile that refuses to quantify anything reads as inert rather than principled. The evidence — shared books with both ratings, and the sharpest disagreement — is still there underneath it. The number is an entry point, not the verdict.

**4.9 Honest emptiness** — when there's no overlap it says *"Nothing in common yet"* and explains that this isn't a verdict on their taste, just an absence of data.

**4.10 Present** — Read, Followers, Following and Library Match as a ruled band of figures (Match on another reader's page only); the joining year; and a **Follow / Following control, on another reader's page only**. *Reversed 2026-08-04 — see §12. Corrected 2026-08-06 — see §12.9.1.*

This line was wrong for two days and worth recording as a lesson rather than quietly fixing. It listed the Follow button as **present** from 2026-08-04, while §12.9.1 listed the same control as **known-open** in the same document — and the code agreed with §12.9.1: `toggleFollow(_:)` had exactly one caller, in onboarding. A spec that contradicts itself is worse than one that is merely out of date, because each half looks authoritative on its own. The rule this suggests: when a pass reverses a decision, the "Present" inventory is a claim about the build, not about the intent, and it should be written after the code is, not alongside the decision to write it.

**4.11 Still absent** — post counts, activity totals, badges, streaks, reading goals.

**4.12 The section index.** The profile is a set of collapsible rows — About, Read, Reading List, Books you both have read, Favorite Books — rather than one continuous scroll. A profile should be navigable, not endured. Below it, Bookshelves render as titled horizontal cover rows.

---

## 5. Book detail

**5.1 The order** — masthead, then the **Dewey Score** and its distribution, then **Add to Library**, then **"Why it reached you."** *Changed 2026-08-04 — see §12.* The page previously opened with the sender's reason and kept the crowd quiet and late. The crowd now leads, the action you came for is the first thing you can press, and the person who sent you is the first prose you read.

| | Section | Contains |
|---|---|---|
| **5.2** | Masthead | Cover, title, author, year, shelf state |
| **5.3** | Why it reached you | The sender's reason, set as prose |
| **5.4** | You sent this | *(if you sent it)* Your reason, whether they started it, their reaction, their reply |
| **5.5** | Who has this | Who holds it and **the specific surface** — "In *Books that made work feel strange*" |
| **5.6** | How it got to you | The provenance chain, up to three hops |
| **5.7** | About | Two sentences. Editorial, not marketing |

**5.8 Actions** — Save / Not for me (equal weight), shelf chips once saved, add a private note, recommend to someone.

**5.9 Present** — the Dewey Score with its distribution histogram, Reviews and Shelves counts as paired tiles, Similar Books, and a full details table: original title, publish date, publisher, ISBN, **Dewey Decimal**, editions, language, characters, setting, and genre chips.

**5.10 Still absent** — edition picker, buy links, ads.

---

## 6. Save with provenance

**6.1 The core mechanic.** When you save, Dewey records *who put it there* — silently. You are never asked where you found it.

**6.2 Three origins** — a person (with the surface: shelf / list / reflection / direct recommendation), your own browsing, or somewhere outside Dewey.

**6.3 The chain** — renders as up to three hops: *A bookseller in Lisbon → Priya Raghunathan → You.*

**6.4 Why it matters** — an unattributed want-to-read list is a chore. An attributed one is a set of small promises you made to people. This is the claimed answer to why to-read lists go stale.

---

## 7. Library

**7.1** Five states: Want, Reading, Finished, Paused, Did Not Finish. See §11.6.

**7.2 The signature detail** — the provenance line sits **above the author**. In every other reading app the author is the second most important fact about a book on your shelf. Here it's how it reached you.

**7.3** Optional private note per book, never prompted for.

**7.4 The row** — cover, title, **provenance**, author, then the rating as a score circle at the trailing edge. The date a book was added is real information but it is not why you open it; it lives in the book's detail view and in expanded metadata, never competing with provenance on the main line. *Settled 2026-08-04 — see §12.*

**7.5 Absent** — tags, sort options, import, export, goals, streaks, reading time.

---

## 8. The social layer

Deliberately the smallest vocabulary that still lets a quiet reader participate.

| | Feature | Rules |
|---|---|---|
| **8.1** | **Direct recommendation** | **One** person. A reason is **required** — presets make it a tap, not a paragraph |
| **8.2** | The reasons | "Because you loved—" / "For the prose" / "For the ideas" / "This made me think of you" / write your own |
| **8.3** | **Decline** | "Not for me" is equal visual weight. Nothing is sent to the sender. No confirmation |
| **8.4** | **Closure** | *"Ana started it."* Arrives ~20s later, unbidden. Asks for nothing |
| **8.5** | Closure direction | **To the giver, never the receiver.** "Someone started your recommendation" is a gift. "You started Elena's book — tell her?" is a debt. The second is not built |
| **8.6** | **Reaction** | Three marks: Noted / Already loved it / Exactly right. **Never counted, never totalled** |
| **8.7** | **Private reply** | One line, threaded to a book, visible to two people. No public thread |

**8.8 Absent** — public comments, likes with counts, quote-posts, DMs unrelated to a book, group chat, clubs, buddy reads, sharing to social, follower counts, notifications of any kind.

---

## 9. My read on the Letterboxd gap

You said you'd define this. Here's my analysis in the meantime — treat it as a starting point to argue with.

**9.1 What actually makes Letterboxd feel like Letterboxd:**

| | Element | Present in Dewey? |
|---|---|---|
| **9.1.1** | The **★ rating as the visual signature** — everywhere, instantly scannable, iconic | **Nearly absent.** Ratings exist in the data and barely appear in the UI |
| **9.1.2** | **Poster density** — grids of cover art, pleasure from volume | **No.** Dewey is spacious and typeset |
| **9.1.3** | **Short, witty reviews** — the culture is one-liners, not analysis | **No.** Dewey's reflections are earnest and literary |
| **9.1.4** | **The diary** — a dated, chronological log. "What I watched in March" | **No chronology at all** |
| **9.1.5** | **Lists as a creative medium** — obsessive, funny, competitive | **Underbuilt.** One read-only list per reader; you can't make one |
| **9.1.6** | **Year in Review** — the annual moment | **No** (deliberately) |
| **9.1.7** | **Volume** — a feed with real activity | **No.** Five cards a week |
| **9.1.8** | **Voice** — genuine humor and personality in the copy | **Partially.** Dewey is calm and dry; Letterboxd is funny |

**9.2 The honest tension.** Several of these *directly contradict* Dewey's stated positioning. You can't have Letterboxd's liveliness and Dewey's calm at the same time — Letterboxd is loud, dense, funny, and high-volume by design.

**9.3 So the list splits in two.** This is the useful part:

**Compatible — pure wins, no strategy change needed:**
- **9.3.1** The rating as a visual anchor. You can make ratings iconic without gamifying anything.
- **9.3.2** Cover density. Calm and dense aren't opposites — Letterboxd is fairly calm.
- **9.3.3** Voice. Dry isn't the same as flat, and Dewey's copy is currently a bit reverent.
- **9.3.4** A diary — your own chronological reading log. A personal record is not a vanity metric.
- **9.3.5** Lists you can actually make. Already in the strategy, just not built.

**In genuine conflict — would require reopening a decision:**
- **9.3.6** Volume and liveliness (needs more activity than books produce) — *still not reopened*
- **9.3.7** Year in Review (that's a stats surface) — *still not reopened*
- **9.3.8** Public counts of any kind — **reopened and adopted 2026-08-04. See §12.**

**9.4 My blunt read.** The thing most missing isn't social features — it's that **Dewey has no visual signature.** Letterboxd has the star rating and the poster grid; you know one at a glance from across a room. Dewey is beautiful but it doesn't yet have a *mark*. That's a bigger gap than any feature on this list, and 9.3.1 and 9.3.2 are the cheapest routes to one.

**9.5 The second thing.** Letterboxd is *fun*. Dewey is currently *tasteful*. Those aren't the same, and taste without fun is how a product gets admired and not used.

---

## 10. Where to mark up

Most useful to me, in order:

1. **§9.3** — which of those five compatible wins do you actually want, and which of the three conflicts are you willing to reopen?
2. **§3.3** — are these the right five cards? Which would you cut, and what's missing?
3. **§4.8** — the no-percentage decision. Still right, or does it cost too much legibility?
4. **§8.6–8.7** — is the social vocabulary too small now?
5. Anywhere the **language** is wrong — section names, button labels, the word "provenance" itself.

---

## Appendix — the objects, in plain English

| Object | What it holds |
|---|---|
| **Book** | Title, author, year, two-sentence description, cover palette, how widely read it is |
| **Reader** | Name, one line of texture, four Favorite Books, their ratings, one list, one reflection |
| **Provenance** | Who or what put a book in your library, the reason, the date |
| **Library entry** | A book, a shelf, its provenance, an optional private note |
| **Recommendation** | One book, one sender, one recipient, a required reason, a status, an optional reaction and reply |
| **Edition card** | One of five kinds of item in the weekly edition |

Six objects. No accounts, no follows, no sync, no backend.

**Superseded in part by §17.** Accounts and follows both exist now: a reader signs
in with Apple, chooses a display name and a unique handle, and both are rows in
Postgres. The rest of the sentence still holds and is worth holding onto — there
is no sync, and the backend covers identity only. Every object listed above is
still local.

---

## 11. What the expanded build added

The Letterboxd-completeness pass. Mechanics translated, never expression — no dark teal, no green stars, no borrowed layout. Full mapping in [letterboxd-to-dewey-feature-map.md](letterboxd-to-dewey-feature-map.md).

**11.1 The rating is now the visual signature.** A mark rendered as **filled rules, not stars** — short horizontal strokes. It reads as typesetting rather than arcade scoring, sits naturally beside serif type, and is unmistakably not Letterboxd's. It appears on book pages, diary entries, reflections, profiles, lists, shelves, and edition cards. This is the "mark" §9.4 said was missing. *The scale moved from half-to-5 to 0.1–10.0 on 2026-08-04 — see §12.2.*

**11.2 Rating is not Favorite.** Lifted wholesale from Letterboxd's rating-vs-like split, which is the smartest thing they have. A 5 is a judgement; a Favorite is a book you love, and it may be a 3 you'd defend to the death. Credited openly in the feature map.

**11.3 The complete book page.** *Reordered 2026-08-04 — see §12.1.* The hierarchy is now: hero, **Dewey Score**, Add to Library, why it reached you, you sent this, your relationship, community, lists, about, people, related, details. The community average was previously rendered deliberately quieter than a named friend's rating; it is now the headline number on the page, with the named friends immediately beneath it.

**11.4 The log sheet.** Status, dates, rating, Favorite above the fold — a five-second log. Reread, format, tags, reflection, spoiler, draft, visibility behind "Add more". Nothing is required.

**11.5 The Reading Diary.** Month-grouped, dated, with rereads as separate entries — you read *Severance* in 2025 and again in 2026 and rated it differently, and the diary keeps both. No totals, no streaks, no scoreboard.

**11.6 Five reading states**, not three: Want, Reading, Finished, Paused, Did Not Finish. Abandoning is an act of taste, not a failure to comply.

**11.7 Lists you can make.** Ranked or unranked, public or private, drag to reorder, a note per book. Seeded with personality — "Novels I finished out of spite", "Books I have lied about finishing", "Doorstops worth the wrist pain". §9.5 said Dewey was tasteful and not fun; the lists are where the fun went.

**11.8 Optional pairwise ranking.** Binary-search insertion, four rotating prompts ("Which stayed with you more?", "Which would you rather reread?"). Abandonable at any point. Never required to rate, log, or finish anything.

**11.9 Search.** Books, authors, readers, lists, series over the seeded corpus. Empty state is browsable, never blank.

**11.10 The profile as a body of work.** Four Favorite Books, diary, reflections, lists, ranked books, rating distribution — and **"Discovered through you"**, the books other people started because of you. No follower counts.

**11.11 Reflections with real filters** — Friends, Popular, Recent, Positive, Critical, with spoiler-blurring. Friends is the default, because that is the whole argument.

**11.12 The corpus** — 41 real books with genres, themes, pages, publisher, ISBN, translators, series; 8 community lists; 32 reflections written in a voice; 18 diary entries across 14 months.

**11.13 Preserved** — direct recommendations with required reasons, closure to the giver, taste overlap by named books, and the finite Weekly Edition. *Revised 2026-08-10:* "why it reached you" and multi-hop provenance chains, listed here as untouched, were removed in the simplification recorded in the amendment above §1 — see that note for what replaced them.

---

## 12. The 2023 wireframe pass

Source: the hand-built Figma file (`ZFvKpCj4JCAmyVcENnNi2O`), made roughly two years before this build existed. It was mined for **features and layout**, not visual expression. Several things in it turned out to be better than what had been built from the strategy docs alone, and two of its decisions reverse positions taken in §4 and §11.

Where this section conflicts with an earlier one, **this section wins** — the earlier text is annotated rather than deleted so the reasoning stays legible.

### 12.1 The crowd leads now

The wireframe puts the community score, review counts, shelf counts, follower counts, and a library-match percentage in the loudest positions on their screens. The prior build subordinated all of them to named individuals.

**Decision: adopt the wireframe's hierarchy.** The Dewey Score is the headline number on a book page. Followers, Following, and Library Match are the profile's three-stat row.

**The reasoning, stated honestly.** The earlier position — that a person you trust outranks 604 strangers — is still true about *how people decide what to read*. It was not true about *how a screen should feel*. A product that refuses to quantify anything reads as inert rather than principled, and a reader arriving at an empty-feeling profile does not stay long enough to discover the good part. The named-individual layer is not being removed; it is being placed under a number that gets people to look.

**What did not change:** the required reason on a recommendation, closure to the giver, and the finite Weekly Edition. Those remain the reason the app exists. *("Why it reached you" and provenance chains were listed here as unchanged; they were removed 2026-08-10 — see the amendment above §1.)*

### 12.2 Rating: 0.1 to 10.0

Replaces the half-to-5 scale.

| | Rule | |
|---|---|---|
| **12.2.1** | Range | 0.1 – 10.0, stored to one decimal |
| **12.2.2** | Input | A continuous slider, not a segmented tap target |
| **12.2.3** | Haptics | A subtle tick at **every 0.1**, a stronger one at each whole number for orientation |
| **12.2.4** | Display | Rules at `.regular` and `.large`, with the numeral beside them; **the numeral alone at `.tiny`**. *Inverted 2026-08-05 after seeing it on device — see §12.8.2* |
| **12.2.5** | Clearing | An explicit affordance — "tap the current value again" cannot survive a continuous track |

**12.2.6 The mark survives the scale change.** Ten rules instead of five, and the partial rule fills *proportionally* rather than snapping to half-width. 8.3 renders as eight filled rules, one filled 30%, one empty. This generalises to any granularity and keeps the typographic signature of §11.1 intact. *True of the type but of no screen as of 2026-08-05: the audit in §12.8.8 left every surviving render site at `.tiny`, which is the numeral. The rules are still implemented and still correct; nothing draws them.*

**12.2.7 The counter-argument, recorded.** One decimal is finer than a reader can reproduce week to week, and it adds a decision to every log. This was raised and overruled deliberately: the expressiveness is worth the friction, and the slider makes the cost small. Noted here so nobody re-derives the objection as though it were new.

### 12.3 The histogram displays in 0.5 buckets

Input keeps 0.1 precision; the community distribution renders in **20 half-point bins**. Ninety-nine bars is noise on any real corpus, and the wireframe's own histogram has about twelve.

### 12.4 Pairwise ranking stays first-class

It was briefly argued that finer ratings make ranking a vestigial tie-breaker. That was wrong. **A rating is a valuation; a ranking is a forced ordering.** They answer different questions, and the second is hardest and most interesting exactly when several books are close. Ranking remains a meaningful secondary system, not a tie-break utility.

### 12.5 Taken from the wireframe

| | Element | Note |
|---|---|---|
| **12.5.1** | Collapsible profile section index | About / Read / Reading List / Books you both have read / Favorite Books |
| **12.5.2** | "Books you both have read" as a destination | The overlap idea from §4.3, given its own page instead of an inline strip |
| **12.5.3** | Bookshelves as titled horizontal cover rows | Poster density and list personality in one move |
| **12.5.4** | The Dewey Score block | Circled numeral with the histogram beside it |
| **12.5.5** | Paired stat tiles | Reviews and Shelves |
| **12.5.6** | Score circle at the row's trailing edge | On library rows |
| **12.5.7** | The expanded details table | Including **Dewey Decimal**, which the app was named for and had never shown |
| **12.5.8** | Similar Books | |

### 12.6 Not taken

**12.6.1** The wireframe's visual expression — its greens, its stars, its type. The built palette and the rule-mark stand.

**12.6.2** Its book-page sequencing. The wireframe buries the score below a three-paragraph summary; here the score sits in the masthead region and the summary moves down.

**12.6.3** Stars as the rating input. Superseded by 12.2.

### 12.7 The library row keeps provenance

Score circle at the trailing edge, provenance above the author, and the added-date demoted to the book's detail view. See §7.4. The wireframe put "Added on 19 May 2017" on the main line; that is real information, but it is not why anyone opens a book six months later.

### 12.8 Corrections made after running it

Fourteen defects, none of which was visible to the reasoning that produced it. **12.8.1–12.8.5** came out of the first pass on a device. **12.8.6–12.8.14** came out of the rating pass that followed, which also cleared three of the five items §12.9 had listed as open.

**12.8.1 The histogram alternated tall/short.** Each old bucket was spread 20/60/20 across three new ones, so odd buckets drew from one old bucket and even buckets drew from two — about a 1.5× alternation down the whole chart, on the app's new headline block. The verification that ran was "no empty buckets", which this passes. Now each old bucket splits evenly into the two new buckets it owns, followed by one [1,2,1] smoothing pass, with the rounding shortfall returned to the peak so `communityCount` still matches the seed exactly.

**12.8.2 The mark became a dotted line, and §12.2.4 was backwards.** Ten rules in the ~44pt that five used to occupy left each rule barely longer than it was thick. At `.tiny` the row rendered as ten identical dots: it read as a dotted rule, and 6.0 was indistinguishable from 10.0. §12.2.4 had put the numeral at large sizes only — exactly backwards, since the mark stops resolving precisely where space runs out. `.tiny` now renders the numeral alone, which is also *narrower* than the rules it replaces and so relieves every tight inline row the build flagged. `.regular` and `.large` keep the rules, with thickness cut so they read as strokes rather than dots. *Both sizes were subsequently corrected again (§12.8.6) and then left with no call sites (§12.8.8).*

**12.8.3 The rating slider was invisible until touched.** The thumb was only drawn when a rating existed, so an unrated book showed a bare capsule on a page already full of hairline rules — nothing said it could be dragged. The thumb is now always drawn, sitting at the floor and faintly stroked when unrated, so it offers itself without claiming a value of 0.1.

**12.8.4 The corpus hid the feature.** Doubling the old half-to-5 rungs put every seeded rating on a whole number, so shelves read 9 / 10 / 8 / 9 / 10 and the 0.1 scale — the entire point of §12.2 — was invisible in the one place it was meant to be felt. `SeedData.textured` now nudges each seeded rating off its whole by ±0.1–0.4, derived deterministically from the key (FNV-1a, never `String.hashValue`, which is per-process seeded). Ratings at the ceiling hold, so a clean 10 stays a clean 10. *That promise is now enforced explicitly rather than incidentally — see §12.8.10.*

**12.8.5 Library Match couldn't discriminate.** Agreement was `1 - meanDifference / 10`, but no two readers have a mean gap of eight points, so agreement bottomed out near 0.6 and every reader scored 60–72% — including the one the seed was built so you'd share almost nothing with. The divisor is now 4: on a ten-point scale, readers who agree land within a point, and a mean gap of four points is disagreement, not partial agreement.

**12.8.6 The partial rule was a dot, and the top of the scale was a full rule.** The fractional slot drew `unit × fraction` with no floor and no ceiling. At `.regular` (unit 5.5pt, thickness 2pt) any fill at or under 0.36 was shorter than it was thick — 8.1, 8.2 and 8.3 all rendered as eight rules and a speck. At the other end a 0.9 fill was 4.95pt against a full rule's 5.5pt, half a point, under one device pixel at 2×; 9.9 was indistinguishable from 10.0, and §12.8.4 had just filled the corpus with values ending in a tenth. A non-zero partial now draws at least 1.5× thickness and at most 0.8 × unit, which leaves over a point of daylight at every size. Both are corrections to what the shape *says*; no value is rounded, and the fill stays monotonic.

**12.8.7 The `.tiny` numeral was the only sans-serif figure in a serif app.** It rendered in `Theme.TypeScale.meta()`, which is `.system(.caption)` with no `design: .serif`. Two silent failures were stacked, and neither is visible to a compiler — this was caught by enlarging a screenshot. First, `.fontDesign(.serif)` cannot override the token: `.system(.caption)` carries an explicit `.default` design, and an explicit design beats the environment modifier. Second, even with the design baked into the font, `.monospacedDigit()` on a *text-style* serif system font drops back to the default design. New token `Theme.TypeScale.metaNumeral()` — `.system(.caption, design: .serif)`, no `.monospacedDigit()`, with a comment saying why not to re-add it — is used by the `.tiny` numeral and by the unrated dash. `meta()` stays sans for the dates and counts that share it. `ScoreCircle` keeps its `.monospacedDigit()` and stays serif because it builds from `.system(size:)` rather than a text style.

**12.8.8 The mark audit: the rules now draw nowhere.** Every render site was reviewed against one test — does this reader, on this screen, have anything to compare this number *to*. Fourteen sites lost the mark; twelve kept it, six of those in changed form, and every one of the twelve is `.tiny`, which is the numeral. `.regular` and `.large` are implemented, correct, and unused. The diary was the clearest case: three rows reading 9.3, 9.7 and 7.8 rendered as three identical dashes.

| | Removed | Because |
|---|---|---|
| **a** | Book-page hero | 112.5pt of rules a short way above the 88pt Dewey Score circle put two competing numeric objects in one masthead, and the rules are a comparison device with nothing on that page to compare against. The serif numeral stays. |
| **b** | Book-page facts table | Third persistent statement of the same number on one page; every sibling row is a label and a plain string. |
| **c** | Similar Books cards | A strip of books you have not read, so the slot was empty on almost every card. |
| **d** | Pairwise choice card | Showing both ratings at the instant of choosing hands the reader the answer (§12.4). |
| **e** | Ranked list rows and neighbour rows | The ordinal is the claim; unrated books drew an empty container that still took its padding. |
| **f** | List editor rows, Add-to-list confirmation, list index cards | Nothing is being compared while you drag order or confirm one book. |
| **g** | Recently-added grid and profile shelf rails | Browse surfaces; the avatar and first name already carry the attribution. |
| **h** | The "from a list" edition card | The card ends on its provenance line, and a tinted number above it out-argued the §7.2 signature detail. The direct-recommendation card keeps its sender's rating. |
| **i** | Reflection cards in Search | 66pt of rules stood in front of the six lines of prose the card exists to show. |
| **j** | Book-page detail row for Translator | Not a mark; listed here so one table holds every removal. See §12.8.13. |

The twelve kept, all `.tiny`: the diary, the profile's Read rows, search results and Browse, ranked list rows, friend rows, reflection bylines, the four edition-card slots (book row, sender's verdict, the both-ratings pair, a reader's defining covers), "Books you both have read", and the cover strips. `ScoreCircle` was not part of this audit and is unchanged — the library shelf's trailing circle (§12.5.6), the Dewey Score block (§12.5.4) and the histogram all stand. Two structural fixes came with it: the cover slots reserved a hardcoded 6pt for a caption glyph more than twice that height and unbounded at accessibility sizes, now replaced by a hidden numeral in the same font; and one row that carried both a mark and a loose numeral spoke the value twice to VoiceOver, now one element.

**12.8.9 Clearing a rating did not clear it.** `myRating(for:)` was `latestEntry(for:)?.rating ?? myRatings[bookID]`. The explicit Clear of §12.2.5 wrote `nil` to the diary entry, which persisted correctly, and the `??` then fell straight through to the seed. Because `SeedData.myRatings` and the seeded diary are textured independently, clearing Bluets did not even restore the 9.3 that had been on screen — it produced **8.8**, a number the reader had never entered and that had never been displayed anywhere. It failed without needing a relaunch. The diary is now the sole authority for any book it holds an entry for, *including* when that entry carries no rating; the seed is consulted only for books the diary never mentions. `allMyRatings` is routed through the same function, which fixed two matching faults: it had overlaid `diary` in insertion order rather than `loggedOn` order, so on a reread the wrong entry could win, and it skipped `nil` ratings, so a cleared rating left the stale seed feeding Library Match.

**12.8.10 The seed ceiling, and the nudge at the edges.** `SeedData.textured` now early-returns `Rating.range.upperBound` for any value at or above the ceiling, so a seeded 10.0 is exactly 10.0. Nudges that would land out of range reflect (`value - offset`) instead of clamping; clamping parked values on 10.0 or 0.1 — a whole number, and at the top a false perfect score, which are the two artefacts the function exists to remove. Still a pure FNV-1a function of stable keys, so it is deterministic and re-texturing on relaunch remains structurally impossible. Every seeded rating literal is a whole number, so this changes no other value.

**12.8.11 The slider's floating readout (was open in §12.9).** Removed, not shrunk. A numeral appeared above the thumb on touch and vanished on release, while the surface that owns the slider already states the live value in its own header on a fixed baseline. The readout row was 30pt and the touch band was 34pt — 64pt total, and the row was part of the gesture. Deleting the row alone would have left a 34pt target, under the 44pt minimum, on the one control in the app that is touch-only. The band is now 44pt, symmetric around the thumb: 20pt of genuine dead space returned, and no target regression. Because nothing appears on touch, the control's height is identical before, during and after a drag.

**12.8.12 The hero gap beside the cover (was open in §12.9).** The text column now takes the row's height and centres its content in it, so on an unrated book the leftover space is split above and below instead of dumped under the type as a hole against the cover's lower half. Nothing is measured — no offset, no fixed height, no cover-derived constant — so it holds at any Dynamic Type size and any width, and when the text column is the taller one it is a no-op.

**12.8.13 Translator rendered twice (was open in §12.9).** The Details table's Translator row is deleted; the People section keeps it. People is the table built for people, and Language stays in Details because it is a property of the edition.

**12.8.14 The shelf chips clipped mid-word.** The shelf row was a horizontal `ScrollView`, so a label wider than the remaining space was cut at the margin rather than wrapped. It is now a wrapping layout that proposes the container width to each chip, so an over-long name wraps inside its own capsule and a chip can never be wider than the space it was given. Deliberately *not* the shared `FlowLayout` used by three other screens: that one measures with `.unspecified`, which reproduces the same clip one layer down — those three call sites still carry it latently at accessibility text sizes. Visible consequence: the shelf names wrap to two lines on every current iPhone width at the default text size, which is the whole set stated at once rather than a line you have to scroll.

### 12.9 Known and open

**12.9.1 The follow control — resolved 2026-08-06.** *Was: "There is no follow control, despite Followers and Following now being headline stats. No follow state exists in the store to bind one to."*

The store half of that had already been fixed by §13.7, which added `follows`, `toggleFollow(_:)` and `isFollowing(_:)` and persisted them. What survived was worse than the original gap: the state existed, worked and was durable, and exactly one screen in the app could reach it — onboarding's suggestion rows. A reader who skipped onboarding, or finished it, could never follow anyone again. In an app whose edition is assembled from the readers you follow, the follow graph is the product, and it could only be built in the first ninety seconds of the first session.

`ProfileView` now carries the control, in **two places**, and it is `isMe`-guarded so it never appears on your own page.

**Placement, and why both.** The first sits in the identity block, under the texture line and "Keeps returning to", above the ruled band. It belongs to the *person* — the question it answers is "do I want this reader in my editions", which the four lines above it have just spent their whole length answering, and which the follower tally below it does not bear on. It is also above the fold, which matters: following is cheap and reversible, and often the reason the page was opened.

The second sits at the end of **Books you both have read** — the section that makes the actual case, with both ratings on each shared book and the sharpest disagreement under them. It previously ended on "A shelf that only agrees with you is a sales pitch" and then simply stopped: the argument fully made, with nothing to make it *to*. Sending a persuaded reader back up five sections is friction arriving exactly when intent peaks. This second control renders **only when there are shared books** — with no overlap the section says so honestly, has persuaded nobody, and there is nothing to collect on.

They are one component with one label and one state, so the duplication reads as a long page repeating its action rather than as two competing affordances.

**`ChipStyle`, matching onboarding**, rather than a new style: the two states map onto the style's two, and a reader who followed three people on their first evening should meet the same object a week later. `PrimaryButtonStyle` was rejected twice over — full-width makes following the loudest thing on someone else's page, and it is the one filled button, which by its own rule appears once per screen. The label carries a `minHeight` so the capsule reaches the 44×44 minimum (`ChipStyle`'s padding alone lands near 40 at default Dynamic Type).

**Not on `ReaderRow`** in search results, deliberately. All that row shows of a stranger is a shared-book count, and §12.1's whole position is that the figures are the doorway and the evidence is underneath — a chip there lets the follow graph be built off a tally, without the argument. It is also a `NavigationLink`, which merges its children into one accessibility element and makes a nested button a coin-toss at the hit-test boundary. Onboarding stays the exception: no profiles to push to yet, a real computed reason on every row, and building the first follow set fast is that screen's only job.

**Vocabulary** lives in `FollowCopy` in `Models/OpinionModel.swift` — the two words, the spoken label, value and hint, and the one sentence stating the mechanic. Onboarding's chip now reads its label from there too, so the same action cannot come to read "Following" on one screen and "Followed" on the next. The spoken label is built from the drawn word, because Voice Control matches on the announced name (WCAG 2.5.3).

**Nothing is fabricated.** `profile.followerCount` is a seed fixture on other readers and is never mutated — following Priya leaves her at 412, as it should, since this prototype has no back end for her to gain a follower in. Your own Following figure does move in a fresh account, because §13.7 already derives it from `store.follows.count`, which is real state. Verified on device: follow and unfollow from a profile, state surviving relaunch, the Edition moving from five cards to three when a reader is unfollowed, no control on your own page, and a fresh world still starting at zero follows.

**One thing this did not fix**, noted rather than silently left: in the *seeded* world your own profile shows `ReaderProfile.me`'s fixture Following count, so following someone changes nothing visible there. Only the fresh account derives that figure from real state. Out of scope here — it is a property of the seeded fixture, not of the control.

**12.9.2 `Persistence.State` still carries no version field.** The filename (`dewey-prototype-v3.json`) is the only schema guard.

**12.9.3 An unrated mark still draws nothing at almost every site.** `RatingMark` gained an `Unrated` option — `.blank` or `.stated`, a faint em dash carrying "Not rated" — but it defaults to `.blank` and no call site passes `.stated`. Eleven of the twelve surviving sites therefore render an empty view with no accessibility element, so VoiceOver skips the slot in silence rather than saying the book is unrated. The exception is "Books you both have read", which hand-rolls a dash locally because a row that reads as having failed to load is worse there than anywhere else. `ScoreCircle` already answers this with an em dash and "Not yet rated"; the mark has the mechanism and is not using it.

**12.9.4 Three founder-evaluation controls exist in the debug menu, and are temporary.** Haptic preset (Quiet / Balanced / Mechanical / Minimal), rating scale (Tenths / Halves / Wholes), and book-page order (A: Score, Add, Why — B: Why, Add, Score), plus a scratch slider that belongs to no book. They are in-memory only, are never written to the saved state, and reset to Balanced / Tenths / A on relaunch. Facts that matter while they exist: the scale mode governs only what a *new* drag can land on and converts nothing, so a book already at 7.8 is still 7.8 and still saves as 7.8; under Minimal a fast drag that skips a whole fires nothing unless it lands on x.0 or x.5; and variant B is indistinguishable from A on a book with no incoming recommendation and no library entry, because "Why it reached you" renders nothing there. The cost is one layering concession: `Models/Rating.swift` reads `Features/Debug/DebugSettings.swift` at five points and `BookDetailView` at one, each commented as prototype scope. Removing the harness is six line deletions plus the debug files.

## 13. The opinion-model correction pass

A walkthrough of the running prototype on 2026-08-05 found the product's most
important contradiction, and this pass exists to resolve it before any API,
backend, metadata or additional Letterboxd feature work.

**The finding.** Dewey asked for one opinion in three incompatible currencies.
Logging a single book requested a 0.1–10.0 rating, a Favorite mark, and a
pairwise ranking — three separate value systems for one act. Then it displayed
the results in flat contradiction: a book rated **8** landed at **No. 1 of 14**,
above a book rated **10**, with nothing anywhere on screen acknowledging that
those two figures answer different questions. A reader could not tell which one
the app believed, which one their followers saw, or which one drove
recommendations.

### 13.1 The judgements, and their one job each

The fix is not to collapse them, and not to derive one from another. All of them
are worth having and were never in conflict as *ideas* — they were in conflict
because the app never said what each was for. Each now has exactly one job, and
the copy for all of them lives in `Models/OpinionModel.swift` so no surface can
invent a local phrasing.

| System | Answers | Independent of |
|---|---|---|
| **Rating** | How good was this book? | identity, ranking |
| **Favorite** | Do you love this book? | quality, and the profile |
| **Favorite Books** | Which four do you want on your profile? | everything — it is a hand-picked list |
| **Personal ranking** | Where does this book sit among my books? | rating |

**The scale did not change.** 0.1–10.0 was reconsidered during this pass and
deliberately kept. The contradiction was never the granularity; it was the
absence of an explanation. Rescaling would have changed the currency without
resolving the confusion *between* currencies — and the walkthrough's objection to
0.1 precision (§12.2.7) remains recorded, raised and overruled, unchanged.

**Favorite and Favorite Books are two things, and the pass ended up proving
why.** The concept arrived wearing four names — "Favorite", "Favorite Books",
"Defining Books", "Part of Me" — across four screens, backed by *two different
model fields*, so a reader could not tell whether marking a book put it on their
profile. The first correction collapsed all of it into one field called Part of
Me. That was wrong in a subtler way: the profile then republished whatever the
log sheet had most recently touched, so a reader who loved thirty books had four
of them chosen *for* them, by recency, and the four stopped being a decision.

They are now two fields with two jobs and one vocabulary:

- **`DiaryEntry.isFavorite`** — the mark. Unlimited, made in passing while
  logging, and it changes nothing on the profile.
- **`ReaderProfile.favoriteBookIDs`** — the four you sit down and pick. Nothing
  derives it: not top ratings, not the head of the ranking, not the most recent
  Favorites. `DeweyStore.setFavoriteBooks(_:)` is the only writer, and the
  profile shows four slots whether or not they are full, because three covers
  and a gap says "unfinished" where three covers alone says "this is the list".

**Ranking asks one question.** The pairwise prompt used to rotate between "Which
stayed with you more?", "Which would you recommend first?" and "Which would you
rather reread?" across rounds of a *single* ranking. Those are three genuinely
different questions — the book that stayed with you is often not the one you
would recommend first — and collapsing their answers into one ordering silently
corrupts it. Every pair now asks: **"Which book belongs higher in your personal
library?"** If Dewey ever wants the other orderings, they are separate rankings,
not alternating prompts feeding one list.

**The sentence that does the actual work** appears before ranking begins, and
again on the result screen:

> Your rating reflects your judgment of the book. Your ranking reflects where it
> sits for you personally. They do not have to match.

That is what makes an 8 at No. 1 legible instead of broken. The result screen
adds "Placed by your comparisons, not by your ratings" and must never imply the
position follows mathematically from the rating.

### 13.2 The book page has one logging path

The page stated reading status **four times** — a badge under the cover, an
"In your library · …" line, a chip row under "Where it sits", and a Status row
under "Your relationship" — and offered **two competing logging paths**: a
prominent "Log this read" button with a complete inline status picker and rating
slider directly beneath it. The inline editor is gone. One prominent
**Log / Update** action opens the progressive log sheet; a compact read-only
relationship summary states each fact once and opens the same editor when
tapped. The `BookPageVariant` A/B ordering harness was deleted with it — it
existed to compare two orderings of a region that no longer has a competing
second editor in it.

### 13.3 One vocabulary

Three words, three meanings, no overlap: **Library** is the reader's full
collection, **Status** is one of the five reading states, and **Lists** are named
curated collections. "Shelves" and "Bookshelves" are gone — they previously
meant statuses in the Library tab and curated collections on the profile, the
same word for two different things one tab apart.

The five statuses are always written in full: **Want to Read · Reading ·
Finished · Paused · Did Not Finish**. `ReadingStatus.shortTitle` is deleted;
"Want" and "DNF" meant a reader saw three different names for one state
depending on where they stood, and a row too narrow for "Did Not Finish" is a
layout problem, not a vocabulary problem. `ReadingStatus.Shelf` is deleted too:
Paused and Did Not Finish used to collapse into a Library-only bucket called
"Set Down", a phrase used nowhere else in the app, so a reader who marked a book
Paused went looking for Paused and found no such filter. The Library now filters
by the five states directly.

### 13.4 Saving completes

Save used to leave the sheet open: the finished form stayed visible and
apparently editable, "Cancel" quietly became "Done", and the ranking prompt slid
up *inside the same sheet*. The flow is now save → dismiss → confirm → optional
ranking as a distinct step. Logging a book already Finished defaults **A reread**
on, since the app already knows.

### 13.5 One rating treatment

A rating is the one figure on screen that must mean the same thing wherever it
appears, so `RatingMark`, `ScoreCircle` and `DistributionHistogram` no longer
accept a `tint` — the parameter is *removed* rather than defaulted, so the
compiler catches every site. The Edition used to pass each reader's accent into
the mark, so on a convergence card Priya's 9.2 drew warm and Ana's 10 drew cool,
which reads as a claim about the books and takes a moment to decode as a claim
about the speakers. Reader identity still colours avatars, names, borders and
provenance accents — the places colour answers "who" without being mistaken for
"how good".

### 13.6 Layout defects

Content scrolling under an unblurred navigation title, floating tab-bar labels
losing contrast over saturated covers, chip rows clipped mid-word at the right
margin, diary reflections truncating mid-word, fanned list covers obscuring
their own titles, unequal ranking-card heights, and the Library opening on a
near-empty Reading segment. The Library default is now
`DeweyStore.busiestStatus` — a property of the reader's actual library rather
than a hardcoded case — and the session remembers the last selection.

### 13.7 The fresh account

The prototype had only ever booted into the seeded world: fourteen ranked books,
sixty-one followers, a populated diary. That is the right world for showing what
Dewey *is* and the wrong one for answering the question the app could not
otherwise answer — what a stranger sees on first launch, when "readers you
follow" is nobody. For a product whose whole premise is other people's taste,
that screen decides whether anyone reaches the second one.

`WorldMode` switches between **Seeded world** and **Fresh account** from the
debug menu; both reset cleanly and the choice persists. `.fresh` fabricates
nothing — no follower count, no history, no ratings, no ranked library, no
lists. `SeedData.freshWorld` is a literal with no arguments, which is the point.
Onboarding climbs out of it: pick a few known books, react to them, choose the
four Favorite Books for the profile, see readers suggested with a reason computed
from real overlap, and save one book *with provenance* — the moment that teaches
what makes Dewey different.

`Persistence.State` gained `world`, `follows` and `needsOnboarding` as
**optional** fields. Synthesised `Codable` does not fall back to a property's
default when a key is missing, so declaring them non-optional would make every
file written before this pass fail to decode — which reads to a user as "the app
wiped my library" rather than "a field was added". (The filename later moved to
`dewey-prototype-v4.json` for §14 — see there.)

### 13.8 The Edition still ends

The finite weekly edition is kept — the restraint is the best idea in the
product. What went is the closing line's second sentence, which effectively
advertised that the app had nothing to offer for six days. The edition now
closes without advertising inactivity, and without infinite scroll or fake
refresh.

## 14. Favorite and Favorite Books

§13.1 found one idea wearing four names — "Favorite", "Favorite Books",
"Defining Books" and "Part of Me" — across four screens, backed by two model
fields, and merged them into one field under one name. The merge was the wrong
half of the fix. The names were genuinely a mess; the two fields were not. They
held **two different concepts that happened to share vocabulary**, and
collapsing them deleted a distinction the product depends on.

**Two concepts, stated once each.**

| | **Favorite** | **Favorite Books** |
|---|---|---|
| Question | Do you love this book? | Which four books do you want on your profile? |
| How many | Unlimited | Exactly four |
| Set where | Log sheet, one book at a time | The profile, deliberately |
| Stored as | `DiaryEntry.isFavorite` | `ReaderProfile.favoriteBookIDs` |
| Who sees it | Beside the book, wherever it appears | The top of your profile |

**Nothing derives the four.** Not the highest ratings, not the head of the
ranking, not the most recently marked Favorites. `DeweyStore.setFavoriteBooks(_:)`
is the only writer. The previous merge had the profile fold in diary marks by
recency, which meant a reader who loved thirty books had four of them chosen on
their behalf and watched their profile change every time they logged one — the
scarcity that makes four worth reading was gone, and nobody had chosen anything.

**The profile shows exactly four slots.** On your own page, unfilled slots are
dashed outlines reading "Choose" and open the picker; on someone else's, only
what they actually chose is drawn, because four outlines where a stranger's
taste should be reads as a broken profile rather than an unfinished one.

**Where the four are chosen.** A picker reached from the profile, listing
everything you have logged or shelved, newest first. Books you have marked
Favorite carry the mark so they are findable, and are **never preselected** —
preselecting them would be the app filling the slots and calling it a choice.
Chosen books show their position, because the order you pick them in is the
order the profile shows them. Edits commit on Done, so backing out changes
nothing. Onboarding's fourth step is the same decision in its first form, and it
writes only the profile four — it used to also stamp `isFavorite` on those
entries, which taught a new reader on day one that the two concepts were the
same thing.

**Marcus carries four now, like everyone else.** He held five in the seed back
when the list was an unlimited mark that the profile truncated for display. Now
the list *is* the profile's four and a fifth would be a bug rather than a
demonstration. His other loves live on his diary entries as Favorites, where
there is no cap — which is the distinction the corpus now exists to show.

**Persistence moved to `dewey-prototype-v4.json`.** `DiaryEntry.isPartOfMe`
became `isFavorite`, so a v3 file carries a key nothing reads and omits one
`DiaryEntry` requires; that decode fails outright, which is the correct outcome
— but under the old filename it would fail as a mystery. Under a new one it is a
fresh seed on purpose. `favoriteBookIDs` is optional in `State` so a file
written before the split restores as the seeded four rather than as nothing.

**Retired vocabulary.** "Part of Me", "Books that made me", "Books that made
them", "Defining Books" and "Essential Books" appear nowhere a reader can see
them. `Judgement.FavoriteCopy` and `Judgement.FavoriteBooksCopy` are the only
sources for either concept's words, so no surface can invent a local phrasing —
and the two enums are separate precisely so the two concepts cannot drift back
into one.

### 13.9 Found by walking the build

Four defects that only appeared once the pass was running on a device, all of
them introduced or exposed by this work rather than inherited:

**13.9.1 Onboarding could not be dismissed.** The cold-start cover was presented
with `.constant(store.needsOnboarding)`. A constant binding has a no-op setter,
so Skip and Finish both ran, both cleared the flag on the store, and the sheet
stayed exactly where it was — a fresh account was trapped on the first screen.
Now driven by real `@State` mirrored from the store in both directions.

**13.9.2 The welcome screen overflowed horizontally at accessibility text
sizes.** Two deliberately over-wide rows of covers were hung directly in the
page's `VStack`, so their intrinsic width propagated up and the enclosing
`ScrollView` sized its content to the widest row: the *entire screen* became
wider than the display. At default type it merely bled; at accessibility sizes
the headline and the paragraph were both sliced down the middle, on both edges,
on the first screen a new reader ever sees. The band is now drawn in an overlay
on a bounded `Color.clear` box and clipped, so it cannot influence layout.

**13.9.3 The Edition ignored who you follow.** `WeeklyEditionView` rendered
`SeedData.edition` directly, which was fine while there was one world and you
followed everybody in it. In a fresh account it was a straightforward lie: five
cards from four strangers, under a header reading "Five things from the readers
you follow". `DeweyStore.edition` now filters the run against `follows`, the
header counts what is actually below it, and an empty edition says so plainly
rather than manufacturing activity to cover the gap.

**13.9.4 The seeded reader followed everybody, including the person being
suggested to them.** The Edition's `.readerSuggestion` card proposes a reader you
do not follow, so once the filter above existed, the seeded world silently
dropped its own fifth card. Tobias is no longer in the seeded follow set —
which is also just truer to how a network looks in use.

### 13.10 Still open

**13.10.1 The rating slider's precision is unresolved, deliberately.** 0.1
granularity is roughly three pixels per step on the track, and the objection
that no reader holds a 100-point opinion about a novel stands. This pass
answered the *contradiction* (three currencies, no explanation) and explicitly
did not re-litigate the *scale*. The debug menu's Tenths / Halves / Wholes
switch is still the way to feel it on a device before deciding.

**13.10.2 `ScaleMode` and `HapticPreset` remain prototype scaffolding.** Both
live in memory, reset on relaunch, and are still read from `Models/Rating.swift`
at five points — the one layering concession in the app.

---

## 17. Real accounts

The prototype had one identity and it was a constant: `SeedData.me`, name
"You", handle `@you`, sixty-one followers. Every profile screen in the app was
therefore a picture of a person who did not exist, and the sixty-one was the
loudest of several numbers that were simply invented. This pass replaces that
constant with an authenticated account, and moves the seeded world out of the
default launch path.

**Scope, stated as a boundary rather than a to-do list.** This is identity, not
a migration. Library, diary, ratings, rankings, lists and imported book metadata
all remain local and are not touched. The temptation to "just also put the diary
in Postgres while we are here" is the thing this section exists to refuse: the
reading record is the product's most valuable state and moving it needs a
migration story, a conflict story and an offline story, none of which identity
needs.

### 17.1 The first-run sequence

```
welcome → sign in → name and handle → pick → rate → Favorite Books → people → done
└──────────── account ─────────────┘ └────────────── taste ──────────────────────┘
```

**The four taste steps are unchanged.** Not rewritten, not restyled, not
reordered — `OnboardingView` gained two parameters and lost its welcome screen to
a file of its own. `WelcomeView` is the same copy, the same full-bleed cover
band, the same named-reader card; `FirstRunFlow` draws it as step one and then
enters `OnboardingView` at `.pick`. Constructed with no argument, which is what
the debug menu's replay does, all six steps still run in their original order.

**Where the reader is, is the session phase**, not a step counter. `AccountPhase`
is one enum — `.restoring`, `.signedOut`, `.needsIdentity`, `.needsTasteOnboarding`,
`.ready` — and `RootView` switches on it and nothing else. Three booleans would
have admitted the state that must not exist (an identity with no session); one
enum cannot represent it. The single piece of local state in the whole flow is
whether the welcome screen has been dismissed, which is genuinely local because
it is the only step with nothing behind it on the server.

**`.restoring` is not cosmetic.** Without it the app opens signed-out and
corrects itself a beat later, which for a returning reader is the sign-in screen
flashing past on every cold launch.

### 17.2 Sign in with Apple, natively

`SignInWithAppleButton` presents the system sheet in-process. A browser-based
OAuth round trip works and is what the Supabase quickstart shows; it is also a
worse first impression than the sheet every other iOS app uses, and it puts
Safari chrome between a stranger and the second screen of the product.

**One provider, cleanly.** `AuthService` is a protocol with one method per
sign-in mechanism. Email arrives as a second method, not a second code path
through `SessionStore`.

**The nonce is generated per attempt.** Apple receives `sha256(raw)` and embeds
it in the token's `nonce` claim; Supabase receives the raw value and checks the
two agree. Sending the hash to both fails every sign-in with a nonce mismatch,
which is the mistake this is written down to prevent.

**Apple's `fullName` arrives once and never again** — first authorization only,
per Apple ID, and nil after a reinstall. It is a prefill for the name field. The
authority for a display name is the `profiles` row, or every returning reader
would have a blank name.

### 17.3 Handles

Case preserved for display, folded for uniqueness. A reader who types `JackS` is
shown `@JackS`; nobody else can then take `jacks`, `JACKS` or `jAcKs`. That split
is a generated column — `handle_normalized text generated always as (lower(handle))
stored` — with the unique index on the generated form. A trigger would have done
the same job and could drift; a generated column has no code path that writes the
handle without also producing the key it is judged on.

**The `@` is display and never storage.** It is not in the column, not in the
uniqueness key, and drawn beside the text field rather than typed into it — so it
is not the one character a reader can delete to break their own handle.

**Client validation is a mirror, not the authority.** `Handle.validate` exists so
a reader learns a space is not allowed while typing it. The `CHECK` constraint is
what decides. Availability is answered by a `SECURITY DEFINER` function rather
than a `select`, so a taken handle can be reported without exposing the table to
enumeration — and it is explicitly a convenience: two readers can be told the
same handle is free in the same second, the unique index decides, and the client
maps Postgres' `23505` back to "that handle is taken".

### 17.4 The schema, and one thing it deliberately splits

`profiles`, `follows`, `seed_follows`, `favorite_books`. RLS on all four from the
first migration — the anon key ships inside the binary, so every rule that
matters is a policy rather than a check in Swift. `profiles` and `favorite_books`
are readable by any signed-in reader, because a profile you cannot read is not a
profile and the four books are the most public thing on it. Writes are
`auth.uid() = user_id` everywhere, with both `using` and `with check` on updates
so a row cannot be reassigned to somebody else.

**`follows` is created and expected to be empty.** Every reader the taste
onboarding can currently offer is a fixture in `SeedData`, not a row in
`auth.users`, so those follows cannot go in a table whose columns are foreign
keys. They go in `seed_follows`, keyed by slug. Modelling them as a nullable
column on `follows` was the alternative and is worse: it would mean dropping
`followed_user_id not null`, removing the constraint that matters most on the
real table to accommodate the temporary one. `seed_follows` is expected to be
dropped whole.

### 17.5 `"me"` stays

`DeweyStore.me` now carries a real name, handle and join date, and reports **zero
followers** rather than the seed's sixty-one — a real account has no followers
until real accounts can follow each other.

Its `id` is still the string `"me"`. That is the sentinel local rows use to mean
"mine": list `ownerID`s, ranking contexts and diary entries all carry it, and
promoting it to the account's UUID would be a migration of every locally-stored
row in exchange for nothing a reader can see. The account's real identifier is
`identity.userID`, which is what every server-facing call uses; the string never
leaves the device.

### 17.6 Two stores, one direction

`DeweyStore` is what a reader has read and thought. `SessionStore` is who the
reader is. They meet in `RootView`, which hands the account to the store and
never the reverse — so `DeweyStore` still has no idea accounts exist and is still
constructible in a preview with no session in the environment. Folding identity
into the store would have put a network call behind `store.me`, a property read
on nearly every screen.

Edits reach the server through two closures (`onFavoriteBooksChanged`,
`onFollowsChanged`) called *after* `persist()`. Local is the authority, the write
to disk has already happened, and the server is told afterwards. A reader
toggling a follow on a plane gets the follow.

**Restore only fills gaps.** `applyAccountState` adopts a collection only when
the local one is empty, making it a fresh-install restore and nothing more.
Letting the server win would mean a reader whose taste onboarding failed to
upload loses their four on the next launch, and there is no reconciliation in
this stage that could tell those two cases apart.

### 17.7 The seeded world is no longer the default

`DebugSettings.world` now defaults to `.fresh`, and a persisted file with no
`world` key restores as `.fresh` rather than `.seeded`. An ordinary launch of an
ordinary build no longer hands a stranger sixty-one followers, fourteen ranked
books and somebody else's diary. The seeded corpus is one tap away in the
prototype controls and is still what the fixtures draw; it just stopped being
what happens by default.

### 17.8 Found by building

**17.8.1 The Release build caught what Debug could not.** `replayTasteOnboarding`
and `forgetLocalAccount` are `#if DEBUG` on `SessionStore`, but `DebugMenuView`
compiles into release builds. The debug-only call sites had to be wrapped too.
Worth generalising: this project's debug scaffolding ships, so `#if DEBUG` on a
method is only half a decision.

**17.8.2 `PrimaryButtonStyle` draws no disabled state.** The taste steps get away
with it because their label says what is missing ("Pick 3 more"); "Continue"
cannot, so it read as tappable while doing nothing. Dimmed in `FirstRunScaffold`
rather than in the shared style, which every primary button in the app uses.

**17.8.3 A lower-cased diagnostic ate a filename.** The sign-in screen's debug
footer lower-cased `AccountConfig.diagnostic` for grammar and turned "add
SupabaseConfig.plist" into "add supabaseconfig.plist" — the one line that tells
you what file to create, with the filename no longer copyable out of it.

### 17.9 Still open

**17.9.1 No settings screen.** Signing out lives in the prototype controls. It
belongs on the profile, and inventing a settings surface to hold one destructive
control was a product decision this task had no business making.

**17.9.2 Avatar, bio and email are not collected.** `ReaderProfile.texture` still
shows the seed's placeholder line for a real account. Deliberate: the four books
make a profile legible, and a first run that asks for a photo before showing what
the app is for is asking for work in exchange for nothing.

**17.9.3 There is no account deletion.** `on delete cascade` is in place
throughout, so the server side is a single `delete from auth.users`, but nothing
in the app calls it.

**17.9.4 An unconfigured debug build uses a local account store.** It exists so
the flow can be walked before anyone has a Supabase project, it is never
constructed when configuration is present, and a release build cannot compile it.
It is not a fallback for the real one failing.

---

## 18. Verifying the account system

§17 built accounts and shipped them with three caveats: the Supabase path had
never spoken to Postgres, the SQL had never been executed, and the whole flow had
only ever run against a local stand-in. This pass closes the first two properly,
finds two real defects doing it, and fixes a third that the previous pass created
and did not notice.

### 18.1 The SQL is now executed, not merely written

`supabase/test/` holds a faithful local stand-in for the parts of a Supabase
project the migration depends on — the four API roles, an `auth.users`, and
`auth.uid()` reading `request.jwt.claims` exactly as Supabase defines it — plus
**89 assertions that exercise the schema rather than inspect it**. Reading
`pg_policies` proves a policy exists; it proves nothing about what it denies.
Every check here runs a real statement as a real role with a real JWT claim and
asserts on the SQLSTATE.

Asserting on the *code* rather than on "it failed somehow" is the part that
earns its keep: a policy denial (`42501`), a check violation (`23514`) and a
unique violation (`23505`) are different outcomes, and a test that accepted any
of them would pass while the schema was wrong in an interesting way.

Two of the first run's failures were the harness's fault and worth recording:

**18.1.1 `now()` is transaction-scoped.** The `updated_at` trigger looked dead
because the insert and the update were in one transaction, so `created_at` and
`updated_at` were necessarily equal. The trigger was perfect. The check moved to
its own transaction.

**18.1.2 The fixture did not insert what the app inserts.** `account_setup_complete`
defaults to false and `ProfileService.createProfile` sets it explicitly; the
fixture omitted it. That surfaced something real, though — see 18.3.

### 18.2 The migration depended on ambient project configuration

**The real defect.** `0001_identity.sql` issued no `GRANT`s at all. It worked
anyway on a stock Supabase project, because Supabase pre-configures
`alter default privileges … grant all on tables to anon, authenticated,
service_role`, and the migration silently inherited that. Run into a project
whose defaults differ — a different owning role, a restored database, a team
that tightened them — and every request fails with *permission denied for table
profiles*.

Found by building the stub twice: once with those default privileges and once
without. The second database failed immediately.

GRANT and RLS are independent layers and both are required. The fix states the
privileges explicitly, **revoking first** so the result does not depend on what
was there before: `authenticated` gets exactly the verbs its policies allow,
`anon` gets nothing. Without the revoke, `authenticated` would keep a DELETE
privilege on `profiles` that no policy will ever permit — blocked by RLS instead
of by grant, which also makes the same statement behave differently on two
projects. The harness now asserts the grants exist, and both databases pass all
89 checks.

### 18.3 `account_setup_complete` was a column nobody read

`SessionStore` decided "does this reader need the identity step" by asking
whether a profile row existed, and never looked at the flag. The two agree today
because the row and the flag are written in one statement — but the column
defaulted to false, so a row created by any other path would have routed a
half-made account straight into the app. It is now read, which is what makes the
default correct rather than a trap, and the harness asserts both directions.

### 18.4 Local reading data belonged to the device, not the account

**The serious one, and it was created by §17.** `Persistence` wrote a single
file at `Documents/dewey-prototype-v4.json` — no account in the path, no account
inside it. Signing out left it there; `DeweyStore.init()` loaded it
unconditionally. **A second reader signing into the same phone inherited the
first one's diary, library, ratings, rankings, lists and follows.**

Confirmed on disk before it was fixed, not merely reasoned about: the file
carried three diary entries, four library rows, a follow set and a chosen four,
and contained no account identifier of any kind.

The fix has three parts, and all three are needed:

* **The file is scoped to the account.** `Documents/accounts/<uuid>/state-v5.json`.
  A directory rather than a suffix so deleting an account's data is one
  `removeItem`. `v5` because the *meaning* changed — the filename rule in
  `Persistence` tracks meaning, not shape.
* **Memory is cleared on sign-out.** Without this, User B signing in without an
  app restart gets User A's diary straight out of RAM with no file involved.
* **The store starts empty.** Constructing `DeweyStore` no longer implies a
  reader; `activate(_:)` and `deactivate()` are the only ways in and out.

The pre-account `v4` file is **never read and never deleted**. Adopting it into
the first account to sign in would hand somebody a stranger's reading history;
deleting it would destroy a real one. It is reported in the debug menu so its
existence is stated rather than discovered.

A new account always begins `.fresh`, never `DebugSettings.world` — a first
sign-in must not be able to land in the seeded corpus because a switch was left
flipped, which is §17.7's fix coming back through a side door.

Verified by hand, A → B → A: B saw zero of A's three diary entries, four library
rows, two Favorite Books or one follow; both accounts' files existed separately
on disk; and signing back into A restored all of it exactly.

### 18.5 The stand-in no longer activates by accident

§17's local account system engaged silently whenever configuration was missing,
in any debug build. That is the most dangerous shape available: a developer
running what looks like the real thing, watching handles reserve and profiles
save, concluding something about a server they were never connected to.

Missing configuration is now a **state the app shows you** — a developer
configuration screen naming the file to create — and local mode is an explicit,
persisted choice, announced by a bordered banner on the sign-in screen and by a
`Backend` row in the debug menu. A configured build cannot enter it; the toggle
is not offered. A release build cannot compile it.

The stand-in also grew a second account, because proving that one reader's diary
cannot reach another reader's session needs two readers.

**18.5.1 Sign in with Apple is deliberately not drawn in local mode.** The
stand-in ignores the credential entirely, so offering the real button would imply
the resulting account had something to do with Apple.

**18.5.2 The prototype controls had to become reachable from the first-run
flow.** They live on the Edition and Library toolbars, which sit behind the
cover — so while signed out there was no way to switch test account or leave
local mode, making the one state where those controls matter most the one state
they could not be opened from.

### 18.6 What this pass did not verify

Stated plainly because the point of the pass was to stop over-claiming.

Nothing here has run against a real Supabase project, and Sign in with Apple has
not been exercised on a physical device. Both need credentials and hardware this
session did not have. The local Postgres run is a strong proxy for the schema and
the policies — it is the same SQL, the same policy expressions and the same
`auth.uid()` — and it is not the same thing as the real project. The Apple path
is unexercised beyond the entitlement being live and the system sheet appearing.

---

## 20. Adopting the pre-account file

§18 scoped local reading data to the account and left `dewey-prototype-v4.json`
orphaned on disk — never read, never deleted, reported in the prototype controls
as a fact and nothing more. That was the right call for the leak it was avoiding
and a dead end for the reader it stranded: their actual prototype library, one
`mv` from being visible, with no way to ask for it.

The reason it was a dead end was real. Adopting the file *automatically* would
hand a stranger's reading history to whoever signed in first. But that argues for
a decision, not a refusal.

### 20.1 The four properties

Everything about the design follows from making a destructive, once-only
operation safe to offer:

* **Nothing is deleted, in either direction.** The account's current record is
  *moved aside* to `state-v5.replaced.json` before it is replaced; the source is
  *renamed* to `dewey-prototype-v4.adopted.json` rather than removed. Two files
  survive an adoption that "replaces" everything.
* **One-time means the offer stops being made**, and the rename is what achieves
  it: `legacyFileExists` no longer finds the file, so the section removes itself.
  Deleting would achieve the same thing and throw away a real reading history on
  the strength of one tap.
* **It is a whole-snapshot replacement, not a merge.** There is no identity to
  merge diary entries on — two logs of the same book on the same day are a
  legitimate pair, not a duplicate — and a merge that guessed would produce a
  record that is not a record of anything. Replacing is the only honest
  operation; the backup is what makes it safe to offer.
* **The decision is informed.** The section states what is in the file and, more
  importantly, which world it was written in. A `.seeded` file carries the demo
  corpus, and adopting it puts a populated diary and a ranked library onto a real
  account. That may be exactly what the reader wants — it is the state their
  phone was in — but it is theirs to decide, and it cannot be unless the screen
  says so.

Because the backup makes it non-destructive, adoption does **not** need to be
blocked when the account already holds a record. Blocking was the first design,
and it fails the likeliest reader: somebody who finishes onboarding, *then*
notices their old library is missing, and under that rule could never get it back.

### 20.2 Found by testing

**20.2.1 The confirmation alert was attached to the view that removes itself.**
`.alert` sat on `preAccountSection`, which disappears the instant adoption
succeeds — so the modifier left the hierarchy in the same update that set the
flag, and the one confirmation a destructive once-only action owes the reader
never appeared. The disk said it had worked perfectly; the screen said nothing.
Moved to the enclosing `List`.

**20.2.2 It was written at the bottom of the menu and belonged at the top.**
By subject it sits with the other account rows. By use it is a one-time recovery
offer for somebody who has just found their library missing, and it was below
twelve sections of haptic presets and card fixtures — several screens of
scrolling, on a sheet long enough that the drag keeps being read as a dismiss.
It costs the top of the menu nothing, because it removes itself.

**20.2.3 "1 Favorite Books", twice.** The term is a fixed plural naming the four
on a profile, so it cannot be singularised and cannot be lower-cased without
saying something the app means differently. Counted against the cap instead —
"1 of 4 Favorite Books" — matching how the State section already renders it. The
second instance was a `.lowercased()` one layer up, in the confirmation sentence.

### 20.3 Verified

Executed end-to-end on a simulator, against a real file written by the app's own
writer rather than a hand-made fixture, and checked on disk:

| | |
|---|---|
| Account after adopting | exactly the source file's contents |
| `state-v5.replaced.json` | the account's prior record, intact |
| `dewey-prototype-v4.adopted.json` | the source, intact |
| `dewey-prototype-v4.json` | gone — the section removes itself |

The seeded-world warning, the counts, the confirmation and the result alert were
all read off the screen. What is **not** verified is adoption of a file written by
an actually older build: the fixture was a current-schema file, so the
`migrated(from:)` path for the pre-§19 five-ranking shape is exercised by the code
but was not observed converting a real one.
