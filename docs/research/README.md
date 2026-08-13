# Dewey Research Kit — Index

This directory is the complete operational kit for two concurrent studies that together decide whether Dewey gets built. **Experiment 1, the Card Study (N=20, in person, paper only)**, tests whether a reader's taste is legible from a shelf alone — a grid of covers and ratings, no name, no bio, no prose — and whether a card carrying a real person's attribution can displace the book a participant already intended to read next, when the table has exactly one slot. **Experiment 2, the Provenance Study (30 enrolled, ≥20 completers, four weekly digests)** holds the book pool constant and varies only which true fact is surfaced — attributed to a named real neighbour (P), anonymous evidence (N), or editorial (G) — and measures verified starts, not saves. Everything here is meant to be executed as written, not read as a proposal. Governing memo: `/Users/jacksirianni/dewey/docs/strategy/2026-08-04-tuesday-problem-and-prototype-reduction.md` §§6–10.

## The four documents

| Document | What it contains | When it is used |
|---|---|---|
| [`01-protocol-and-schedule.md`](/Users/jacksirianni/dewey/docs/research/01-protocol-and-schedule.md) | Both protocols end to end: what is measured, recruiting channels and yields, block structure, the pre-registration freeze, the 8-week schedule (~160 founder hours), the $3,121 cost breakdown, and the step most likely to slip | Read first, in full, before anything is printed or posted. Returned to at each week boundary |
| [`02-stimuli-and-real-reader-sources.md`](/Users/jacksirianni/dewey/docs/research/02-stimuli-and-real-reader-sources.md) | How to source and transcribe the four real readers (five eligible source types, eligibility floor, selection axes, verbatim attribution lines), plus every printed card: reader profile A–D, P/N/G, the Reading Next holder, the overlap worksheet, materials checklist | Week 0, during sourcing and printing. The overlap worksheet is used again in the ~25 min of prep before each session |
| [`03-intake-and-commitment-instrument.md`](/Users/jacksirianni/dewey/docs/research/03-intake-and-commitment-instrument.md) | The two-stage intake (Google Form screener + 20-minute call), the elicitation method for a real 20–25 title library, the forward-looking triad that captures the incumbent book, the friend capture, and the one-slot displacement instrument with its verbatim scripts and debrief | Weeks 1–3, at recruitment, on every intake call, and at the moment of choice in every session |
| [`04-guide-capture-and-decision-rules.md`](/Users/jacksirianni/dewey/docs/research/04-guide-capture-and-decision-rules.md) | The moderator's working copy: staged 45-minute session script, what the moderator must never say, behaviours B1–B24, the 13-sheet results workbook, the blind double-coding procedure, the criteria table C1–C8 and the decision tree | On the table during every session; then during coding, reconciliation, and the combined readout in Weeks 4–7 |

## Binding constraints

These are not preferences. Violating any one of them invalidates the result it touches.

1. **Real published lists, never invented readers.** The four readers are named people whose public record is *transcribed*, not authored. Zero authored titles. A candidate list is unusable below 60 transcribed titles; target 100–120.
2. **No 350-book corpus.** Nothing is pre-built at scale. R1–R3 are simply the three real lists with the highest computed overlap against this participant; R4 is a real list landing at 3–4. If nothing overlaps ≥8, record that as a finding and proceed — do not tune, swap, or trim.
3. **Ordinary tools only.** Paper, card stock, a Google Form, Sheets, Airtable's free plan, two audio recorders. No software is built. No Swift is written until the four conditions in §C.4 hold.
4. **Saves are a lying metric.** Saves are logged for diagnosis and may never be substituted for a success measure. The evidence is verified starts, the forced choice, and the articulation transcript.
5. **Counts, never percentages, at N=20.** Write "14 of 20". No p-values, no decimals. Any number in any output ending in a decimal point is a defect.

## Stop condition

Legibility of the reader the participant chose, coded blind by two coders and resolved conservatively, on the falsifiable-specificity standard (≥2 falsifiable attributes across ≥2 classes):

- **≥12 of 20 SPECIFIC** — clears the build bar.
- **9, 10, or 11** — genuine ambiguity. Report the count with transcripts attached, attempt no interpretation, build nothing further.
- **≤8 of 20 SPECIFIC → STOP.** A shelf of covers and numbers does not resolve into a person; provenance has nothing to attach to. Dewey is expression-driven or it is not built. This is not a design problem and must not be treated as one. If C2 fires, no row of the decision tree applies.

Three further standing stop conditions live in §C.4: P ≈ N ≈ G (C4), verified starts near zero across every arm (C5), and required density no plausible early network can supply (C8).

## Start here on Monday

1. **Modmail r/books and r/suggestmeabook asking permission to post.** Week 0, not Week 1. A removed post is unrecoverable; a delayed one is not. This is the single most schedule-critical action in the kit.
2. **Source and transcribe 12 real published lists** into the reader bank, per `02` §§2–6 — eligibility floor 60 titles, target 100–120, title + author + stated verdict, most recent first. Run the eligibility screen and record every source in `Reader_Sources`.
3. **Build the overlap spreadsheet and the Airtable base**, plus the digest Doc template and the Sheets render tab for Experiment 2.
4. **Design and print the reader profile cards A–D and the P/N/G template**, assemble the session kit against the `02` §14 materials checklist, and verify that every statement on every card is true of the book shown.
5. **Run the two pilot sessions, then freeze the pre-registered sections** (`01` §§2.5, 2.8, 3.6, 3.7, 4.4) before the first participant is contacted. Post-freeze changes are logged with a reason and apply prospectively only.
