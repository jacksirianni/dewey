# Dewey — The Tuesday Problem & Prototype Reduction Memo

**Date:** August 4, 2026
**Status:** Decision memo. Supersedes the prototype specification in scope and sequencing.
**Governing document:** `2026-08-04-dewey-product-strategy-v2.md` (unchanged; this memo does not amend it)

---

## Preamble: what this memo concludes

Two conclusions, stated up front so the reasoning can be checked against them.

**One.** The Tuesday problem is not a frequency problem. It is a **trigger** problem, and Dewey has been designing for the wrong occasion. The occasion that recurs is not *finishing* a book (~1.7/month) — it is **choosing the next one** (~5–6/month) and **the middle of the current one** (2–5/month). Dewey has built its entire event model around the rarest moment in reading and then been surprised that the app is empty.

**Two.** The 56-day prototype should not be built. Not reduced — **not built, yet**. Every question it was designed to answer can be answered with paper, email, and a spreadsheet in about six weeks for roughly a tenth of the effort, and the native build introduces a confound (design polish) that the cheaper instruments do not have. The founder's instinct that ~350 hand-tagged titles and four tuned libraries would validate *our curation* rather than *the product model* is correct, and it is worse than suspected: the hand-tuning is not a side effect of the design, it **is** the design.

A third conclusion follows from the second and is the most useful sentence in this document:

> **The four "readers" should not be invented. They should be real people with real, already-published book lists.** This eliminates the authoring burden, the caricature risk, and the founder's-taste confound simultaneously — and it makes the thing under test (can you read a stranger's taste?) literally true rather than simulated.

---

## 1. The Tuesday problem, defined precisely

### 1.1 Five things that get conflated

| # | Failure mode | Description | Real examples | Is this Dewey? |
|---|---|---|---|---|
| **A** | **Infrequent but deeply valued** | Low usage, high value, *reliable external trigger*. The world creates the occasion; the app just has to be there. | Flighty (you fly), Citymapper (you travel), TurboTax (April), Delta | **Aspiration.** Not currently true. |
| **B** | **Forgotten** | No reliable trigger exists. Nothing in the user's life reminds them the app is there. Death by absence, not by rejection. | Most journaling apps, Litsy, Riffle, most "beautiful" v1s | **This is the actual risk.** |
| **C** | **Rare-milestone-only** | Genuinely useful, but only at lifecycle events too rare to support a consumer business without enormous ARPU. | Will-writing, moving apps, wedding planners | Partially — if we keep centering *finishing*. |
| **D** | **Structurally empty social surface** | The network arithmetic cannot produce enough content for the surface that was designed. | Any small-graph social product with a daily feed | **Yes, at daily cadence. No, at weekly.** |
| **E** | **Artificially triggered** | The product manufactures occasions it hasn't earned. Works, corrodes trust, off-wedge. | Streaks, challenge counters, "your friend is 3 days ahead" | **Refused. Correctly.** |

**Dewey's problem is B compounded by D.** It is not C — books are not a rare-milestone medium; reading is continuous. It is not A yet, because A requires a trigger and we haven't identified one.

The distinction matters because the remedies are opposite. If the problem were **D** (empty surface), the fix is more users or a slower cadence. If it's **B** (forgotten), more users doesn't help at all — a forgotten app with a rich network is still forgotten. **Both are true for us, and B is the one that kills.**

### 1.2 The question, restated correctly

> *What recurring value can Dewey provide during the long periods when the user has not started, finished, or publicly reflected on a book?*

The framing embeds an error worth naming. It assumes those three events are the valuable ones and everything between is a gap to be filled. **The arithmetic says the opposite.** For the wedge reader (20 books/year):

| Occasion | Frequency/month | Currently served by Dewey? |
|---|---|---|
| **"What should I read next?"** | **5–6** | Barely — and only at the moment of finishing |
| **Mid-book: something shifted** | **2–5** | No |
| Book added to library | 4.2 | Yes (the add) |
| Book finished | 1.7 | Yes, heavily |
| Book started | 1.7 | Yes |
| Book abandoned | 0.25 | Partially |

The two most frequent occasions in a reader's month are the two Dewey does not serve. **That is the Tuesday problem in one table.** It is not that reading has no cadence — it's that we built for the milestone and ignored the interval.

Note especially: *"what should I read next"* fires **3× more often than finishing**. People wonder about their next book constantly — browsing a bookshop, hearing a podcast, seeing a cover, finishing something disappointing, being between books, packing for a trip. This is a real, high-frequency, wedge-native, non-manufactured occasion, and it is precisely the occasion Dewey exists to serve. We have been treating it as an output of finishing rather than as the primary event.

### 1.3 The cadence Dewey actually needs

**Weekly, with tolerance for a 2–3 week silence.** Justification from three directions:

**Content supply.** 30 follows × 20 books/year ≈ 600 finish-events/year across the graph ≈ **11.5/week**. Split daily that's 1.6 items — a dead surface, empty 63% of days. Weekly it's ~11 items — a real edition. *The arithmetic chooses weekly for us.* Any daily surface in Dewey is a decision to be empty most days.

**Business model.** A personal-value subscription (£3–5/month) needs **attachment**, not frequency. Day One, Readwise, and Strava's paid tier all sustain on weekly-or-less usage with high switching cost. What must be true is that leaving costs something — accumulated library, provenance chains, reflections. Frequency is a means to accrual, not the goal.

**Honesty.** A product that demands daily use from a medium with a 1–4 week cycle must manufacture the demand. That is anti-goal E.

**But the tolerance clause is where the danger lives.** A user who does not open Dewey for three weeks is fine. A user who does not *think of* Dewey for three weeks is gone. The metric that matters is not opens-per-week; it is **whether a 14-day silence is followed by a return** (§5.4).

---

## 2. Twelve wedge-native return reasons

Excluded by construction: streaks, quotas, challenges, generic push, infinite feeds, vanity metrics, follower growth, unrelated messaging, engagement bait, manufactured urgency.

Columns: **Need** — what it serves. **Cadence** — times/month for the wedge reader. **Others?** — requires other people. **Density** — creates or consumes social density. **Quiet?** — valuable to a user who shares nothing. **Risk** — administrative / performative / manipulative. **Where** — prototype, later, or nowhere.

| # | Reason to return | Need | Cadence | Others? | Density | Quiet? | Risk | Where |
|---|---|---|---|:--:|---|:--:|---|---|
| **1** | **The next-book question** — "I need something to read" | Decision support at the point of choice | **5–6** | Better with | Consumes | **Yes** — own shelf works | Low | **Prototype** |
| **2** | **Someone acted on your recommendation** | Recognition; being useful to someone | 0.5–3, grows with graph | Yes | **Creates, strongly** | No | Low | **Prototype (as concept)** |
| **3** | **Mid-book turn** — the book changed on you | Preserving a feeling before it fades | 2–5 | No | Creates if shared | **Yes** | **Medium** — becomes progress logging | Later |
| **4** | **An unresolved recommendation waiting** | Social obligation, gently | As received | Yes | Consumes then creates | No | **Medium** — inbox guilt | Prototype |
| **5** | **A trusted reader *started* something** | Early signal, before verdict | **3.4** (2× finish rate) | Yes | Creates | No | Low | Later |
| **6** | **Contextual resurfacing** — the book you saved from X, surfaced when you finish X's other book | Memory made useful | 1–2 | No | Consumes | **Yes** | Medium — nostalgia spam if time-triggered | Later |
| **7** | **A trusted reader abandoned something** | Negative signal, rare and valuable | 0.25/person | Yes | Creates | No | Medium — negativity surface | Later |
| **8** | **Checking on a person** — pull, not push | Curiosity about a specific mind | User-initiated, 1–4 | Yes | Consumes | No | **Low** — it's pull | **Prototype** |
| **9** | **Closing a loop you opened** — "did his reason hold up?" | Completion, intimacy | 0.3–1 | Yes | Creates, high quality | No | Medium — social friction | Later |
| **10** | **The weekly edition** | A designated moment to catch up | **4.3 by construction** | Yes | Consumes | Partially | Low | Later |
| **11** | **Returning to your own unfinished thought** | Continuity of interior life | Irregular, 0.5–2 | No | None | **Yes** | **High** — homework | Later |
| **12** | **Your library as an object** — browsing what you've read | Self-recognition; identity | 1–3 | No | None | **Yes** | Low | **Prototype** |

Two additional candidates, rejected:

- **Taste drift noticing** ("you've been reading differently this year") — cadence quarterly at best, and it is a statistics dashboard wearing a nicer coat. The line between "a meaningful personal pattern" and "a stats page" is real but thin, and we cannot walk it in v1. **Nowhere, for now.**
- **Life-context matching** ("you're travelling to Japan — here's what you saved") — requires external data, high creepiness, low frequency. **Nowhere.**

### 2.1 What the table shows

Three findings fall out that were not visible before doing it.

**The highest-frequency reason (#1, the next-book question) needs no new mechanic and no other people.** It is served by a good library, a good save list with provenance, and a way to decide between them. Dewey can serve this on day one, for a user with zero follows. This is the single most under-exploited asset in the strategy.

**The most emotionally potent reason (#2, someone acted on your recommendation) is the reciprocity engine without a reciprocity mechanic.** It creates social density, requires no posting, and produces the only notification in books that is unambiguously a gift rather than a demand. It is also *entirely absent from every competitor.* Goodreads cannot tell you that someone read a book because of you. Neither can Letterboxd.

**Everything valuable at high frequency is a pull, and everything valuable at low frequency is a push.** That is the correct shape and it should be the design rule: Dewey pushes rarely and only with gifts (#2, #4); it rewards pulling often (#1, #8, #12).

---

## 3. Pressure-testing the six proposed mechanics

### A. The evolving book relationship — **REAL, with one hard constraint**

Is it authentic value or progress logging in disguise? The discriminating test: **does the artifact still have value in six months?** "45% complete" does not. "This is where it turned for me" does. Position decays to nothing; meaning accrues.

So it is authentic — *if and only if* three constraints hold:

1. **Never asked for.** No prompt, no nudge, no "you haven't logged in a while." It is a thing available when wanted, invisible when not.
2. **No position anywhere.** No percentage, no page, no bar, no implied completion. The moment a meter appears, this becomes progress logging with better copy.
3. **The vocabulary is about meaning, not milestone.** "Something changed my mind." "I found its center." "I'm losing interest." "This made me think of someone." These are *judgments*, and a judgment is a taste artifact.

Frequency check: a wedge reader has ~1 book in progress; turns fire 1–3 per book ≈ **2–5/month**. That is genuinely more than finishing. **Verdict: real, and the second-strongest answer to Tuesday.** But it is a *later* mechanic — it requires no network and can be added any time, so it should not consume first-test budget.

The one to watch: *"this made me think of someone"* is not a mid-book turn at all. It is a direct recommendation with a running start, captured at the moment of highest emotional charge. That is a better trigger for the recommendation flow than any share button, and it costs nothing.

### B. Resurfacing with purpose — **REAL, but worthless in year one**

The rule that separates useful resurfacing from nostalgia spam:

> **Resurfacing must be triggered by a change in the user's context, never by the passage of time.**

Time-triggered is "On This Day" — it is spam with a memory theme, and its hit rate is governed by luck. Context-triggered is: *you just finished a Rachel Cusk; here is the note you left in her other book.* Or: *you just added a book about grief; here is the one Priya recommended eight months ago for the same reason.* The trigger is the user's own action, which means the moment is already relevant.

Three additional constraints: it must be **in-app, not a notification** (a push about your own old note is an intrusion); it must be **dismissible without cost**; and it must **never be the primary content of a screen**, because its supply is unpredictable.

**Verdict: real, high value, and structurally unavailable early.** Resurfacing requires accumulated data. A user in month two has nothing to resurface. This is a month-twelve feature that looks like a month-one feature, and mistaking the two would be expensive.

### C. Social closure — **REAL and the strongest available, with one asymmetry rule**

Does closing loops create intimacy without obligation? Yes — **but only in one direction**, and the drafts had it backwards.

| Direction | Message | Effect |
|---|---|---|
| **To the giver** | "Someone started the book you recommended." | **Gift.** Recognition, no action required, no debt. |
| To the receiver | "You started Elena's book — let her know?" | **Debt.** Converts a private act into an owed reply. |
| To the giver | "They finished it. They rated it 5." | **Gift**, and the strongest one available. |
| Mutual | "You both finished it — did his reason hold up?" | **Ambiguous.** Lovely between close friends, an obligation between near-strangers. Gate on relationship strength or don't ship it. |

> **The rule: closure flows toward the person who gave, never toward the person who received.** Giving is unrewarded everywhere else on the internet; receiving is already over-instrumented.

This is Dewey's single best notification, and it has a property nothing else in the product has: **it makes recommending feel good enough to do again.** That is a supply mechanic disguised as a retention mechanic. It directly feeds the provenance chain that s4 identified as the signature experience.

**Verdict: real, strongest of the six, and the core of the push strategy.** Requires a graph, so it cannot be the first thing tested — but it should be the thing the first test is *for*.

### D. Taste exploration — **INSUFFICIENT ALONE. Necessary, not sufficient.**

Is browsing a person, list, or disagreement strong enough without new activity? Honestly: **no**, and this needs saying plainly because it is the mechanic the strategy leans on hardest.

Exploration is a **pull with no trigger**. Nothing in a reader's Tuesday makes them think *"I wonder what Priya's shelf looks like today."* It works beautifully for the first two or three sessions — the novelty of a legible stranger is real — and then decays, because a shelf that has not changed offers nothing new and a shelf that changes weekly offers one book.

It is a **destination, not an occasion**. Destinations are essential — they are where people go once something else has brought them — but a product made only of destinations is a product nobody arrives at.

**Verdict: keep, but stop asking it to carry Tuesday.** It must be paired with a trigger (#1 next-book, or #2 closure).

### E. The finite reading desk — **REAL only if one slot is externally fed**

Useful place, or rearranged stale information? The discriminating test:

> **Does anything on the desk change without the user having acted?**

If every slot is fed by the user's own behaviour — your current book, your saved thought, your saved possibility — then the desk is a **drawer**. It contains exactly what you put in it, arranged more attractively. Opening it tells you nothing you didn't know, and after three visits you stop.

If **at least one slot is fed by other people** — an unresolved recommendation, a signal from someone you trust — then the desk has a reason to be checked, and the user's own material gets re-encountered as a side effect. That is the whole mechanism: **the social slot buys attention that the private slots then reward.**

Proposed composition, and the count matters — five is one too many:

| Slot | Fed by | Purpose |
|---|---|---|
| The current book | You | Orientation; the only "in progress" surface |
| **One unresolved recommendation** | **Someone else** | **The reason to check** |
| One saved possibility, contextually chosen | Your past self | The next-book question, answered |
| **One meaningful signal** | **Someone else** | Ambient density |

The private thought slot is cut — it is the most likely to be empty, and an empty slot on a four-slot desk is 25% dead. It belongs inside the book, not on the desk.

**Verdict: real, if and only if two of four slots are externally fed.** And on a quiet week, both external slots may be empty — so the desk must be designed to look complete with two items, not degraded. That is a design constraint, not a caveat.

### F. Periodic (weekly) editions — **STRONG. This should be the spine.**

Is weekly more honest for books, and sufficient for retention? **Yes, and the arithmetic is unambiguous:**

| Cadence | Items per edition (30 follows) | Feels like |
|---|---|---|
| Daily | **1.6** — empty **63%** of days | A broken app |
| **Weekly** | **~11.5** | **A real edition** |
| Monthly | ~50 | A backlog; too much to read, too rare to habituate |

Weekly is not a compromise. It is the cadence the medium actually produces, and it has three further advantages:

1. **It creates the trigger that exploration lacks.** A weekly edition is an *appointment*. Appointments are how infrequent products avoid being forgotten — the thing failure mode B needs.
2. **It makes silence legible.** A quiet week produces a short edition, which reads as honest. A quiet day produces an empty screen, which reads as broken.
3. **It permits real editing.** Eleven items can be consolidated, ordered, and given shape. 1.6 items cannot.

The risk is that a weekly edition is a scheduled push, and scheduled pushes are how manufactured urgency starts. The guard: **the edition is always there when you arrive; the notification about it is optional, off by default, and never contains a count.**

**Verdict: strongest structural answer. Weekly is the honest rhythm for books and should replace "the home edition" as a daily concept everywhere in the strategy.**

---

## 4. Are the anti-goals overconstrained?

Classification: **Fundamental** (never reverse) · **Launch constraint** (right for now, revisit) · **Hypothesis** (we don't know; test it) · **Overreaction** (we banned a healthy mechanic because an unhealthy version exists).

| Prohibition | Class | Reasoning |
|---|---|---|
| **No challenges** (annual counts, "52 books") | **Fundamental** | Directly optimizes volume, which is the anti-wedge. Goodreads' worst mechanic. Never. |
| **No conventional infinite feed** | **Fundamental** | Structurally incompatible with the content arithmetic and with the register. Never. |
| **No public counts** (followers, likes, view counts) | **Fundamental** | Converts taste into status. This is the failure mode that kills the wedge. Never. |
| **No frequent public progress activity** | **Fundamental** *(public)* / **Launch constraint** *(private)* | Public page-updates are the noise problem. Private progress is just data and can return quietly. |
| **No goals** | **Launch constraint** | A *quota* is productivity theater. A *private intention* — "I want to read more translated fiction this year" — is a taste statement, and arguably the most wedge-native thing on this list. Reopen later, framed as intention, never as a counter. |
| **No statistics center** | **Launch constraint** | A dashboard is off-wedge. A *pattern noticed* is not. The distinction is whether it produces a number to improve or an observation to recognize. Reopen carefully; the failure mode is one screen away. |
| **No clubs** | **Launch constraint — and possibly an overreaction** | Fable-style club infrastructure is off-wedge. But **synchronized reading is the single strongest known density mechanic for books** — two people reading the same thing at the same time generates continuous conversation from a slow medium. Banning the mechanic because Fable's implementation is bad is the definition of the error this section exists to catch. Reopen as *two people, one book*, not as clubs. |
| **No reciprocity mechanics** | **Hypothesis** | Reciprocity ≠ status competition. "Someone read your recommendation" (§3C) is reciprocity, it is the best thing in this memo, and it is currently banned by our own rule. The ban is wrong as written. Reopen: the prohibition should be on *obligation*, not on *reciprocity*. |
| **No reactions** | **OVERREACTION** | See below. |
| **No replies** | **OVERREACTION** | See below. |

### 4.1 The contradiction: we banned the quiet user's only voice

The strategy makes two promises that cannot both hold:

> "A quiet user must receive a complete product… and still contribute indirectly to discovery." *(v2 §7)*
> "Reactions, replies, counts: not in v1." *(v2 §12 defer list)*

**A reaction is the cheapest possible expression, and it is the only one a quiet user will make.** Someone who will never write a review will absolutely tap once to say *"yes, this one."* By banning reactions we removed the entire participation surface for the exact user we designed the product around, and left them contributing only *passively* — through library state they didn't choose to share.

That is worse than a missing feature. It means the quiet user's only contribution is the one they didn't consent to, while the contribution they *would* consent to is forbidden. That is backwards, and it makes the visibility model harder to defend, not easier.

Similarly: **a thoughtful reply is the substance of book conversation.** "Reply" is not a synonym for "comment section." The failure mode we fear — pile-ons, performance, hot takes — comes from *public replies attached to a person's profile in front of an audience*. A reply attached to a book, visible to two people, is a conversation.

**Recommendation:**

| Reopen | As what | Guard |
|---|---|---|
| **Reactions** | A small, fixed, non-numeric set attached to a reflection or a book. **Never counted or displayed as a total.** | If it produces a number, it's a like. |
| **Replies** | Threaded to a **book**, not a profile. Not aggregated into a feed. No public thread view. | If a stranger can find a pile-on, we built the wrong thing. |
| **Reciprocity** | Recast the prohibition: ban **obligation**, permit **reciprocity**. §3C's asymmetry rule is the implementation. | Closure flows to the giver only. |
| **Synchronized reading** | Two people, one book. Not clubs, not schedules, not infrastructure. | If it needs a moderator, it's a club. |

**Remain absolute:** challenges, infinite feed, public counts, public progress streams, streaks, manufactured urgency, paid placement in discovery.

---

## 5. Retention vs. frequency

### 5.1 Expected cadence for the primary user

**4–8 sessions per month**, clustered — not distributed. Real reader months look like: two sessions in the days around finishing and choosing, one or two mid-book, one or two triggered by someone else, and a two-week silence somewhere. **The silence is normal and must not be treated as churn.**

### 5.2 Minimum cadence for the social graph to function

This is the number nobody has computed, and it is a hard product requirement rather than a nice-to-have:

- Each active user must emit **≥2 visible signals/month** (realistic: 4.2 adds + 1.7 finishes = ~6, so achievable — *if adds are visible*).
- A user must follow **≥12 people** for a weekly edition to be reliably non-empty. At 30 follows a weekly edition holds ~11 items; at 12 it holds ~4.6; at 8 it holds ~3.1 and is empty some weeks; below 5 the surface is dead.

> **Twelve follows is therefore an activation requirement, not an onboarding suggestion.** A user who finishes onboarding with 4 follows has been handed a broken product, and no amount of design fixes it. This single number should govern the onboarding design.

### 5.3 Business-model cadence

Attachment, not frequency. Comparable products sustain paid tiers on weekly-or-less usage: Day One, Readwise (~$8–10/mo), Strava's paid tier. What they share is **accrual** — the product holds something of yours that grows and cannot be exported into an equivalent elsewhere.

For Dewey the accruing asset is: your library with provenance, your reflections, your lists, and your taste graph. **Frequency matters only insofar as it produces accrual.** A user who opens Dewey four times a month and adds four books with origins is worth more than one who opens it daily and adds nothing.

### 5.4 Frequency ≠ attachment

| | Frequency | Attachment |
|---|---|---|
| Measures | How often they come | What leaving costs |
| Improved by | Triggers, notifications, habit | Accrual, social ties, provenance |
| Fails as | Vanity metric; optimizable by manipulation | Slow to move; lags months |
| Dewey's stance | A means | **The goal** |

### 5.5 Metrics that do not reintroduce time-spent optimization

| Metric | Definition | Why it resists gaming |
|---|---|---|
| **Return-after-silence** | % of users who return after a **14+ day gap** | The direct measure of failure mode B (forgotten). Cannot be improved by making sessions longer. **This is the Tuesday metric.** |
| **Weeks with a meaningful action** | Weeks (not days) containing an add, finish, reflection, recommendation, or response | Weekly granularity refuses to reward daily poking |
| **Provenance ratio** | % of books added that carry a human origin | Measures the thesis directly; unaffected by session count |
| **Started-from-Dewey rate** | Books *started* (not saved) that came from another person | Saves lie; starts don't |
| **Library depth at month 6** | Accrued objects per retained user | The attachment proxy |
| **Give-rate** | % of monthly actives who send ≥1 direct recommendation | Supply health; the leading indicator for §3C |

**Explicitly not measured:** sessions/day, time in app, feed depth, notification open rate, books completed per user.

---

## 6. Prototype reduction — three experiments

### 6.0 What the 56-day build was actually buying

Honest accounting of what the native prototype uniquely provides:

| Capability | Requires native? |
|---|---|
| Show a stranger's library and ask if it's legible | **No** — static images work |
| Personalize the overlap to this participant's real books | **No** — a person can compute this before the session |
| Present P/N/G conditions with matched framing | **No** — cards |
| Force a displacement choice | **No** — cards + a real slot on paper |
| Measure articulation quality | **No** — it's a transcript |
| Test how the *interface* feels | **Yes** |
| Test whether provenance changes behaviour over weeks | **No** — email does it better |

**Only one row requires Swift, and it is the row that does not gate the go/no-go decision.** Whether Dewey feels good is a design question we will answer eventually and can afford to answer late. Whether the model works is the question that decides if there is anything to design.

That is the reduction argument in full, and it is decisive.

---

### Experiment 1 — The Card Study *(paper/Figma, no code)*

| | |
|---|---|
| **Hypothesis** | H-P, both clauses. Can a stranger's taste be read from library + overlap alone (a), and does attribution beat personalization and generic framing when a real choice is forced (b)? |
| **Instrument** | Per participant: four printed reader profiles (library grid + ratings + computed overlap, no prose, no bio) and three book cards in conditions P / N / G. One "Reading Next" card pre-filled with their own stated next book. |
| **Participant burden** | One 20-min intake call + one 45-min session. |
| **Founder prep** | **~25 min/participant** (compute overlap, print, verify unread). Down from 100. |
| **Build effort** | **2–3 days total** — a card template, an overlap spreadsheet, a printer. |
| **Corpus** | **Zero authored titles.** The participant supplies their own; the readers supply theirs (see §7). |
| **Real vs simulated** | Participant's history: real. Readers: **real people, real published lists.** Overlap: real, computed. Product context: absent. |
| **Evidence quality** | **High on legibility and articulation. Medium on choice** — no app context, and the displacement is symbolic. |
| **Confounds** | No product context, so "which would you read" is closer to hypothetical than the app version. Moderator presence. Paper is not a phone. |
| **Enables** | Kill/continue on the legibility half of H-P — the stop condition. If people cannot read a shelf on paper, they will not read it in SwiftUI. |
| **Elapsed** | **~2 weeks** including recruiting. |

### Experiment 2 — The Provenance Study *(concierge field test, email)*

Substantively as designed in the teardown (`s3 §3.4`), unchanged and unimproved-upon.

| | |
|---|---|
| **Hypothesis** | H2 — does attributed provenance change what people actually **start**, over four weeks, versus anonymous-aggregate and editorial framings? |
| **Instrument** | Airtable + a weekly static page. Three arms **within** each digest; same book pool; only the *true fact surfaced* varies. Pre-registered selection pseudocode. |
| **Participant burden** | 20-min intake + 60 seconds/week × 4. |
| **Founder prep** | ~50 hours total across the study. |
| **Build effort** | **Zero.** |
| **Corpus** | Participants' own libraries. |
| **Real vs simulated** | Everything real except that a human assembles the digests. |
| **Evidence quality** | **Highest available.** Verified starts, evidence-backed, within-subject, hostile to its own hypothesis. |
| **Confounds** | Volunteer bias, Hawthorne — both inflate all arms and cancel in the ratio. Ideal density (stated as a limitation). |
| **Enables** | The existential go/no-go. |
| **Elapsed** | **5 weeks.** Cost ~$2,250. |

### Experiment 3 — The Narrow Native Prototype *(only if 1 and 2 pass)*

| | |
|---|---|
| **Hypothesis** | Not H-P. **S1** (is a taste identity intrinsically valuable — does anyone edit it unprompted?) and the *felt* quality of a legible profile. |
| **Instrument** | Two screens: the identity surface (confirm-and-correct, live portrait) and one reader profile with computed overlap. Nothing else. |
| **Build effort** | **8–12 days.** No catalog (participants' books only, typed in), no search, no home, no recommendation flow, no conditions. |
| **Corpus** | **~60 titles**, 4 fields each. |
| **Evidence quality** | Medium. Design evidence, not model evidence. |
| **Enables** | Whether to invest in the identity surface as a destination. **Does not gate the product decision.** |
| **Elapsed** | 3–4 weeks. |

### 6.1 The recommended sequence

> **Run Experiment 1 and Experiment 2 concurrently, starting now. Do not build Experiment 3 until both report.**

| Week | Activity |
|---|---|
| 1 | Recruit for both. Build the card templates and the Airtable. Intake calls begin. |
| 2 | Card sessions (10–12). Digest week 1 sends. |
| 3 | Card sessions complete (20 total). Digest week 2. |
| 4–6 | Digests 3–4. Card study analysis. |
| 7 | Provenance exit interviews. Combined readout. **Decision.** |

**Total: ~7 weeks elapsed, ~90 founder hours, ~$2,700, zero lines of Swift.**

Against the previous plan: **18 weeks → 7. ~56 build-days → 3.** And the evidence is *better*, because the confound that worried the founder — validating our curation instead of the model — is removed rather than disclosed in a limitations section.

---

## 7. The authored-data audit

### 7.1 Why 350 titles were specified

Three requirements drove it: **search plausibility** (a participant types a book and finds it), **controlled popularity tiers** (the distinctiveness weighting needs to know what's common), and **cover images** (a grid of covers is the interaction). Nine metadata fields per title × 350 = **~3,150 hand judgments.**

### 7.2 Elimination, option by option

| Option | Verdict | Effect |
|---|---|---|
| **Participant-supplied books** | **Adopt.** The participant's own 20–25 titles come from the intake call. They are the substrate of every overlap computation. | Removes the need for a general catalog entirely in Exp 1 & 2 |
| **Real public lists as the readers** | **Adopt — this is the key move.** See §7.3. | Removes reader authoring; removes the caricature risk; removes the founder's-taste confound |
| **Much smaller balanced corpus** | **Adopt for Exp 3 only.** ~60 titles. | −83% |
| **Live catalog with only experimental dimensions controlled** | **Reject for Exp 1–2** (no app), **adopt for Exp 3** (Open Library lookup, popularity tier hand-set on the ~60 that matter) | Removes metadata authoring |
| **Within-subject recs from books participants already know** | **Adopt.** The three condition books are drawn from the readers' real shelves, filtered against the participant's own history. | Removes candidate-pool authoring |
| **Human-written cards per participant** | **Reject.** This is the concierge-halo confound — it makes the founder's judgment the treatment. | — |
| **Fewer metadata fields** | **Adopt: 4 fields, not 9** — title, author, cover, popularity tier. Translator/publisher/imprint/series existed to support "specificity" coding, but the *participant* supplies that from their own knowledge; we don't need it in the data. | −56% per title |

### 7.3 The move that changes everything

> **Do not invent the four readers. Use four real people with real, already-published book lists.**

Sources that exist in public, with attribution, at zero authoring cost: year-end critics' lists; independent bookseller staff picks (which are signed, personal, and often annotated); published "my favourite books" interviews (*The Guardian*'s books questionnaire, *By the Book* in the NYT, literary podcasts' recurring segments); public Letterboxd-equivalent shelves where the reader has made them public.

What this buys, in order of importance:

1. **The thing under test becomes literally true.** H-P asks whether a *real stranger's* taste is legible. With invented readers we were testing whether *our fiction of a stranger* is legible — a strictly easier and less informative question.
2. **The founder's-taste confound disappears.** Nobody tuned these shelves to land in a band. They are what they are. The realistic-density reader (R4) is no longer a special construction — it is just whichever real person happens to overlap thinly.
3. **Caricature becomes impossible.** Real people's lists are messy, contradictory, and specific in ways invented ones never are. The "at least one book that contradicts their profile" requirement, which we were going to fabricate, is simply present.
4. **Authoring cost goes to approximately zero.** Transcribe a list. That is the whole task.

Constraints: use published lists with attribution and link to the source; do not imply endorsement of or participation in Dewey; use the person's public byline, not a fabricated persona; disclose at debrief. If any participant recognizes the source, record it and exclude that reader's data for them.

### 7.4 The reduced requirement

| | Before | After |
|---|---|---|
| Authored titles | ~350 | **0** for Exp 1–2; **~60** for Exp 3 |
| Fields per title | 9 | **4** |
| Total hand judgments | ~3,150 | **0 / ~240** |
| Reader libraries authored | 4, tuned per participant | **0** — real published lists |
| Prep per participant | ~100 min | **~25 min** |
| Prep total at N=20 | ~40 hours | **~8 hours** |

**Truly required for experimental validity:** the participant's real history (real), the readers' real lists (real), a correctly computed overlap (arithmetic), and matched framing across P/N/G (design). **Everything else was prototype overproduction.**

---

## 8. The preserved experimental design

### 8.1 The commitment instrument

- **One visible slot.** Not five.
- **Pre-filled at intake** with the participant's own stated next book — captured before they see anything from Dewey.
- **A Dewey recommendation must displace it** to be counted.
- **Keeping their own book is the null action**, and is explicitly presented as a normal, expected outcome.
- **No purchase, mailing, reward, or artificial consequence.** The cost is the displacement itself: giving up a book they told us they wanted to read.

**What this proves:** that under matched framing, with a genuine opportunity cost, some participants preferred a book delivered with human attribution over one delivered with the same evidence but no person, and over a generic recommendation. It produces a **forced choice that generates a sentence**, and the sentence is the finding.

**What it does not prove:** that they will read it; that the preference survives a week; that it survives outside a room with a researcher in it; that it would occur at real network density; or anything at all if reported as a percentage. **At N=20 a 14/20 split is inside the range twenty coin flips produce.** The count is reported without a verdict; no threshold on this measure licenses a build decision.

### 8.2 The three conditions

| | **P** | **N** | **G** |
|---|---|---|---|
| Named person + photo | **Yes** | No | No |
| That person's rating | **Yes** | No | No |
| Three named shared books (+ covers) | Yes | **Yes — identical** | No |
| Impersonal framing line | No | No | **Yes** |
| Book quality / popularity tier | Matched | Matched | Matched |
| Visual weight, vertical extent, typography | Matched | Matched | Matched (spacer) |

**Held constant:** the books themselves (drawn from one pool, rotated across conditions between participants), visual treatment, position on screen, and the participant's prior familiarity (all three verified unread).

**What varies:** *which true fact is surfaced.* Every statement in all three conditions is true of the book shown.

**What the results distinguish:**

| Pattern | Conclusion |
|---|---|
| **P > N > G** | **Human attribution has value beyond personalization.** The thesis holds. |
| **P ≈ N > G** | **Personalization works; the person adds nothing.** Dewey is a recommender. The trust graph is decoration. This is the most likely non-null result and the most dangerous one. |
| **P ≈ N ≈ G** | Framing does not move choice at all. Either the instrument is too weak or the mechanism does not exist. |
| **P > N ≈ G** | Attribution works *and* the evidence alone does not — the person is doing all the work. Strongest possible result for the thesis; treat with suspicion and check for a face-preference artifact. |
| **G competitive** | Book quality dominates framing. Curation beats network. A different, smaller company. |

The addition of N is what separates *attribution* from *self-relevance*. Without it, a P-over-G result is fully explained by "the card named three books I love," which requires no person and no graph.

### 8.3 The realistic-density reader

**R4 differs from R1–R3 in exactly one way: nothing was done to it.** No tuning, no swapping, no target band. It is whichever real published list happens to overlap thinly with this participant — the overlap a genuine 50-person network produces, which the arithmetic puts at **3–4 shared books**, not 12.

**If participants read R1–R3 fluently and R4 not at all**, the finding is precise and consequential:

> *Taste is legible at engineered density and illegible at realistic density.*

The correct response is **not** to build. It is to establish what minimum density legibility requires, because that number is the gate on the entire cold-start and onboarding design — and if the answer is "40 shared books," Dewey cannot work at any plausible early scale and the model needs rebuilding around something other than library overlap.

---

## 9. Decision tree

| # | Finding | Continue | Change | Narrow | Reframe | Abandon |
|---|---|---|---|---|---|---|
| 1 | **P > N and P > G** | Build the trust graph and provenance as specified | — | — | — | — |
| 2 | **P ≈ N, both > G** | Keep personalization | **Stop calling the graph a moat.** Attribution becomes UI garnish, not mechanism | Narrow to a taste-driven **recommender** with a social skin | Reframe the pitch: "the recommender that knows your actual taste" | Abandon *social density from signals* |
| 3 | **P ≈ N ≈ G** | — | — | — | — | **Abandon the thesis.** Framing does not move behaviour. Consider the private journal as a paid single-player app |
| 4 | **Engineered readers legible, R4 not** | — | — | **Narrow to a density study.** Establish the minimum overlap for legibility | Reframe: Dewey needs a *dense* niche (one genre, one community) before it needs a broad network | Abandon the general-audience network plan |
| 5 | **Direct recs strong, ambient discovery weak** | Continue on direct recommendation as the core | Change the home surface from ambient to **inbox-shaped** | Narrow v1 to the two-person loop | Reframe Dewey as *the place books travel between people*, not a discovery network | Abandon the ambient/aggregate surface |
| 6 | **Private product valued, social interest weak** | Continue on library + provenance-for-yourself | Change the business model to paid single-player early | Narrow to the annotated want-to-read shelf | **Reframe as a reading journal that gets better with friends** — social as amplifier, not substrate | Abandon the social-first positioning |
| 7 | **Concept liked, but nobody displaces their next book** | — | Change the instrument once (the displacement may be too costly to be realistic) and re-run | Narrow: treat Dewey as a *long-horizon* save tool, measured at 90 days not 7 | Reframe the North Star from *starts* to *eventual starts* | If it repeats with a softer instrument: **abandon** — intent theater confirmed |
| 8 | **Tuesday mechanics raise return but feel burdensome** | — | **Change every push to a pull.** Delete notifications; keep the mechanics as in-app surfaces | Narrow to the two highest-value: next-book, and closure-to-the-giver | Reframe: the appointment is weekly, not situational | — |
| 9 | **Weekly editions work, daily surfaces do not** | Continue — **this is the expected result** | Change every daily surface in the strategy to weekly | — | Reframe the home screen as a desk (always there) plus a weekly edition (an event) | Abandon all daily framing |

**Stop condition (from the card study):** **≤8 of 20 participants produce a specific, falsifiable description of the reader they chose.** Not a weak choice split — a weak split is a design problem and design problems are fixable. This is different: it means a shelf of covers and numbers does not resolve into a person. If that is true, provenance has nothing to attach to and Dewey must be expression-driven or must not be built.

---

## 10. Final recommendation

**The Tuesday problem, defined.** Dewey risks being *forgotten* (failure mode B), not merely infrequent. The cause is that Dewey built its event model around the rarest moment in reading — finishing — and ignored the two most frequent: **choosing the next book (~5–6/month)** and **the middle of the current one (2–5/month)**. The remedy is not more frequency; it is serving the occasions that already recur.

**The most promising wedge-native reason to return.** Two, working together:
- **Pull:** the next-book question. Highest frequency, needs no other people, works on day one, already central to the wedge, and currently unserved.
- **Push:** **"someone started the book you recommended."** The only notification in books that is a gift rather than a demand. It is reciprocity without obligation, it feeds the provenance chain, and no competitor can send it.
- **Spine:** the **weekly** edition. The content arithmetic chooses it: ~11.5 items/week vs 1.6/day.

**Anti-goals that remain absolute.** Challenges and annual counters; the infinite feed; public counts of any kind; public progress streams; streaks; manufactured urgency; paid placement in discovery.

**Constraints to reopen.** **Reactions** and **replies** — we banned the quiet user's only voice, which contradicts our own promise to them; reopen with hard guards (never counted; threaded to a book, not a profile). **Reciprocity** — ban *obligation*, not reciprocity; closure flows to the giver only. **Synchronized reading** — two people, one book; the strongest known density mechanic for a slow medium, banned because Fable's version is bad. **Private intentions** and **noticed patterns** — later, and only if they never produce a number to improve.

**The smallest next experiment.** Run **Experiment 1 (Card Study)** and **Experiment 2 (Provenance Study)** concurrently, starting this week. Do not build the native prototype until both report.

**Effort and elapsed time.** **~7 weeks elapsed. ~90 founder hours. ~$2,700. Zero lines of Swift.** (Previously: 18 weeks, ~56 build-days, ~40 hours of participant prep alone.)

**Minimum authored corpus.** **Zero.** Participants supply their own histories; the four readers are **real people with real, already-published book lists**, used with attribution. If Experiment 3 is later justified: ~60 titles, 4 fields each.

**Exact evidence required before building the native prototype.** All four:
1. **≥12 of 20** card-study participants produce a specific, falsifiable description of the reader they chose (clears the stop condition).
2. **P > N** in the field study by a margin large enough to see without statistics — attribution beats personalization, not just genericness.
3. **R4 (untuned, realistic density) is legible to a meaningful minority** — otherwise the next step is a density study, not a build.
4. **Verified starts, not saves,** move between arms. High saves with flat starts is intent theater and is a fail.

**The condition under which we stop pursuing Dewey.** Any one of:
- Participants cannot articulate a taste judgment from a library alone (the stop condition).
- P ≈ N ≈ G — framing does not move behaviour at all.
- Verified starts are near zero across every arm — passive signal does not move reading, full stop.
- Legibility requires a density (say, 20+ shared books) that no plausible early network can supply, and no niche is dense enough to bootstrap it.

---

## Unresolved — flagged for the founder

1. **Reactions and replies are a genuine strategy amendment, not a clarification.** §4.1 argues we banned the quiet user's only voice. Accepting it means editing the constitution, which you asked to keep frozen until a product decision forces it. This is that decision. Your call whether to amend now or hold it until after the experiments.
2. **Using real people's published lists needs your comfort, not just my reasoning.** It is defensible — public, attributed, linked, disclosed at debrief, no implied endorsement. It is also the kind of thing that reads differently to a journalist than to a researcher. If it makes you uneasy, the fallback is four invented readers at ~2 days of authoring, and we accept the confound.
3. **Whether "someone started your recommendation" survives contact with reality is untested and I have assumed it.** It is the best idea in this memo and it rests on an intuition about giving, not on evidence. It could be added as a fourth arm to the field study for roughly $400.
4. **Synchronized reading may be the actual answer to Tuesday, and this memo did not evaluate it properly.** Two people reading the same book at the same time generates continuous conversation from a slow medium — it is the only mechanic that solves the cadence problem at its root rather than routing around it. It got one paragraph because it was on the banned list. It deserves its own analysis.
5. **The name.** Still unresolved from the strategy doc, still cheap now and expensive later.
