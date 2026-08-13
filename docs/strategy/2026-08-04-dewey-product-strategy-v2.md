# Project Dewey

## Founder Product Strategy — Taste-Driven Social Reading

**Status:** Strategic foundation (supersedes `2026-08-04-dewey-product-strategy.md`)
**Date:** August 4, 2026
**Working product name:** Dewey
**Primary platform:** Native iOS
**Author:** Founder

---

## 1. Executive decision

Dewey should begin with the **taste-driven social reader**: a person for whom books are part of identity, culture, conversation, and connection. They may read ten books a year or thirty. Volume is not the defining behavior. What matters is that their choices and opinions carry meaning—for themselves and for other people.

The wedge is:

> **People who want their reading life to express their taste and connect them with people whose taste they trust.**

This is more defensible than leading with tracking, statistics, or habit formation. Those categories naturally optimize for completion, quantity, streaks, and personal productivity. Dewey should instead optimize for **memory, expression, trust, and discovery**.

The proposed product promise is:

> **Dewey is where your reading life becomes a living expression of your taste—and a trusted way to find what matters next.**

The initial product should make three things exceptional:

1. **Capture what a book means to you** without turning reading into administration.
2. **Express a distinctive reading identity** through a living library, reflections, and lists.
3. **Discover books through people whose taste is useful or resonant**, with clear human provenance.

The strategic model is not "every reading session becomes content." It is:

> **Capture privately. Crystallize meaning. Share intentionally. Discover through trust.**

That sentence should guide product, design, privacy, ranking, notifications, and metrics.

---

## 2. The problem

Readers currently piece together several incomplete tools:

- Catalogs help them remember what they read, but often reduce books to rows, shelves, and ratings.
- Trackers visualize volume and habits, but can make reading feel like performance management.
- Social feeds create activity, but often reward posting frequency, popularity, and engagement rather than taste.
- Notes apps preserve private thoughts, but separate them from the book, the reader's identity, and future discovery.
- Recommendation systems suggest books, but frequently obscure the most persuasive context: **who loved this, what they value, and why they thought of me**.

The unmet need is not another universal book database. It is a coherent place where a person can:

- remember their interior life as a reader;
- develop and express taste over time;
- understand the taste of other people;
- discover books through trusted human context; and
- participate socially without becoming a content creator.

The central design tension is therefore:

> **How can Dewey produce enough meaningful social density to become a destination while protecting the quiet, private nature of reading?**

The answer should not be "ask users to post more." It should be to make ordinary reading activity capable of producing **optional, contextual, durable signals**.

---

## 3. Primary user and jobs to be done

### Primary user: the taste-driven social reader

They:

- consider books part of their identity;
- enjoy recommending and discussing books;
- care whose opinion they are hearing;
- save passages or thoughts, even inconsistently;
- want a record of how books affected them;
- build lists as acts of curation, not only organization;
- may read moderately rather than voraciously; and
- dislike feeling that reading has been converted into a quota.

Their defining behavior is **meaningful attention**, not high throughput.

### Functional job

> Help me remember, organize, and reflect on my reading life without creating work.

### Emotional job

> Help me see and develop who I am through the books that matter to me.

### Social job

> Help me find people whose taste I trust, understand why their taste matters, and exchange books with them naturally.

### Discovery job

> When I want my next book, show me compelling possibilities with human context—not an anonymous wall of recommendations.

### Identity job

> Give me a profile and library that feel like me, not like a résumé of completed books.

### Anti-jobs

Dewey is not primarily helping users:

- maximize books or pages completed;
- maintain a daily reading streak;
- win a public challenge;
- create frequent book content;
- grow a follower count;
- manage a comprehensive personal database; or
- receive publisher-driven recommendations disguised as taste.

---

## 4. Positioning

### Category

**A social reading journal built around taste.**

"Journal" communicates memory and reflection. "Social" communicates trusted connection. "Taste" distinguishes Dewey from utilities centered on cataloging, statistics, or reading productivity.

### Positioning statement

For readers who experience books as part of their identity, Dewey is a social reading journal that helps them remember what books meant, express their taste, and discover through people they trust. Unlike catalog-first trackers or engagement-first social feeds, Dewey is private by default, intentional about sharing, and designed around meaningful signals rather than reading volume.

### Competitive stance

This strategy does not depend on competitors being poorly designed. It depends on Dewey having a different center of gravity.

- **Goodreads** is fundamentally a broad catalog and community utility: shelves, ratings, reviews, recommendations, and a reading challenge. Its breadth and existing graph are strengths. Dewey should not try to beat it at exhaustive utility in version one.
- **The StoryGraph** explicitly emphasizes tracking, mood-based recommendations, statistics, and social reading formats such as buddy reads. Dewey should not compete on analytical depth.
- **Fable** combines tracking, social posting, lists, goals, streaks, and clubs. Dewey's distinction should be a quieter, more personal social model centered on individual taste and selective signals rather than club participation or daily habit reinforcement.
- **Literal and emerging trackers** reinforce that basic logging, imports, lists, and feeds are increasingly table stakes. Visual polish alone will not create durable differentiation.

The opportunity is the intersection others only partially serve:

> **Personal meaning × legible taste × trusted discovery × low-pressure participation**

Sources for the current competitive framing: [Goodreads' own description of shelves, Kindle activity, recommendations, and its Reading Challenge](https://www.goodreads.com/amazon), [The StoryGraph's feature overview](https://www.thestorygraph.com/?lang=en), and [Fable's current product description](https://fable.co/).

---

## 5. Strategic principles

### 5.1 Taste over volume

Dewey should make a thoughtful reader of twelve books feel as interesting as a reader of one hundred. Prominence should come from resonance and specificity—not output.

### 5.2 Private value before social value

Every core action must be worthwhile even if nobody else sees it. Social participation should amplify a useful personal product, not subsidize an empty feed.

### 5.3 Sharing is a deliberate transition

Private capture and public expression are different mental modes. The interface should respect that boundary. Privacy cannot be a small audience selector attached to a composer designed for posting.

### 5.4 Provenance makes discovery persuasive

"Recommended for you" is weaker than "saved because Maya, whose literary fiction taste overlaps with yours, called this emotionally exact." Dewey should preserve the chain of inspiration.

### 5.5 A library is a portrait, not inventory

The product should reveal patterns, eras, affinities, contradictions, and evolving opinions. Organization matters, but expression is the differentiator.

### 5.6 Finishing is not the only valid outcome

Pausing or abandoning a book is part of taste formation. Dewey should normalize these decisions without shame or euphemism.

### 5.7 Social density is curated, not manufactured

A feed with fewer high-context signals can feel more alive than a feed full of page updates. Dewey should aggregate, filter, and resurface rather than indiscriminately publish every action.

### 5.8 Trust must survive monetization

If paid placement can masquerade as a friend's recommendation or organic discovery, the core product is compromised.

---

## 6. Pressure test: what is the atomic unit?

An atomic unit should be frequent enough to sustain a product loop, meaningful enough to warrant attention, flexible enough to support different readers, and coherent enough to guide design and measurement.

### Alternative A: the finished book

**Strengths**

- High meaning and natural closure.
- Easy to understand and model.
- Produces durable ratings, reflections, and library history.

**Weaknesses**

- Too infrequent for moderate readers.
- Overvalues completion and excludes the life of a book while it is being read.
- Makes abandoned and paused books feel like failures or missing data.
- Creates long gaps with little personal or social activity.

**Verdict:** Essential lifecycle milestone, poor primary atom.

### Alternative B: the reading session or progress update

**Strengths**

- Naturally frequent.
- Useful for accurate tracking and goals.
- Provides a steady source of activity.

**Weaknesses**

- Often contains little meaning for another person.
- Encourages administrative behavior and numerical optimization.
- Risks interrupting reading and rewarding performative consistency.
- A feed of percentages and page counts has high activity but low social value.

**Verdict:** Optional private metadata, not the social or strategic atom.

### Alternative C: the post, review, or piece of content

**Strengths**

- Expressive and socially legible.
- Supports conversation and strong creator identity.
- Familiar feed mechanics.

**Weaknesses**

- Requires users to become creators.
- Creates blank-page anxiety and production pressure.
- Favors articulate, frequent posters over quietly interesting readers.
- Pulls the product toward engagement incentives and audience performance.

**Verdict:** Valuable high-intent output, dangerous as the default atom.

### Alternative D: the recommendation between people

**Strengths**

- High trust, intent, and social value.
- Produces a clear discovery outcome.
- Strengthens relationships and creates natural reciprocity.

**Weaknesses**

- Too episodic to support the entire product.
- Requires an existing relationship and enough context to know what fits.

**Verdict:** A signature interaction and powerful loop accelerator, but too narrow as the universal atom.

### Alternative E: the reading moment

A reading moment is a meaningful event in the relationship between a person and a book: starting, saving a passage, recording a thought, reacting, making meaningful progress, pausing, abandoning, finishing, being inspired, or recommending.

**Strengths**

- Matches the real, non-linear lifecycle of reading.
- Supports both private and social use.
- Creates more opportunities for memory and expression than completion alone.
- Avoids requiring every interaction to have a polished format.
- Can preserve provenance between discovery and action.

**Weaknesses**

- It is a category of events, not one consistent object.
- Different moments vary enormously in meaning and audience value.
- If every moment enters the feed, the result is noisy surveillance of reading behavior.
- If moments use one generic composer, the interaction becomes vague and burdensome.
- It is difficult to define one quality metric across a saved passage, a pause, and a direct recommendation.

**Verdict:** Correct foundation for the private experience, incomplete as a single product atom.

### Recommendation: a three-layer model

The strategic model should be:

#### Layer 1: Moment — the private capture atom

A **moment** records a meaningful change or observation in a reader's relationship with a book. It is private by default, quick to create, and allowed to remain private forever.

Examples: started, passage saved, thought recorded, paused, finished.

#### Layer 2: Signal — the social distribution atom

A **signal** is a socially useful expression derived from a moment or durable artifact. It is intentionally shared or made visible through an explicit standing preference. It must answer at least one question for another reader:

- Why might I care about this book?
- What does this reveal about this person's taste?
- Why is this relevant to me?

Examples: a shared reaction, a finish reflection, a book added to a public curated list, a direct recommendation, or an aggregated "three trusted readers saved this" card.

#### Layer 3: Taste artifact — the durable identity atom

A **taste artifact** persists on a profile or book relationship and becomes more valuable over time.

Examples: a reflection, an annotated favorite, a ranked or themed list, a library status, or an evolving opinion.

This produces a clean division of responsibility:

- **Moments create personal frequency.**
- **Signals create social density.**
- **Taste artifacts create identity and long-term value.**

Therefore, "reading moment" should remain a central product concept, but Dewey's social atomic unit should be the **taste signal**, not the raw moment.

---

## 7. The core product loop

### Primary loop: the trusted taste loop

1. **Encounter** — The reader sees a high-context signal from a person they trust or may want to trust.
2. **Recognize** — They understand why the book matters and why this person's taste is relevant.
3. **Save or begin** — They add the book with provenance preserved: "Inspired by…"
4. **Experience** — While reading, they capture zero or more private moments without social obligation.
5. **Crystallize** — A meaningful opinion, passage, status change, or reflection becomes a durable taste artifact.
6. **Share selectively** — They intentionally publish a signal, recommend directly, or allow an existing public artifact to appear contextually.
7. **Strengthen trust** — Others act on that signal; Dewey learns which people, contexts, and kinds of expression are genuinely useful.

The loop is successful even when steps 4–6 occur weeks later. Books are slow media; Dewey should remember causal relationships across time instead of forcing session-length loops.

### Quiet-user loop

1. Save a book from a trusted person.
2. Read and capture private moments.
3. Update the personal library or leave a private reflection.
4. Contribute low-pressure, privacy-safe aggregate signals only where explicitly permitted.
5. Receive better discovery because the taste model becomes richer.

A quiet user must receive a complete product. They should never encounter disabled-feeling empty states implying that the "real" app begins when they post.

### Direct recommendation loop

1. A reader thinks of a specific person while viewing a book or reflection.
2. They send the book with one lightweight reason: "for the prose," "because you loved…," or a short note.
3. The recipient saves, declines, or responds.
4. If they later start or finish it, Dewey can close the loop privately or socially according to both users' preferences.

This should become a signature Dewey interaction because it combines taste, intimacy, provenance, and utility.

---

## 8. Product pillars

### Pillar 1: The living library

**Purpose:** Help the user see and shape their reading identity.

The library should prioritize meaning over database controls. It should include familiar statuses—want to read, reading, read, paused, did not finish—but present them as parts of a living reading history.

Key ideas:

- Beautiful book-first browsing with restrained metadata.
- "Important to me" or "part of me" designation distinct from a numerical rating.
- Private notes and moments attached to the book relationship.
- Personal, curated shelves/lists with expressive titles and optional context.
- A temporal view showing eras and changes in taste without turning them into performance charts.
- Fast import and reliable export so users do not have to abandon their history or fear lock-in.

### Pillar 2: Reflection without a blank page

**Purpose:** Help the user preserve what mattered with minimal friction.

Reflection should be progressive:

- One tap: mark a lightweight reaction or status.
- One phrase: "What stayed with you?"
- A few sentences: structured reflection prompts.
- Full expression: an optional long-form review.

Prompts should be specific and emotionally intelligent, not school-like. Examples:

- "What are you still thinking about?"
- "Who would you hand this to?"
- "What did this change—or confirm—for you?"
- "What kind of reader is this for?"

The default finish flow should not demand a star rating and review. It should offer a small set of meaningful actions and allow completion in seconds.

### Pillar 3: Legible taste profiles

**Purpose:** Help someone quickly understand whether another reader's taste is interesting or useful to them.

A Dewey profile should not be a leaderboard. It should answer:

- What does this person care about?
- Which books define them?
- What have they been thinking about lately?
- Where does our taste intersect or productively differ?
- Why might I follow them?

Components may include:

- a small, intentionally chosen "books that made me" set;
- current reading, if visible;
- recent public signals;
- distinctive lists;
- taste affinities expressed in plain language;
- overlap and divergence shown privately to the viewer; and
- no prominent public follower count in the initial product.

### Pillar 4: Trusted discovery

**Purpose:** Help the user find a compelling next book through human context.

Discovery should combine:

- people the user follows;
- direct recommendations;
- provenance chains ("you found this through…");
- editorial or invited tastemakers at launch;
- taste-neighbor suggestions; and
- resurfacing from the user's own library at the right moment.

Algorithmic ranking is acceptable, but its job is to select among human signals—not erase them. Every recommendation should explain its source.

### Pillar 5: Intentional social exchange

**Purpose:** Turn taste into connection without producing a conventional attention economy.

Initial interactions should be small and purposeful:

- save because of someone;
- react to a reflection;
- reply privately or publicly where appropriate;
- recommend directly;
- follow for taste;
- add a book to a list with attribution.

Open-ended posting, broad public discourse, large groups, and viral mechanics should not lead version one.

---

## 9. The home experience

The home screen exists to answer:

> **What in my reading world deserves my attention right now?**

It should not be a reverse-chronological exhaust stream. A better model is a finite, refreshable edition containing a small number of high-quality cards:

- a meaningful signal from someone trusted;
- a direct recommendation awaiting response;
- one currently reading book with an easy private capture action;
- a resurfaced saved book with relevant context;
- an aggregated social signal rather than five repetitive actions;
- an occasional prompt to revisit a private moment or finish reflection.

Ranking priorities:

1. Direct interpersonal relevance.
2. Strength of taste trust.
3. Specificity and quality of context.
4. Novelty relative to what the reader already knows.
5. Timeliness when it genuinely matters.

Raw recency and popularity should be secondary. The feed should have a natural end. "You're caught up" is a feature, not a failure.

---

## 10. Privacy and audience model

"Private by default" must be implemented as product architecture, not copywriting.

### Recommended defaults

- Private thoughts and saved passages: **private**.
- Progress percentages/pages: **private**.
- Reading status: chosen during onboarding, with a clear default of **followers** or **private** rather than public internet.
- Finish reflections: private draft first, then explicit audience selection.
- Curated lists: private until published.
- Direct recommendations: visible only to sender and recipient.
- Profile-defining books: explicitly selected and public to the profile's chosen audience.

### Audience levels

Keep the model understandable:

- Only me
- People I approve / followers, depending on the graph decision
- Everyone on Dewey

Avoid a complex per-field privacy matrix in version one. Provide good global defaults, remember the last intentional choice by content type, and show audience state at the moment it matters.

### Passively derived signals

Dewey should not silently transform a private action into a named social card. Aggregate discovery—such as "popular among people you follow"—must use only activity covered by a clearly chosen visibility setting. Users should be able to understand and disable this contribution.

### Passages and copyright

Saved passages require product and legal care. Dewey should limit excerpt length, preserve source/edition/page or location when available, discourage bulk capture, provide takedown processes, and avoid making public passage collections a substitute for the book.

---

## 11. Social graph and trust model

### Recommendation: asymmetric following, enriched by private trust signals

Taste is directional. I may value someone's fiction recommendations even if they do not know me. Therefore, Dewey should use **following**, not require mutual friendship.

However, a simple follow graph is insufficient. Internally, Dewey should learn contextual trust from behavior:

- whose recommendations are saved;
- whose suggestions lead to starts or finishes;
- where taste overlaps;
- which divergences are still useful;
- whose lists a user revisits; and
- whom a user recommends to directly.

This should not become a public compatibility score. Public percentages flatten taste, invite status comparison, and imply false precision. Use the model to explain specific relevance in human language.

### Network health choices

- Do not prominently display follower counts initially.
- Do not rank users globally by activity or popularity.
- Give users control over replies and mentions.
- Provide spoiler-aware controls tied to progress and explicit spoiler labels.
- Treat blocks, mutes, and reporting as launch requirements for any public social surface.
- Separate "I know this person" from "I follow their taste" only if real usage proves the need; do not begin with two overlapping graphs.

---

## 12. MVP recommendation

The MVP should prove one proposition:

> **A reader can build a meaningful taste identity and reliably discover books through trusted people without feeling pressure to post.**

### Must ship

#### Identity and onboarding

- Account and tasteful profile setup.
- Select a small set of defining books.
- Import from Goodreads-compatible CSV or another practical source.
- Follow known people and curated seed readers.
- Clear privacy default selection explained in plain language.

#### Book and library foundation

- Search with edition-aware book records.
- Want to read, reading, read, paused, and did not finish.
- Personal book relationship with dates and optional progress.
- Reliable library browsing and filtering.
- Data export.

#### Moments and reflection

- Start, pause, abandon, finish.
- Private note/thought.
- Saved passage with source metadata.
- Lightweight reaction.
- Progressive finish reflection.
- Explicit promotion of a private moment into a shared signal.

#### Taste and social

- Follow users.
- Taste-first profile.
- Public or follower-visible reflection.
- Curated lists with notes.
- Direct book recommendation with a reason.
- Finite, ranked home edition.
- Save a book with inspiration provenance.
- Basic reactions/replies with spoiler protection.
- Block, mute, report, and audience controls.

#### Reliability

- Fast local cache and resilient sync.
- Accessible dynamic type, VoiceOver labels, contrast, reduced-motion support, and large tap targets.
- Analytics that measure the product loop without collecting private note content.

### Explicitly defer

- Reading streaks.
- Public annual goals.
- Deep statistics dashboards.
- Large book clubs and open groups.
- Generic text/image posting detached from a book.
- Public follower leaderboards.
- Publisher advertising and sponsored rankings.
- Complex challenges and badges.
- AI-generated reviews or social content.
- Desktop/web parity beyond shareable public surfaces and account essentials.
- Messaging unrelated to a book recommendation or existing context.

### Why lists remain in MVP

Lists can easily become commodity organization. They earn their place here because a well-made list is a high-signal, durable expression of taste and an efficient discovery object. Dewey lists should therefore require or invite a premise—not merely a shelf name—and support a short note explaining each inclusion.

### Why ratings should not lead

Star ratings are interoperable and quickly legible, so eliminating them entirely creates migration and comprehension costs. But making them the dominant expression reproduces the same reductive behavior as existing platforms.

Recommendation:

- Support an optional familiar rating as secondary metadata.
- Lead with a short reflection and qualitative signals such as "stayed with me," "I'd recommend this to…," or "not for me."
- Do not use one global average as the primary visual hierarchy on a book page.

---

## 13. Onboarding and cold start

The cold-start problem is existential for a taste-driven social product. A beautiful empty feed and empty library will not retain users.

The initial onboarding should produce value in under five minutes:

1. **Bring your history** — import or quickly select previously read books.
2. **Declare taste, lightly** — choose 5–10 books that reveal something meaningful, not fifty genre preferences.
3. **Find signal** — follow a small set of friends, invited readers, critics, authors, booksellers, or community curators.
4. **See your profile come alive** — immediately render a beautiful first version of the user's reading identity.
5. **Receive one useful discovery** — show a book with understandable human provenance.

Do not begin with a long preference quiz. Taste is better inferred from books and people than from abstract genre sliders.

### Launch supply strategy

Before broad release, Dewey needs concentrated communities rather than scattered users. Recruit small, taste-coherent networks:

- independent booksellers and their communities;
- literary newsletters and book podcasters;
- graduate programs or culturally active alumni networks;
- niche genre communities;
- authors who are generous recommenders rather than only promoters; and
- existing real-world book groups, even though group tooling is not yet the product center.

The goal is not celebrity reach. It is enough graph overlap that a new user quickly encounters several people worth trusting.

---

## 14. Metrics

### North-star metric: Trusted Discovery Outcomes

A **Trusted Discovery Outcome (TDO)** occurs when a user takes a meaningful book action—save, request, begin, or direct recommendation—in response to a traceable person or curated human source.

Track both:

- **Weekly users with at least one TDO**, and
- **TDOs that progress from save to start within a suitable long window**.

This measures Dewey's differentiated value better than posts, sessions, books completed, or time spent.

### Product health metrics

#### Activation

- Imported or added at least five meaningful books.
- Followed at least three relevant people or sources.
- Completed one private moment.
- Saved or started one book through a trusted signal.

An activated user should experience both sides of the product: **self-expression and trusted discovery**.

#### Retention

- Four-week retained users who captured a private moment or revisited their library.
- Four-week retained users who consumed or acted on a signal.
- Percentage of moderate readers retained independent of completion frequency.

#### Signal quality

- Saves/starts per signal impression.
- Direct recommendation acceptance or save rate.
- Reflection/list revisit rate.
- Hide, mute, and "not relevant" rate.
- Percentage of feed cards with clear provenance.

#### Pressure and trust guardrails

- Users reporting that Dewey makes reading feel pressured.
- Notification disable rate.
- Percentage of moments kept private.
- Posting concentration among the top one percent of users.
- Reports, blocks, unwanted replies, and spoiler incidents.
- Feed depth/time spent without a corresponding meaningful action.

High private usage is not a failure. If the product only looks healthy when private moments become public, the model is wrong.

### Metrics not to optimize

- Daily posting rate.
- Minutes spent in feed.
- Number of pages logged.
- Public content volume.
- Follower growth as a universal goal.
- Books completed per user.

---

## 15. Business model

The network and core reading journal should be free enough to grow and remain useful. The cleanest long-term model is a paid membership for enhanced personal value—not reach.

Potential paid value:

- richer private journal and resurfacing;
- advanced personal library views;
- premium export, print, or annual keepsakes;
- deeper taste history and reflection tools;
- customization that preserves design quality;
- household or close-circle features; and
- supporter membership for users who want an independent, ad-free network.

Do not sell:

- algorithmic reach;
- boosted reviews;
- undisclosed publisher influence;
- private note content;
- social status; or
- basic data portability.

Affiliate book sales may eventually be compatible if attribution is transparent and ranking is independent. Advertising inside trusted discovery is strategically dangerous.

---

## 16. Technical and data implications

### Product architecture

The three-layer product model should exist in the domain architecture from the beginning:

- **Book/Edition** — bibliographic identity and edition-specific metadata.
- **UserBook** — a user's durable relationship to a work/edition.
- **Moment** — private-first event or capture.
- **Signal** — an audience-aware social representation with provenance.
- **TasteArtifact** — durable public/private expression such as reflection or list.
- **Recommendation** — a directed object between people, not merely a notification.
- **Attribution** — a chain connecting discovery to save, start, and later reflection.

Do not model the feed as the system of record. It is a projection assembled from these durable objects.

### Book data is a core risk

Bibliographic data is messy: works, editions, ISBNs, translations, formats, cover rights, duplicate records, and missing publication metadata. Dewey needs a canonical work model with edition-specific attachments from the outset. Otherwise, social activity and reviews will fragment across duplicate books.

The data strategy should include:

- one canonical work with multiple editions;
- user-selected reading edition when known;
- merge and correction tooling;
- source provenance and licensing records;
- resilient search tolerant of imperfect metadata; and
- a path for community corrections with moderation.

### iOS and backend direction

- Native SwiftUI for the primary experience.
- Clear domain modules rather than screen-based business logic.
- Local persistence/cache for instant library access and resilient capture.
- Server-authoritative social, privacy, moderation, and attribution data.
- A relational backend suited to graph-adjacent queries and strict audience controls.
- Search infrastructure designed for books, authors, ISBNs, editions, and users.
- Background media processing only where required; keep the core product text- and cover-led.
- Event instrumentation that records action metadata without ingesting private note bodies.

Vendor selection should follow a short technical discovery focused on book-data licensing, authentication, search, moderation, sync, and operating cost. Choosing infrastructure before clarifying these constraints would be premature.

---

## 17. Roadmap

### Phase 0: Validate the behavior, not the interface

Goal: prove that taste context changes discovery and that private capture creates durable value.

- Interview and prototype with 15–25 taste-driven readers.
- Test profiles built from defining books and lists.
- Test private-to-shared moment transitions.
- Run a concierge direct-recommendation loop.
- Compare a finite contextual home edition with a conventional activity feed.
- Measure whether provenance changes saves and starts.

Exit signal: participants return to see what trusted people surfaced and preserve thoughts without being prompted to "post."

### Phase 1: Private alpha

Goal: establish the complete trusted taste loop in small, dense networks.

- Core library and import.
- Moments and reflections.
- Taste profile.
- Following and finite home edition.
- Lists.
- Direct recommendations.
- Privacy, blocking, reporting, and spoiler controls.

Exit signal: activated cohorts generate repeat trusted discovery outcomes across a multi-week book lifecycle.

### Phase 2: Invite beta

Goal: improve cold start, graph formation, and signal quality.

- Better people discovery.
- Attribution-aware ranking.
- Taste explanations and profile refinement.
- Resurfacing and notification tuning.
- Book-data correction operations.
- Lightweight public web views for shared profiles, reflections, and lists.

Exit signal: new users reliably find at least three valuable follows and one useful book within their first session, with healthy four-week retention.

### Phase 3: Public launch

Goal: scale network growth without degrading trust.

- Concentrated community launch playbook.
- Creator/curator tooling focused on quality, not reach hacking.
- Mature moderation operations.
- Membership test based on personal value.
- Selective integrations where they remove logging friction.

### Later, only if earned

- Small-group reading.
- Richer private statistics framed as reflection rather than productivity.
- Reading goals expressed as intentions rather than quotas.
- Web and iPad expansion.
- Independent bookstore and library connections.
- Optional AI for private retrieval, summarization of the user's own notes, or discovery explanation—with strong consent and no synthetic social voice.

---

## 18. Key risks and mitigations

### Risk 1: An empty social product

**Failure mode:** Users join without relevant people or signals.

**Mitigation:** Launch through dense taste communities, make import excellent, seed credible curators, and guarantee a complete private journal experience.

### Risk 2: "Private by default" starves the feed

**Failure mode:** The social surface lacks enough activity.

**Mitigation:** Use durable artifacts, intentional standing visibility choices, aggregation, resurfacing, direct recommendations, and editorial seeding. Do not solve this by weakening consent.

### Risk 3: Taste becomes status

**Failure mode:** The app rewards conspicuous sophistication, follower counts, and performative opinions.

**Mitigation:** Minimize public metrics, personalize relevance, value specific curation, and prevent global popularity from dominating ranking.

### Risk 4: Reflection becomes homework

**Failure mode:** Users stop logging because every milestone asks for prose.

**Mitigation:** Progressive disclosure, optional prompts, one-tap completion, private drafts, and no completeness score.

### Risk 5: Book data undermines trust

**Failure mode:** Duplicates, missing editions, and poor search make the product feel unreliable.

**Mitigation:** Treat bibliographic infrastructure and correction operations as a core product competency, not backend cleanup.

### Risk 6: Moderate reading frequency weakens retention

**Failure mode:** Users only return when they finish a book.

**Mitigation:** Build value around discovery, private moments, direct recommendations, lists, and resurfacing. Measure multi-week loops rather than forcing daily behavior.

### Risk 7: The name "Dewey" carries avoidable constraints

**Failure mode:** Trademark availability, searchability, library-system associations, or the legacy of Melvil Dewey create brand limitations.

**Mitigation:** Treat Dewey as a working name until legal, trademark, App Store, domain, cultural, and user-perception diligence is complete. Do not let affection for the codename substitute for brand validation.

---

## 19. Product decisions made by this strategy

1. The primary user is the taste-driven social reader, not the highest-volume reader.
2. The product optimizes for meaning, expression, trust, and discovery—not completion volume.
3. Reading moments are the private capture model, not automatically social content.
4. Taste signals are the social distribution unit.
5. Taste artifacts are the durable profile and identity unit.
6. Sharing is intentional and private capture is fully valuable on its own.
7. The home screen is a finite, ranked edition—not an infinite raw activity feed.
8. Following is asymmetric; taste trust is contextual and mostly private.
9. Direct recommendation is a signature interaction.
10. Lists ship early because they are expressive, durable taste objects.
11. Ratings may exist as secondary metadata but do not define the reflection model.
12. Streaks, public goals, deep stats, generic posting, and large clubs are deferred.
13. Trusted Discovery Outcomes—not posts or time spent—anchor measurement.
14. Core social access, portability, and trust are not monetized through reach or ads.
15. Book identity, privacy, provenance, and moderation are foundational architecture.

---

## 20. The product test

Every proposed Dewey feature should pass four questions:

1. **Does it help someone remember or understand their reading life?**
2. **Does it make taste more legible without making it performative?**
3. **Does it improve discovery through trustworthy human context?**
4. **Can a quiet user receive value without creating public content?**

If a feature fails all four, it does not belong. If it primarily increases frequency, content volume, or time spent, it should be treated with suspicion.

The strategic aim is not to build a prettier place to log books. It is to build the place where books become part of how people remember themselves and find one another.

> **Dewey should feel alive because taste travels—not because everyone is posting.**
