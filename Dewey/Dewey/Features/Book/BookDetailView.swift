import SwiftUI

/// The book page.
///
/// **A concrete recommendation leads, when Dewey has one** (`recommendationContext`)
/// — a person's reason is the most persuasive thing on the page and, when it
/// exists, is the reason the reader is here at all. Then the **Dewey Score**,
/// the number the crowd landed on. Then the reader's own state and actions:
/// status, score, rank, Favorite, review, Log.
///
/// **There is no "Why it reached you" section, and no provenance chain.**
/// Dewey can say who sent a book when somebody genuinely did — that is
/// `recommendationContext`, a name and a reason, nothing more. It cannot
/// honestly say *why* a self-found book "reached" its reader, and it no
/// longer tries to: a self-found save — most of them — renders nothing where
/// that story would have gone. See `Provenance`'s own note for why.
///
/// After the reader's own state: the people they follow and what those
/// people wrote, the lists holding the book, the catalogue record, then
/// author and series exploration. Details are last, and collapsed, because
/// nobody scrolls for them and everybody wants them once.
///
/// **§13.2 removed a different duplication.** The page used to state your
/// reading status four times and offer two competing editors for it; it now
/// carries one status control and one primary action, and every fact about
/// your copy appears exactly once. See `personalStateBlock`.
struct BookDetailView: View {
    /// The snapshot the page was pushed with (§16). Kept private because a
    /// snapshot ages: catalog enrichment and import promotion write into the
    /// store *after* the push, and every reference below reads through
    /// `book`, which re-resolves against the store so those writes land on
    /// screen. Seed books resolve to themselves; the cost is a dictionary
    /// lookup.
    private let initialBook: Book

    init(book: Book) {
        self.initialBook = book
    }

    @Environment(DeweyStore.self) private var store

    private var book: Book { store.book(resolving: initialBook) }

    // Sheets
    @State private var showingLog = false
    @State private var logExisting: DiaryEntry?
    @State private var showingRanking = false
    @State private var showingAddToList = false
    @State private var showingRecommend = false
    @State private var showingCapture = false

    // Inline note editing
    @State private var noteDraft: String = ""
    @State private var editingNote = false

    // Community.
    //
    // `nil` means "the reader has not chosen" — see `effectiveFilter`. It was
    // `= .friends`, a fixed default, which was harmless only while `.friends`
    // silently returned everything. Now that it filters, a fixed default lands
    // a book whose reviews are all from strangers on an empty section with a
    // sentence in it, and lands a fresh account — following nobody — on an
    // empty section for *every* book in the app.
    @State private var reviewFilter: ReviewFilter?
    @State private var revealedSpoilers: Set<String> = []
    @State private var expandedReviews: Set<String> = []

    /// Closed on arrival. See `detailsSection`.
    @State private var detailsExpanded = false

    /// Closed on arrival. See `historyDisclosure`.
    @State private var historyExpanded = false

    /// Read for the judgement pair, which drops from two columns to one at
    /// accessibility sizes. See `judgementPair`.
    @Environment(\.dynamicTypeSize) private var typeSize

    // MARK: - Derived state

    private var entry: LibraryEntry? { store.entry(for: book.id) }
    private var myStatus: ReadingStatus? { store.status(of: book.id) }

    /// Whether the reader has finished this book, **from either record**.
    ///
    /// Not `myStatus == .finished`, which is the library only. A book logged as
    /// a finish but never shelved — most of the seeded back catalogue, and any
    /// read logged straight from a search result — has no library entry at all,
    /// so the "Place it" offer never appeared on exactly the books most likely
    /// to be missing from Your Ranking.
    private var hasFinished: Bool { store.hasFinished(book.id) }
    private var myRating: Rating? { store.myRating(for: book.id) }
    private var isFavorite: Bool { store.isFavorite(book.id) }
    private var myEntries: [DiaryEntry] { store.entries(forBook: book.id) }
    private var latestEntry: DiaryEntry? { store.latestEntry(for: book.id) }
    private var bookMoments: [Moment] { store.moments(forBook: book.id) }

    private var incomingRecommendation: Recommendation? {
        store.recommendations.first { $0.bookID == book.id && $0.isIncoming }
    }

    private var sentRecommendation: Recommendation? {
        store.sent.first { $0.bookID == book.id }
    }

    /// Every list holding this book that the reader can see — theirs and any
    /// public one. `listsSection` is the only reader of it; the fact table used
    /// to carry a second, flatter copy of the same information.
    private var listsContaining: [BookList] { store.lists(containing: book.id) }

    /// Readers you follow who scored this book **and did not review it** (§21).
    ///
    /// The unfiltered version put the same person on the page twice, roughly
    /// two hundred points apart, *with two different numbers*: the Bluets page
    /// listed "Tobias Nkemelu … 9.1" under Readers and "Tobias Nkemelu … 8.6"
    /// under Reviews. Both are real — `ReaderProfile.ratings` is the score on
    /// their profile and `Review.rating` is the score attached to the piece of
    /// writing — and a reader has no way to know that, so the page reads as
    /// having a bug where it is in fact holding two records.
    ///
    /// Only one of the two can be shown, and it is the review: it carries the
    /// name, the score, and several sentences of why. A row that says the same
    /// person felt something, without saying what, is the lesser of two claims.
    private var friendsWhoRead: [ReaderProfile] {
        let reviewers = Set(store.reviews(for: book.id).map(\.readerID))
        return store.readersWhoRead(book.id).filter { !reviewers.contains($0.id) }
    }
    private var friendsReading: [ReaderProfile] { store.readersCurrentlyReading(book.id) }
    private var friendsFavourited: [ReaderProfile] { store.readersWhoFavourited(book.id) }
    private var reviews: [Review] { store.reviews(for: book.id, filter: effectiveFilter) }

    /// The filter actually in force: the reader's choice, or — before they make
    /// one — Friends where a Friends slice exists and everything otherwise.
    /// Friends-first is still the argument (§12.1); it just cannot be the
    /// argument on a book no friend has read.
    private var effectiveFilter: ReviewFilter {
        reviewFilter ?? (offersFilters ? .friends : .popular)
    }

    /// Everything written about this book, unfiltered — the denominator that
    /// decides whether offering filters is honest.
    private var totalReviews: Int {
        store.allReviews.filter { $0.bookID == book.id }.count
    }

    private var relatedBooks: [Book] { book.relatedBookIDs.map { store.book($0) } }

    /// Position in Your Ranking, with the size of the field.
    ///
    /// "No. 1" alone is unreadable — of what? — and the denominator is also the
    /// honest qualifier on a young library: No. 1 of 3 is a different claim from
    /// No. 1 of 300.
    private var myRank: (position: Int, total: Int)? {
        guard let position = store.rank(of: book.id) else { return nil }
        return (position, store.rankedCount)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                hero
                openingBlock
                listsSection
                aboutSection
                peopleSection
                seriesSection
                alsoBySection
                relatedSection
                detailsSection
                closingRule
            }
            .padding(.bottom, Theme.Space.vast)
        }
        .background(Theme.Palette.paper)
        .scrollIndicators(.hidden)
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .logFlow(book: book, isPresented: $showingLog, existing: logExisting)
        .sheet(isPresented: $showingRanking) {
            RankingSheet(book: book)
        }
        .sheet(isPresented: $showingAddToList) {
            AddToListSheet(book: book)
        }
        .sheet(isPresented: $showingRecommend) {
            RecommendSheet(book: book)
        }
        .sheet(isPresented: $showingCapture) {
            MomentCaptureSheet(book: book)
        }
        // The refresh policy's trigger (§16). Fire-and-forget on purpose:
        // the page has already rendered from what Dewey holds, and the store
        // decides whether the catalog is even worth asking — seed books and
        // fresh answers return immediately. Keyed to the ID so a push to a
        // related book re-evaluates.
        .task(id: initialBook.id) {
            await store.enrichIfNeeded(initialBook.id)
        }
    }

    // MARK: - Opening hierarchy

    /// The blocks under the hero, in one fixed order.
    ///
    /// **A concrete recommendation, when there is one, leads.** If somebody
    /// sent this book — or a genuine person-originated save put it here —
    /// that is the reason the reader is looking at this page at all, and it
    /// reads before Dewey's own verdict on the book.
    ///
    /// Otherwise: score, then the people you follow and what they thought,
    /// then your own state and actions. A reader who has never heard of the
    /// book needs one number before they will read a sentence about it
    /// (§12.1) — but Dewey mostly has no such number (§12.5.4), and on those
    /// books `deweyScoreSection` is one quiet sentence, not a headline.
    /// `communitySection` is what actually answers "should I read this":
    /// named people the reader recognises, and what they rated or wrote. It
    /// used to sit *after* `personalStateBlock` — behind the status control,
    /// the review editor, Moments and the history disclosure — so a reader
    /// had to scroll past their own unfilled state on a book they had not
    /// even opened yet to reach the one section with real human judgement in
    /// it. Trusted-reader perspective now reads before the reader is asked to
    /// do anything themselves.
    ///
    /// **There is no "Why it reached you" section, and no chain.** Dewey can
    /// say who sent a book when somebody did; it cannot honestly say *why* a
    /// self-found book "reached" anyone, and a section that fires with a
    /// two-node diagram of "You found it → You" for every self-found book —
    /// which is most of them — is the absence of a story drawn as if it were
    /// one. See `Provenance`'s own note.
    ///
    /// **The A/B variant harness is gone.** It existed to compare two orderings
    /// of a region that also contained a *second, competing* editor — a
    /// prominent Log button with a full inline status picker and rating slider
    /// stacked underneath it. Once the duplicate editor went, the thing being
    /// compared went with it: there is now one action in this region, so there
    /// is nothing left to reorder against it.
    @ViewBuilder
    private var openingBlock: some View {
        recommendationContext
        deweyScoreSection
        communitySection
        personalStateBlock
    }

    // MARK: - Recommendation context

    /// **The one social fact this page states without a heading.**
    ///
    /// Fires only when Dewey genuinely knows a person is behind this book: an
    /// active incoming recommendation, with its reason and sender, gets the
    /// full card. Otherwise a genuine person-originated library entry —
    /// "From Priya's list" — gets the same one-line treatment the library row
    /// uses, with the quoted reason underneath when there is one. A
    /// self-found or outside-Dewey save renders nothing here: Dewey has
    /// nothing true to say about how it arrived, so it says nothing.
    @ViewBuilder
    private var recommendationContext: some View {
        if let rec = incomingRecommendation {
            reasonBlock(rec)
        } else if let entry, let text = store.personAttributionText(for: entry.provenance) {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                ProvenanceLine(text: text, reader: store.reader(entry.provenance.readerID), emphasis: true)
                if let reason = entry.provenance.reason, !reason.isEmpty {
                    Text("“\(reason)”")
                        .font(Theme.TypeScale.prose())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .pageMargin()
            .padding(.top, Theme.Space.snug)
        }
    }

    // MARK: - Section scaffolding

    /// Flat sections, hairline separated. Cards are reserved for the two blocks
    /// that are genuinely *someone speaking to you*.
    private func sectionHeader(_ text: String) -> some View {
        Text(text).kickerStyle().pageMargin()
    }

    private var divider: some View {
        Rule().padding(.vertical, Theme.Space.roomy)
    }

    private var closingRule: some View {
        Rule()
            .frame(width: 40)
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Space.loose)
    }

    // MARK: - 1. Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            // **Beside the cover, until beside the cover means hyphenated**
            // (§19.2).
            //
            // The cover is a fixed 132 points that scales with type, so at an
            // accessibility size it takes most of the width and leaves the
            // title a column too narrow to set a word in: "The Fellowship of
            // the Ring" came out as "The Fel-", "low-", "ship of the", "Ring" —
            // four lines, two hyphens, on the masthead of every book page.
            //
            // Stacked, the title gets the whole measure. The plate loses its
            // side-by-side composition, which is the right thing to lose: the
            // composition is a nicety and the title is the page.
            if typeSize.isAccessibilitySize { stackedHero } else { sideBySideHero }

            if !heroChips.isEmpty {
                chipStrip
            }
        }
        .padding(.top, Theme.Space.snug)
    }

    private var stackedHero: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            BookCoverView(book: book, width: 132, scalesWithType: true)
            heroTitle
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
    }

    private var heroTitle: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(book.title)
                .font(Theme.TypeScale.title())
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(book.subtitleLine)
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if let physical = heroPhysicalLine {
                Text(physical)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Length, and the format you read it in.
    ///
    /// **Length is a deciding fact and it was filed as a reference one.** Page
    /// count sat eleven rows into a collapsed disclosure at the foot of the
    /// page, next to the ISBN — but "two hundred pages" and "nine hundred
    /// pages" are different propositions on a Tuesday night, and a reader
    /// weighs that *before* they read the blurb, not after they have gone
    /// looking for the catalogue record. It belongs in the plate.
    ///
    /// It earns its place twice over: the text column beside a 132pt cover was
    /// two lines tall on most books, and the leftover height is exactly the
    /// "hole beside the cover" the hero has been redistributing with vertical
    /// centring rather than filling. A third line of real information fills it.
    ///
    /// `nil` on a book with neither fact, which is most imported ones — an
    /// empty line here would put the hole back with a colon in it.
    private var heroPhysicalLine: String? {
        var parts: [String] = []
        if let pages = book.pageCount { parts.append("\(pages) pages") }
        // The reader's own copy, when they have said what it was. Not a
        // catalogue fact — this is the edition *they* met, which is the only
        // edition question the prototype can answer honestly.
        if let format = latestEntry?.format { parts.append(format.title) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var sideBySideHero: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            HStack(alignment: .top, spacing: Theme.Space.base) {
                BookCoverView(book: book, width: 132, scalesWithType: true)

                // §12.9: the hole beside the cover.
                //
                // The text column is shorter than the cover whenever a book is
                // unrated, and every point of the difference was being dumped
                // underneath it — a stack of type at the top and empty paper
                // against the cover's lower half. The fix is not an offset: the
                // column takes the height of whichever column is taller and
                // centres its content inside it, so the leftover space is split
                // and the two columns share one optical centre. That reads as a
                // book plate rather than as something that failed to load.
                //
                // Nothing here is measured, which is the point — no fixed
                // height, no number tuned to a seeded title. When the text is
                // the taller column the centring is a no-op and the row is
                // top-aligned exactly as before, so a one-word title and a
                // five-line one both land, at every Dynamic Type size.
                // Cover, title, author — and nothing about *you* (§13.2).
                //
                // This column used to open with a status badge and close with
                // your rating numeral and Favorite mark. Both are now stated
                // in `personalStateBlock`, roughly one screen below, which is
                // the block that owns them and the one place they can be
                // changed. Carrying them here as well was two of the four
                // simultaneous statements of the reading status, and it put
                // your verdict directly above the crowd's without labelling
                // either — a reader met two numerals in the masthead and had to
                // work out which was whose.
                heroTitle
                    // `.leading` is leading-and-centred: horizontal alignment
                    // is unchanged, vertical alignment is the fix above. The
                    // greedy width replaces the `Spacer` this row used to
                    // carry.
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .pageMargin()
        }
    }

    /// Genres only, and the Details table below carries the themes (§13.2).
    ///
    /// This used to be `book.genres + book.themes` merged into one undifferen-
    /// tiated strip while the Details table further down listed the same values
    /// again under two *separate* headings. So a reader met "Literary Fiction,
    /// Experimental, Books, Girlhood" as one flat row here — in which "Books"
    /// is a meaningless label on a book — and then the same four values
    /// correctly split into Genres and Themes at the bottom of the page. One of
    /// the two had to go, and it is this one: a masthead strip is for the
    /// coarse, recognisable category, and the distinction between a genre and a
    /// theme only means anything once it is labelled.
    private var heroChips: [String] {
        Array(book.genres.prefix(4))
    }

    /// Wraps rather than scrolls, for the same reason the shelf chips do
    /// (§12.9): a horizontal ScrollView cuts a word in half at the screen edge,
    /// and a half-word reads as broken rather than as "there is more this way."
    /// It survives default type because these labels are short; it does not
    /// survive accessibility sizes, where "Colour" arrives on screen as "Co".
    /// Wrapping has no width at which it fails.
    private var chipStrip: some View {
        FlowLayout(spacing: Theme.Space.tight) {
            ForEach(heroChips, id: \.self) { label in
                Text(label)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .padding(.horizontal, Theme.Space.snug)
                    .padding(.vertical, 5)
                    .background(Capsule().stroke(Theme.Palette.rule, lineWidth: 1))
            }
        }
        .pageMargin()
    }

    // MARK: - 2. The Dewey Score

    /// The loudest thing on the page after the title (§12.1, §12.5.4).
    ///
    /// It sits in the masthead region, immediately under the cover. The same
    /// number used to be a caption at the bottom of a histogram in the sixth
    /// section down, rendered small on purpose. A reader who has never heard of
    /// the book needs one number before they will read a sentence about it, and
    /// withholding it was principle paid for with attention nobody had.
    ///
    /// The histogram sits *beside* the numeral rather than under it, which keeps
    /// the whole block about a hundred points tall — tall enough to be the
    /// headline, short enough that the button underneath is still on screen.
    /// **The ring is drawn only when there is a score to put in it.**
    ///
    /// It used to render unconditionally, so every book Dewey has no
    /// distribution for — which is every book imported from the catalogue, and
    /// therefore every book a reader finds through Search — opened on an 88pt
    /// hairline circle containing a single em dash, under a heading reading
    /// DEWEY SCORE, as the loudest object on the page. That reads as a number
    /// that failed to load, in the masthead, on first impression.
    ///
    /// `scoreDetail` beside it already branched correctly on `communityCount`
    /// and printed a sentence instead of a histogram; the circle simply never
    /// got the same test. Unrated now shows the kicker and the sentence, which
    /// is the whole truth about the book and takes a third of the height.
    ///
    /// The seed carries a hand-written distribution for `white-album` added
    /// specifically because "this page would have opened on an em dash" — a
    /// per-book patch for a whole-corpus problem. That note can go; this is the
    /// general answer.
    /// **And the kicker goes with the ring** (§21).
    ///
    /// Withholding the circle fixed half of it. The other half was that a book
    /// Dewey has no distribution for still drew a tracked, uppercase
    /// **DEWEY SCORE** across the masthead with the sentence "Nobody has rated
    /// this one yet." underneath — a section heading announcing a section that
    /// does not exist. On an imported book that is the *first* of four
    /// consecutive headed blocks whose entire content is a denial, and the
    /// reader meets it before they have met a single fact about the book.
    ///
    /// A heading earns its line by organising something. With no crowd there is
    /// nothing to organise, so what is left is one quiet sentence that says the
    /// whole truth and takes a fifth of the height.
    @ViewBuilder
    private var deweyScoreSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            if communityCount > 0 {
                Text("Dewey Score").kickerStyle()
                HStack(alignment: .center, spacing: Theme.Space.base) {
                    ScoreCircle(score: communityAverage, size: .large)
                        .accessibilityLabel(scoreLabel)
                    scoreDetail
                }
            } else {
                scoreDetail
            }
        }
        .pageMargin()
        .padding(.top, Theme.Space.roomy)
    }

    private var communityAverage: Double? { store.communityAverage(book.id) }
    private var communityCount: Int { store.communityCount(book.id) }

    /// Twenty half-point bins (§12.3). Input keeps a tenth of a point; ninety-nine
    /// bars would be noise, and the shape is the only thing this drawing is for.
    @ViewBuilder
    private var scoreDetail: some View {
        if communityCount > 0 {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                DistributionHistogram(counts: store.ratingDistribution(book.id), height: 52)

                // **The axis was unlabelled** (§13.6). Twenty bars rising to the
                // right, with nothing saying where the left edge starts or the
                // right edge ends — so the shape was legible and its meaning was
                // not, and a reader could not tell a distribution peaking at
                // eight from one peaking at five. Two figures at the ends is the
                // whole fix; a full axis would out-shout the score beside it.
                //
                // **The rater count is no longer wedged between them.** It sat
                // in the middle of the axis row under `lineLimit(1)` and
                // `minimumScaleFactor(0.8)`, in a column roughly a hundred
                // points wide beside an 88pt circle — so "4,182 readers rated
                // it" was already shrunk at default type and illegible at an
                // accessibility size, and the two axis figures it was crushing
                // are the only part of the row that has to hold its position.
                // It was never part of the axis: it is a caption about the
                // whole block, and it reads as one on its own line.
                HStack(spacing: Theme.Space.snug) {
                    Text(Rating.clamping(Rating.range.lowerBound).compact)
                    Spacer(minLength: 0)
                    Text(Rating.clamping(Rating.range.upperBound).compact)
                }
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .lineLimit(1)
                // Decoration for VoiceOver: the histogram already speaks its own
                // range and peak, and the count below says the rest.
                .accessibilityHidden(true)

                Text("\(communityCount.formatted()) readers scored it")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text("Nobody has scored this one yet.")
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// VoiceOver hits the circle before it hits the kicker above it, so the label
    /// carries the kicker's meaning instead of relying on reading order. The
    /// number is spoken through `Rating` so it is phrased the same way here as it
    /// is on every other rating in the app.
    private var scoreLabel: String {
        guard let communityAverage else { return "Dewey Score, not yet scored" }
        return "Dewey Score, \(Rating.clamping(communityAverage).spoken), from \(communityCount.formatted()) readers"
    }

    // MARK: - 3. Personal state and actions

    /// **One logging path, and every fact stated once** (§13.2).
    ///
    /// This region used to say the reading status *four times* — a badge in the
    /// hero, an "In your library · Finished" line under the button, the selected
    /// chip in a "Where it sits" row, and a Status row in a fact table further
    /// down the page — and it offered *two competing editors*: a prominent
    /// "Log this read" button with a complete inline status picker, rating
    /// slider and Favorite toggle stacked directly beneath it. A reader could
    /// not tell which one was canonical, or whether using one meant the other
    /// had not been applied.
    ///
    /// **There is no "Your relationship" card.** Status, score, rank, Favorite
    /// and the review used to sit inside one bordered card under that name — a
    /// wrapper nobody but a product team would reach for, and one that put
    /// Favorite, one of the four things that make Dewey Dewey, in a fact-table
    /// row between "Reread" and "Format". Each primitive now states itself: a
    /// tappable status row, the score/rank pair in the two visual languages the
    /// app reserves for them, a Favorite mark on its own line, and the review
    /// under its own name.
    ///
    /// **Order follows what the reader has actually done.** A book with a
    /// judgement leads with it — score and rank are the loudest thing Dewey
    /// knows about a book the reader has finished, louder than the fact that
    /// they finished it. A book with no judgement yet has nothing to lead
    /// with, so the block reduces to the status row and the actions under it;
    /// an untouched book has neither, and reduces further to the two actions
    /// that add it.
    // `communitySection` now sits between `deweyScoreSection` and this block
    // (§21 update, trusted-reader prominence pass), so this no longer
    // directly follows the score — it needs the same hairline separation
    // every other section below the opening block draws for itself.
    @ViewBuilder
    private var personalStateBlock: some View {
        divider
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            judgementPair
            favoriteRow
            myReviewRow
            statusControl
            actionsRow
            captureMomentRow
            // The note about your own copy, with the rest of your own copy
            // (§21). It cannot go *inside* the status control: that row is a
            // button that opens the log editor, and a second control nested
            // in a control is a tap nobody can predict.
            privateNoteRow
            momentsSection
            historyDisclosure
            secondaryActions
            sentLine
        }
    }

    /// Favorite, on its own line — not a row in a fact table between "Reread"
    /// and "Format". It is one of the four things that make Dewey Dewey, and
    /// the mark says so on sight.
    @ViewBuilder
    private var favoriteRow: some View {
        if isFavorite {
            HStack(spacing: Theme.Space.tight) {
                FavoriteMark(filled: true, size: 15)
                Text(Judgement.FavoriteCopy.title)
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.ink)
            }
            .pageMargin()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Judgement.FavoriteCopy.title)
        }
    }

    // MARK: - Your Score and Your Ranking

    /// **The two judgements, side by side, in two different visual languages**
    /// (§19).
    ///
    /// They used to be two consecutive rows in the fact table below — "Your
    /// Score  8.0" directly above "Rank  No. 3 of 14" — in the same font, the
    /// same weight and the same column, between "Reread" and "Format". Two
    /// numbers set identically and stacked read as two measurements of one
    /// thing, and a reader looking at an 8.0 above a No. 3 in that layout has
    /// every reason to think one of them is wrong.
    ///
    /// Pulled out and given the two shapes the app reserves for them: a bare
    /// serif numeral for the score, an ordinal for the ranking. **There is
    /// deliberately no numeric ranking value** — no percentile, no bar, no
    /// second score out of ten. The moment a ranking acquires one, the page has
    /// two figures on the same scale again and the reader is back to deciding
    /// which the app believes.
    ///
    /// **Both halves hold their shape in all four states** (§19.2). The first
    /// build let the unset side collapse: a missing score drew the words "Not
    /// scored" at `support()` beside a `display()` ordinal, so the pair had two
    /// different heights, two different baselines and two different weights
    /// depending on what the reader happened to have recorded. A pair whose
    /// geometry depends on its contents is not a pair — and this one is the
    /// app's whole argument that the two are equals answering different
    /// questions.
    ///
    /// So each side is the same three lines, always: **kicker, value, caption.**
    /// The value is one line in one font — the figure, or the faint dash that
    /// stands in for it, which is `RatingMark.Unrated.stated`'s rule applied to
    /// a bigger numeral. The caption carries what a dash cannot say. Nothing
    /// moves between states except the glyphs.
    ///
    ///     YOUR SCORE     YOUR RANKING      YOUR SCORE     YOUR RANKING
    ///     8.0            No. 12            —              No. 12
    ///     out of 10      of 67             Not scored     of 67
    ///
    /// The "Place it" offer therefore cannot live *inside* the ranking slot,
    /// where it was: a button is a different height from a numeral and it put
    /// the lopsidedness back on the one state that most needed the pair to read
    /// as a pair. It is its own row underneath.
    @ViewBuilder
    private var judgementPair: some View {
        if myRating != nil || myRank != nil || hasFinished {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                // Two columns until the type gets big enough that two columns
                // means two words per line, then one. The same trade the
                // Library row makes for its score column.
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Theme.Space.base) {
                        scoreSlot
                        rankSlot
                    }
                } else {
                    HStack(alignment: .top, spacing: Theme.Space.base) {
                        scoreSlot
                        rankSlot
                    }
                }

                if myRank == nil, hasFinished {
                    placeItRow
                }

                // Unconditional when both exist. A sentence that turned up only
                // when the two disagreed would be a warning, and the
                // disagreement is not an error — it is the most interesting
                // thing on the page.
                if myRating != nil, myRank != nil {
                    Text(Judgement.RankingCopy.contrast)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .pageMargin()
        }
    }

    private var scoreSlot: some View {
        JudgementSlot(
            kicker: Judgement.ScoreCopy.title,
            value: myRating?.compact,
            caption: myRating == nil ? "Not scored" : "out of 10",
            spoken: myRating.map { "\(Judgement.ScoreCopy.title), \($0.spoken) out of 10" }
                ?? "\(Judgement.ScoreCopy.title), not scored"
        )
    }

    private var rankSlot: some View {
        JudgementSlot(
            kicker: Judgement.RankingCopy.title,
            value: myRank.map { "No. \($0.position)" },
            caption: myRank.map { "of \($0.total)" } ?? "Not placed",
            spoken: myRank.map { "\(Judgement.RankingCopy.title), number \($0.position) of \($0.total)" }
                ?? "\(Judgement.RankingCopy.title), not placed"
        )
    }

    /// The offer to rank, on its own row.
    ///
    /// Shown only for a book the reader has finished and never placed — which
    /// is the common case, since ranking is optional and always has been. Before
    /// this existed, a reader who tapped "Not now" on the receipt after a save
    /// had no way back to the question except the tuning queue.
    private var placeItRow: some View {
        Button {
            showingRanking = true
        } label: {
            HStack(spacing: Theme.Space.tight) {
                Text("Place it in \(Judgement.RankingCopy.title)")
                Image(systemName: "arrow.right")
            }
            .font(Theme.TypeScale.ui())
            .foregroundStyle(Theme.Palette.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Space.tight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Places this book by comparing it with books you have already placed")
    }

    /// The reader's own actions. Before the book is in the library the honest
    /// primary is to add it — labelled for the status it creates, not for the
    /// filing act of adding. Once it is in the library, Log moves in beside
    /// Add to list and Recommend: it is no longer the one thing to do with an
    /// untouched book, it is one of three things to do with a saved one.
    ///
    /// Logging stays reachable in both states — a reader who finished a book
    /// last year should not have to shelve it first.
    @ViewBuilder
    private var actionsRow: some View {
        if myStatus == nil {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                Button {
                    choose(.wantToRead)
                } label: {
                    Label("Want to Read", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())

                logButton.buttonStyle(QuietButtonStyle())
            }
            .pageMargin()
        } else {
            logButton.buttonStyle(QuietButtonStyle()).pageMargin()
        }
    }

    private var logButton: some View {
        Button {
            logExisting = nil
            showingLog = true
        } label: {
            Label(logButtonTitle, systemImage: "square.and.pencil")
        }
    }

    private var logButtonTitle: String {
        myEntries.isEmpty ? "Log this read" : "Log another read"
    }

    // MARK: - Capture a Moment

    /// The entry point, offered only while the book is actually open.
    ///
    /// Gated to `.reading` rather than shown whenever the book is in the
    /// library: a Moment is a line caught mid-book, and offering the action
    /// on a book not yet started, or one already finished, invites a note
    /// that is really a review wearing the wrong hat. `momentsSection` below
    /// still shows what was captured on an earlier read regardless of status —
    /// the record does not disappear when the reading ends, only the offer to
    /// add to it.
    @ViewBuilder
    private var captureMomentRow: some View {
        if myStatus == .reading {
            Button {
                showingCapture = true
            } label: {
                Label("Capture a Moment", systemImage: "quote.opening")
            }
            .buttonStyle(QuietButtonStyle())
            .pageMargin()
        }
    }

    /// What has been caught so far, most recent first. Reads like the diary's
    /// review text — full-width serif prose — because it is the same kind of
    /// object: the reader's own words, not a fact about the book.
    @ViewBuilder
    private var momentsSection: some View {
        if !bookMoments.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                Text("Moments").kickerStyle()
                VStack(alignment: .leading, spacing: Theme.Space.base) {
                    ForEach(bookMoments) { moment in
                        momentRow(moment)
                    }
                }
            }
            .padding(.top, Theme.Space.tight)
            .pageMargin()
        }
    }

    private func momentRow(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(moment.text)
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.ink)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
            Text(momentCaption(moment))
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
        }
        .contextMenu {
            Button(role: .destructive) {
                store.deleteMoment(moment.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func momentCaption(_ moment: Moment) -> String {
        let date = Self.dayFormatter.string(from: moment.capturedAt)
        guard let page = moment.pageNumber else { return date }
        return "p. \(page) · \(date)"
    }

    // MARK: - Status control

    /// The reading status, stated once, as a single tappable row — icon, name
    /// and (where the state has one worth stating plainly) a detail line.
    /// Replaces the read-only "Your relationship" card: there is nothing here
    /// to be wrong about, so the whole row opens the same log sheet the
    /// primary action does.
    ///
    /// **"Added Aug 1" does not lead here.** It is real information, but not
    /// prominent-by-default information — a save date belongs beside the
    /// other facts a reader wants once, in `historyDisclosure`, not on the
    /// line the reader scans every time they open the book. Reading keeps its
    /// start date on the line below the status, because knowing you are
    /// partway through something is closer to the point than knowing when you
    /// bookmarked it.
    @ViewBuilder
    private var statusControl: some View {
        if let status = myStatus {
            Button {
                logExisting = latestEntry
                showingLog = true
            } label: {
                statusControlLabel(status)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the log editor")
            .pageMargin()
        }
    }

    private func statusControlLabel(_ status: ReadingStatus) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.hair) {
            HStack(spacing: Theme.Space.tight) {
                Image(systemName: status.symbol)
                    .foregroundStyle(Theme.Palette.accent)
                Text(statusHeadline(status))
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.ink)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.inkFaint)
            }
            if let detail = statusDetail(status) {
                Text(detail)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
            }
        }
        .padding(Theme.Space.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.Palette.rule, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenStatus(status))
    }

    /// "Read", not "Finished" — folded together with the finish date on one
    /// line so the two do not repeat each other the way "Finished · finished
    /// Aug 9" would.
    private func statusHeadline(_ status: ReadingStatus) -> String {
        guard status == .finished else { return status.title }
        guard let finished = latestEntry?.finishedOn else { return "Read" }
        return "Read · finished \(Self.dayFormatter.string(from: finished))"
    }

    /// Only Reading gets a second line. Want to Read's date is demoted to
    /// `historyDisclosure`, and Finished's is already folded into the
    /// headline above.
    private func statusDetail(_ status: ReadingStatus) -> String? {
        guard status == .reading, let started = latestEntry?.startedOn else { return nil }
        return "Started \(Self.dayFormatter.string(from: started))"
    }

    private func spokenStatus(_ status: ReadingStatus) -> String {
        [statusHeadline(status), statusDetail(status)].compactMap { $0 }.joined(separator: ", ")
    }

    /// Equal weight, both outlined. Recommending is the act the whole product is
    /// built around, but it is not what the reader opened this page to do.
    private var secondaryActions: some View {
        HStack(spacing: Theme.Space.snug) {
            Button {
                showingAddToList = true
            } label: {
                Label("Add to list", systemImage: "text.append")
            }
            .buttonStyle(QuietButtonStyle())

            Button {
                showingRecommend = true
            } label: {
                Label("Recommend", systemImage: "paperplane")
            }
            .buttonStyle(QuietButtonStyle())
        }
        .pageMargin()
    }

    // MARK: - Recommendation reason

    /// The reason gets the most prominent prose on the page. The blurb tells you
    /// what the book is; this tells you why it is here, for you, from a person.
    private func reasonBlock(_ rec: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text(rec.reason.text)
                .font(Theme.TypeScale.proseLarge())
                .foregroundStyle(Theme.Palette.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let sender = store.reader(rec.fromReaderID) {
                NavigationLink(value: sender) {
                    ProvenanceLine(text: "\(sender.name) · \(sender.texture)", reader: sender, emphasis: true)
                }
                .buttonStyle(.plain)
            }
        }
        .pageMargin()
    }

    // MARK: - Sent

    /// Your side of an exchange, folded into your own state rather than a
    /// top-of-page section under its own heading — sending is your action, not
    /// the book's arrival story. Nothing here asks you to act again: the giver
    /// gets told they were useful, and that is the whole transaction.
    @ViewBuilder
    private var sentLine: some View {
        if let rec = sentRecommendation {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                if let recipient = store.reader(rec.toReaderID) {
                    NavigationLink(value: recipient) {
                        ProvenanceLine(text: "You sent this to \(recipient.name)", reader: recipient, emphasis: true)
                    }
                    .buttonStyle(.plain)
                }

                Text("“\(rec.reason.text)”")
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                if rec.status == .startedByRecipient {
                    HStack(spacing: Theme.Space.tight) {
                        Image(systemName: "book")
                            .font(.caption)
                        Text("They started it.")
                            .font(Theme.TypeScale.support())
                    }
                    .foregroundStyle(Theme.Palette.accent)
                } else if let reaction = rec.reaction {
                    HStack(spacing: Theme.Space.tight) {
                        Image(systemName: reaction.symbol)
                            .font(.caption)
                        Text("They marked it “\(reaction.label.lowercased())”.")
                            .font(Theme.TypeScale.support())
                    }
                    .foregroundStyle(Theme.Palette.inkSoft)
                }
            }
            .pageMargin()
        }
    }

    // MARK: - History

    /// Everything about your own copy that does not want to be on the status
    /// line: when it was added, how many times reread, its format, its tags.
    /// Collapsed by default, the same convention `detailsSection` uses for the
    /// catalogue record below — a reader wants these once, deliberately, not
    /// on every visit.
    @ViewBuilder
    private var historyDisclosure: some View {
        if !historyFacts.isEmpty {
            DisclosureGroup(isExpanded: $historyExpanded) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(historyFacts.enumerated()), id: \.element.id) { index, fact in
                        if index > 0 { Rule() }
                        FactRow(fact.id, fact.value)
                    }
                }
                .padding(.top, Theme.Space.snug)
            } label: {
                Text("History").kickerStyle()
            }
            .tint(Theme.Palette.inkSoft)
            .pageMargin()
        }
    }

    private struct HistoryFact: Identifiable {
        let id: String
        let value: String
    }

    private var historyFacts: [HistoryFact] {
        var facts: [HistoryFact] = []
        if let entry {
            facts.append(HistoryFact(id: "Added", value: Self.dayFormatter.string(from: entry.savedAt)))
        }
        if rereadCount > 0 {
            facts.append(HistoryFact(id: "Reread", value: rereadCount == 1 ? "Once" : "\(rereadCount) times"))
        }
        if let format = latestEntry?.format {
            facts.append(HistoryFact(id: "Format", value: format.title))
        }
        if let tags = latestEntry?.tags, !tags.isEmpty {
            facts.append(HistoryFact(id: "Tags", value: tags.joined(separator: ", ")))
        }
        return facts
    }

    private var rereadCount: Int {
        myEntries.filter(\.isReread).count
    }

    // MARK: - Your review

    // An "On your lists" row used to close the old fact table, naming each of your lists
    // holding the book as flat text. It was the last surviving duplication §13.2
    // set out to remove: `listsSection`, one screen down, renders *the same
    // lists* — `store.lists(containing:)` returns yours as well as the public
    // ones — as cards you can actually open. The table stated them; the rail
    // states them and is a destination. Only one of the two can be the answer,
    // and it is the one that goes somewhere.
    //
    // The reasoning that put it here was sound about the constraint it faced —
    // a `NavigationLink` nested inside the summary button would be a second
    // destination hidden in a control that already has one — and wrong about
    // the conclusion, which should have been to drop the row rather than
    // flatten it.

    // `factLabel` and `factRow` were this page's first of three private
    // label-and-value implementations, on a 92pt column stated in points. They
    // are `FactRow` now, along with the catalogue table's 108pt version and the
    // People table's second 92pt one — see that type for why a fixed column
    // cannot survive an accessibility text size.

    /// Your own review, in full — **whatever its visibility**.
    ///
    /// It used to require `hasPublishedReview`, which is `!isDraft &&
    /// visibility != .onlyMe`. So a review saved as a draft, or set to
    /// "Only me", existed in no readable form anywhere in Dewey: the diary row
    /// clamps to three lines, tapping that row opens the *editor*, and this —
    /// the one surface that sets a person's own prose full-width in serif —
    /// refused to draw it. A reader could write six paragraphs about a book,
    /// keep them private, and never see them again outside a text field.
    ///
    /// The visibility is stated instead of being used as a filter, because that
    /// is the only thing the reader loses by having it shown: they need to know
    /// a draft is still a draft. A published one says nothing, since the section
    /// heading above already says what this is.
    ///
    /// **No "Your relationship" or "What you wrote" wrapper above it.** A
    /// small kicker — "Your Review" — does the naming job a section header
    /// used to, without a heading announcing a section that, for most books,
    /// has nothing in it: this whole block renders nothing when there is no
    /// review to show.
    @ViewBuilder
    private var myReviewRow: some View {
        if let written = myWriting, let text = written.review {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("Your \(Judgement.ReviewCopy.title)").kickerStyle()
                if let caveat = writingCaveat(written) {
                    Text(caveat)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                }
                Text(text)
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Edit this entry") {
                    logExisting = written
                    showingLog = true
                }
                .buttonStyle(.plain)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.accent)
                // `.plain` hit-tests the label's bounds and nothing else, which
                // at caption size is roughly 90×15pt — a third of the 44pt
                // minimum on the only control in this block. Padded inside the
                // label so the target grows while the text stays on its line.
                .padding(.vertical, Theme.Space.snug)
                .contentShape(Rectangle())
            }
            .pageMargin()
        }
    }

    /// The most recent entry carrying any prose at all.
    private var myWriting: DiaryEntry? {
        myEntries.first { ($0.review?.isEmpty == false) }
    }

    /// Why this piece of writing is not public, when it is not. `nil` means it
    /// is, and the reader needs no caption for the ordinary case.
    private func writingCaveat(_ entry: DiaryEntry) -> String? {
        if entry.reviewIsDraft { return "Draft — saved with the entry, published by nobody." }
        if entry.visibility == .onlyMe { return "Only you can see this." }
        return nil
    }

    /// Private, one line, never prompted for. A product that asks you to
    /// annotate everything turns reading into filing.
    ///
    /// **It sits under the relationship card now, and it is labelled** (§21).
    /// Under a heading reading "What you wrote", in serif italic, an existing
    /// note was typographically indistinguishable from a published review — the
    /// Temporary page rendered "Priya's reason was very specific" in exactly
    /// the treatment the Bluets page used for a review three hundred readers
    /// can see. Two audiences, one appearance. The label is four words and it
    /// removes the whole ambiguity; the position puts the note with the rest of
    /// your record, which is what it is a note on.
    @ViewBuilder
    private var privateNoteRow: some View {
        if let entry {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                if entry.note != nil || editingNote {
                    Text("Private note")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                }
                if editingNote {
                    TextField("A line for yourself.", text: $noteDraft, axis: .vertical)
                        .font(Theme.TypeScale.prose())
                        .lineLimit(1...4)
                        .padding(Theme.Space.snug)
                        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.Palette.rule, lineWidth: 1)
                        )
                    HStack {
                        Spacer()
                        // The only way to commit a note, at ~40x20pt before this.
                        Button { commitNote() } label: {
                            Text("Done")
                                .font(Theme.TypeScale.ui())
                                .foregroundStyle(Theme.Palette.accent)
                                .padding(.vertical, Theme.Space.snug)
                                .padding(.horizontal, Theme.Space.base)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } else if let note = entry.note {
                    Button {
                        beginEditingNote(note)
                    } label: {
                        Text(note)
                            .font(Theme.TypeScale.prose())
                            .foregroundStyle(Theme.Palette.inkSoft)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Padded inside the label, not around the button: `.plain`
                    // hit-tests the glyphs and nothing else, so this — the only
                    // way to reach the private note — was a ~135x15pt target on
                    // a 44pt minimum.
                    Button {
                        beginEditingNote("")
                    } label: {
                        Text("Add a private note")
                            .font(Theme.TypeScale.meta())
                            .foregroundStyle(Theme.Palette.accent)
                            .padding(.vertical, Theme.Space.snug)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Theme.Space.tight)
            .pageMargin()
        }
    }

    // MARK: - 7. Community

    /// What is left of the crowd once the number moved to the top of the page:
    /// people, and what they wrote.
    ///
    /// The average and its histogram used to render here, small and last, as a
    /// deliberate act of subordination. They are the headline now (§12.1), so
    /// drawing them twice would be two answers to the same question — this
    /// section keeps the named ratings, the filters and the reviews, and
    /// quantifies nothing on its own.
    ///
    /// **One section when the crowd is silent, two when it is not** (§21). The
    /// block drew "READERS" over "Nobody you follow has scored this one." and
    /// then "REVIEWS" over "Nothing written here yet." — two tracked headings,
    /// a rule between them, and roughly two hundred points of page, to say the
    /// same "no" twice. On an imported book those were the third and fourth
    /// consecutive headed denials in a row.
    ///
    /// Collapsed, it is one heading and one sentence that covers both, and it
    /// still says the true thing: Dewey knows nothing about this book *yet*.
    @ViewBuilder
    private var communitySection: some View {
        if communityIsSilent {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                divider
                sectionHeader("Readers")
                Text("Nobody you follow has read this one, and nothing is written here yet.")
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .pageMargin()
            }
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                divider
                // **"Readers" earns its heading only when it has readers
                // under it.** With reviewers filtered out of `friendsWhoRead`
                // above, a book whose only follower activity is a review —
                // now the ordinary case — had this heading fire over an
                // empty stack, immediately followed by `reviewsBlock`'s own
                // rule and "REVIEWS" heading: two headings back to back, one
                // of them empty. `reviewsBlock` states its own heading, so
                // this one only draws when it is introducing something.
                if hasNamedReaders {
                    sectionHeader("Readers")
                    friendsWhoReadBlock
                    friendsReadingBlock
                    favouritedBlock
                    Rule().pageMargin()
                }
                reviewsBlock
            }
        }
    }

    /// Nobody you follow has touched this book and nobody at all has written
    /// about it — the state every imported book starts in.
    private var communityIsSilent: Bool {
        friendsWhoRead.isEmpty && friendsReading.isEmpty
            && friendsFavourited.isEmpty && totalReviews == 0
    }

    /// Whether the "Readers" rows have anything to draw, independent of
    /// whether reviews exist. Reviewers are excluded from `friendsWhoRead`
    /// (see its own doc comment), so a book can be non-silent purely on the
    /// strength of its reviews.
    private var hasNamedReaders: Bool {
        !friendsWhoRead.isEmpty || !friendsReading.isEmpty || !friendsFavourited.isEmpty
    }

    /// Named people with their ratings at full weight.
    ///
    /// This block used to be defended as the thing the crowd average must never
    /// outshout. The average now opens the page, and these rows are what give it
    /// a meaning: 7.9 from four thousand strangers and 9.1 from someone whose
    /// last three recommendations landed are different facts, and only one of
    /// them is about you.
    ///
    /// **The "nobody" line only fires when nobody is the whole answer.** It was
    /// unconditional on an empty list, so a book whose only follower-activity is
    /// a review — now the common case, since reviewers are filtered out of these
    /// rows above — printed "Nobody you follow has scored this one." directly
    /// above a review by somebody you follow, with their score in the byline.
    @ViewBuilder
    private var friendsWhoReadBlock: some View {
        if friendsWhoRead.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(friendsWhoRead.enumerated()), id: \.element.id) { index, reader in
                    NavigationLink(value: reader) {
                        friendRow(reader)
                    }
                    .buttonStyle(.plain)
                    if index < friendsWhoRead.count - 1 { Rule() }
                }
            }
            .pageMargin()
        }
    }

    private func friendRow(_ reader: ReaderProfile) -> some View {
        HStack(spacing: Theme.Space.snug) {
            ReaderAvatarView(reader: reader, size: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(reader.name)
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.ink)
                Text(friendContext(reader))
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            // Their profile four, not their Favorite mark — this row is about
            // what a reader chose to publish, and the mark on their own diary
            // entry is not visible to anyone else.
            if reader.favoriteBookIDs.contains(book.id) {
                FavoriteMark(filled: true, size: 13)
                    .accessibilityLabel("One of \(reader.name)'s \(Judgement.FavoriteBooksCopy.title)")
            }

            if let value = reader.ratings[book.id], let rating = Rating(value) {
                // A numeral, not rules. This is one of the few genuine
                // comparison surfaces on the page — several people you follow,
                // stacked, hairline-separated — and §12.1 leans on exactly these
                // rows to give the crowd's average its meaning. Rules at this
                // length cannot separate 9.1 from 8.7; the numeral can, and it
                // takes less width than the ten rules it replaces, which this
                // row needs beside an avatar, a name, two lines of context, a
                // Favorite Books mark and a chevron.
                RatingMark(rating: rating)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.Palette.inkFaint)
        }
        .padding(.vertical, Theme.Space.snug)
        .contentShape(Rectangle())
    }

    private func friendContext(_ reader: ReaderProfile) -> String {
        if reader.favoriteBookIDs.contains(book.id) {
            return "One of their four \(Judgement.FavoriteBooksCopy.title)"
        }
        let overlap: TasteOverlap = store.overlap(with: reader)
        if overlap.isMeaningful { return "\(overlap.headline) with you" }
        return reader.texture
    }

    @ViewBuilder
    private var friendsReadingBlock: some View {
        if !friendsReading.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                Text("Reading it now")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                ScrollView(.horizontal) {
                    HStack(spacing: Theme.Space.base) {
                        ForEach(friendsReading) { reader in
                            NavigationLink(value: reader) {
                                VStack(spacing: Theme.Space.tight) {
                                    ReaderAvatarView(reader: reader, size: 44)
                                    Text(reader.name)
                                        .font(Theme.TypeScale.meta())
                                        .foregroundStyle(Theme.Palette.inkSoft)
                                        .lineLimit(1)
                                }
                                .frame(width: 76)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .pageMargin()
        }
    }

    @ViewBuilder
    private var favouritedBlock: some View {
        if !friendsFavourited.isEmpty {
            HStack(spacing: Theme.Space.tight) {
                FavoriteMark(filled: true, size: 13)
                Text(favouritedLine)
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .pageMargin()
        }
    }

    /// These readers put this book in their profile four — a scarcer claim than
    /// a Favorite mark, and the sentence says which one it is. "One of their
    /// four" is the whole weight of the line: it is not that they liked it, it
    /// is that they gave up one of four slots for it.
    private var favouritedLine: String {
        let names: [String] = friendsFavourited.map(\.name)
        switch names.count {
        case 1: return "\(names[0]) made this one of their four \(Judgement.FavoriteBooksCopy.title)."
        case 2: return "\(names[0]) and \(names[1]) made this one of their four \(Judgement.FavoriteBooksCopy.title)."
        default:
            let head: String = names.prefix(2).joined(separator: ", ")
            return "\(head) and \(names.count - 2) others made this one of their four \(Judgement.FavoriteBooksCopy.title)."
        }
    }

    // MARK: Reviews

    @ViewBuilder
    private var reviewsBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            // The separating rule is `communitySection`'s to draw, not this
            // block's own — see `hasNamedReaders` there. Owning it here meant
            // a book with no named readers got the community divider *and*
            // this hairline within a `base` of each other, introducing a
            // heading with two rules instead of one.
            HStack(alignment: .firstTextBaseline) {
                Text(Judgement.ReviewCopy.plural).kickerStyle()
                Spacer(minLength: Theme.Space.snug)
                if totalReviews > 0 {
                    Text("\(totalReviews)")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                }
            }
            // Filters only when there is something to filter (§13.2). The row
            // offered Friends / Popular / Recent / Positive / Critical above a
            // single review, which is five controls that can only ever
            // reorder one item — it read as an unfinished screen rather than a
            // considered one. Three is the point where sorting starts to do
            // work.
            if offersFilters {
                filterRow
            }
            if reviews.isEmpty {
                Text(emptyReviewLine)
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: Theme.Space.roomy) {
                    ForEach(reviews) { review in
                        reviewCard(review)
                    }
                }
            }
        }
        .pageMargin()
    }

    /// **Filters have to be able to disagree with each other** (§21).
    ///
    /// The gate was `totalReviews >= 3`, which counts the rows but not whether
    /// the chips would sort them differently. `.friends` genuinely filters now,
    /// so on a book where every review comes from somebody you follow the row
    /// offers five controls that return an identical list in a slightly
    /// different order — the same "unfinished screen" the count-gate was added
    /// to prevent, arriving through the other door.
    ///
    /// So: enough reviews to sort, *and* a Friends set that is a real subset.
    /// Below that the section shows what it has, which at two reviews is the
    /// whole truth anyway.
    private var offersFilters: Bool {
        guard totalReviews >= 4 else { return false }
        let friends = store.friendReviewCount(book.id)
        return friends > 0 && friends < totalReviews
    }

    /// Two different silences. "Nothing written here yet" is false on a book
    /// with eleven reviews and a Friends filter that matches none of them, and
    /// it is the state the default filter lands a new account in.
    private var emptyReviewLine: String {
        if totalReviews > 0, effectiveFilter == .friends {
            return "Nobody you follow has written about this one. \(totalReviews) other\(totalReviews == 1 ? " has" : "s have")."
        }
        return Judgement.ReviewCopy.emptyOnBook
    }

    /// Wraps; it does not scroll sideways.
    ///
    /// This was a horizontal `ScrollView`, and it is the same defect §12.9 fixed
    /// on the Library's status chips and then left standing here: a sideways
    /// scroller slices its last visible label mid-word at the right margin, and
    /// a cut word reads as a broken row rather than as "there is more this way"
    /// — the reader has to already suspect the row scrolls before the cut means
    /// anything. Five short labels wrap to two lines at default type and stay
    /// whole at every accessibility size, which is a shape no scroll offset can
    /// break.
    ///
    /// `ChipFlowLayout` rather than `FlowLayout` for the reason its own
    /// documentation gives: it proposes the container's width to each chip, so a
    /// label that cannot fit a line wraps *inside its capsule* instead of being
    /// clipped at the margin one layer down.
    private var filterRow: some View {
        FlowLayout(spacing: Theme.Space.tight, lineSpacing: Theme.Space.tight) {
            ForEach(ReviewFilter.allCases) { filter in
                Button(filter.title) {
                    withAnimation(Theme.Motion.standard) { reviewFilter = filter }
                }
                .buttonStyle(ChipStyle(selected: effectiveFilter == filter))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(effectiveFilter == filter ? [.isSelected] : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reviewCard(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            reviewByline(review)
            reviewBody(review)
            readMoreRow(review)
            reviewFooter(review)
        }
    }

    /// Shown only on a review long enough to have been clamped, and only once
    /// it is readable — offering "Read more" on a blurred spoiler asks the
    /// reader to expand something they have not agreed to see.
    @ViewBuilder
    private func readMoreRow(_ review: Review) -> some View {
        let clamped = review.text.count > Self.clampLength
            && !expandedReviews.contains(review.id)
            && !(review.isSpoiler && !revealedSpoilers.contains(review.id))
        if clamped {
            Button {
                withAnimation(Theme.Motion.standard) {
                    _ = expandedReviews.insert(review.id)
                }
            } label: {
                Text("Read more")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.accent)
                    // Padded inside the label: `.plain` hit-tests the glyphs,
                    // which at caption size is well under the 44pt minimum.
                    .padding(.vertical, Theme.Space.snug)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the rest of this review")
        }
    }

    /// A review short enough to be an epigram rather than an argument. Tuned to
    /// the seeded one-liners — "The episode guide. That's it. That's the entry."
    /// is 47 characters — and comfortably under a line and a half at
    /// `proseLarge()` on the narrowest supported phone.
    private static let epigramLength = 110

    /// Where a review stops being something a reader skims past on the way to
    /// the next one. Six lines of `prose()` is roughly this many characters at
    /// default type; the clamp is in lines, so it holds at every size.
    private static let clampLength = 340
    private static let clampLines = 6

    ///
    /// **The follow marker earns its place only in a mixed list.** A reader you
    /// follow and a stranger set identically is the flattening the Friends
    /// filter exists to undo, and the filter cannot help a reader who is
    /// looking at Popular. Under the Friends chip it says nothing — every row
    /// is a friend — so it is suppressed there rather than repeated down the
    /// column.
    @ViewBuilder
    private func reviewByline(_ review: Review) -> some View {
        if let reader = store.reader(review.readerID) {
            NavigationLink(value: reader) {
                HStack(spacing: Theme.Space.snug) {
                    ReaderAvatarView(reader: reader, size: 28)
                    Text(reader.name)
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.ink)
                    if review.isFavorite {
                        FavoriteMark(filled: true, size: 12)
                    }
                    if effectiveFilter != .friends, store.isFollowing(review.readerID) {
                        Text(FollowCopy.following)
                            .font(Theme.TypeScale.meta())
                            .foregroundStyle(Theme.Palette.inkFaint)
                            .padding(.horizontal, Theme.Space.tight)
                            .padding(.vertical, 2)
                            .background(Capsule().stroke(Theme.Palette.rule, lineWidth: 0.5))
                    }
                    Spacer(minLength: 0)
                    // A numeral, for the same reason as the friend rows: a
                    // reviews list is scanned for *whose verdict* before a
                    // word of the prose is read, so this number is being
                    // compared against the one two cards down. Rules blur every
                    // rating in the list into the same dashed row.
                    RatingMark(rating: review.rating)
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Spoilers are hidden until asked for. A blur plus a stated reason is the
    /// only honest treatment — hiding the whole review loses the byline and
    /// the rating, which are exactly the parts that are safe to read.
    ///
    /// **Length is now visible in the setting** (§21). Every review drew at
    /// `prose()` regardless, so a nine-word one-liner and four paragraphs
    /// arrived at the same weight in the same column, and the column read as a
    /// uniform grey block whatever was in it — which is the opposite of what a
    /// reviews section is for. A short review is an epigram and gets the
    /// pull-quote size the recommendation reason uses; a long one is an essay
    /// and gets clamped, so six of them can coexist on a page a reader can
    /// still scroll past.
    private func reviewBody(_ review: Review) -> some View {
        let hidden: Bool = review.isSpoiler && !revealedSpoilers.contains(review.id)
        let expanded: Bool = expandedReviews.contains(review.id)
        let isEpigram: Bool = review.text.count <= Self.epigramLength
        let isLong: Bool = review.text.count > Self.clampLength
        return ZStack {
            Text(review.text)
                .font(isEpigram ? Theme.TypeScale.proseLarge() : Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.ink)
                .lineSpacing(3)
                .lineLimit(isLong && !expanded ? Self.clampLines : nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .blur(radius: hidden ? 7 : 0)
                .accessibilityHidden(hidden)

            if hidden {
                Text("Contains spoilers — tap to show")
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .padding(.horizontal, Theme.Space.base)
                    .padding(.vertical, Theme.Space.snug)
                    .background(Capsule().fill(Theme.Palette.card))
                    .overlay(Capsule().stroke(Theme.Palette.rule, lineWidth: 1))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard hidden else { return }
            withAnimation(Theme.Motion.standard) {
                _ = revealedSpoilers.insert(review.id)
            }
        }
        .accessibilityAddTraits(hidden ? [.isButton] : [])
        .accessibilityLabel(hidden ? "Contains spoilers. Tap to show." : review.text)
    }

    private func reviewFooter(_ review: Review) -> some View {
        HStack(spacing: Theme.Space.snug) {
            Text(Self.dayFormatter.string(from: review.date))
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
            if review.appreciations > 0 {
                Text("·")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                Text("\(review.appreciations) found this useful")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 8. Lists containing it

    @ViewBuilder
    private var listsSection: some View {
        if !listsContaining.isEmpty {
            divider
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                sectionHeader("On lists")
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: Theme.Space.base) {
                        ForEach(listsContaining) { list in
                            NavigationLink(value: list) {
                                listCard(list)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Space.margin)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    /// **Whose list it is, and where this book sits in it** (§21).
    ///
    /// The card carried covers, a title, `subtitle` and the note — everything
    /// except the two facts a reader on *this* page wants. Who made it, because
    /// "Ana thinks this belongs with four other collections" and "somebody on
    /// Dewey filed it" are different invitations; and the position, because a
    /// list that has taken the trouble to be ordered has said something
    /// specific about this book by putting it third, and a card that omits it
    /// throws that away.
    ///
    /// The ordinal replaces `subtitle`'s "ordered" rather than joining it —
    /// "No. 1 of 5" states both facts and the word would be the third time the
    /// card said the same thing.
    private func listCard(_ list: BookList) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack(spacing: -14) {
                ForEach(Array(list.bookIDs.prefix(4)), id: \.self) { id in
                    BookCoverView(book: store.book(id), width: 42)
                }
            }
            .frame(height: 63, alignment: .leading)

            Text(listAttribution(list))
                .kickerStyle(list.ownerID == "me" ? Theme.Palette.accent : Theme.Palette.inkFaint)

            Text(list.title)
                .font(Theme.TypeScale.cardTitle())
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if !list.premise.isEmpty {
                Text(list.premise)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(listStanding(list))
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)

            if let note = list.note(for: book.id) {
                Text("“\(note)”")
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 210, alignment: .leading)
        .padding(Theme.Space.base)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(list.ownerID == "me" ? Theme.Palette.accent.opacity(0.35) : Theme.Palette.rule,
                        lineWidth: list.ownerID == "me" ? 1 : 0.5)
        )
    }

    /// Yours reads as a fact about you; anyone else's reads as a name.
    private func listAttribution(_ list: BookList) -> String {
        if list.ownerID == "me" { return "On your list" }
        return store.reader(list.ownerID)?.name ?? "On Dewey"
    }

    /// The ordinal where the list has claimed one, the size of the list where
    /// it has not. An unordered list must not be given a fake position — see
    /// `BookList.position(of:)`, which returns `nil` on purpose.
    private func listStanding(_ list: BookList) -> String {
        if let position = list.position(of: book.id) {
            return "No. \(position) of \(list.count)"
        }
        return list.subtitle
    }

    // MARK: - 9. About

    /// Two sentences, editorial rather than jacket copy — and now only two
    /// sentences. The metadata grid that used to hang off the bottom of this
    /// section moved to `detailsSection`, where it has room to be a real
    /// catalogue record instead of a footnote to a blurb. Every row it carried
    /// survives there.
    ///
    /// Withheld entirely when there is nothing to say (§16). An imported
    /// book's blurb arrives with the catalog's work record or not at all,
    /// and an "About" header over blank paper is the page promising prose it
    /// doesn't have.
    @ViewBuilder
    private var aboutSection: some View {
        if !book.blurb.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                divider
                sectionHeader("About")
                Text(book.blurb)
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .pageMargin()
            }
        }
    }

    private func seriesLine(_ series: String) -> String {
        if let position = book.seriesPosition { return "\(series), book \(position)" }
        return series
    }

    // MARK: - 10. People

    /// **Only the people the hero has not already named** (§21).
    ///
    /// The section always opened with `personRow("Author", book.author)` — and
    /// the author is set in the masthead, under the title, on the cover
    /// artwork, and again in every related card. On the thirty-odd seeded books
    /// with no translator, narrator, illustrator or editor, that made the whole
    /// section a divider, a tracked heading reading "PEOPLE", and one row
    /// repeating the second line of the page. A section whose entire content is
    /// a fact stated three times above it is not thoroughness.
    ///
    /// Where there *are* other contributors the section is worth having, and
    /// the author belongs in it as the anchor of the list — a translator row
    /// with nobody to be translating for reads as a fragment. So the whole
    /// table appears exactly when it has something to add.
    ///
    /// Nothing is lost on the books it now skips: `alsoBySection` below makes
    /// the author a place you can go, which the row never did.
    @ViewBuilder
    private var peopleSection: some View {
        if hasOtherContributors {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                divider
                sectionHeader("People")
                VStack(alignment: .leading, spacing: 0) {
                    personRow("Author", book.author)
                    if let translator = book.translator {
                        Rule()
                        personRow("Translator", translator)
                    }
                    if let narrator = book.narrator {
                        Rule()
                        personRow("Narrator", narrator)
                    }
                    if let illustrator = book.illustrator {
                        Rule()
                        personRow("Illustrator", illustrator)
                    }
                    if let editor = book.editor {
                        Rule()
                        personRow("Editor", editor)
                    }
                }
                .pageMargin()
            }
        }
    }

    private var hasOtherContributors: Bool {
        book.translator != nil || book.narrator != nil
            || book.illustrator != nil || book.editor != nil
    }

    /// The third of the page's three private label-and-value tables, and the one
    /// that made the case for merging them: it drew the same shape as the
    /// catalogue table below it on a *different* column width, so two tables one
    /// scroll apart hung their values off two different gutters.
    private func personRow(_ role: String, _ name: String) -> some View {
        FactRow(role, name)
    }

    // MARK: - 10b. The rabbit holes

    /// **Other books by this author, and the rest of the series** (§21).
    ///
    /// The page had exactly one lateral move — `relatedBookIDs`, hand-curated
    /// in the seed and therefore empty on every imported book — and no way at
    /// all to act on the two strongest signals it was already printing. The
    /// author's name appeared four times and was not a destination anywhere;
    /// "Wolf Hall #2" sat in the masthead with no route to #1.
    ///
    /// Both are answered from what Dewey already holds — `books(byAuthor:)` and
    /// `books(inSeries:)` — so this invents no recommendation engine and makes
    /// no claim the local corpus cannot support. A strip that would contain
    /// only the book you are looking at renders nothing.
    @ViewBuilder
    private var alsoBySection: some View {
        // Excludes the reader's own series, not just this book — an author
        // whose series has three entries would otherwise show book two twice
        // on book one's page: once in "The Broken Earth", again in "Also by
        // N. K. Jemisin" a screen below it, as the exact same cover.
        let seriesIDs = Set(seriesSiblingIDs)
        let others = store.books(byAuthor: book.author)
            .filter { $0.id != book.id && !seriesIDs.contains($0.id) }
        if !others.isEmpty {
            divider
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                sectionHeader("Also by \(book.author)")
                bookStrip(others)
            }
        }
    }

    private var seriesSiblingIDs: [String] {
        guard let series = book.series else { return [] }
        return store.books(inSeries: series).map(\.id)
    }

    @ViewBuilder
    private var seriesSection: some View {
        if let series = book.series {
            let siblings = store.books(inSeries: series).filter { $0.id != book.id }
            if !siblings.isEmpty {
                divider
                VStack(alignment: .leading, spacing: Theme.Space.base) {
                    sectionHeader(series)
                    bookStrip(siblings, showPosition: true)
                }
            }
        }
    }

    /// One horizontal strip of covers, shared by the three exploration rails so
    /// they cannot drift into three slightly different cards.
    private func bookStrip(_ books: [Book], showPosition: Bool = false) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Theme.Space.base) {
                ForEach(books) { other in
                    NavigationLink(value: other) {
                        relatedCard(other, caption: showPosition ? other.seriesPosition.map { "Book \($0)" } : nil)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Space.margin)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - 11. Related

    /// **"If this reached you" was a sentence with no predicate.** It is the
    /// opening clause of the argument the strip is making — *if this reached
    /// you, these might too* — printed on its own as a heading, where it reads
    /// as an unfinished thought rather than an invitation. Every other heading
    /// on the page names its contents.
    @ViewBuilder
    private var relatedSection: some View {
        if !relatedBooks.isEmpty || book.adaptationNote != nil {
            divider
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                sectionHeader("If this one landed")
                if !relatedBooks.isEmpty { relatedStrip }
                if let note = book.adaptationNote {
                    Text(note)
                        .font(Theme.TypeScale.prose())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .pageMargin()
                }
            }
        }
    }

    private var relatedStrip: some View { bookStrip(relatedBooks) }

    /// Cover and title only — deliberately no rating.
    ///
    /// This strip offers books the reader has *not* read, so a slot for their
    /// own rating renders empty on almost every card and ragged where it does
    /// not. It answered a question nobody asks here: the reader is deciding
    /// whether to open the book, not comparing their own past verdicts.
    ///
    /// `caption` is the series strip's "Book 2" — the one fact that makes a
    /// row of near-identical spines navigable rather than decorative. It stays
    /// optional because on an author strip it would be noise.
    private func relatedCard(_ related: Book, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            BookCoverView(book: related, width: 92)
            Text(related.title)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let caption {
                Text(caption)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
            }
        }
        .frame(width: 92, alignment: .leading)
    }

    // MARK: - 12. Details

    /// The catalogue record (§12.5.7). Last on the page, because nobody scrolls
    /// for it and everybody wants it once — which edition, what year, who
    /// translated it, where it sits on a shelf that is not yours.
    ///
    /// **The Dewey Decimal row is the point of the exercise.** The app is named
    /// after the classification and had gone three builds without ever printing
    /// one, which is the sort of thing you only notice when somebody finally
    /// draws the table.
    ///
    /// Rows whose value is unknown are omitted rather than printed empty. Only
    /// sixteen of the forty-one seeded books have a publication date precise
    /// enough to state, and a column of dashes tells a reader the data is bad
    /// rather than that the fact is genuinely not known.
    /// **Collapsed by default** (§13.2). Eleven catalogue rows plus a genre strip
    /// is the longest block on the page, and it sat permanently open at the foot
    /// of an already long scroll — ISBN, Dewey Decimal, Editions and Language are
    /// things a reader wants *once*, deliberately, and never while deciding
    /// whether to read the book. Closed, the page ends a screen and a half
    /// sooner; the disclosure states what is inside so nobody has to open it to
    /// find out.
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            divider

            DisclosureGroup(isExpanded: $detailsExpanded) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(detailRows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { Rule() }
                        detailRow(row)
                    }
                }
                .padding(.top, Theme.Space.snug)
                // **No genre chips down here** (§21). `heroChips` already draws
                // `book.genres.prefix(4)` in the masthead, in the same capsule,
                // in the same order — and the note above this one records that
                // §13.2 split genres from themes precisely so each would be
                // stated once. Themes survived that split as a labelled row in
                // the table above; genres did not, and the strip was left
                // standing here as a second copy of the hero's.
                //
                // The hero is the right home: a coarse category is orienting
                // information, and this table is where a reader comes for the
                // facts the masthead has no room for.
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Details").kickerStyle()
                    Text("Publisher, ISBN, Dewey Decimal, editions, themes, setting")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.Palette.inkSoft)
            .pageMargin()
        }
    }

    /// Keyed by its own label, which is unique by construction and reads better
    /// at the call site than an index.
    private struct DetailRow: Identifiable {
        let id: String
        let value: String
    }

    /// Ordered the way a catalogue record is: what it is called, when it
    /// appeared, who made it an object, what identifies it, then what is inside
    /// it. Pages and Themes are carried over from the grid this replaced.
    private var detailRows: [DetailRow] {
        var rows: [DetailRow] = []
        rows.append(DetailRow(id: "Title", value: book.title))
        if let published = publishedLine { rows.append(DetailRow(id: "First published", value: published)) }
        if let publisher = book.publisher { rows.append(DetailRow(id: "Publisher", value: publisher)) }
        if let pages = book.pageCount { rows.append(DetailRow(id: "Pages", value: "\(pages)")) }
        if let isbn = book.isbn { rows.append(DetailRow(id: "ISBN", value: isbn)) }
        if let dewey = book.deweyDecimal { rows.append(DetailRow(id: "Dewey Decimal", value: dewey)) }
        if let editions = book.editionCount { rows.append(DetailRow(id: "Editions", value: "\(editions)")) }
        if let language = book.language { rows.append(DetailRow(id: "Language", value: language)) }
        // No Translator row (§12.9). The People section above already names
        // them, in a table built for exactly that, and a page that prints the
        // same person twice within one screen of itself reads as a bug rather
        // than as thoroughness. Language stays here because it is a property of
        // the edition; the translator is a person.
        if let series = book.series { rows.append(DetailRow(id: "Series", value: seriesLine(series))) }
        if !book.characters.isEmpty {
            rows.append(DetailRow(id: "Characters", value: book.characters.joined(separator: ", ")))
        }
        if let setting = book.setting { rows.append(DetailRow(id: "Setting", value: setting)) }
        if !book.themes.isEmpty {
            rows.append(DetailRow(id: "Themes", value: book.themes.joined(separator: ", ")))
        }
        return rows
    }

    /// The exact day where it is genuinely known, the year where it is not,
    /// and nothing where neither is. A serialised Victorian novel has no
    /// publication day, and a translated one has two dates that mean
    /// different things — the seed leaves both blank rather than picking one,
    /// so this falls back to the year. `nil` skips the row entirely (§16): an
    /// imported book whose catalog record carries no first-publication year
    /// gets no row, per this file's own rule that a blank row beats a wrong
    /// one.
    private var publishedLine: String? {
        if let date = book.publishDate { return Self.dayFormatter.string(from: date) }
        return book.year.map(String.init)
    }

    /// This table set the shared column width. Its labels are the longest in the
    /// app — "First published", "Dewey Decimal" — and its own note recorded that
    /// they "do not fit in 92 at caption size, and a table whose labels wrap has
    /// stopped being a table". Correct, and it was solved by giving *this* table
    /// a second number rather than by giving every table the number that works,
    /// which is what `FactRow` does now. The observation was also incomplete: a
    /// column in points wraps at accessibility sizes whether it is 92 or 108.
    private func detailRow(_ row: DetailRow) -> some View {
        FactRow(row.id, row.value)
    }

    // `genreChips` lived here and drew `book.genres` a second time at the foot
    // of the Details disclosure, in the same capsule the hero uses. Removed
    // rather than left unwired: a computed property with no caller reads as a
    // supported treatment somebody forgot to place, and this one has an
    // identical twin four screens up. `heroChips` is the survivor.

    // MARK: - Mutation

    /// Provenance is inferred at the moment of saving, never asked for. If the
    /// book reached you through a person, Dewey already knows — a form here
    /// would defeat the entire idea.
    ///
    /// **The inference itself lives on the store now**
    /// (`DeweyStore.inferredProvenance(for:)`), not here. It used to be a
    /// private method on this view alone, which meant the quick "Want to
    /// Read" tap on a search row — added so a reader does not have to open
    /// this page just to save what they found — had no way to ask the same
    /// question and risked calling a book "self-found" that a friend had
    /// actually sent. One inference, called from every place a save can
    /// happen.
    private func choose(_ status: ReadingStatus) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(Theme.Motion.standard) {
            if store.entry(for: book.id) == nil {
                store.save(book.id, status: status, provenance: store.inferredProvenance(for: book.id))
            } else {
                store.setStatus(status, for: book.id)
            }
        }
    }

    // `ratingBinding` and `toggleFavorite` lived here until this pass, and
    // nothing had called either since §13.2 removed the inline status picker,
    // rating slider and Favorite toggle that used to sit under the primary
    // action. They were the second of the page's "two competing editors" — the
    // mechanism, still wired up, with its controls taken away. Left in place
    // they read as a supported way to write a rating from the book page, which
    // is exactly the ambiguity that pass existed to end: the log sheet is the
    // one editor, and `mutateLatestEntry` below is the only writer.

    /// Rating and Favorite live on the diary, because a reread can be rated
    /// differently from a first read. Tapping either here writes to the most
    /// recent entry, or opens a new one if there is nothing to write to yet.
    private func mutateLatestEntry(_ mutate: (inout DiaryEntry) -> Void) {
        var target: DiaryEntry
        if let existing = store.latestEntry(for: book.id) {
            target = existing
        } else {
            target = DiaryEntry(
                id: UUID().uuidString,
                bookID: book.id,
                status: store.status(of: book.id) ?? .finished,
                startedOn: nil,
                finishedOn: nil,
                loggedOn: Date(),
                rating: nil
            )
            if store.entry(for: book.id) == nil {
                store.save(book.id, status: target.status, provenance: store.inferredProvenance(for: book.id))
            }
        }
        mutate(&target)
        store.log(target)
    }

    private func beginEditingNote(_ text: String) {
        noteDraft = text
        withAnimation(Theme.Motion.standard) { editingNote = true }
    }

    private func commitNote() {
        let trimmed: String = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        store.setNote(trimmed.isEmpty ? nil : trimmed, for: book.id)
        withAnimation(Theme.Motion.standard) { editingNote = false }
    }

    // MARK: - Formatting

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    // `compactCount` and `oneDecimal` formatted the "Reviews 106 / Shelves 3.3k"
    // stat tiles, which the same pass deleted for being the two largest numbers
    // in a region where neither changed a decision. The formatters outlived
    // their only caller. `Rating.compact` and `ScoreCircle` carry the
    // drop-the-trailing-zero rule these duplicated.
}

// MARK: - A judgement slot

/// One half of the Your Score / Your Ranking pair: **kicker, value, caption**,
/// in that order, at those sizes, always.
///
/// The point of the type is that there is no state in which it renders a
/// different shape. A slot with no figure draws a faint em dash where the
/// figure would be — the convention `RatingMark.Unrated.stated` already
/// establishes for "no entry in this column" — and says what is missing in the
/// caption line underneath, which the dash cannot. Both lines are always
/// present and always one line, so two slots side by side share a baseline
/// whatever either of them contains.
///
/// The caption is doing real work in both states, which is why it is not just
/// an empty-state affordance: "out of 10" is the scale a first-time reader has
/// not been told, and "of 67" is the denominator that makes an ordinal mean
/// anything. "No. 1" alone is unreadable — of what?
///
/// Spoken as one element. VoiceOver has no column to look at, so the label
/// carries which judgement it is, the value, and the scale in one phrase.
private struct JudgementSlot: View {
    let kicker: String
    /// `nil` draws the dash.
    let value: String?
    let caption: String
    let spoken: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.hair) {
            Text(kicker).kickerStyle()

            Text(value ?? "\u{2014}")
                .font(Theme.TypeScale.display())
                .foregroundStyle(value == nil ? Theme.Palette.inkFaint : Theme.Palette.ink)
                .monospacedDigit()
                .lineLimit(1)
                // Only ever engaged by a four-digit ranking on a narrow phone.
                // The floor is high enough that the two slots cannot end up
                // visibly different sizes, which is the whole point of the type.
                .minimumScaleFactor(0.7)

            Text(caption)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}
