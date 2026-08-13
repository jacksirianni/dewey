import Foundation

/// **The reader's one personal ranking**, by pairwise comparison.
///
/// The insight borrowed from Beli (the mechanic, not the expression): people
/// are bad at assigning absolute scores and very good at answering "which of
/// these two?". An 8.2 is a guess; "I'd pick this one" is a fact about you. The
/// finer scale of §12.2 does not close that gap — it widens it, because a reader
/// who cannot reliably choose between 8.1 and 8.3 can still say without
/// hesitating which of the two they would rather have read. See §12.4.
///
/// **There is exactly one, and it is a single ordered claim** (§19). This was
/// `[RankingContext]` — a list of independent rankings keyed by a `Kind` enum of
/// `.all`, `.year`, `.genre`, `.author` and `.list`, with a chip switcher
/// between them on the ranked list and two of them in the seed. Five orderings
/// meant one book could hold two positions at once, built from two disjoint sets
/// of comparisons, and no screen could say which one answered "which do you
/// prefer". A genre view is now this list with rows hidden — see
/// `RankingFilter` — and hiding rows cannot contradict anything.
///
/// It is **always optional**. You can score, finish, log and shelve a book
/// without ever ranking anything. Ranking is offered after a log is saved and
/// can be stopped at any point — a half-finished ranking is still a valid
/// ranking, and Dewey uses whatever comparisons it was given.
struct PersonalRanking: Hashable, Codable {
    /// Book IDs in preference order, most preferred first. **This array is the
    /// ranking**; every position anywhere in the app is an index into it.
    var order: [String] = []

    /// How well-supported each book's position is.
    ///
    /// Kept because the order alone cannot answer "does the reader actually
    /// believe this?". A book placed on one comparison sits where a single tap
    /// put it and the reader never said a word about the twenty books around
    /// it; a book placed on six is somewhere they chose. Both look identical in
    /// `order`, and only one of them is worth offering to tune.
    ///
    /// Deliberately **not** a log of every comparison ever answered. A full
    /// comparison history would let Dewey rebuild the order from scratch, which
    /// is precisely the sophisticated-recommender direction §19 rules out: the
    /// list a reader can see and reason about is the list, and re-deriving it
    /// behind their back would make positions move for reasons no screen could
    /// explain.
    var placements: [String: Placement] = [:]

    /// What Dewey knows about how a book got where it is.
    struct Placement: Hashable, Codable {
        /// Comparisons the reader answered while placing it. Zero is possible
        /// and honest: the first book in an empty ranking was never compared
        /// with anything.
        var comparisons: Int
        /// When it was last placed. Feeds the "these are old" half of tuning —
        /// a position built from comparisons made a year ago may no longer be
        /// one the reader would make today.
        var placedAt: Date
    }

    var isEmpty: Bool { order.isEmpty }
    var count: Int { order.count }

    func contains(_ bookID: String) -> Bool { order.contains(bookID) }

    /// One-based position, or `nil` if the book was never placed.
    func rank(of bookID: String) -> Int? {
        order.firstIndex(of: bookID).map { $0 + 1 }
    }

    func comparisons(for bookID: String) -> Int {
        placements[bookID]?.comparisons ?? 0
    }

    func placedAt(_ bookID: String) -> Date? {
        placements[bookID]?.placedAt
    }

    /// Records a completed insertion.
    ///
    /// Takes the whole new order rather than a position because
    /// `RankingInsertion` owns the arithmetic and returns the finished array;
    /// re-deriving the index here would be a second implementation of the same
    /// decision. Placement metadata is written for the candidate only — nobody
    /// else's position changed, and stamping every book with today's date would
    /// destroy the one signal tuning reads.
    mutating func apply(order newOrder: [String], placing bookID: String, comparisons: Int, on date: Date) {
        order = newOrder
        placements[bookID] = Placement(comparisons: comparisons, placedAt: date)
        // Anything no longer in the order has no position to support.
        placements = placements.filter { order.contains($0.key) }
    }

    mutating func remove(_ bookID: String) {
        order.removeAll { $0 == bookID }
        placements[bookID] = nil
    }
}

// MARK: - Filtering

/// **A view of the one ranking, never a ranking of its own** (§19).
///
/// A filter hides rows. It does not reorder, recompute, or re-ask anything, and
/// there is no such object as a "Sci-Fi ranking" — there is `PersonalRanking`
/// with everything that is not science fiction taken off the screen. The
/// positions a reader sees under a filter are their positions in the one list,
/// gaps and all, which is what makes the claim checkable: 1, 4, 9 is visibly a
/// subset, where 1, 2, 3 is visibly a second ranking.
enum RankingFilter: Hashable {
    case all
    case genre(String)
    case year(Int)
    case author(String)

    var title: String {
        switch self {
        case .all: return "All"
        case .genre(let g): return g.capitalized
        case .year(let y): return String(y)
        case .author(let a): return a
        }
    }
}

// MARK: - One comparison

/// One question in an insertion.
///
/// **There is one prompt, and it never changes** (§13.1).
///
/// This used to carry a `Prompt` enum of four questions — "Which stayed with you
/// more?", "Which would you recommend first?", "Which would you rather reread?",
/// "Which belongs higher in your library?" — rotated across the rounds of a
/// *single* insertion so the exercise "doesn't feel like a form". The rotation
/// was justified on the grounds that each asks a genuinely different question
/// and the difference is the interesting part. Both halves of that are true, and
/// together they are the bug: four different questions were being asked, and
/// their four answers were being folded into **one** ordering. The book that
/// stayed with you is frequently not the one you would recommend first, so the
/// resulting list is an average of incompatible judgements — a ranking nobody
/// actually holds.
///
/// The surviving prompt is now `Judgement.RankingCopy.comparison`, which asks
/// for **preference** rather than for what "belongs higher". The old wording was
/// one question, but it was a question about merit, and merit is what
/// `Judgement.ScoreCopy` already asks for — a reader answering it honestly was
/// giving Dewey their score a second time, in a worse format.
struct RankingComparison: Identifiable, Hashable {
    let id = UUID()
    let candidate: String     // the book being placed
    let opponent: String      // the already-ranked book it's measured against

    /// The single question, for every pair in every round.
    static var prompt: String { Judgement.RankingCopy.comparison }
    static var support: String { Judgement.RankingCopy.comparisonSupport }

    enum Answer {
        case candidate
        case opponent
        case equal
        case tooDifferent
        case stop
    }
}

// MARK: - Insertion

/// Binary-search insertion over an ordered list.
///
/// Deliberately simple: no Elo, no global leaderboard, no decay. The reader can
/// stop early — if they do, the book lands at the midpoint of whatever range is
/// still open, which is the honest answer given what they told us.
///
/// **How many questions this asks scales with the ranking, and is capped**
/// (§19). Binary search already adapts on its own — the work is `log2` of the
/// open window, so a 3-book ranking costs two questions and a 25-book ranking
/// five — and it needed no tiers, no thresholds and no table of sizes. What it
/// did need was a ceiling: unbounded, a 67-book ranking asks seven and a
/// 300-book one asks nine, and past about six the exercise stops being a
/// pleasant tactile thing and becomes an exam. `maximumQuestions` stops there
/// and places the book in the middle of whatever is still open, which on a
/// 100-book ranking is a window of two positions. Anything left over is what
/// tuning is for.
///
/// Resulting shape, with no size hardcoded anywhere. Measured by exercising
/// this type over every size and answer pattern rather than derived on paper:
///
/// | Ranked books | Questions |
/// |---|---|
/// | 1–2   | 1–2 |
/// | 3–10  | 2–4 |
/// | 11–30 | 4–5 |
/// | 31+   | 5–6 |
///
/// A refusal (`.tooDifferent`) costs a question, so a reader who declines
/// several pairs can see one or two more than the table — which is right: they
/// answered that many times, they just did not answer with an ordering.
///
/// **Past about 63 ranked books the cap can bite**, and the search stops with
/// the window still open. The midpoint of an unexplored window is the honest
/// answer — the reader was never shown the books in it, and promoting the
/// candidate above them would be Dewey inventing a comparison, the same
/// fabrication `.tooDifferent` stopped committing.
///
/// Honest is not always enough. On a 300-book ranking a reader who preferred
/// the new book in all six comparisons landed it at **No. 3**: every answer
/// pointed at the top of the list and the result did not say so, which reads as
/// the app disagreeing with them. Being off by two in the middle of a long list
/// costs nothing; being off by two at the top costs the only positions anyone
/// ever quotes.
///
/// So there is **one optional extra question, and only at the top** — see
/// `stage` and `offersBoundaryQuestion`. It is not a seventh round of the
/// search: it is asked once, against one specific book, and only when answering
/// it could move the candidate into the first few positions.
struct RankingInsertion {
    /// The ceiling on ordinary rounds, and the only number in this type that
    /// was chosen rather than derived.
    static let maximumQuestions = 6

    /// How many positions count as "the top" for the boundary question.
    ///
    /// Three, because that is how far people count. "My third favourite book"
    /// is a sentence a reader says; "my ninth favourite book" is a spreadsheet.
    /// This is the whole definition of "important boundary" in this type —
    /// there is no notion of an important *mid-list* boundary, because there
    /// isn't one: at the cap the open window is always about 1/64th of the
    /// list, which is immaterial at No. 150 and decisive at No. 1.
    static let topPositions = 3

    /// Which question the insertion is asking.
    enum Stage: Hashable {
        /// The binary search. Up to `maximumQuestions` of these.
        case placing
        /// The single optional question at the top boundary. Never more than
        /// one, never reached twice, and never entered mid-list.
        case boundary
    }

    let candidate: String
    private(set) var low: Int
    private(set) var high: Int
    private var order: [String]
    private(set) var asked = 0
    private(set) var stage: Stage = .placing

    /// Opponents the reader declined to compare against.
    ///
    /// See `.tooDifferent` in `answer(_:)`. Held as book IDs rather than
    /// indices because the window moves underneath them.
    private var skipped: Set<String> = []

    init(candidate: String, into order: [String]) {
        self.candidate = candidate
        self.order = order
        self.low = 0
        self.high = order.count
    }

    var isComplete: Bool { low >= high }

    // MARK: The boundary question

    /// **Whether one more question could put this book in the top few.**
    ///
    /// Four conditions, and all of them have to hold:
    ///
    /// 1. `low < topPositions` — the open window still contains a top position,
    ///    so the answer decides something a reader would quote.
    /// 2. `high - low >= 2` — the window is genuinely open. A window of one is
    ///    already resolved; asking again would be theatre.
    /// 3. `high < order.count` — the reader preferred the candidate at least
    ///    once. Without this, someone who answered `.tooDifferent` six times
    ///    would be asked a seventh question having made no ordering claim at
    ///    all, which is a nag dressed as a courtesy.
    /// 4. Not already asked (`stage == .placing`).
    ///
    /// Deliberately **not** offered at the bottom of the list. "Is this my new
    /// least favourite?" is a real question and nobody has ever wanted to be
    /// asked it.
    var offersBoundaryQuestion: Bool {
        stage == .placing
            && !isComplete
            && asked >= Self.maximumQuestions
            && low < Self.topPositions
            && high - low >= 2
            && high < order.count
    }

    /// The book the boundary question is asked against: the best book whose
    /// position is still unresolved.
    ///
    /// Not the midpoint. The midpoint would halve the window, which is the
    /// efficient question; this is the *legible* one — it is the book currently
    /// holding the position the candidate might take, so "which do you prefer"
    /// and "does this go above it" are the same question, and the answer either
    /// lands the book at that position or does not.
    private var boundaryIndex: Int? {
        guard low < high, low < order.count else { return nil }
        return low
    }

    /// The position the candidate takes if the reader picks it here. Drives the
    /// framing line on the screen — see `Judgement.RankingCopy.boundaryNote`.
    var boundaryPosition: Int { low + 1 }

    /// Roughly how many questions remain. Shown so the exercise feels bounded.
    ///
    /// Bounded by the cap as well as by the window, so the count never promises
    /// more questions than the flow will actually ask.
    var remainingEstimate: Int {
        guard !isComplete else { return 0 }
        if stage == .boundary { return 1 }
        guard asked < Self.maximumQuestions else { return 0 }
        let window = max(1, Int(log2(Double(high - low + 1)).rounded(.up)))
        return max(1, min(window, Self.maximumQuestions - asked))
    }

    var nextComparison: RankingComparison? {
        guard !isComplete else { return nil }
        if stage == .boundary {
            guard let index = boundaryIndex else { return nil }
            return RankingComparison(candidate: candidate, opponent: order[index])
        }
        guard asked < Self.maximumQuestions, let probe = probeIndex() else { return nil }
        return RankingComparison(candidate: candidate, opponent: order[probe])
    }

    /// The book to measure against: the midpoint of the open window, or the
    /// nearest book to it the reader has not already declined.
    ///
    /// Walks outward from the midpoint rather than picking a fresh random
    /// opponent, because the midpoint is what makes the search halve. A probe
    /// one or two rows off centre costs a fraction of a question; a random one
    /// costs the guarantee.
    private func probeIndex() -> Int? {
        guard low < high else { return nil }
        let mid = (low + high) / 2
        for offset in 0..<max(1, high - low) {
            for index in [mid - offset, mid + offset] where index >= low && index < high && index < order.count {
                if !skipped.contains(order[index]) { return index }
            }
        }
        return nil
    }

    /// Returns the final order once the insertion completes or is stopped, and
    /// `nil` while there is still a question to ask.
    mutating func answer(_ answer: RankingComparison.Answer) -> [String]? {
        if stage == .boundary { return answerBoundary(answer) }
        guard let probe = probeIndex() else { return finish(at: (low + high) / 2) }
        asked += 1

        switch answer {
        case .candidate:
            high = probe                   // candidate ranks above the opponent
        case .opponent:
            low = probe + 1                // candidate ranks below
        case .equal:
            // A real answer, and the most precise one available: two books the
            // reader cannot separate belong next to each other. Nothing is left
            // to narrow.
            return finish(at: probe)
        case .tooDifferent:
            // **Not an answer, and no longer treated as one** (§19). This used
            // to collapse the window to the midpoint and end the insertion, so
            // declining to compare a novel with a poetry collection *placed the
            // book next to that collection* — a strong claim about order,
            // derived from a refusal to make one.
            //
            // It now means only "not this pair". The window is untouched and
            // the same position is probed against the next-nearest book. If
            // every book in the window has been declined there is nothing left
            // to ask, and the midpoint is the honest fallback.
            skipped.insert(order[probe])
            if probeIndex() == nil { return finish(at: (low + high) / 2) }
        case .stop:
            return finish(at: (low + high) / 2)
        }

        if low >= high { return finish(at: low) }
        if asked >= Self.maximumQuestions {
            // Out of ordinary questions. Either this is a top-boundary case
            // worth one more, or the midpoint of the open window is the answer.
            guard offersBoundaryQuestion else { return finish(at: (low + high) / 2) }
            stage = .boundary
            return nil
        }
        return nil
    }

    /// The one extra question, answered.
    ///
    /// Every path here ends the insertion. There is no second boundary question
    /// and no way back into the search — the reader was told this was the last
    /// choice, and a flow that then asks another one has lied to them.
    private mutating func answerBoundary(_ answer: RankingComparison.Answer) -> [String]? {
        guard let index = boundaryIndex else { return finish(at: (low + high) / 2) }
        asked += 1
        switch answer {
        case .candidate:
            // It beats the best book still in play, so it takes that position.
            return finish(at: index)
        case .opponent:
            // It does not. Everything above `index` is now settled, and the
            // midpoint of what is left is the honest answer for the rest —
            // which is exactly the fallback this question was added to improve
            // on, now one position better informed.
            low = index + 1
            return finish(at: (low + high) / 2)
        case .equal:
            return finish(at: index)
        case .tooDifferent, .stop:
            // No ordering claim made. Nothing has changed, so the answer is
            // what it would have been without the question.
            return finish(at: (low + high) / 2)
        }
    }

    private mutating func finish(at index: Int) -> [String] {
        let position = min(max(index, 0), order.count)
        var result = order
        result.insert(candidate, at: position)
        order = result
        low = position
        high = position
        return result
    }

    /// Bail out entirely, keeping the list untouched.
    func abandoned() -> [String] { order }
}
