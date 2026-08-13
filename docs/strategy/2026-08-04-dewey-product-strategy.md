# Dewey — Founder-Level Product Strategy

_Date: 2026-08-04 · Status: Founding document · Owner: co-founders_

> The definitive social reading app for people whose reading is part of their identity.
> Not a tracker. Not a spreadsheet. Not Goodreads with a nicer skin.

---

## 1. Positioning

**One line:** Dewey is where readers with taste remember what they read, develop their opinions, and discover their next book through people they trust.

**The wedge (who Dewey is built for at launch):**
People who want their reading life to **express their taste** and **connect them with others whose taste they trust.** They read 10–30 books a year. Volume is not the point — books matter to them *culturally, emotionally, and socially*.

**Who we are deliberately NOT building for first:**

- **The heavy tracker (50+/yr).** Valuable later, but leading here turns Dewey into a prettier StoryGraph — a functional utility competing on stats. That's a features race we don't want.
- **The aspirational reader (motivation-seeker).** Leading here pulls the product toward streaks, reminders, goals, and productivity language — the exact emotional register we're avoiding. We will *welcome* this person (see §8, the "quiet journal" path), but we will not *design for* them. The taste-driven reader is aspirational-adjacent: reading 20 great books and having sharp opinions is itself aspirational, without a single streak.

**Emotional center:** *"These are my books. This is my taste. These are the people who make me want to read."*

---

## 2. The central problem: cadence, reframed

Letterboxd works because of **cadence**. A film is ~2 hours; you log constantly; the stream stays alive. Books take 1–4 weeks. Copy Letterboxd's *interaction model* and the social layer starves before it starts.

My first instinct was: make reading-in-progress the content, so activity happens continuously. **You correctly killed that.** Forcing social output from every reading session is performative, interruptive, and turns readers into content creators — the opposite of Dewey's soul.

**The corrected problem statement:**

> Generate enough *social density* to power trusted-taste discovery — **without asking anyone to post.**

The resolution is to stop conflating two different units:

- The **capture unit** — what an individual does inside Dewey (mostly private, low-effort, ambient).
- The **distribution unit** — what actually feeds other people's discovery (mostly derived, not authored).

Most reading apps fuse these: to help others discover, you must post. Dewey splits them. That split is the whole strategy.

---

## 3. The atomic unit (pressure-tested)

You asked me to compare "reading moments" against at least three alternatives and recommend a model that produces enough activity without making reading feel like content production. Here they are, judged against three tests:

- **Density** — does it produce enough signal to power discovery?
- **Effort** — how much does it demand of the reader?
- **Performativity** — does it make reading feel like a performance?

### Option A — The finished book (Letterboxd-literal)
Log/rate/review only on finish.
- Density: **Low** (a 20-book/yr reader produces <2 signals/month).
- Effort: Low. Performativity: Low.
- **Verdict:** Too sparse. This is the trap. Rejected as the *primary* unit.

### Option B — The progress update (every session)
Each reading session emits an update.
- Density: **High.** Effort: **High** (nagging, administrative).
- Performativity: **High** — this is the "reading as content" failure you flagged.
- **Verdict:** Rejected. Wrong emotional register.

### Option C — The reading moment (your proposal)
A flexible unit: start, save a passage, private thought, lightweight reaction, meaningful progress, pause/abandon, finish/reflect, add-because-inspired, recommend-to-someone.
- Density: **Medium–High.** Effort: **Low** (moments are optional and self-paced). Performativity: **Low** (private by default).
- **Verdict:** Strong. But "moment" alone doesn't answer *how discovery gets its density* if most moments are private. It needs one more distinction to be complete.

### Option D — The library-state / shelf as the unit
The unit isn't an *event* — it's the evolving *state* of your library (what you've added, finished, rated, shelved, listed). Discovery reads the state, not a feed of posts.
- Density: **High and passive** — every quiet action changes shared state.
- Effort: **Near-zero.** Performativity: **Zero** (no posting, no feed).
- **Verdict:** The missing half. Its weakness alone is that pure state is *low-energy* — it doesn't create the delightful, human, "someone reacted / recommended / highlighted" moments that make an app feel alive.

### Recommendation — the synthesis: **Signals & Expressions**

Dewey's atomic unit is the **reading moment (C)**, but every moment resolves into one of two channels — and *the reader never has to think in these terms; the system does.*

**Signals (ambient, mostly private, derived).**
Adding a book, updating progress, finishing, rating, shelving, listing, saving a passage privately, abandoning. These require **no audience and no authoring.** They quietly change your *library state* (D). Discovery is powered *primarily* by the aggregate of signals across people you trust — "3 readers whose taste you follow finished this last month," "this is climbing among people you trust." **This is how we get social density without posts.**

**Expressions (intentional, public, authored).**
A shared passage, a public note or reaction, a written reflection, a list published for others, a direct recommendation to a specific person. These are **opt-in, one deliberate tap**, and they're where the expressive, taste-driven user shines.

**Why this wins:**

- A reader who never writes a word still contributes rich discovery signal *just by reading and shelving.* (Serves the quiet user and the whole graph.)
- A reader who loves to express has a first-class, beautiful surface for it. (Serves the taste-driven core.)
- No one is ever asked to perform. Density comes from **signals in aggregate**, not from any individual's obligation to post.
- It gives us a clean privacy model (§5) and a clean discovery model (§6) that fall directly out of this split.

> **The one-sentence product truth:** _Reading quietly still makes Dewey better for everyone; reading expressively makes it yours._

---

## 4. The core loop

```
   REACT / DISCOVER  ──►  ADD to library
        ▲                      │
        │                      ▼
   trusted-taste          READ (private,
   signals surface         self-paced —
   the book                 optional moments)
        ▲                      │
        │                      ▼
   others' signals  ◄──  FINISH + (optionally) EXPRESS
   + your expressions        rate · reflect · list · recommend
```

The loop is powered by **signals at every stage** and **expressions at the edges**. Critically, the loop closes even for a silent user: they discover via trusted signals, read privately, finish, rate — and that rating becomes a trusted signal for someone else. No posting required for the flywheel to spin.

---

## 5. The privacy & sharing model

**Private by default. Sharing is a deliberate, delightful choice — never a default, never a nag.**

Three visibility tiers, chosen per-object, with sane defaults:

| Object | Default | Notes |
|---|---|---|
| Library / shelves | **Signal-visible** | Contributes to aggregate discovery ("N trusted readers own this") but not broadcast as a post. Can be set fully private. |
| Progress | **Private** | Never a feed event unless the user shares a specific moment. |
| Rating | **Signal-visible** | Powers taste-matching; can be private. |
| Saved passages | **Private** | The reader's commonplace book. One tap to make a passage an Expression. |
| Private thoughts / notes | **Private, always** | A protected space. This is sacred — it's what makes Dewey a journal, not a stage. |
| Reflections / reviews | **Public when written** | Writing one *is* the act of choosing to express. |
| Lists | **Per-list choice** | |
| Direct recommendations | **Person-to-person** | Not public. Intimate, high-trust. |

**Design consequence:** there is no global "post" button and no obligation to fill a feed. The closest thing to a feed is a **discovery surface** built from trusted signals + opt-in expressions (§6), not a stream of everyone's activity.

---

## 6. The discovery engine — trusted taste, not an algorithmic firehose

The primary functional need is *discover books through trusted people.* So discovery is **relationship-weighted, not engagement-weighted.**

**Inputs:**
1. **Signals from people you follow** (finishes, high ratings, adds, list inclusions) — the density workhorse.
2. **Taste affinity** — overlap in rating patterns identifies "readers like you," surfaced as *people*, not just books ("you and Maya agree on 14 books" → follow Maya).
3. **Expressions** — passages, reflections, lists, and direct recs from trusted people, shown because *they chose to share*, weighted by how much you trust them.

**Explicitly rejected inputs:** trending-everywhere virality, engagement-bait ranking, publisher promotion, "readers also bought." Dewey's discovery answers *"what are people with good taste actually reading and loving right now?"* — and it can name the people, which is the trust primitive Goodreads never had.

**Two discovery modes:**
- **Ambient** — a calm home surface: what trusted readers are into, a resurfaced passage, a friend's new list. Not infinite scroll; a finite, considered set that refreshes with real activity.
- **Intentional** — search + "who should I trust?" (taste-match) + browsable lists.

---

## 7. Product principles & anti-goals

**Principles**
1. **Private by default; expression is a gift, not a tax.**
2. **Density from signals, not from posting.**
3. **Show people, not just books** — trust is the moat.
4. **Calm, finite surfaces** — no infinite feed, no dopamine slot-machine.
5. **Native, fast, handcrafted** — HIG-first SwiftUI, large type, breathing room, purposeful motion.
6. **One screen, one job.**

**Anti-goals (things we will actively refuse, even under pressure)**
- ❌ Streaks, daily goals, reading-minute counters, gamified nudges.
- ❌ Productivity/optimization language ("crush your goal!").
- ❌ Vanity metrics as the point (pages/yr as a scoreboard).
- ❌ Public global feed / follower-count status games.
- ❌ Algorithmic engagement maximization.
- ❌ Reading challenges as a core mechanic. (A yearly count can *exist* quietly; it is never the emotional center.)

> Reading goals & statistics from your original feature list are **demoted, not deleted** — present as a calm personal reflection, never as motivation machinery. This is a direct consequence of the wedge.

---

## 8. Feature audit — challenging each area

Your list, each earning or losing its place in **v1**. Default posture: cut ruthlessly, YAGNI.

| Area | v1? | Decision & rationale |
|---|---|---|
| **Library** | ✅ Core | The spine. Signal-visible shelves. This *is* the product's resting state. |
| **Reading tracker** | ✅ Minimal | Status + optional progress *moments* only. No session logging, no streaks. |
| **Ratings** | ✅ Core | The lowest-effort, highest-value signal — powers taste-matching. Consider a Letterboxd-style half-star + a private "for me" axis (see open questions). |
| **Reviews / Reflections** | ✅ Core (as Expression) | The taste-driven user's canvas. Optional, beautiful, never required. |
| **Saved passages** | ✅ Core | The "commonplace book" — a signature, private-first delight competitors lack. Strong differentiator. |
| **Lists** | ✅ Core | Central to taste expression and discovery. Curated identity artifacts. |
| **Direct recommendations** | ✅ Core | Person-to-person recs are the highest-trust social act in reading. Rare in competitors. Cheap to build, huge emotional payoff. |
| **Discovery** | ✅ Core (trusted-signal version) | Ambient + intentional per §6. No algorithmic feed. |
| **Profiles** | ✅ Core | A profile is a *taste portrait*: shelves, ratings, lists, favorites — not a stat dump. |
| **Friends / Follows** | ✅ Core | Asymmetric follow + taste-match suggestions. The trust graph is the moat. |
| **Search** | ✅ Core | Must be instant and gorgeous — book search is table stakes; people/taste search is the twist. |
| **Onboarding** | ✅ Core | Critical: must produce *taste signal fast* (rate a handful of books) so discovery isn't cold. |
| **Recommendations (algo)** | ⚠️ v1.5 | Ship trusted-people discovery first; formal recommendation modeling later. |
| **Statistics** | ⚠️ v1.5, reframed | "Your reading year," calm and reflective. Never motivational. |
| **Reading goals** | 🅿️ Parked | Against the emotional center. Revisit only as an *optional, quiet* number. |
| **Notifications** | ⚠️ v1, restrained | Only high-trust, high-signal events: a direct rec, someone you trust finished a book you saved. No engagement pings. |
| **Settings** | ✅ Minimal | Visibility controls are the important part here (§5). |

**Cut from v1 entirely:** goals/challenges, algorithmic recs, deep stats, any gamification. **Signature bets that differentiate us:** saved passages (private commonplace book), direct person-to-person recommendations, and people-you-can-trust taste-matching.

---

## 9. Competitive positioning

| Product | What it is | Where it leaves the door open |
|---|---|---|
| **Goodreads** | Bloated, ad-heavy catalog + ratings; Amazon-owned. | No taste, no beauty, no trust primitive. Everyone hates it and can't leave. |
| **StoryGraph** | Stats/mood/tracking utility for heavy readers. | Functional, not emotional; serves trackers, not taste-driven social readers. |
| **Fable** | Social + book clubs + content. | Feed-y, community-forum energy; leans toward posting/creators. |
| **Literal / others** | Prettier Goodreads attempts. | Thin social graph; no distinctive interaction model; discovery still weak. |

**Dewey's defensible wedge:** the *taste graph* (people you trust, named and weighted) + a *private-first journal* that still fuels discovery. Competitors force a choice between "private tracker" and "social feed." Dewey refuses the choice — that's the insight the category hasn't productized.

---

## 10. What we build first — the v1 vertical slice

We do **not** build all of §8 at once. We build the thinnest slice that proves the emotional center and the signals→discovery mechanic. Proposed **v1 (single-player-beautiful → light multiplayer):**

1. **Library + shelves** (Want / Reading / Finished + custom shelves) — signal-visible.
2. **Add a book** via a fast, gorgeous search.
3. **Rate + optional reflection** on finish.
4. **Saved passages** (private commonplace book) — our signature delight, and it's compelling even solo.
5. **Profile as taste portrait.**
6. **The trust layer, minimal:** follow a person, see their finished books + ratings + public lists; **taste-match** suggestion ("you agree on N books").
7. **Direct recommendation** to a followed person.
8. **Ambient discovery surface** built from followed-people signals.

**Sequencing rationale:** items 1–5 make Dewey worth opening *before it has a social graph* (solving cold-start — a solo user still gets a beautiful journal). Items 6–8 turn accumulated private signals into discovery the moment a second person appears. This is how we avoid the empty-network death that kills social apps.

**Deferred to v1.5+:** stats/"reading year," algorithmic recs, notifications beyond direct recs, clubs/threads, cross-posting, web.

---

## 11. North Star & guardrail metrics

Choosing the wrong metric will quietly pull us toward the anti-goals, so this matters.

**North Star:** **Trusted-taste discoveries** — _books added to a library because of another person on Dewey_ (a trusted signal or a direct rec). This is the literal measurement of our core value: *discover books through people you trust.* It cannot be gamed by making the app more addictive; it only goes up if trust and taste are working.

**Supporting/health metrics:**
- **Taste-match connections formed** (follows that stick).
- **Passages saved per active reader** (depth of the private journal — our retention primitive).
- **Reflections & lists published** (expression rate — without pressuring it).

**Guardrails we will watch to protect the soul:**
- Share/expression rate should stay *healthy but not coerced* — if we ever see it spike because of nagging, that's a red flag, not a win.
- Session frequency is **not** a success metric. A reader who opens Dewey twice a week and loves it beats one we've trained to compulsively check.

---

## 12. Key risks & mitigations

1. **Cold start / empty network.** → v1 is valuable solo (journal + passages + library). Onboarding harvests taste fast (rate a few books) so discovery isn't empty. Taste-match creates connection *before* you know anyone.
2. **Catalog/metadata quality.** A book app lives or dies on its book data (covers, editions, authors). → Pick a serious data source early (Open Library / Google Books / a licensed provider); design an abstraction so we can swap providers. **This is the first real engineering decision and a genuine risk — flagged for the technical spec.**
3. **Density still too low.** → If signals under-deliver, we lean harder on taste-match and direct recs (highest-value, lowest-volume-required interactions) before ever adding feed mechanics.
4. **Drift toward Goodreads/tracker.** → The anti-goals list (§7) is a standing veto. Any feature that smells like gamification or stat-scoreboarding gets challenged against the wedge.
5. **Expression pressure creeping in.** → Guardrail metric above; private-by-default is architectural, not a setting we can casually weaken.

---

## Open questions for the technical spec (not blockers)

_Stated with recommended defaults so we can proceed:_

- **Book data provider.** _Assume Open Library + Google Books hybrid for v1_, behind a `BookCatalog` abstraction; revisit licensing at scale.
- **Rating scale.** _Assume Letterboxd-style half-stars (0.5–5)_ plus a private note; consider a separate private "meant something to me" flag distinct from quality.
- **Backend.** _Assume local-first SwiftData for v1_ so the solo experience is instant and offline, with a sync/backend seam designed in (CloudKit or a custom API) for the social layer. Native iOS + SwiftUI per the stack.
- **Account model.** Solo usable without an account; account required only to follow/share.

---

## The through-line

Everything above collapses to one decision we should protect at all costs:

> **Dewey earns its social density from signals, not from posts — so a reader can use it as a quiet, beautiful journal and still make the whole network smarter, while the reader who wants to express their taste gets the most elegant canvas in the category.**

If a future feature violates that sentence, it doesn't ship.
