import SwiftUI
import UIKit

// MARK: - The comparison screen

/// One pair, one question, five ways to answer.
///
/// Extracted so that placing a book after a log and tuning an established
/// ranking are visibly the *same act*. They were going to be two screens
/// asking one question in two layouts, which is how a second phrasing gets in.
private struct ComparisonScreen: View {
    let comparison: RankingComparison
    let candidateKicker: String
    let opponentKicker: String
    let remaining: Int
    /// The line under the options. Placing and tuning are the same act and the
    /// same screen, but they are not reached the same way — "your log is
    /// already saved" is exactly right two seconds after a save and a non
    /// sequitur in a tuning session nobody logged anything to get to.
    let reassurance: String
    /// Set only for the top-boundary question. Replaces the "About 3 more"
    /// kicker and adds one line under the support text; the prompt and the
    /// support line themselves are untouched, because there is one question and
    /// this is still it.
    var boundary: (kicker: String, note: String)? = nil
    let onAnswer: (RankingComparison.Answer) -> Void

    @Environment(DeweyStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.loose) {
                head
                pair
                options
                Text(reassurance)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, Theme.Space.base)
            .padding(.bottom, Theme.Space.loose)
            .pageMargin()
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// The question, and under it the one line that stops a reader answering
    /// with their score by mistake.
    ///
    /// "Which book do you prefer?" is deliberately the vaguest thing Dewey ever
    /// asks, because preference is vague. A reader given no steer at all
    /// substitutes the precise question they already know — "which is better?" —
    /// and answers it with the number they already gave, which produces a
    /// ranking that is the score column sorted. The support line names the two
    /// ingredients of a preference without splitting them into two prompts, the
    /// mistake the four rotating questions made.
    private var head: some View {
        VStack(spacing: Theme.Space.snug) {
            Text(boundary?.kicker ?? remainingLine).kickerStyle()
            // Fixed for the whole insertion, so no `.id`/`.transition` pair —
            // the question does not change between rounds and cross-fading a
            // string into itself is a flicker with no information in it.
            Text(RankingComparison.prompt)
                .font(Theme.TypeScale.title())
                .foregroundStyle(Theme.Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(RankingComparison.support)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let note = boundary?.note {
                Text(note)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var remainingLine: String {
        remaining <= 1 ? "One more" : "About \(remaining) more"
    }

    /// **Side by side, until side by side means two hyphens per word** (§19.2).
    ///
    /// `ViewThatFits` picks the widest cover that still leaves both books on one
    /// line, which is the right question at default type and the wrong one
    /// above it: the widths are fixed points, so the pair *fits* at an
    /// accessibility size and is simply illegible — the kicker came out
    /// "PLAC-ING", the title "The Fellow-", and a 156-point column held about
    /// two syllables a line.
    ///
    /// Stacked, each card gets the whole measure. It costs the side-by-side
    /// composition, which is worth something here — a forced choice reads best
    /// as two things you can see at once — and costs less than a question the
    /// reader cannot read. They are still the first two things in the scroll
    /// view, one above the other, in the same order.
    @ViewBuilder
    private var pair: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: Theme.Space.base) {
                choiceCard(book: store.book(comparison.candidate), kicker: candidateKicker,
                           coverWidth: 132, isStacked: true, answer: .candidate)
                choiceCard(book: store.book(comparison.opponent), kicker: opponentKicker,
                           coverWidth: 132, isStacked: true, answer: .opponent)
            }
            .frame(maxWidth: .infinity)
        } else {
            ViewThatFits(in: .horizontal) {
                pairRow(coverWidth: 156)
                pairRow(coverWidth: 136)
                pairRow(coverWidth: 116)
                pairRow(coverWidth: 96)
                pairRow(coverWidth: 78)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func pairRow(coverWidth: CGFloat) -> some View {
        // `fixedSize(vertical:)` stops the equal-height cards from stretching
        // to fill the scroll view; they grow to the taller card and stop.
        HStack(alignment: .top, spacing: Theme.Space.base) {
            choiceCard(book: store.book(comparison.candidate), kicker: candidateKicker,
                       coverWidth: coverWidth, isStacked: false, answer: .candidate)
            choiceCard(book: store.book(comparison.opponent), kicker: opponentKicker,
                       coverWidth: coverWidth, isStacked: false, answer: .opponent)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func choiceCard(
        book: Book,
        kicker: String,
        coverWidth: CGFloat,
        isStacked: Bool,
        answer: RankingComparison.Answer
    ) -> some View {
        Button {
            onAnswer(answer)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                Text(kicker).kickerStyle()
                BookCoverView(book: book, width: coverWidth)
                Text(book.title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(book.author)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                favoriteMark(for: book.id)
            }
            .frame(
                width: isStacked ? nil : coverWidth,
                alignment: .leading
            )
            .frame(maxWidth: isStacked ? .infinity : nil, alignment: .leading)
            .padding(Theme.Space.snug)
            // **Both cards are as tall as the taller one.**
            //
            // `favoriteMark` already reserves its slot so a Favorite on one
            // side cannot change the height (§13.6), and that fixed the case it
            // was written for and not the commoner one: a two-line title or a
            // wrapped author name does the same thing. Two cards of visibly
            // different height in a forced choice is not neutral — the taller
            // one reads as the recommended answer, on a screen whose entire
            // job is to present two options with no thumb on the scale.
            //
            // Stacked, they are one above the other and their heights carry no
            // such implication, so the equalising is skipped — forcing it would
            // pad the shorter card for no reason.
            .frame(maxHeight: isStacked ? nil : .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Theme.Palette.rule, lineWidth: 0.5)
            )
        }
        .buttonStyle(ChoiceCardButtonStyle())
        .accessibilityLabel("\(book.title) by \(book.author)")
        .accessibilityHint("Choose this one")
    }

    /// Favorite only. **Your Score is deliberately not on these cards.**
    ///
    /// Showing a reader 8.9 against 8.4 at the instant of choosing hands them
    /// the answer, and the answer it hands them is to the *other* question. The
    /// whole value of a ranking is that it is a forced ordering arrived at
    /// without arithmetic; a comparison screen that prints both scores produces
    /// the score column, sorted, and calls it taste (§12.4).
    ///
    /// Favorite survives because it is a claim about the reader rather than a
    /// valuation — it says the book is load-bearing, which is close to what
    /// "means more to you" in the support line is asking about.
    ///
    /// The slot is always drawn and only the glyph inside it comes and goes
    /// (§13.6). Conditionally *adding* the mark made the two cards different
    /// heights whenever exactly one of the pair was a Favorite — which is most
    /// pairs — so the choice arrived visibly lopsided and the taller card read
    /// as the recommended answer.
    private func favoriteMark(for bookID: String) -> some View {
        FavoriteMark(filled: true, size: 12)
            .padding(.top, Theme.Space.hair)
            .opacity(store.isFavorite(bookID) ? 1 : 0)
            .accessibilityHidden(!store.isFavorite(bookID))
    }

    // MARK: The quieter answers

    private var options: some View {
        VStack(spacing: 0) {
            Rule()
            optionRow(Judgement.RankingCopy.equal, answer: .equal)
            Rule()
            optionRow(Judgement.RankingCopy.incomparable, answer: .tooDifferent)
            Rule()
            optionRow(Judgement.RankingCopy.stop, answer: .stop)
            Rule()
        }
    }

    private func optionRow(_ label: String, answer value: RankingComparison.Answer) -> some View {
        Button {
            onAnswer(value)
        } label: {
            HStack {
                Text(label)
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.inkSoft)
                Spacer(minLength: 0)
            }
            .padding(.vertical, Theme.Space.base)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Card press feedback. Quieter than a button fill — the card *is* the button,
/// so it dips rather than tints.
private struct ChoiceCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Theme.Motion.standard, value: configuration.isPressed)
    }
}

// MARK: - Placing one book

/// Placing one book among the ones you've already placed.
///
/// The whole exercise is optional and interruptible. The log is already saved
/// before this sheet appears, so closing it at any point costs nothing — which
/// is the only reason it is safe to ask five questions.
///
/// **This survived the move to 0.1–10.0 scores, deliberately** (§12.4). The
/// argument for demoting it was that ninety-nine steps leave almost no ties to
/// break, so ranking becomes a tie-breaker with nothing to do. That is wrong on
/// both halves: a score is a valuation and a ranking is a preference, and the
/// preference is hardest — and most worth having — exactly when two books sit
/// half a point apart. Nothing in this file reads a score to decide an order.
///
/// **Nor does it require one** (§19). The offer used to be gated on
/// `rating != nil`, so a reader who logged a finish without scoring it was never
/// asked, and the two judgements Dewey most wants people to understand as
/// independent were wired together at the one moment both were on screen.
struct RankingSheet: View {
    let book: Book

    @Environment(DeweyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The order as it stood before this book, with the candidate removed so a
    /// re-rank doesn't compare a book against itself.
    @State private var base: [String] = []
    @State private var insertion: RankingInsertion?
    @State private var finalOrder: [String]?
    /// How many comparisons the reader actually answered. Drives the result
    /// screen's closing line — see `landedHead`.
    @State private var comparisonsMade = 0
    @State private var didSetUp = false

    /// False until the reader has read `intro` and tapped through it.
    @State private var didStart = false

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Theme.Palette.paper)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if finalOrder == nil {
                            Button("Not now") { dismiss() }
                                .font(Theme.TypeScale.ui())
                                .foregroundStyle(Theme.Palette.inkSoft)
                        }
                    }
                }
        }
        .presentationDragIndicator(.visible)
        .onAppear(perform: setUpIfNeeded)
    }

    @ViewBuilder
    private var content: some View {
        if let order = finalOrder {
            result(order: order)
        } else if !didStart, insertion != nil {
            intro
        } else if let comparison = insertion?.nextComparison {
            ComparisonScreen(
                comparison: comparison,
                candidateKicker: "Placing",
                opponentKicker: opponentKicker(for: comparison.opponent),
                remaining: insertion?.remainingEstimate ?? 1,
                reassurance: Judgement.RankingCopy.optional,
                boundary: boundaryFraming,
                onAnswer: answer
            )
        } else {
            Color.clear.frame(height: 1)
        }
    }

    // MARK: Intro

    /// **The screen that resolves the app's central contradiction** (§13.1).
    ///
    /// A walkthrough found a book scored **8** sitting at **No. 1 of 14**, above
    /// a book scored 10, with nothing anywhere saying why that was not a bug.
    /// Both numbers were presented as the reader's opinion and they flatly
    /// disagreed. The fix is not to make one derive from the other — that would
    /// destroy the thing ranking is for — it is to say, once, in the reader's
    /// own language, that they answer different questions.
    ///
    /// It costs one tap on an entirely optional flow and it is worth the tap:
    /// without it, the result screen is the moment a reader decides the app is
    /// confused. "Not now" is still in the toolbar, so this is also the cheapest
    /// possible place to back out.
    private var intro: some View {
        // **Scrollable, like every other screen in this sheet** (§19.2).
        //
        // It was a bare `VStack`, which is fine at default type and broken
        // above it: at an accessibility size the explainer alone is taller than
        // the phone, so "Start placing" sat on the bottom edge with the
        // reassurance line below it off-screen and no way to reach either — and
        // the headline ran up under the "Not now" button in the toolbar, so the
        // first word of the question was behind a control.
        ScrollView {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                Text("Before you start").kickerStyle()
                Text(Judgement.RankingCopy.question)
                    .font(Theme.TypeScale.title())
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(Judgement.RankingCopy.explainer)
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Text("You'll be asked the same question a few times — \(RankingComparison.prompt.lowercased().replacingOccurrences(of: "?", with: "")). Stop whenever you like.")
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)

            Button("Start placing") {
                withAnimation(Theme.Motion.standard) { didStart = true }
            }
            .buttonStyle(PrimaryButtonStyle())

            Text(Judgement.RankingCopy.optional)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.loose)
        .padding(.bottom, Theme.Space.loose)
        .pageMargin()
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Setup and answering

    private func setUpIfNeeded() {
        guard !didSetUp else { return }
        didSetUp = true

        var order = store.ranking.order
        order.removeAll { $0 == book.id }
        base = order

        guard !order.isEmpty else {
            // Nothing to measure against yet. The book is simply first, and it
            // was placed on no comparisons — which `placeInRanking` records
            // honestly, so tuning will offer it once there is something to
            // compare it with.
            complete(with: [book.id], comparisons: 0)
            return
        }
        insertion = RankingInsertion(candidate: book.id, into: order)
    }

    private func opponentKicker(for bookID: String) -> String {
        guard let index = base.firstIndex(of: bookID) else { return "In \(Judgement.RankingCopy.title)" }
        return "No. \(index + 1) for you"
    }

    /// Non-nil only on the top-boundary question. "Done for now" is still one
    /// of the options on the screen, so this stays an offer rather than a gate.
    private var boundaryFraming: (kicker: String, note: String)? {
        guard let insertion, insertion.stage == .boundary else { return nil }
        return (
            Judgement.RankingCopy.boundaryKicker,
            Judgement.RankingCopy.boundaryNote(position: insertion.boundaryPosition)
        )
    }

    private func answer(_ value: RankingComparison.Answer) {
        guard var working = insertion else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let finished = working.answer(value) {
            complete(with: finished, comparisons: working.asked)
        } else {
            withAnimation(Theme.Motion.standard) { insertion = working }
        }
    }

    private func complete(with order: [String], comparisons: Int) {
        comparisonsMade = comparisons
        store.placeInRanking(book.id, order: order, comparisons: comparisons)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(Theme.Motion.gentle) {
            insertion = nil
            finalOrder = order
        }
    }

    // MARK: Result

    private func result(order: [String]) -> some View {
        let position: Int = (order.firstIndex(of: book.id) ?? 0) + 1
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.roomy) {
                landedHead(position: position, total: order.count)
                RankNeighbourhood(order: order, focus: book.id)
                VStack(spacing: Theme.Space.snug) {
                    Button("Done") { dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                    NavigationLink {
                        RankedListView().deweyDestinations()
                    } label: {
                        Text("See \(Judgement.RankingCopy.title.lowercased())")
                            .font(Theme.TypeScale.ui())
                            .foregroundStyle(Theme.Palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Space.snug)
                    }
                }
                .padding(.top, Theme.Space.snug)
            }
            .padding(.top, Theme.Space.base)
            .padding(.bottom, Theme.Space.loose)
            .pageMargin()
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func landedHead(position: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text("Where it landed").kickerStyle()
            RankFigure(position: position, total: total)
            Text(Judgement.RankingCopy.title)
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)

            // Restated at the moment it is most likely to be doubted (§13.1).
            //
            // This is the screen where the contradiction actually surfaces: a
            // book the reader gave an 8 arriving above one they gave a 10. The
            // intro says they are different judgements *before* the questions;
            // a reader who has just answered five comparisons and is now
            // looking at the answer needs it said again, here, or the position
            // reads as arithmetic that has gone wrong.
            //
            // **The first book ever placed gets the other sentence.** It was
            // told "placed by your comparisons" having made none — the intro
            // is skipped when there is nothing to compare against, so on a
            // first-ever placement this line was both false and the reader's
            // only explanation of what a ranking is. It now carries the
            // explainer instead, which is what that reader actually needs.
            Text(comparisonsMade == 0
                 ? Judgement.RankingCopy.explainer
                 : "Placed by your comparisons, not by \(Judgement.ScoreCopy.title).")
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Space.hair)
        }
    }
}

// MARK: - Tuning

/// **Revisiting positions the ranking has little behind them** (§19).
///
/// Not a correction. The order is the honest result of the comparisons the
/// reader made, and every string on this screen is careful not to suggest
/// otherwise — what tuning fixes is thin *evidence*, not wrong taste.
///
/// A session is a handful of re-placements and it can be left at any point.
/// There is no schedule behind it and no notification: it is offered when
/// `DeweyStore.tuningCandidates` is non-empty, which is a fact about the data,
/// and it is reachable on demand from the ranked list whether or not it is
/// being offered.
struct RankingTuneSheet: View {
    @Environment(DeweyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// How many books one session will offer. Small on purpose — the reader can
    /// come back, and a queue that keeps producing another book is a treadmill.
    private static let sessionLength = 3

    @State private var queue: [String] = []
    @State private var current: String?
    @State private var base: [String] = []
    @State private var insertion: RankingInsertion?
    @State private var didStart = false
    @State private var didSetUp = false
    @State private var movement: (book: String, from: Int, to: Int)?
    @State private var tunedCount = 0

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Theme.Palette.paper)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(tunedCount > 0 ? "Done" : "Not now") { dismiss() }
                            .font(Theme.TypeScale.ui())
                            .foregroundStyle(Theme.Palette.inkSoft)
                    }
                }
        }
        .presentationDragIndicator(.visible)
        .onAppear(perform: setUpIfNeeded)
    }

    @ViewBuilder
    private var content: some View {
        if !didStart {
            intro
        } else if let movement {
            moved(movement)
        } else if let comparison = insertion?.nextComparison, let current {
            ComparisonScreen(
                comparison: comparison,
                candidateKicker: "Re-placing",
                opponentKicker: opponentKicker(for: comparison.opponent),
                remaining: insertion?.remainingEstimate ?? 1,
                reassurance: Judgement.TuningCopy.optional,
                boundary: boundaryFraming,
                onAnswer: { answer($0, for: current) }
            )
        } else {
            finished
        }
    }

    // MARK: Screens

    private var intro: some View {
        // Scrollable for the same reason `RankingSheet.intro` is — see there.
        ScrollView {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                Text(Judgement.TuningCopy.title).kickerStyle()
                Text(Judgement.TuningCopy.question)
                    .font(Theme.TypeScale.title())
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(Judgement.TuningCopy.explainer)
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if queue.isEmpty {
                Text(Judgement.TuningCopy.settled)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Done") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                HStack(spacing: Theme.Space.snug) {
                    ForEach(queue, id: \.self) { id in
                        BookCoverView(book: store.book(id), width: 56)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Books to re-place: \(queue.map { store.book($0).title }.joined(separator: ", "))")

                Button("Start") { advance() }
                    .buttonStyle(PrimaryButtonStyle())
                Text(Judgement.TuningCopy.optional)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.loose)
        .padding(.bottom, Theme.Space.loose)
        .pageMargin()
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// **Rank movement, stated as movement** (§19).
    ///
    /// The one place Dewey draws a change in position rather than a position.
    /// "No. 9 → No. 4" is the whole receipt for a tuning round, and it is
    /// legible in a way "No. 4" alone is not — the reader is here precisely
    /// because they wanted to know whether their answers would move anything.
    /// A book that did not move says so, which is also a result.
    private func moved(_ movement: (book: String, from: Int, to: Int)) -> some View {
        let entry = store.book(movement.book)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.roomy) {
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    Text(movement.from == movement.to ? "Stayed put" : "Moved").kickerStyle()
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
                        if movement.from != movement.to {
                            Text("No. \(movement.from)")
                                .font(Theme.TypeScale.title())
                                .foregroundStyle(Theme.Palette.inkFaint)
                                .monospacedDigit()
                                .strikethrough()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(Theme.Palette.inkFaint)
                        }
                        Text("No. \(movement.to)")
                            .font(Theme.TypeScale.display())
                            .foregroundStyle(Theme.Palette.ink)
                            .monospacedDigit()
                        Text("of \(store.rankedCount)")
                            .font(Theme.TypeScale.support())
                            .foregroundStyle(Theme.Palette.inkSoft)
                            .monospacedDigit()
                    }
                    Text(entry.title)
                        .font(Theme.TypeScale.support())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                RankNeighbourhood(order: store.ranking.order, focus: movement.book)

                VStack(spacing: Theme.Space.snug) {
                    if !queue.isEmpty {
                        Button("Next book") { advance() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    Button(queue.isEmpty ? "Done" : Judgement.RankingCopy.stop) { dismiss() }
                        .buttonStyle(QuietButtonStyle())
                }
            }
            .padding(.top, Theme.Space.base)
            .padding(.bottom, Theme.Space.loose)
            .pageMargin()
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var finished: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.roomy) {
                Text(Judgement.TuningCopy.finished)
                    .font(Theme.TypeScale.title())
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Done") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Space.loose)
            .padding(.bottom, Theme.Space.loose)
            .pageMargin()
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Driving

    private func setUpIfNeeded() {
        guard !didSetUp else { return }
        didSetUp = true
        // Worst-supported first, then anything finished and never placed. Both
        // are "Dewey does not know where this goes"; splitting them into two
        // flows would wear an implementation detail on the outside.
        queue = Array((store.tuningCandidates + store.unrankedFinishedBooks).prefix(Self.sessionLength))
    }

    /// Pulls the next book off the queue and starts an insertion for it.
    ///
    /// Re-placing is *removing and inserting*, using the same
    /// `RankingInsertion` a first placement uses. A separate "move this book"
    /// path would be a second implementation of the ordering rules, and the two
    /// would drift.
    private func advance() {
        movement = nil
        guard !queue.isEmpty else {
            withAnimation(Theme.Motion.gentle) { didStart = true; current = nil }
            return
        }
        let next = queue.removeFirst()
        var order = store.ranking.order
        order.removeAll { $0 == next }
        current = next
        base = order
        withAnimation(Theme.Motion.standard) {
            didStart = true
            insertion = order.isEmpty ? nil : RankingInsertion(candidate: next, into: order)
        }
        // A one-book ranking has nothing to compare against; skip rather than
        // present an empty screen.
        if order.isEmpty { advance() }
    }

    private func opponentKicker(for bookID: String) -> String {
        guard let index = base.firstIndex(of: bookID) else { return "In \(Judgement.RankingCopy.title)" }
        return "No. \(index + 1) for you"
    }

    private var boundaryFraming: (kicker: String, note: String)? {
        guard let insertion, insertion.stage == .boundary else { return nil }
        return (
            Judgement.RankingCopy.boundaryKicker,
            Judgement.RankingCopy.boundaryNote(position: insertion.boundaryPosition)
        )
    }

    private func answer(_ value: RankingComparison.Answer, for bookID: String) {
        guard var working = insertion else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let before = store.rank(of: bookID) ?? 0
        guard let finished = working.answer(value) else {
            withAnimation(Theme.Motion.standard) { insertion = working }
            return
        }
        store.placeInRanking(bookID, order: finished, comparisons: working.asked)
        tunedCount += 1
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(Theme.Motion.gentle) {
            insertion = nil
            movement = (bookID, before, store.rank(of: bookID) ?? before)
        }
    }
}

// MARK: - Shared figures

/// **"No. 12 of 67" — the ranking's entire visual vocabulary** (§19).
///
/// An ordinal and a denominator. No bar, no percentile, no second score. Dewey
/// deliberately has no numeric ranking *value*: the moment a ranking acquires
/// one it becomes a second thing to compare against Your Score, and a reader has
/// to work out which of the two numbers the app believes.
///
/// The denominator is not decoration. "No. 1" alone is unreadable — of what? —
/// and No. 1 of 3 is a different claim from No. 1 of 300.
///
/// **A headline, and only a headline.** The book page draws the same two facts
/// as half of a matched pair with Your Score, which needs the ordinal and the
/// denominator on separate lines so both slots keep one shape in every state —
/// see `JudgementSlot`. This one-line form is for screens where the position is
/// the subject rather than one of two.
struct RankFigure: View {
    let position: Int
    let total: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.tight) {
            Text("No. \(position)")
                .font(Theme.TypeScale.display())
                .foregroundStyle(Theme.Palette.ink)
                .monospacedDigit()
            Text("of \(total)")
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Number \(position) of \(total) in \(Judgement.RankingCopy.title)")
    }
}

/// A book and its immediate neighbours in the order.
///
/// **No score on these rows, deliberately.** The whole job here is to show
/// *where the book landed*, and the ordinal in the left column is the answer. A
/// number in the trailing column reopens the question the comparisons just
/// closed and invites the reader to audit the ordering against figures that
/// were never used to produce it (§12.4).
struct RankNeighbourhood: View {
    let order: [String]
    let focus: String

    @Environment(DeweyStore.self) private var store

    var body: some View {
        let index = order.firstIndex(of: focus) ?? 0
        VStack(spacing: 0) {
            Rule()
            if index - 1 >= 0 {
                row(bookID: order[index - 1], position: index, isCurrent: false)
                Rule()
            }
            row(bookID: focus, position: index + 1, isCurrent: true)
            Rule()
            if index + 1 < order.count {
                row(bookID: order[index + 1], position: index + 2, isCurrent: false)
                Rule()
            }
        }
    }

    private func row(bookID: String, position: Int, isCurrent: Bool) -> some View {
        let entry = store.book(bookID)
        return HStack(alignment: .center, spacing: Theme.Space.base) {
            Text("\(position)")
                .font(Theme.TypeScale.cardTitle())
                .monospacedDigit()
                .foregroundStyle(isCurrent ? Theme.Palette.ink : Theme.Palette.inkFaint)
                .frame(width: 34, alignment: .trailing)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            BookCoverView(book: entry, width: isCurrent ? 44 : 34)

            VStack(alignment: .leading, spacing: Theme.Space.hair) {
                Text(entry.title)
                    .font(.system(.subheadline, design: .serif, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Theme.Palette.ink : Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.author)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Space.snug)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - The ranked list

/// **Your Ranking as an artifact rather than a settings screen.**
///
/// Big serif numerals and covers. A ranking is the most personal thing in Dewey
/// — it is an argument, not a statistic — so it is typeset like a page from a
/// magazine and not like a table. Scores used to run down every line and have
/// been taken off: the ordinal in the left column *is* the claim, and a second
/// number beside it turns the artifact back into the table this layout exists to
/// avoid.
///
/// **One list, filtered — never several lists, switched** (§19). This had a chip
/// switcher across `store.rankings`, each chip a genuinely separate ordering
/// built from its own comparisons. The chips are still here and now they are
/// filters: they hide rows and change nothing else. That is why the positions
/// stay *global* under a filter — 1, 4, 9 rather than 1, 2, 3. The gaps are the
/// proof that nothing was recomputed, and renumbering from 1 would produce
/// exactly the artifact this pass removed: a thing that looks like a Sci-Fi
/// ranking, reads like a Sci-Fi ranking, and would be treated as one.
struct RankedListView: View {
    /// Whose ranking. `nil` is yours — the only one that can be tuned or
    /// hidden.
    var reader: ReaderProfile? = nil

    @Environment(DeweyStore.self) private var store
    @State private var filter: RankingFilter = .all
    @State private var isTuning = false

    private var profile: ReaderProfile { reader ?? store.me }
    private var isMine: Bool { profile.isMe }
    private var ranking: PersonalRanking { store.ranking(for: profile) }

    /// Filtered rows carry their **global** position. See the type comment.
    private var rows: [(position: Int, bookID: String)] {
        store.rankedBooks(in: ranking, matching: filter)
    }

    private var availableFilters: [RankingFilter] { store.rankingFilters(for: ranking) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.roomy) {
                header
                if availableFilters.count > 1 { filters }
                if isMine, store.hasTuningWork { tuneRow }
                if rows.isEmpty { emptyState } else { list }
                colophon
            }
            .padding(.top, Theme.Space.snug)
            .padding(.bottom, Theme.Space.vast)
        }
        .background(Theme.Palette.paper)
        .navigationTitle(isMine ? Judgement.RankingCopy.title : "\(firstName)'s Ranking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { if isMine { overflow } }
        // A chip that no longer exists would leave the list empty with no
        // selected chip on screen to explain why.
        .onChange(of: availableFilters) { _, current in
            if !current.contains(filter) { filter = .all }
        }
        .sheet(isPresented: $isTuning) { RankingTuneSheet() }
    }

    private var firstName: String {
        profile.name.split(separator: " ").first.map(String.init) ?? profile.name
    }

    // MARK: Head

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(isMine ? "Ordered by you" : "Ordered by \(firstName)").kickerStyle()
            Text(isMine ? Judgement.RankingCopy.title : "\(firstName)'s Ranking")
                .font(Theme.TypeScale.display())
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(countLine)
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if isMine, !store.isRankingPublic {
                Text(Judgement.RankingPrivacyCopy.hidden)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .padding(.top, Theme.Space.hair)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
    }

    /// Says what the filter is doing, in the reader's words, so a list with gaps
    /// in its numbering never reads as a list that has lost rows.
    /// The kicker above already says whose list this is, so the count line does
    /// not repeat it. What it does say, under a filter, is why the numbering has
    /// gaps in it — a ranked list running 2, 10, 11 reads as broken until
    /// something states that the positions are the whole list's.
    private var countLine: String {
        let total = ranking.count
        guard case .all = filter else {
            let whose = isMine ? "your" : "\(firstName)'s"
            return "\(rows.count) of \(whose) \(total) ranked books · positions are from the whole list"
        }
        return total == 1 ? "1 book" : "\(total) books"
    }

    // MARK: Filters

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.snug) {
                ForEach(availableFilters, id: \.self) { candidate in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(Theme.Motion.standard) { filter = candidate }
                    } label: {
                        Text(candidate.title)
                    }
                    .buttonStyle(ChipStyle(selected: candidate == filter))
                }
            }
            .pageMargin()
        }
        .accessibilityLabel("Filter \(Judgement.RankingCopy.title)")
    }

    // MARK: Tuning offer

    /// Quiet, and only drawn when there is something behind it.
    private var tuneRow: some View {
        Button { isTuning = true } label: {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
                VStack(alignment: .leading, spacing: Theme.Space.hair) {
                    Text(Judgement.TuningCopy.title)
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.accent)
                    Text(Judgement.TuningCopy.invitation(
                        store.tuningCandidates.count + store.unrankedFinishedBooks.count
                    ))
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right").foregroundStyle(Theme.Palette.accent)
            }
            .padding(.vertical, Theme.Space.snug)
            .pageMargin()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ToolbarContentBuilder
    private var overflow: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(Judgement.TuningCopy.title, systemImage: "slider.horizontal.3") {
                    isTuning = true
                }
                Divider()
                Button(
                    store.isRankingPublic
                        ? Judgement.RankingPrivacyCopy.hide
                        : Judgement.RankingPrivacyCopy.show,
                    systemImage: store.isRankingPublic ? "eye.slash" : "eye"
                ) {
                    store.setRankingPublic(!store.isRankingPublic)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("\(Judgement.RankingCopy.title) options")
        }
    }

    // MARK: Rows

    private var list: some View {
        VStack(spacing: 0) {
            Rule()
            ForEach(rows, id: \.bookID) { row in
                rankedRow(bookID: row.bookID, position: row.position)
                Rule()
            }
        }
    }

    private func rankedRow(bookID: String, position: Int) -> some View {
        let entry = store.book(bookID)
        return NavigationLink(value: entry) {
            HStack(alignment: .center, spacing: Theme.Space.base) {
                Text("\(position)")
                    .font(Theme.TypeScale.title())
                    .monospacedDigit()
                    .foregroundStyle(position <= 3 ? Theme.Palette.ink : Theme.Palette.inkFaint)
                    .frame(width: 46, alignment: .trailing)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                BookCoverView(book: entry, width: 46)

                VStack(alignment: .leading, spacing: Theme.Space.hair) {
                    Text(entry.title)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Theme.Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(entry.author)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if store.isFavorite(bookID) {
                        FavoriteMark(filled: true, size: 12)
                            .padding(.top, Theme.Space.hair)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, Theme.Space.base)
            .pageMargin()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(position). \(entry.title) by \(entry.author)")
    }

    // MARK: Edges

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text(ranking.isEmpty ? "Nothing placed yet" : "Nothing here under this filter")
                .font(Theme.TypeScale.cardTitle())
                .foregroundStyle(Theme.Palette.ink)
            Text(ranking.isEmpty
                 ? "\(Judgement.RankingCopy.title) builds one book at a time, offered after you log something. Nothing here is required."
                 : "Every book under this filter is still unplaced.")
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
    }

    private var colophon: some View {
        VStack(spacing: Theme.Space.snug) {
            Rule().frame(width: 40)
            Text(Judgement.RankingCopy.contrast)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Space.roomy)
        .pageMargin()
    }
}
