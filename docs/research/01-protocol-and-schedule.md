# Dewey — Research Protocol and Execution Schedule

**Covers:** Experiment 1 (Card Study) and Experiment 2 (Provenance Study)
**Governing document:** `/Users/jacksirianni/dewey/docs/strategy/2026-08-04-tuesday-problem-and-prototype-reduction.md` §§6–9
**Status:** Operational. Everything below is meant to be executed as written.
**Pre-registration freeze:** Everything in §§2.5, 2.8, 3.6, 3.7, 4.4 is frozen before the first participant is contacted. Changes after freeze are logged with a reason and apply prospectively only.

---

## 0. Two decisions this protocol makes that the memo left open

Both are stated up front so they can be overruled before anything is printed.

**0.1 — The reader sheets are anonymous. The name and the face appear only in condition P.**
The memo specifies reader profiles as "library grid + ratings + computed overlap, no prose, no bio." It does not say whether the reader is named. This protocol runs them as **Reader A / B / C / D**, with no name and no photograph, throughout the legibility block. The name and photo are introduced for the first time on the P card in the choice block.

Why: H-P(a) asks whether taste is legible *from a shelf alone*. A name is a prose signal — it carries a byline, a publication, a reputation. Naming the reader during the legibility block would let a participant read the person instead of the shelf and would silently convert the stop-condition measure into a recognition measure. It also removes source-recognition contamination from the block where it would do the most damage, and defers it to the choice block where it can be recorded as a covariate.

**0.2 — Density is *selected*, not engineered.**
With real published lists nothing can be tuned into a target band. R1–R3 are simply the three panel readers with the **highest** computed overlap for that participant; R4 is the panel reader with the **smallest overlap that is still ≥3**. That is the honest operationalization of memo §8.3 and it is stronger than the original: R1–R3 are not "engineered," they are "the best the world happened to supply." If R1–R3 land at 6–8 shared books rather than 12, that is a finding about the ceiling, not a defect, and it must be reported as the actual overlap counts per participant, never as a band label.

---

# PART A — EXPERIMENT 1: THE CARD STUDY

## 1. What is being measured

| Measure | Instrument | Reported as |
|---|---|---|
| **Legibility (H-P a)** | Articulation transcript, coded against §2.9 | Count out of 20 |
| **Falsifiable specificity** | The prediction task, Block C | Count out of 20 — **this is the stop condition** |
| **Choice under opportunity cost (H-P b)** | One-slot displacement, Block D | Four counts summing to 20: P / N / G / kept own book |
| **Density gradient** | Per-reader legibility × actual shared-book count | Counts by reader, with the raw overlap number attached |

**Primary output is the transcript, not the count.** The counts are reported without a verdict. See §5.

---

## 2. Card Study protocol

### 2.1 Recruiting: criteria, channels, yield, cost

**Inclusion:** 18+, finished **10–30 books** in the last 12 months, can name the last three books they finished, has **one specific book they intend to read next**, recommends books to other people at least "rarely," consents to audio recording, available in person.

**Hard exclusions:** knows the founder or has heard of Dewey; works or has worked in the last three years in UX/product research or design; is a current bookseller or working book critic; cannot name a specific next book.

**Sample guard:** no more than 10 of 20 from any single "what do you mostly read" category.

**Channels — target 26 scheduled to deliver 20 completed sessions plus 2 pilots.**

| Channel | Approach | Screener starts | Pass | Scheduled | Show | Cost |
|---|---|---|---|---|---|---|
| Two independent bookshops | Counter card + QR, one week, plus a line in the shop's own newsletter | 30 | 18 | 11 | 9 | $50 (thank-you to each shop) |
| Public library book-club leads | Email 3 branch coordinators, they forward to group leads | 20 | 12 | 8 | 7 | $0 |
| Second-degree network | Ask 12 people to forward. **They are told explicitly they may not participate and may not forward to anyone who knows the founder.** | 25 | 14 | 7 | 6 | $0 |
| Local Slack / Discord books channel | One post, one follow-up | 15 | 8 | 4 | 4 | $0 |
| **Total** | | **90** | **52** | **30** | **26** | **$50** |

Over-recruit is deliberate. Assume a 15% no-show and 2 exclusions for source recognition or zero overlap.

**Do not recruit from a single bookshop's regulars.** Two shops minimum, in different neighbourhoods, or the sample is one taste community wearing twenty faces.

### 2.2 The screener — exact questions and thresholds

Google Form. Nine questions. Two minutes. Title: **"Reading habits — 2 minute questionnaire."** Do not name Dewey anywhere in the screener.

> **Q1.** In the last 12 months, roughly how many books have you finished? *(whole number)*
> **PASS 10–30. FAIL <10. FAIL >30.**
> *Do not soften the upper bound. A 60-book-a-year reader is a different animal and will read four shelves fluently for reasons that do not generalize.*

> **Q2.** Please name the last three books you finished, with authors.
> **PASS** if three real, distinct titles are named. **FAIL** if fewer than three, if the answer is a genre rather than titles, or if the count is flatly inconsistent with Q1 (e.g. Q1 = 25, Q2 = "I can't remember any").

> **Q3.** Which of these best describes most of what you read? *(single choice)* Literary fiction / Science fiction & fantasy / Crime & thriller / Romance / Nonfiction & memoir / Classics / Genuinely mixed
> **No fail.** Used for the ≤10 quota.

> **Q4.** What are you planning to read next? Please name one specific book.
> **PASS** if a specific title is given. **FAIL** on "not sure," "whatever's next," or a genre.
> *This is the pre-fill for the commitment slot. A participant with no next book cannot be tested on displacement. **Log every Q4 failure** — the count of otherwise-qualified readers with no specific next book is itself evidence about the next-book occasion and belongs in the readout.*

> **Q5.** Do you recommend books to other people? Never / Rarely / Sometimes / Often
> **FAIL on "Never."**

> **Q6.** Do you know Jack Sirianni, or have you heard of a reading app called Dewey? Yes / No / Not sure
> **FAIL on "Yes" and on "Not sure."** No adjudication, no exceptions.

> **Q7.** In the last three years, have you worked in any of the following? *(check all)* Product design or UX · User research · Bookselling · Book criticism or reviewing · Publishing · None of these
> **FAIL** on UX/product design, user research, bookselling, or book criticism. Publishing alone does not fail; flag it.

> **Q8.** Are you 18 or over, and would you be willing to have a 45-minute in-person session audio-recorded? Yes to both / No
> **FAIL on No.**

> **Q9.** Name, email, and which of these times work for you. *(availability grid)*

**Screening throughput:** review in batches once daily. Invite in the order received, subject to the Q3 quota. Send the invite email within 24 hours of the screener submission — beyond 48 hours the acceptance rate roughly halves.

### 2.3 Session logistics

| | |
|---|---|
| **Format** | **In person.** Remote is a documented fallback, capped at **6 of 20**, and the mode is recorded as a covariate on every participant. |
| **Duration** | 45 minutes hard stop. Book the room for 75 to allow reset. |
| **Location** | A quiet room with a table you can lay 4 sheets side by side on. A library study room or a co-working meeting room. Not a café — the card layout needs a clean table and the audio needs a quiet room. |
| **Recording** | **Audio only.** Phone or handheld recorder on the table, visible. No video, no screen capture, no photograph of the participant. Backup recorder running on a second device. |
| **Retention** | Audio deleted after transcription and coding, no later than the combined readout. Transcripts pseudonymised at P-01…P-20 and retained. Stated in the consent form. |
| **Payment** | **$25 gift card to an independent bookshop, handed over at the end of the session regardless of what the participant chose or declined to choose.** Stated in the invitation email and again at the start of the session, in those words, so it never reads as contingent. |
| **Moderator** | One person. No observer in the room. A second person in the room converts an articulation task into a performance. |

**Materials per participant (printed the night before, in one labelled envelope):**

1. Consent form ×1 (2 pages, one signed copy retained, one carbon/photo to participant)
2. **Reader sheets ×4** — A, B, C, D — colour, single-sided, letter/A4 portrait
3. **Card sets ×4** — one set of three cards per reader, colour, cut to 5″ × 7″ card stock. **Twelve cards printed; three used.** Each set is in its own paper sleeve labelled A/B/C/D on the back only.
4. **The Reading Next slot card ×1** — 5″ × 7″, pre-filled in the same typeface as the condition cards with the participant's own Q4 book
5. Moderator run sheet ×1, with the participant's assignment row (π, L, S) pre-written at the top
6. Prep record sheet ×1 (overlap counts per reader, the three pool books, the evidence triples, truth-audit ticks)
7. Debrief and attribution handout ×1 — the four source URLs, printed
8. Pen, blank paper (participants sometimes want to write), $25 gift card

**Room setup, done before the participant enters:**

- Table cleared. Recorder placed centre-far, visible.
- The **Reading Next slot card face-up in the centre of the table**, alone. It stays there the entire session.
- All four reader sheets face-down in a stack at the moderator's left, in the order given by the participant's sequence S.
- All four card sleeves face-down at the moderator's right, out of the participant's reading distance.
- The debrief handout in the envelope, out of sight.

### 2.4 Founder prep, per participant (~25 minutes) — the exact sequence

Run this the day before the session, never the morning of.

1. **Transcribe the intake list.** 20–25 titles into the overlap spreadsheet's participant column. (6 min)
2. **Compute overlap.** The sheet returns shared-title counts against all 12 panel readers. (0 min — it is a formula)
3. **Assign R1–R4.** R1/R2/R3 = the three highest overlaps. R4 = the smallest overlap **≥3**. If two readers tie, take the one with fewer total titles on the shelf. Record all four raw counts on the prep sheet. (2 min)
4. **Build the candidate pool per reader.** For each of R1–R4, list that reader's titles the participant has **not** read and has **not** named as their next book. Take the top three by the reader's own rating/rank. These are B1, B2, B3 for that reader. (5 min)
5. **Verify unread.** Cross-check B1–B3 against the participant's intake list *and* against the "books I started and put down" question from intake. Any hit → drop and take the next candidate. (3 min)
6. **Fix the evidence triple per book.** For each of B1, B2, B3: the three titles that are on both the participant's list and that reader's shelf, chosen as the three with the highest combined salience (the participant named it unprompted at intake > the reader rated it top > everything else). **The evidence triple is attached to the book slot and does not change with condition.** (4 min)
7. **Truth audit** — §2.6. (3 min)
8. **Print and sleeve.** (2 min)

### 2.5 The three conditions — exact card specification

All three cards are the same size, the same stock, the same typeface, the same margins, and **the same number of typeset lines below the cover**. Only the content of those lines changes.

**Fixed skeleton, identical across P/N/G:**

```
┌──────────────────────────────────────┐
│                                      │
│        [ COVER IMAGE  55 × 84 mm ]   │   ← identical dimensions all conditions
│                                      │
│   TITLE IN 14pt SEMIBOLD             │
│   Author name, 11pt regular          │
│                                      │
│   ●●●   ── line 1 of masthead ──     │   ← ● = 28 mm circle, always present
│   28mm  ── line 2 of masthead ──     │
│                                      │
│   ── header line ──                  │
│   ── body line 1 ──                  │   ← always exactly three body lines
│   ── body line 2 ──                  │
│   ── body line 3 ──                  │
│                                      │
└──────────────────────────────────────┘
```

**Condition P — named person**

| Element | Content |
|---|---|
| Circle | The reader's published byline photograph, 28 mm, circular crop |
| Masthead 1 | `Dan Kois` |
| Masthead 2 | `Rated this 5 out of 5` — **or**, for a rank-only source, `Their #2 book of the year` |
| Header | `You and Dan Kois have both read:` |
| Body 1–3 | The three evidence titles, `Title — Author` |

**Condition N — same evidence, no person**

| Element | Content |
|---|---|
| Circle | Neutral 10% grey disc, 28 mm. No icon, no silhouette, no initials. |
| Masthead 1 | `Your library` |
| Masthead 2 | `Matched on what you've read` |
| Header | `You have read:` |
| Body 1–3 | **The identical three evidence titles from the same book slot.** |

**Condition G — impersonal framing, no named books**

| Element | Content |
|---|---|
| Circle | Neutral 10% grey disc, 28 mm — identical to N |
| Masthead 1 | `Widely recommended` |
| Masthead 2 | `A general recommendation` |
| Header | `Why you're seeing this:` |
| Body 1–3 | One of the three pre-registered framings below, always exactly three lines, **no book titles** |

**Pre-registered G framings.** Pick the first one that is verifiably true of the book.

- **G-a** — `In print for more than [N] years / and still reissued by a major / publisher today.`
- **G-b** — `Shortlisted for the [Prize] in [Year]. / Translated into more than / [N] languages.`
- **G-c** — `Named a book of the year by / three or more national / publications on publication.`

If none is verifiably true, the book is **ineligible for slot G** and is swapped at prep.

### 2.6 The truth audit — run before every print

Tick every row on the prep sheet. An unticked row means the card does not get printed.

| Claim | Verification |
|---|---|
| Reader has read the book | The title appears on the published source list. Cite the line. |
| Reader's rating / rank | Taken verbatim from the source. Never derived, never rounded, never inferred. |
| Participant has read all three evidence titles | Appears on the intake transcript. |
| Reader has read all three evidence titles | Appears on the published source list. |
| Participant has **not** read the recommended book | Not on the intake list; not on the "started and put down" list; confirmed again verbally in Block D. |
| N's header (`You have read:`) is true | Same check as row 3. |
| G's three-line fact | Two independent sources, both URLs written on the prep sheet. Prize sites and publisher catalogues only. Not a retailer blurb. |
| P, N, G are the same tier | All three books in the same popularity tier, assigned at panel-build time. |
| P, N, G occupy the same vertical extent | Physically stack the three printed cards and check the baselines align. |

### 2.7 Session run sheet — minute by minute

Timings are elapsed from the participant sitting down. Bracketed text is instruction; quoted text is said verbatim.

---

**0:00 – 0:03 — Consent and framing**

> "Thanks for coming. This will take forty-five minutes and I'll stop us at forty-five whether or not we're finished. I'm going to record the audio so I don't have to take notes while you're talking — I'll delete the recording once it's typed up, and your name won't be on anything. Is that okay?"

[Wait for a spoken yes. Start the recorder. Then:]

> "Two things before we start. First — there are no right answers here and I have no stake in what you say. Second — the gift card is yours at the end regardless of what you tell me, including if you tell me all of this is useless. That's a genuinely useful outcome for me."

[Signed consent form.]

---

**0:03 – 0:05 — The Reading Next slot**

[Point to the card already on the table.]

> "When we spoke, you said the next book you were planning to read was *[Title]*. That's what's on this card. This card is going to stay on the table for the whole session. At the end I'm going to ask you a question about it. Is *[Title]* still what's next for you?"

[If yes, proceed. If no — they've started it, or changed their mind — see §2.10, scenario D.]

> "Good. Leave it there."

---

**0:05 – 0:25 — Legibility block. Four readers, five minutes each.**

[Deal the four sheets one at a time, in sequence order S. Never lay two out at once. Each sheet stays in front of the participant until the next is dealt on top.]

For each reader, verbatim:

> "This is one person's shelf. Everything on it is a book they've actually read, and the number in the corner is how they rated it. The dots mark books you've read too. Take a minute and look at it. Don't talk yet."

[**Silence for 60 seconds. Do not fill it.** Then, in this fixed order:]

> **1.** "Say what you're seeing. Anything."
> **2.** "What kind of reader is this?"
> **3.** "Is there anything on here that surprises you, or doesn't fit with the rest?"
> **4.** "Does this shelf feel familiar at all — does it remind you of a specific person, or of a list you've seen somewhere?" [**Recognition probe. Record verbatim. Do not explain the question.**]

[~4 minutes of talk per reader. If the participant dries up after 45 seconds, ask **only**: "What else?" — once. Then move on. **Do not offer vocabulary. Do not say "so you'd say they're literary?"** The absence of vocabulary is the finding.]

---

**0:25 – 0:31 — The articulation and prediction task**

[Fan all four sheets out so all are visible.]

> "Of these four people, whose shelf would you most want to see more of? Not who's most like you — whose shelf you'd want to keep looking at."

[Record. Then, on the chosen reader:]

> **1.** "Describe this person to me as if I'd never seen the shelf. I'm going to write down what you say."
> **2.** "Name a book that isn't on this shelf that you think they'd love. And tell me why you think that."
> **3.** "Now name a book they'd hate, or would put down at page forty. Same — why."
> **4.** "How confident are you in those two guesses? Would you bet the gift card on either?"

[Q2 and Q3 are the stop-condition instrument. Get an actual named book or record explicitly that they could not produce one. Do not accept a genre. If they name a genre, ask once: "A specific book." If they still can't, record `no prediction`.]

---

**0:31 – 0:40 — The choice**

[Take out the card sleeve for the chosen reader. Lay the three cards out left to right in the participant's layout order L. Do not name the conditions. Do not say the word "recommendation."]

> "These are three books. All three are books you haven't read — is that right, for all three?" [**Verify aloud. If one is a hit, see §2.10 scenario E.**]

> "Now — this card." [Tap the Reading Next slot.] "There's one slot, and *[Their Book]* is in it. If you want one of these three books to be the next book you read, it has to come out and one of these has to go in. If you'd rather keep *[Their Book]*, that's completely normal and it's what I'd expect most people to do. There's no prize and nobody's buying you anything either way."

> "Take as long as you want. Tell me when you've decided, and then tell me why."

[**Say nothing while they decide.** Record the choice and the reason. Then:]

> **1.** "What was the closest one you didn't pick?"
> **2.** "What would have had to be different on that card for you to pick it instead?"
> **3.** "Was there anything on any of these three that you didn't believe?"
> **4.** [If the P card was named] "Had you heard of *[Name]* before today?" [**Record. Tag `NameRecognised`.**]

---

**0:40 – 0:45 — Debrief, disclosure, payment**

> "Last thing, and this is me telling you rather than asking. Those four shelves are real. They're four real people who publish their book lists in public — critics and readers whose lists are on the internet under their own names. I didn't make any of them up, I didn't change any of them, and none of them have anything to do with me or know this is happening. Here are the four sources."

[Hand over the printed handout with the four URLs.]

> "Does that change anything you said? Would you have answered any of it differently if you'd known?"

[Record. Then:]

> "This is for a reading app I'm working on called Dewey. Nothing you've seen today is the app — it's paper on purpose, because I wanted to know whether the idea works before I build anything. If you want, I'll send you what I find. Here's the gift card. Thank you."

[**Stop the recorder. Write the post-session note before you leave the room** — three lines: what surprised you, what you'd change, anything you said that you shouldn't have.]

### 2.8 Counterbalancing — the actual assignment table for a 20-person run

**Three things rotate independently.**

**Book-slot → condition permutations (π).** B1/B2/B3 are the three pool books for the chosen reader, ranked by that reader's own rating. Since the pool books are participant-specific, the rotation is over *slot*, not title.

| | B1 | B2 | B3 |
|---|---|---|---|
| π1 | P | N | G |
| π2 | P | G | N |
| π3 | N | P | G |
| π4 | N | G | P |
| π5 | G | P | N |
| π6 | G | N | P |

**Table layout, left to right (L).**

| | left | centre | right |
|---|---|---|---|
| L1 | P | N | G |
| L2 | P | G | N |
| L3 | N | P | G |
| L4 | N | G | P |
| L5 | G | P | N |
| L6 | G | N | P |

**Reader presentation sequence (S) — Williams square, order 4, balanced for carryover.** A = R1 (highest overlap), B = R2, C = R3, D = R4 (thinnest, ≥3).

| | 1st | 2nd | 3rd | 4th |
|---|---|---|---|---|
| S1 | A | B | D | C |
| S2 | B | C | A | D |
| S3 | C | D | B | A |
| S4 | D | A | C | B |

**The assignment table. Print this. Write the row on each participant's run sheet at prep time.**

| P# | π (slot→condition) | L (left→right) | S (reader order) |
|---|---|---|---|
| P-01 | π1 — B1=P B2=N B3=G | L1 — P N G | S1 — A B D C |
| P-02 | π2 — B1=P B2=G B3=N | L2 — P G N | S2 — B C A D |
| P-03 | π3 — B1=N B2=P B3=G | L3 — N P G | S3 — C D B A |
| P-04 | π4 — B1=N B2=G B3=P | L4 — N G P | S4 — D A C B |
| P-05 | π5 — B1=G B2=P B3=N | L5 — G P N | S1 — A B D C |
| P-06 | π6 — B1=G B2=N B3=P | L6 — G N P | S2 — B C A D |
| P-07 | π1 | L2 — P G N | S3 — C D B A |
| P-08 | π2 | L3 — N P G | S4 — D A C B |
| P-09 | π3 | L4 — N G P | S1 — A B D C |
| P-10 | π4 | L5 — G P N | S2 — B C A D |
| P-11 | π5 | L6 — G N P | S3 — C D B A |
| P-12 | π6 | L1 — P N G | S4 — D A C B |
| P-13 | π1 | L3 — N P G | S2 — B C A D |
| P-14 | π2 | L4 — N G P | S3 — C D B A |
| P-15 | π3 | L5 — G P N | S4 — D A C B |
| P-16 | π4 | L6 — G N P | S1 — A B D C |
| P-17 | π5 | L1 — P N G | S2 — B C A D |
| P-18 | π6 | L2 — P G N | S3 — C D B A |
| P-19 | π1 | L4 — N G P | S4 — D A C B |
| P-20 | π2 | L5 — G P N | S1 — A B D C |

**Balance check, stated so it can be audited:**

- **Reader sequence:** S1, S2, S3, S4 each appear exactly 5 times. Every reader occupies every ordinal position exactly once per square. **Balanced.**
- **Layout:** L4 and L5 appear 4 times, the rest 3. Leftmost condition: P 6, N 7, G 7. **Balanced within one.**
- **Permutation:** π1 and π2 appear 4 times, the rest 3. Condition in slot B1: P 8, N 6, G 6. **Imbalanced by 2 — this is the residue of 20 not dividing by 6 and it is not fixable at N=20.** It is disclosed, not smoothed. It means the highest-rated pool book carries P slightly more often than chance. If the result is P-favouring by a margin of ≤2, say so in the readout in exactly those words.
- **π × S independence:** every π value spans at least three distinct S values; π1 and π2 span all four. Reader order and condition order are decorrelated.

**Replacement rule.** If a participant is excluded, the replacement **takes the excluded participant's row**, not the next row. Never renumber. This preserves the balance table exactly.

### 2.9 Coding the articulation — the stop-condition rubric

A participant's description of their chosen reader is coded **SPECIFIC** if and only if it contains **both**:

**(a) A non-genre, non-rating attribute.** An attribute that could not be recovered from a genre label or a star average.

| Fails (a) | Passes (a) |
|---|---|
| "She reads literary fiction." | "She reads books where nothing happens and the sentences have to carry it." |
| "He likes highly-rated books." | "He seems to trust a book more when it's translated." |
| "Wide-ranging taste." | "Everything here is someone leaving a place they can't go back to." |
| "Very well-read." | "She'll finish a book she's arguing with. Nobody rates a book they hated a 4." |

**(b) A falsifiable prediction.** A **named specific book** the reader would love or bounce off, with a reason tied to (a). "Something by Sally Rooney" fails. "*Beautiful World, Where Are You* — she'd finish it and rate it a 3, because she wants the interiority without the emails" passes.

**Procedure.** Two coders, blind to which reader and to the participant's card choice, working from the transcript with all condition information stripped. Code independently. Disagreements are resolved by a single rule:

> **If either coder can state the specific outcome that would prove the description wrong, it counts.**

Report inter-coder agreement as a raw count of agreements out of 20, not as a kappa.

**Stop condition:** **≤8 of 20 SPECIFIC → stop.** **≥12 of 20 → clears the gate** (memo §10, evidence item 1). **9, 10, or 11 is a genuine ambiguity and must be reported as one**, with the transcripts attached and no interpretation attempted from the count alone.

### 2.10 When things go wrong

**A. The participant has fewer than 3 shared books with every panel reader.**

Caught at prep, the day before, never in the room.

1. **Widen the intake capture first.** The intake call takes 25 titles, not 20, plus "five books you'd defend to anyone" and "five you read a long time ago that stuck." Re-run the overlap with the full set.
2. **If still <3 across all 12 panel readers:** source one additional panel list from that participant's dominant Q3 category before the session. Budget 30 minutes. Add it to the panel permanently — it will help the next participant too.
3. **If that still fails:** run the session as **legibility-only**. Blocks A, B, C, and the debrief. No card block. Pay in full. Their data enters the legibility denominator and the stop-condition count; it does not enter the choice counts, and the choice counts' denominator is stated as the actual number (e.g. "of the 18 who reached the choice block").
4. **Log every occurrence on a running tally.** If this happens to more than **three** participants, stop treating it as an operational annoyance. It is memo §8.3 arriving early: *taste may be illegible at realistic density because there is no overlap at all to read.* Escalate it into the readout as a finding, not a footnote.

**B. The participant recognizes a source.**

Three distinct cases, three different responses.

| When | Response |
|---|---|
| **Block B, recognition probe** — "this is somebody's best-of-year list, isn't it" or names the person | Say: *"Interesting — say more about what made you think that."* Do not confirm or deny. **Exclude that reader's legibility data for this participant.** If it was the reader they then choose, ask them to choose again from the remaining readers, and note the substitution. |
| **Block D, on seeing the name on the P card** | Do not interrupt. Complete the block. Ask the closing probe: *"Had you heard of [Name] before today?"* Record. **Tag the participant `NameRecognised=TRUE` and report their choice separately.** Do not discard it — the count is reported both with and without them. |
| **Debrief** — "oh, I follow her" | Record. Ask the disclosure question anyway. No exclusion; the data was collected clean. |

If **more than five of 20** recognize a source, the panel is too famous. Replace the two most-recognized lists with public rated shelves from non-public figures for any remaining sessions, and report the panel change with the session numbers it took effect on.

**C. The participant refuses the displacement.**

Distinguish two behaviours. Keeping their own book is **the null action and is not a refusal** — it is a valid, expected, pre-registered outcome.

A refusal is: *"I'd read all of them,"* *"I don't work like that,"* *"this isn't a real choice."* Response, verbatim, once:

> "That's fair, and I'd probably say the same. But there is one slot. If I made you put one thing in it right now — including keeping *[Their Book]* — what goes in?"

If they still refuse:

> "Okay. Then tell me what's wrong with the question."

Record `Choice = REFUSED` and take the full explanation. **Report refusals as their own count.** Never collapse them into "kept own book" — that would convert an instrument failure into a result. If refusals reach **4 of 20**, the instrument is too artificial and memo §9 row 7 applies: change the instrument once and re-run, do not reinterpret.

**D. The stated next book is no longer next.**

At Block A they say they've already read it or changed their mind. Do not improvise a substitute in the room — a book chosen thirty seconds ago is not a commitment. Say:

> "No problem. What's next now?"

Write the new title on a blank slot card in the same hand and typeface-adjacent block letters, in front of them. Record `SlotSubstituted=TRUE` and report those participants separately. If this happens to more than four, note it plainly: the next-book intention has a half-life shorter than one week, which is itself relevant to the memo's §2 reason #1.

**E. A pool book turns out to be already read.**

Caught by the verify-aloud line in Block D. Pull the card, apologise briefly (*"my mistake"*), and substitute the pre-printed **spare** card — prep prints a fourth card per reader for exactly this. The spare carries the same condition as the card it replaces. If no spare is available, run the choice with two cards and record `ChoiceN=2` and which condition was missing. Never re-letter the conditions mid-session.

**F. Recording fails.**

The backup recorder is the answer, which is why there are two. If both fail, stop the session at the end of the current block, tell the participant, pay them, and ask permission to re-book. Do not reconstruct an articulation transcript from memory. A remembered quote is not a transcript and the stop condition rests on transcripts.

**G. The participant asks "is this your app?" mid-session.**

> "I'll tell you everything at the end — I promise I'm not hiding anything interesting. If I answer now it'll change what you say and then the last twenty minutes are wasted."

Then answer fully at debrief.

### 2.11 Moderator pre-session checklist

Print one per session. Tick in ink. An unticked box is a stop.

**Night before**
- ☐ Intake list transcribed, 20+ titles, into the overlap sheet
- ☐ Overlap computed; R1/R2/R3/R4 assigned; **R4 overlap is ≥3** and the raw number is written on the prep sheet
- ☐ All four raw overlap counts written on the prep sheet
- ☐ Pool books B1–B3 selected per reader, plus one spare each
- ☐ Every pool book verified against the intake list **and** the started-and-abandoned list
- ☐ Evidence triple fixed per book slot and written on the prep sheet
- ☐ **Truth audit complete — all nine rows ticked (§2.6)**
- ☐ G framing verified against two sources; both URLs on the prep sheet
- ☐ Cards printed, cut, sleeved by reader; sleeve labels on the back only
- ☐ Reader sheets printed; **no names, no photos, no annotations anywhere on them**
- ☐ Slot card printed with the participant's own Q4 title
- ☐ Printed cards stacked and baseline-checked: P, N, G occupy identical vertical extent
- ☐ Run sheet has the participant's π / L / S row written at the top
- ☐ Debrief handout has the four correct source URLs for *this participant's* four readers

**Thirty minutes before**
- ☐ Room booked, quiet, table clear
- ☐ Both recorders charged, tested with a 10-second sample played back
- ☐ Consent forms ×2, pen, blank paper
- ☐ Gift card in the envelope
- ☐ Slot card face-up in the centre of the table
- ☐ Reader sheets face-down at the moderator's left, **in sequence order S**
- ☐ Card sleeves face-down at the moderator's right, out of reading distance
- ☐ Phone silenced and face-down, not on the table
- ☐ Previous participant's materials removed from the room entirely

**Ten seconds before you speak**
- ☐ You know the participant's first name
- ☐ You know their stated next book
- ☐ You have read the two "do not do" lines: **do not supply vocabulary; do not fill silence.**

---

# PART B — EXPERIMENT 2: THE PROVENANCE STUDY

## 3. Provenance Study protocol

Design per memo §6 (Experiment 2) and §8.2. Four weekly digests, three arms **within** each digest, same book pool, only the true fact surfaced varies. The full teardown at `s3 §3.4` is not present in this repository; where detail was required beyond the memo's summary it is specified here and flagged as **[specified here]**.

### 3.1 Structure

| | |
|---|---|
| **N** | 30 enrolled, ≥20 completers |
| **Elapsed** | 5 weeks of participant contact: intake week, then 4 digest weeks, then exits |
| **Digest** | 6 books per participant per week — **2 in P, 2 in N, 2 in G** |
| **Neighbours** | **Other participants.** Real people, real libraries, real ratings, with consent. The founder has no record in the base and therefore cannot be assigned. |
| **Burden** | 20-minute intake + ~60 seconds per week |
| **Primary outcome** | **Verified starts.** Saves are recorded and are never a success measure. |

### 3.2 Recruiting — strangers, hostile by design

**Inclusion:** 18+, 10–30 books finished in the last 12 months, can list at least 15 books they have read with a rating, consents to their first name + last initial + ratings being shown to other participants in the study, consents to supplying photo or screenshot evidence, available for a 20-minute video or phone call.

**Hard exclusions:** knows the founder or has heard of Dewey; UX/product research or design in the last three years; names, or is named by, another enrolled participant.

| Channel | Approach | Clicks | Screener completions | Pass | Intake booked | Attend | Cost |
|---|---|---|---|---|---|---|---|
| **r/books + r/suggestmeabook** | **Ask the moderators first.** Post in the weekly self-promo/research thread if one exists; otherwise a modmail request. A post that gets removed costs the channel permanently. | 120 | 55 | 30 | 18 | 15 | $0 |
| **Three book Discords** | Message the server owner, not the channel. Litfic, SFF, and classics servers — three taste communities, not three of the same. | 40 | 20 | 12 | 8 | 7 | $0 |
| **Bookstagram replies** | Reply to ~60 recent `#currentlyreading` posts. **Lowest-yield channel in the plan and the most likely to be read as spam.** Reply to the post's content first, one sentence, then the link. | 25 | 10 | 6 | 4 | 3 | $0 |
| **Books newsletter classified** | One paid classified line in a mid-size books Substack | 250 | 90 | 45 | 12 | 10 | $150 |
| **Total** | | **435** | **175** | **93** | **42** | **35** | **$150** |

Enrol **30 from 35 attendees.** The five surplus are the buffer against no-shows and cross-recognition exclusions.

**Hostility is a feature and must be preserved.** Do not recruit through anyone the founder knows. Do not soften the screener to keep numbers up. A friendly sample cannot fail a hypothesis.

### 3.3 The screener — provenance study

Same Q1, Q5, Q6, Q7 as §2.2 (books/year 10–30, recommends at least rarely, does not know the founder, not a researcher/designer). Plus:

> **Q10.** Could you list at least 15 books you've read and roughly how you'd rate each out of 5? We'd do this together on a 20-minute call. Yes / No / Not that many
> **FAIL on "No" and "Not that many."** The candidate pool is built from participant libraries; a 15-book floor is structural.

> **Q11.** If you started reading a book because of this study, would you be willing to send a photo or screenshot showing it — the book in your hand, a library hold, a receipt, or a sample opened on your e-reader? Yes / No
> **FAIL on No.** Self-report is not evidence and this must be established before enrolment, not asked for in week 3.

> **Q12.** Which reading communities are you active in online? Please list subreddits, Discord servers, or accounts. *(long text)*
> **No fail.** Used to seed the cross-recognition check.

> **Q13.** Are you willing for your first name and last initial, and your ratings of books you've read, to be shown to a small number of other people in this study? Your email, full name, and anything else stay private. Yes / No
> **FAIL on No.** Without this there is no P arm.

> **Q14.** For four weeks you'd get one email a week and spend about a minute on it. Can you commit to that? Yes / No / Probably
> **FAIL on No.** "Probably" passes and is flagged.

### 3.4 Intake call structure — 20 minutes

Same structure for both studies except where noted. Video or phone. Record with consent. Shared screen is not needed; the founder types into Airtable directly.

| Min | Block | Verbatim opening |
|---|---|---|
| 0–2 | **Consent and framing** | "This is a study about how people decide what to read next. I'm going to ask you for a list of books you've read and how you'd rate them, and then for four weeks I'll email you a short list of suggestions once a week. You'll spend about a minute a week on it. I'm not selling you anything and there's no app to install." |
| 2–4 | **Consent to be a neighbour** *(provenance only)* | "One thing I want to be explicit about. Some of the suggestions other people in this study get will say *[Your first name and last initial] rated this 5 out of 5.* That's the whole point of the study. Your email and your full name are never shown. Are you comfortable with that?" [**Spoken yes required. Tick `ConsentProvenance`.**] |
| 4–14 | **The library** | "Tell me books you've read. Start with anything — the last few, then whatever comes. I'll type. When you slow down I'll prompt you." [Target 25. Floor 15. For each: title, author, rating out of 5. **Do not suggest titles.** If they stall: "What did you read on your last holiday?" / "What's the book you've reread?" / "What did you read in your twenties that stuck?"] |
| 14–16 | **The abandoned list** | "Now the opposite — what have you started in the last couple of years and not finished?" [Critical: these must never appear in a digest.] |
| 16–18 | **The next book** | "What's the next book you're planning to read? One specific title." [**Card study: this is the pre-fill for the slot card.** Provenance: this is the baseline and is excluded from all digests.] |
| 18–20 | **Cross-recognition and logistics** *(provenance only)* | "Last thing — do you know anyone else who might be doing this? Any names or handles from the communities you listed?" [Free text into `NeighbourExclusions`.] "You'll get the first email on [date]. Reply to that address any time — it's me, not a system." |

### 3.5 Airtable base schema

Base name: **`Dewey Provenance Study`**. Seven tables. Buildable in under an hour by one person. Free plan is sufficient at this record count; a paid seat is budgeted only as contingency.

**Table 1 — `Participants`**

| Field | Type | Notes |
|---|---|---|
| `PID` | Single line text | **Primary.** `P-01` … `P-30` |
| `DisplayName` | Single line text | First name + last initial. **This is the only name that ever appears in a digest.** |
| `Email` | Email | |
| `Avatar` | Attachment | Optional. If absent, P renders initials in the same circle. Log which. |
| `Status` | Single select | Screened · Intake booked · Enrolled · Active · Withdrawn · Completed |
| `RecruitChannel` | Single select | r/books · Discord · Bookstagram · Newsletter |
| `RecruitSubchannel` | Single line text | The specific server or thread. Used by the neighbour exclusion rule. |
| `IntakeDate` | Date | |
| `BooksPerYear` | Number (integer) | |
| `ConsentProvenance` | Checkbox | **Must be true to enrol.** |
| `ConsentPhoto` | Checkbox | |
| `KnowsFounder` | Checkbox | **Must be false.** |
| `NeighbourExclusions` | Link to `Participants` | Self-link. Bidirectional. |
| `ExclusionNotes` | Long text | Raw free text from intake Q, before it resolves to links |
| `StatedNextBook` | Link to `Books` | Baseline. **Never appears in a digest.** |
| `Library` | Link to `LibraryEntries` | |
| `Digests` | Link to `Digests` | |
| `WeeksCompleted` | Rollup | `COUNTA` of linked Digests where `CheckInReceived` is true |
| `VerifiedStarts` | Rollup | Count of linked DigestItems where `Outcome_StartVerified` is true |
| `IncentivePaid` | Currency | |

**Table 2 — `Books`**

| Field | Type | Notes |
|---|---|---|
| `Title` | Single line text | **Primary.** Include author in the string if two books share a title. |
| `Author` | Single line text | |
| `Cover` | Attachment | |
| `PopularityTier` | Single select | T1 canonical · T2 well-known · T3 mid · T4 obscure. **Hand-set once, at pool build.** |
| `FirstPubYear` | Number (integer) | |
| `Form` | Single select | Novel · Stories · Nonfiction · Memoir · Poetry · Essays |
| `EditorialFact` | Long text | The exact three lines used in arm G |
| `EditorialSource1` | URL | |
| `EditorialSource2` | URL | |
| `G_Eligible` | Checkbox | True only when both sources are filled and checked |
| `LibraryEntries` | Link | |
| `DigestItems` | Link | |

**Table 3 — `LibraryEntries`** — one row per participant × book. ~750 rows.

| Field | Type | Notes |
|---|---|---|
| `Key` | Formula | `{Participant} & " — " & {Book}` — **primary** |
| `Participant` | Link to `Participants` | |
| `Book` | Link to `Books` | |
| `Status` | Single select | Read · Reading · **Abandoned** · Want to read |
| `Rating` | Number (1 dp, 0–5) | Blank unless Status = Read |
| `Source` | Single select | Intake · Weekly check-in · Exit |
| `DateRecorded` | Date | |

**Table 4 — `Digests`** — one row per participant per week. 120 rows.

| Field | Type | Notes |
|---|---|---|
| `DigestKey` | Formula | `{PID} & "-W" & {Week}` — **primary** |
| `Participant` | Link | |
| `Week` | Number | 1–4 |
| `SendDate` | Date | |
| `PageURL` | URL | The published Google Doc |
| `Items` | Link to `DigestItems` | Exactly 6 |
| `CheckInReceived` | Checkbox | |
| `CheckInDate` | Date | |
| `Week1ArmInSlot1` | Single select | P · N · G. Used by the slot-order constraint. |

**Table 5 — `DigestItems`** — **the unit of analysis.** 720 rows.

| Field | Type | Notes |
|---|---|---|
| `ItemKey` | Formula | `{DigestKey} & "-" & {SlotPosition}` — **primary** |
| `Digest` | Link | |
| `Participant` | Lookup via Digest | |
| `Week` | Lookup via Digest | |
| `Book` | Link to `Books` | |
| `Arm` | Single select | **P · N · G** |
| `SlotPosition` | Number | 1–6 |
| `Tier` | Lookup via Book | Used to verify tier-matching held |
| `NeighbourShown` | Link to `Participants` | **P only.** Blank in N and G. |
| `NeighbourRating` | Number (1 dp) | **P only.** Copied from the neighbour's `LibraryEntries` row. |
| `Evidence1` `Evidence2` `Evidence3` | Link to `Books` ×3 | **The shared triple. Identical for a given book regardless of arm.** Populated for P and N. Blank for G. |
| `FramingTextRendered` | Long text | **The exact text sent.** Paste it back after assembly. This is the audit trail. |
| `TruthAudit` | Checkbox | Ticked before send. **Unticked = do not send.** |
| `Outcome_Saved` | Checkbox | Recorded. **Never a success measure.** |
| `Outcome_StartClaimed` | Checkbox | Self-report |
| `Outcome_StartVerified` | Checkbox | **The outcome.** |
| `EvidenceType` | Single select | Physical photo · Library hold · Purchase receipt · Sample opened · E-reader shelf · None |
| `EvidenceFile` | Attachment | |
| `Adjudication` | Single select | Accepted · Rejected · Pending |
| `AdjudicationNote` | Long text | Written for every Rejected |

**Table 6 — `SelectionLog`** — pre-registration audit trail. One row per participant per week.

| Field | Type |
|---|---|
| `RunKey` | Formula, primary |
| `Participant` · `Week` | Link · Number |
| `Seed` | Number |
| `CandidatePoolJSON` | Long text |
| `AssignmentJSON` | Long text |
| `RunAt` | Created time |
| `ManualOverride` | Checkbox |
| `OverrideReason` | Long text — **required whenever `ManualOverride` is true** |

**Table 7 — `Recruiting`**

| Field | Type |
|---|---|
| `ScreenerID` | Autonumber, primary |
| `Channel` · `Subchannel` | Single select · Single line text |
| `SubmittedAt` | Created time |
| `BooksPerYear` | Number |
| `PassFail` | Formula implementing §3.3 |
| `FailReason` | Multiple select |
| `Invited` · `IntakeBooked` · `Enrolled` | Checkbox · Date · Link to `Participants` |

**Two views to create immediately:**
- `DigestItems` grouped by `Arm`, filtered to `Adjudication = Accepted` — this is the result table.
- `DigestItems` filtered to `TruthAudit = unchecked` — this is the pre-send blocker.

### 3.6 The pre-registered selection pseudocode

**Frozen before Digest W1 is assembled.** Every run writes a `SelectionLog` row. Every manual override writes a reason.

```
CONSTANTS
  ITEMS_PER_DIGEST     = 6
  ITEMS_PER_ARM        = 2
  MIN_SHARED           = 3      # participant and neighbour must share >= 3 read titles
  MIN_NEIGHBOUR_RATING = 4.0
  MAX_ITEMS_PER_NEIGHBOUR_PER_DIGEST = 1
  MAX_ITEMS_PER_NEIGHBOUR_PER_STUDY  = 3

SEED(week, p) = int(sha256("dewey-prov-2026|" + p.PID + "|W" + week).hexdigest()[:8], 16)

FUNCTION assemble_digest(p, week):
  rng = RNG(SEED(week, p))

  # ---- 1. NEIGHBOUR SET -------------------------------------------------
  neighbours = []
  FOR q IN Participants WHERE q.Status IN (Enrolled, Active) AND q.PID != p.PID:
      IF q IN p.NeighbourExclusions:                CONTINUE
      IF q.RecruitSubchannel == p.RecruitSubchannel: CONTINUE   # same server/thread
      IF q.ConsentProvenance != TRUE:                CONTINUE
      shared = |{b : status(p,b)=Read AND status(q,b)=Read}|
      IF shared < MIN_SHARED:                        CONTINUE
      neighbours.append((q, shared))
  # The founder has no Participants record, so cannot be selected. Assert anyway.
  ASSERT FOUNDER_PID NOT IN [q.PID for (q,_) in neighbours]

  # ---- 2. CANDIDATE POOL ------------------------------------------------
  # Everything is drawn from ONE pool. Arms differ only in which true fact is shown.
  pool = []
  FOR (q, shared) IN neighbours:
    FOR b IN q.Library WHERE status(q,b) = Read AND rating(q,b) >= MIN_NEIGHBOUR_RATING:
      IF b IN p.Library:                 CONTINUE   # read, reading, abandoned, or want-to-read
      IF b == p.StatedNextBook:          CONTINUE
      IF b IN items_shown_to(p, weeks < week): CONTINUE
      evidence = top3_shared_titles(p, q)          # deterministic: see below
      IF |evidence| < 3:                 CONTINUE
      pool.append({book:b, neighbour:q, rating:rating(q,b),
                   evidence:evidence, tier:b.PopularityTier})

  IF |pool| < 6: RAISE InsufficientPool(p, week)    # -> §3.9 fallback

  # top3_shared_titles is deterministic and identical across arms:
  #   sort shared titles by (participant named it unprompted at intake DESC,
  #                          neighbour rating DESC,
  #                          title ASC)
  #   take first 3

  # ---- 3. TIER MATCHING -------------------------------------------------
  # Pick two tiers that each have >= 3 distinct books available.
  # Each arm then receives exactly one book from each tier: arms are tier-matched
  # by construction, not by post-hoc balancing.
  tiers = [t for t in (T1,T2,T3,T4) if count_distinct_books(pool, t) >= 3]
  IF |tiers| < 2: RAISE InsufficientTierSpread(p, week)
  tier_a, tier_b = rng.sample(tiers, 2)

  triple_a = rng.sample(distinct_books(pool, tier_a), 3)
  triple_b = rng.sample(distinct_books(pool, tier_b), 3)

  # ---- 4. ARM ASSIGNMENT ------------------------------------------------
  arms = rng.shuffle([P, N, G])
  items = []
  FOR i IN 0..2:
      items.append(make_item(triple_a[i], arms[i]))
      items.append(make_item(triple_b[i], arms[i]))
  # Result: 2 items per arm, one from each tier. Guaranteed.

  # ---- 5. ARM CONSTRAINTS ------------------------------------------------
  FOR item IN items WHERE item.arm == G:
      IF item.book.G_Eligible != TRUE:
          swap item.book with an unused G_Eligible book of the SAME TIER from pool
          IF no such book: RAISE GIneligible(p, week)   # -> §3.9 fallback
      item.neighbour = NULL; item.rating = NULL; item.evidence = NULL

  FOR item IN items WHERE item.arm == N:
      item.neighbour = NULL; item.rating = NULL
      # evidence triple is RETAINED, identical to what P would have shown

  # Neighbour spread
  ASSERT no neighbour appears more than MAX_ITEMS_PER_NEIGHBOUR_PER_DIGEST in items
  ASSERT no neighbour exceeds MAX_ITEMS_PER_NEIGHBOUR_PER_STUDY across all weeks
  IF violated: resample step 3 with rng advanced; max 20 attempts, then RAISE

  # ---- 6. SLOT ORDER -----------------------------------------------------
  order = rng.shuffle(items)
  WHILE order[0].arm == p.digest[week-1].Week1ArmInSlot1:   # no repeat arm in slot 1
      order = rng.shuffle(items)
  ASSERT no two adjacent items share an arm; else reshuffle (max 20 attempts)

  # ---- 7. TRUTH AUDIT ----------------------------------------------------
  FOR item IN order:
      IF item.arm == P:
        ASSERT status(item.neighbour, item.book) == Read
        ASSERT rating(item.neighbour, item.book) == item.rating   # verbatim, never rounded
        ASSERT ALL(status(p, e) == Read for e in item.evidence)
        ASSERT ALL(status(item.neighbour, e) == Read for e in item.evidence)
      IF item.arm == N:
        ASSERT ALL(status(p, e) == Read for e in item.evidence)
      IF item.arm == G:
        ASSERT item.book.EditorialSource1 AND item.book.EditorialSource2
      ASSERT item.book NOT IN p.Library
      item.TruthAudit = TRUE

  LOG SelectionLog(p, week, SEED, pool, order)
  RETURN order
```

**Rendered framings — the exact strings, and the only three permitted.**

```
P:  {DisplayName} rated this {Rating} out of 5.
    You and {DisplayName} have both read:
      {Evidence1}, {Evidence2}, {Evidence3}.

N:  Based on your library.
    You have read:
      {Evidence1}, {Evidence2}, {Evidence3}.

G:  Widely recommended.
    {EditorialFact — exactly three lines, no book titles, two sources on file}
```

All three occupy the same block: one masthead line, one header line, three body lines, one image of identical dimensions. Identical typeface, size, leading, and colour. **The only variable is which true fact is surfaced.**

### 3.7 Weekly digest assembly — the procedure

Runs Monday. ~2.5 hours for 25 active participants. Digest lands Tuesday 07:00 local.

| Step | Action | Time |
|---|---|---|
| 1 | Export `LibraryEntries` and `Participants` to CSV. Paste into the Google Sheet tab `data`. | 5 min |
| 2 | The Sheet's `selection` tab implements §3.6 in formulas with a seeded pseudo-random column. Read off six rows per participant. **Paste the pool and the assignment back into `SelectionLog` before doing anything else** — logging after assembly is not pre-registration. | 20 min |
| 3 | The `render` tab concatenates each participant's six items into one text block using the three framing templates verbatim. | 5 min |
| 4 | Duplicate the Google Doc template `DIGEST-TEMPLATE` once per participant. Rename `W{n} — {PID}`. Paste the rendered block. Drop the six cover images in. | 4 min × 25 = **100 min** |
| 5 | **Truth audit pass.** Open the `TruthAudit = unchecked` Airtable view. Walk every item. Tick or fix. **A digest with an unticked item does not send.** | 20 min |
| 6 | File → Share → Publish to web, link-only, on each doc. Paste the URL into `Digests.PageURL`. | 10 min |
| 7 | Send 25 emails. Body is four lines: greeting, the link, the check-in link, one sentence saying replying is fine. **No subject-line urgency. No count. No "don't miss."** | 15 min |
| 8 | Set `Digests.SendDate`, `Week1ArmInSlot1`. | 5 min |

**Digest email body — verbatim template:**

> Subject: `Your week {n} list`
>
> Hi {First name},
>
> Here's this week's list: {PageURL}
>
> When you get a minute, this takes about sixty seconds: {CheckInFormURL}
>
> Reply to this email any time — it's me, not a system.
>
> Jack

**Two rules that protect the study from the founder:**
1. **The digest page contains nothing but the six items.** No welcome note, no editorial voice, no "I thought you'd like these." Any founder voice is a fourth, uncontrolled condition applied to all six.
2. **The founder never adjusts the selection because a result looks weak.** Overrides are for data errors only (a book that turns out to be already read, a neighbour who withdrew), and every one writes an `OverrideReason`.

### 3.8 The weekly check-in and what counts as a verified start

**Mechanism.** One Airtable form. The same URL every week, prefilled per participant via `?prefill_PID=P-07`. Linked in the digest email and in a single reminder.

**Form fields — six, in this order:**

1. `PID` — prefilled, hidden-ish, do not ask them to type it
2. **"Which week's list is this about?"** — single select, W1–W4
3. **"Did you start reading any of these? Tick all that apply."** — multi-select of the six titles + "None of them"
4. **"If you ticked one, show us."** — file upload, plus a short text field. Helper text, verbatim:
   > *A photo of the book, a screenshot of a library hold, a receipt, or a sample open on your reader. Anything with the book visible. We can't count it without one — not because we don't believe you, but because "I meant to" and "I did" look identical in a spreadsheet.*
5. **"Did you save any of these for later?"** — multi-select
6. **"Did you start any book at all this week that wasn't on the list?"** — short text

**Reminder cadence:** one reminder, Friday morning, one sentence. **Never two.** A second chase converts a research relationship into a nag and it will show up in the exit interviews.

**Evidence adjudication — Saturday, ~45 min/week.**

| Evidence | Accepted? | Requirement |
|---|---|---|
| Photograph of the physical book, in their hand or their home | **Yes** | The title must be legible. A stock cover image is a rejection. |
| Library hold or checkout confirmation | **Yes** | Title and a date visible |
| Purchase receipt or order confirmation | **Yes** | Title and a date visible |
| E-reader screenshot showing a sample or the book opened | **Yes** | Title visible; opened, not merely in the shop |
| Screenshot of the book in a "currently reading" shelf on any app | **Yes** | Title and shelf state visible |
| Library hold **placed** but not yet collected | **Yes, and flagged `HoldOnly`** | Reported both with and without. A hold is a stronger commitment than a save and weaker than a start; do not silently pick one. |
| A photograph of a shelf with the book on it | **No** | Owning is not starting |
| "I started it, I promise" | **No** | Record `Outcome_StartClaimed = TRUE`, `Outcome_StartVerified = FALSE`. **Report the claimed-minus-verified gap as its own number** — the size of that gap is the direct measurement of intent theater. |
| A save, a want-to-read, an add | **No** | `Outcome_Saved` only. **Saves are never a success measure.** |

**One appeal is permitted, once per participant.** If a participant disputes a rejection, ask for a different form of evidence. If none arrives, the rejection stands, and it is not held against them for payment.

### 3.9 Failure modes and fallbacks

| Failure | Response |
|---|---|
| `InsufficientPool` — fewer than 6 eligible candidates for a participant | Relax `MIN_NEIGHBOUR_RATING` to 3.5 for that participant that week and log it. If still short, send a **4-item digest with one item per arm plus one spare arm** and record `ShortDigest = TRUE`. **Never pad from outside the participants' libraries.** |
| `GIneligible` — no G-eligible book at the needed tier | Substitute a G-eligible book from the nearest tier and record the tier mismatch on the item. Do not fabricate an editorial fact. |
| A participant withdraws mid-study | Mark `Withdrawn`. **Their existing `LibraryEntries` remain available as neighbour evidence only if `ConsentProvenance` was given and they have not asked for removal.** If they ask, remove the rows and re-run affected digests. |
| Two enrolled participants discover each other | Add mutual `NeighbourExclusions`. Any already-sent P item naming one to the other is flagged `CrossRecognised` and reported separately. |
| Fewer than 20 completers | Report the actual number in the denominator. Do not extend the study to reach 20 — a 6-week arm and a 4-week arm are not the same study. |

### 3.10 Exit interview — 25 minutes, week 7

Video or phone. Recorded with consent. **Conducted before the founder looks at that participant's outcome data**, so the questions cannot be steered by what they did.

| Min | Block | Verbatim opening |
|---|---|---|
| 0–2 | **Frame** | "Four weeks, four lists. I want to know what it was actually like, including the boring parts. I have no stake in you having enjoyed it." |
| 2–7 | **Unprompted recall** | "Without looking anything up — what do you remember from any of the lists?" [**Do not name any book. Record what surfaces and in which arm it was.** Unprompted recall by arm is the cleanest memory measure in the study and it is free.] |
| 7–12 | **The starts** | "You started *[Title]*. Walk me through the actual moment. Where were you, what made you do it, and what did you do first?" [For each verified start. If none: "Was there one that came closest?"] |
| 12–16 | **The non-starts** | "There were a lot you didn't start. Was that because they weren't for you, or because of something else?" Then: "Was there one you meant to and didn't? What happened?" |
| 16–20 | **The mechanism — asked last, on purpose** | "Some of these had a person's name attached and some didn't. Did you notice?" [Record whether it is spontaneous or news.] "Did it make a difference? Tell me honestly if it didn't." Then: **"Was there anyone whose name you started paying attention to?"** [If yes, this is the trust-graph result arriving in a sentence.] |
| 20–23 | **The falsifier** | "Suppose I told you the names were fake. Would that change how you feel about the four weeks?" [The strongest available check on whether attribution was doing real work or was decorative. Then immediately: **"They were real. Everyone in this study is a real person and they consented."**] |
| 23–25 | **Close** | "Anything I should have asked and didn't?" Payment confirmation, deletion timeline, offer to send the findings. |

**Do not ask "would you use this app."** It is unanswerable, everyone says yes, and it is not a measurement.

---

# PART C — REPORTING, SCHEDULE, COST

## 4. Reporting standard — binding on both studies

**4.1 Counts only.** Every result is reported as *"14 of 20"* or *"9 of 18 verified starts."* Never a percentage. Never a decimal. Never a p-value, a confidence interval, a significance claim, or a chart with error bars.

**4.2 The disclaimer appears at the top of the readout, not the bottom, in these words:**

> This study cannot produce statistical significance and is not trying to. At N=20 a 14/20 split is inside the range twenty coin flips produce. Nothing here licenses a build decision on its own. What it can do is kill a hypothesis, produce sentences, and tell us what to build next in order to be wrong faster.

**4.3 Never report saves as a success.** Saves appear in exactly one place: alongside verified starts, as the measurement of the gap between them.

**4.4 Pre-registered outcome table.** Fill this and nothing else.

| Card study | Count |
|---|---|
| Sessions completed | / 20 |
| Reached the choice block | / 20 |
| **SPECIFIC articulations (stop condition)** | **/ 20** |
| Chose P / N / G / kept own book / refused | five numbers summing to 20 |
| R4 legible (SPECIFIC on R4 when R4 was chosen or described) | / (times R4 shown) |
| Source recognized | / 20 |
| Slot substituted at session | / 20 |
| Zero-overlap exclusions | / 20 |

| Provenance study | Count |
|---|---|
| Enrolled / completers | / 30 |
| Digest items sent, by arm | P / N / G |
| **Verified starts, by arm** | **P / N / G** |
| Claimed but unverified starts, by arm | P / N / G |
| Saves, by arm | P / N / G |
| Holds-only, by arm | P / N / G |
| Unprompted recall at exit, by arm | P / N / G |
| Participants who named a specific neighbour at exit | / completers |

Then read the result straight into memo §8.2's pattern table and §9's decision tree. **Do not write a paragraph explaining why a weak result is encouraging.**

---

## 5. Execution schedule

Concurrent. Weeks are working weeks. Founder hours are broken out by workstream.

| Week | Card study | Provenance study | Card h | Prov h | **Total** |
|---|---|---|---|---|---|
| **0** | Source & transcribe 12 real published lists; build the overlap spreadsheet; design and print the P/N/G card template and the reader sheet; **2 pilot sessions**; write consent + scripts | Build the Airtable base; build the digest Google Doc template and the Sheets render tab; write the screener and the check-in form | 21 | 12 | **33** |
| **1** | Screener live on all four channels; screen and invite; book 26 sessions | Screener live; screen 175; book 42 intakes; **intake calls begin (12 done)** | 8 | 16 | **24** |
| **2** | **Intake calls ×20**; prep ×8; **card sessions 1–8** | Intake calls complete (30 enrolled); **Digest W1 assembled and sent**; check-in W1 | 16 | 11 | **27** |
| **3** | Prep ×12; **card sessions 9–20**; sessions complete | **Digest W2**; check-in W2; evidence adjudication | 20 | 6 | **26** |
| **4** | Transcription; articulation coding begins (2 coders) | **Digest W3**; check-in W3; adjudication | 6 | 6 | **12** |
| **5** | Coding complete; reconcile disagreements; count the stop condition | **Digest W4**; check-in W4; adjudication | 6 | 6 | **12** |
| **6** | Card study write-up | Final adjudication; **exit interviews 1–10**; incentive payouts | 5 | 7 | **12** |
| **7** | — | **Exit interviews 11–20**; outcome table; **combined readout and decision** | 2 | 12 | **14** |
| | | **Totals** | **84** | **76** | **160** |

**Elapsed: 8 weeks. Founder hours: ~160.**

### 5.1 Reconciliation to the memo's targets

The memo (§6.1, §10) targets **~7 weeks, ~90 founder hours, ~$2,700**. Two of the three differ.

**Elapsed: 8 weeks, not 7.** The memo's Week 1 is "recruit for both, build the card templates and the Airtable, intake calls begin." Those cannot be simultaneous. Screener responses take 3–5 days to accumulate before there is anyone to call, and the card template must exist and survive two pilots before the first real session. **The build week is real and the memo folded it into recruiting.** Presented here as Week 0. If a hard 7 weeks is required, the only honest way to get it is to run the card study one week behind the provenance study rather than fully concurrent — which costs nothing, because the two studies do not share instruments.

**Hours: ~160, not ~90.** The memo's 90 is roughly Exp 1 build (~20) + Exp 1 per-participant prep (8) + session time (15) + Exp 2 "founder prep" (50). It counts *execution* and omits four categories:

| Omitted from the memo's 90 | Hours |
|---|---|
| Recruiting and screening, both studies | 24 |
| **Intake calls** — 50 calls across the two studies. The memo counted these as *participant* burden, not founder time. | 25 |
| Transcription, articulation coding, disagreement reconciliation | 12 |
| Exit interviews ×20 | 12 |
| Analysis and write-up, both studies | 13 |
| **Subtotal** | **86** |

90 + 86 ≈ 176; the schedule above lands at 160 because pilots and template work absorb some of the overlap. **~160 is the number to plan against.** At 8 weeks that is 20 hours per week — a half-time job, not a background task.

**Three levers, with their costs, if 160 must come down:**

1. **Batch the card sessions into three days of 6–7 back-to-back rather than spreading them.** Saves ~5h of setup/teardown. Costs nothing. **Do this regardless.**
2. **Contract the second articulation coder rather than double-coding in-house** ($300, already budgeted). Converts ~6h to dollars.
3. **Cut the card study to N=14.** Saves ~14h. **Reject.** The stop condition is pre-registered in twentieths and moving the denominator after the fact is the single worst thing available here.

### 5.2 Cost breakdown

| Line | Detail | Cost |
|---|---|---|
| **Card study — incentives** | 20 participants + 2 pilots × $25 independent-bookshop gift card | $550 |
| **Card study — printing** | ~400 colour sheets (17 per participant × 22, plus spares) @ ~$0.12 | $48 |
| **Card study — materials** | Card stock, sleeves, envelopes, two recorders' batteries, clipboard | $25 |
| **Card study — channel** | Thank-you to two independent bookshops, $25 each | $50 |
| **Card study — second coder** | Contract, ~6h @ $50. **Required: the stop condition rests on this coding.** | $300 |
| **Provenance — intake** | 30 × $15, **paid at the intake call, not at the end** | $450 |
| **Provenance — weekly** | $5 per completed check-in. 20 completers × 4 = $400; ~10 partials averaging 2 weeks = $100 | $500 |
| **Provenance — completion + exit** | 20 × $50 | $1,000 |
| **Provenance — recruiting** | One paid classified in a books newsletter | $150 |
| **Airtable** | Free plan is sufficient at 720 items + 750 library rows. Team seat, 2 months, as contingency for attachment volume. | $48 |
| **Google Workspace, Forms, Docs, Sheets** | Existing | $0 |
| | **Total** | **$3,121** |

**Against the memo's $2,700: +$421.** The overage is one line — the second articulation coder ($300), which the memo did not budget because it did not specify how the stop condition would be coded. The remainder is printing and materials.

**To land exactly on $2,700:** drop the card incentive from $25 to $20 (−$110), skip the Airtable contingency seat (−$48), drop the bookshop thank-you (−$50), and restrict double-coding to a 10-participant reliability subsample rather than all 20 (−$150). Total $2,763. **Do not close the last $63 by cutting incentives further** — a $15 gift card for 65 minutes and a two-day-later session reads as insulting and will cost more in no-shows than it saves.

### 5.3 The single step most likely to slip

> **Booking 30 intake calls with strangers from hostile channels in Week 1.**

Not the build. Not the card sessions. Not the analysis. This one, for three specific reasons:

1. **r/books has self-promotion rules and a research post can be removed within the hour.** That is 15 of the 35 expected attendees gone in a single moderator action, with no appeal and no second attempt from that channel.
2. **The Bookstagram channel will yield close to nothing.** Sixty replies is expected to produce three attendees, and the plan is already assuming a rate that will read as optimistic to anyone who has tried it.
3. **Strangers with no prior relationship no-show scheduled calls at 30–40%.** Everything downstream — the candidate pool, the neighbour graph, the tier spread — is a function of enrolled N. At 20 enrolled instead of 30, `InsufficientPool` starts firing in Week 2 and the digests degrade to four items.

**Mitigations, all of which must be in place before Week 1 starts:**

- **Modmail r/books and r/suggestmeabook in Week 0, not Week 1.** Ask permission. A removed post is unrecoverable; a delayed post is not.
- **Pay $15 at the intake call, not at the end.** This is the single highest-leverage change in the budget. It makes the call itself worth attending and converts the no-show problem into a cost problem.
- **Over-recruit to 42 booked intakes for 30 enrolled**, as scheduled — do not trim this when Week 1 gets busy.
- **Hold the paid newsletter classified in reserve and fire it on Day 3 of Week 1** if bookings are below 20, rather than running it from Day 1 and having no lever left.

**Hard gate, decided in advance:** *if fewer than 18 intake calls are booked by the end of Week 1, Digest W1 slips one week and the study runs to 9 weeks.* Do not start the digests with 20 enrolled to protect the schedule. A thin neighbour graph makes the P arm structurally weaker than N through no fault of the hypothesis, and that is the one error this design cannot recover from.
