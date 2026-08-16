import SwiftUI

/// The front door to the world of books, as opposed to yours.
///
/// **Home and Edition answer different questions and must never merge.**
/// The Edition asks *what is reaching me through people whose taste I trust* —
/// it is finite, attributed, and ends. Home asks *what is happening in books
/// right now* — it is unattributed, external, and browseable. The moment Home
/// starts carrying what your friends are reading it has eaten the Edition; the
/// moment the Edition starts carrying charts it has stopped being a letter
/// from people.
///
/// **This page is editorial first and utilitarian second**, which is the pass
/// that produced its current shape. It was built the other way round: an
/// explanatory paragraph, then a shelf, then eleven outlined genre pills
/// wrapping over five lines, then a nine-item decade scroller. Everything on
/// it was true and most of it was *controls*, so the tab read as a filter panel
/// with some covers at the top — and a reader had to get past four lines of
/// prose before reaching a single book.
///
/// What changed, in order of how much it mattered:
///
/// - The paragraph explaining the Home/Edition split is gone. A reader does
///   not need the product architecture narrated to them; they need books. One
///   quiet line survives.
/// - The covers grew (see `Metrics.heroCover`) and now show two and a half
///   across, so the shelf reads as something you push sideways rather than as
///   a three-column grid that happens to be cut off.
/// - Genre went from eleven pills to six names in two columns with a way
///   through to the rest. Decade went from nine chips to four and a link.
///   **Nothing was removed from the product** — every genre and every decade
///   is still in `BrowseBooksView`, which is the screen that is supposed to
///   hold controls. Home now inspires the browse; Browse contains it.
///
/// **Every figure behind this screen belongs to somebody else** (§16). Dewey
/// has a few dozen readers and no business publishing a chart; what it can
/// honestly do is quote one, and say whose it is. The long disclaimer that
/// used to sit under the shelf is now a short line beside the heading — the
/// full statement lives on `BrowseFilter.sourceLine`, where a reader is
/// actually reading rankings rather than glancing at a shelf.
struct HomeView: View {
    @Environment(DeweyStore.self) private var store

    /// Sizes this page is opinionated about, kept together because they are
    /// arithmetic rather than taste.
    private enum Metrics {
        /// **Two and a half covers across, which is the whole trick.**
        ///
        /// At 118 points a phone showed almost exactly three covers with the
        /// third barely clipped, and a rail that ends flush at the margin is
        /// indistinguishable from a grid — there was nothing on screen saying
        /// it moved. 140 lands the third cover half on and half off at every
        /// phone width the app ships to (2.3 across on the smallest, 2.8 on
        /// the largest), so the invitation to swipe is always visible.
        ///
        ///     margin + W + gap + W + gap  =  20 + 140 + 16 + 140 + 16 = 332
        ///     of 402 points, leaving 70 — half of the next cover.
        ///
        /// Bigger, not smaller: the covers are the content, and the fix for a
        /// grid-like rail is never to shrink the thing the page is about.
        static let heroCover: CGFloat = 140

        /// The Browse grid's cover. Smaller because that screen is a
        /// comparison surface showing two dozen at once.
        static let gridCover: CGFloat = 104
    }

    /// The hero's question. Fixed — the shelf is *the* week's shelf, and a
    /// reader who wants a different one is one tap from the browser where the
    /// controls live.
    private static let hero = BrowseFilter(period: .thisWeek, limit: 10)

    /// The same question at the size a whole screen deserves.
    ///
    /// "See all" used to push `hero` itself, which carries the shelf's limit
    /// of ten — so the full browser opened showing exactly the ten covers the
    /// reader had just swiped through, which is the least useful thing a
    /// see-all can do. This is the same filter at the browser's own default.
    private static let heroExpanded = BrowseFilter(period: .thisWeek)

    /// Home's second shelf: the same popularity signal as `hero`, narrowed to
    /// books whose first publication is recent rather than to a reading
    /// window. Reuses `Decade`'s year-range machinery — see
    /// `BrowseFilter.Decade.recentlyPublished` — so it is a filter the catalog
    /// already answers honestly, not a signal Dewey invented.
    private static let recent = BrowseFilter(period: .allTime, decade: .recentlyPublished, limit: 10)
    private static let recentExpanded = BrowseFilter(period: .allTime, decade: .recentlyPublished)

    /// Where "See all" goes from the genre and decade blocks: the browser
    /// itself, with nothing narrowed, so every genre and decade is one menu
    /// away.
    private static let everything = BrowseFilter(period: .allTime)

    @State private var answer: BrowseAnswer?
    @State private var recentAnswer: BrowseAnswer?

    private var phase: BrowseAnswer.Phase {
        BrowseAnswer.phase(of: answer, for: Self.hero.catalogQuery)
    }

    private var recentPhase: BrowseAnswer.Phase {
        BrowseAnswer.phase(of: recentAnswer, for: Self.recent.catalogQuery)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.loose) {
                popularShelf
                recentShelf
                genreBlock
                decadeBlock
            }
            .padding(.top, Theme.Space.snug)
            .padding(.bottom, Theme.Space.vast)
        }
        .scrollIndicators(.hidden)
        .background(Theme.Palette.paper.ignoresSafeArea())
        .deweyNavigationTitle("Home")
        .task(id: Self.hero.catalogQuery) { await load() }
        .task(id: Self.recent.catalogQuery) { await loadRecent() }
    }

    private func load() async {
        let asked = Self.hero.catalogQuery
        do {
            let books = try await store.browseCatalog(asked)
            guard !Task.isCancelled else { return }
            answer = BrowseAnswer(query: asked, books: books)
        } catch is CancellationError {
            // Superseded; the newer task owns this state.
        } catch {
            guard !Task.isCancelled else { return }
            answer = BrowseAnswer(query: asked, books: nil)
        }
    }

    private func loadRecent() async {
        let asked = Self.recent.catalogQuery
        do {
            let books = try await store.browseCatalog(asked)
            guard !Task.isCancelled else { return }
            recentAnswer = BrowseAnswer(query: asked, books: books)
        } catch is CancellationError {
            // Superseded; the newer task owns this state.
        } catch {
            guard !Task.isCancelled else { return }
            recentAnswer = BrowseAnswer(query: asked, books: nil)
        }
    }

    // MARK: - Popular this week

    /// The front table, and the first thing on the page.
    ///
    /// Standfirst, heading, one line of provenance, covers — four elements
    /// before the books instead of a paragraph. The standfirst is the only
    /// editorial voice left and it is one line: what this tab is *for*, said
    /// once, quietly, rather than explained.
    private var popularShelf: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                standfirst
                shelfHead
            }
            shelfContent
        }
    }

    /// One muted line, where a four-line paragraph about the difference
    /// between Home and the Edition used to be.
    ///
    /// It still does that paragraph's job — it says this is the world's taste
    /// rather than your circle's — but by *sounding* like the world rather
    /// than by describing an information architecture. A reader who wants the
    /// distinction gets it from the two tabs behaving differently, which is
    /// where a distinction is supposed to live.
    private var standfirst: some View {
        Text("What the reading world is into right now.")
            .font(Theme.TypeScale.support())
            .foregroundStyle(Theme.Palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pageMargin()
    }

    /// Kicker left, way through on the right, provenance underneath.
    ///
    /// The whole row is the link rather than a small "See all" word, so the
    /// target is the full measure and a reader who taps the heading — which
    /// they will, because it is the biggest thing on the line — gets what
    /// they expected.
    private var shelfHead: some View {
        NavigationLink(value: Self.heroExpanded) {
            VStack(alignment: .leading, spacing: Theme.Space.hair) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
                    Text(Self.hero.headline).kickerStyle(Theme.Palette.ink)
                    Spacer(minLength: 0)
                    Text("See all")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                }
                // **The honesty line, at the size a glance needs.** It used to
                // be two sentences under the covers — "What the wider
                // catalogue has been opening this week. Not Dewey's own
                // figures." — which is the right claim in the wrong register:
                // a disclaimer that large reads as an apology for the shelf.
                // Beside the heading it does the same work in five words, and
                // the sentence it shortened is still stated in full on
                // `BrowseBooksView`, which is where a reader actually studies
                // an ordering rather than glancing at one.
                Text(Self.provenance)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, Theme.Space.tight)
            .contentShape(Rectangle())
            .pageMargin()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.hero.headline). \(Self.provenance).")
        .accessibilityHint("Opens the full shelf")
        .accessibilityAddTraits(.isButton)
    }

    /// Names the catalogue and not the app, in that order, so there is no
    /// reading of this line on which the ranking belongs to Dewey.
    private static let provenance = "Trending across \(Vocabulary.widerCatalogue.lowercased())"

    @ViewBuilder
    private var shelfContent: some View {
        switch phase {
        case .loading:
            quietLine("Looking at what the world is reading…")
        case .failed:
            quietLine("Couldn't reach \(Vocabulary.widerCatalogue.lowercased()) just now. It'll be here when the connection is.")
        case .empty:
            quietLine("\(Vocabulary.widerCatalogue) had nothing to report this week.")
        case .loaded(let books):
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.Space.base) {
                    ForEach(books) { book in
                        BrowseCover(book: book, width: Metrics.heroCover)
                    }
                }
                .pageMargin()
                .padding(.bottom, Theme.Space.tight)
            }
        }
    }

    /// Loading, failure and emptiness all get one sentence in the same place.
    /// A spinner over a rail that is about to appear reads as a stall; a
    /// sentence reads as the app telling you where it is.
    private func quietLine(_ text: String) -> some View {
        Text(text)
            .font(Theme.TypeScale.support())
            .foregroundStyle(Theme.Palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pageMargin()
    }

    // MARK: - Recently published

    /// The page's second reason to keep scrolling. Same shelf mechanics as
    /// `popularShelf` — heading-as-link, honesty line, horizontal rail of
    /// `BrowseCover` — with no standfirst of its own, since that line is
    /// the page's framing and belongs above the first shelf only.
    private var recentShelf: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            recentShelfHead
            recentShelfContent
        }
    }

    private var recentShelfHead: some View {
        NavigationLink(value: Self.recentExpanded) {
            VStack(alignment: .leading, spacing: Theme.Space.hair) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
                    Text(Self.recentKicker).kickerStyle(Theme.Palette.ink)
                    Spacer(minLength: 0)
                    Text("See all")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                }
                Text(Self.recentProvenance)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, Theme.Space.tight)
            .contentShape(Rectangle())
            .pageMargin()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.recentKicker). \(Self.recentProvenance).")
        .accessibilityHint("Opens the full shelf")
        .accessibilityAddTraits(.isButton)
    }

    /// Names the window, not a claim of editorial notability Dewey has no
    /// way to back — see `BrowseFilter.Decade.recentlyPublished`.
    private static let recentKicker = "Recently published"

    /// The ordering is the same real signal as `provenance`: how widely a
    /// book is shelved, just filtered to a recent publication window rather
    /// than a reading one.
    private static let recentProvenance = "New to \(Vocabulary.widerCatalogue.lowercased()), ranked by how widely it's read"

    @ViewBuilder
    private var recentShelfContent: some View {
        switch recentPhase {
        case .loading:
            quietLine("Looking at what's new…")
        case .failed:
            quietLine("Couldn't reach \(Vocabulary.widerCatalogue.lowercased()) just now. It'll be here when the connection is.")
        case .empty:
            quietLine("\(Vocabulary.widerCatalogue) had nothing recently published to report.")
        case .loaded(let books):
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.Space.base) {
                    ForEach(books) { book in
                        BrowseCover(book: book, width: Metrics.heroCover)
                    }
                }
                .pageMargin()
                .padding(.bottom, Theme.Space.tight)
            }
        }
    }

    // MARK: - Ways in

    /// **Six genres, not eleven, and set as type rather than as pills.**
    ///
    /// The full set was a wall of outlined capsules wrapping over five lines,
    /// which is a control surface: it asks the reader to choose from a
    /// taxonomy before anything interesting happens, and it took up more of
    /// the page than the books did. Six names in two columns reads as the
    /// contents page of something rather than as a filter bar, costs three
    /// lines, and — the part that matters — is an invitation instead of a
    /// requirement, because the other five are one tap away under "See all".
    ///
    /// Each cell still pushes a whole `BrowseFilter`, exactly as the pills
    /// did. Nothing about the browse architecture changed here; this is
    /// presentation.
    private var genreBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            blockHead("Browse by genre", seeAll: Self.everything, spoken: "See all genres")
            LazyVGrid(columns: twoColumns, alignment: .leading, spacing: 0) {
                ForEach(BrowseFilter.Genre.featured) { genre in
                    genreCell(genre)
                }
            }
            .pageMargin()
        }
    }

    private var twoColumns: [GridItem] {
        [GridItem(.flexible(), spacing: Theme.Space.base, alignment: .leading),
         GridItem(.flexible(), spacing: Theme.Space.base, alignment: .leading)]
    }

    /// A name, a chevron, a hairline under it. The rule is what makes two
    /// columns of words read as a list rather than as loose text, and it is
    /// the same hairline the rest of the app separates rows with.
    private func genreCell(_ genre: BrowseFilter.Genre) -> some View {
        NavigationLink(value: BrowseFilter(period: .allTime, genre: genre)) {
            VStack(spacing: 0) {
                HStack(spacing: Theme.Space.tight) {
                    Text(genre.name)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(1)
                        // "Mystery & Thriller" is the longest of the six and
                        // fits a half-measure at default type; this is the
                        // backstop for larger text sizes, where shrinking the
                        // word beats truncating it to "Mystery & Thrill…".
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.Palette.inkFaint)
                }
                .frame(minHeight: 44)
                Rule()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// **Four decades on one line, where nine chips used to scroll.**
    ///
    /// A horizontal strip of nine capsules is a second scroller competing with
    /// the shelf above it, and it was the larger of the two on the page. Four
    /// middot-separated words are the same invitation at a tenth of the
    /// height; the remaining five decades — and the ability to combine one
    /// with a genre — are where they belong, in the browser.
    ///
    /// The four are real decades rather than a rounded-off "Earlier". A bucket
    /// named for a span the data model does not have would be the page
    /// inventing a category to look tidy.
    private var decadeBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            blockHead("Browse by decade", seeAll: Self.everything, spoken: "See all decades")
            HStack(spacing: Theme.Space.snug) {
                ForEach(Array(BrowseFilter.Decade.featured.enumerated()), id: \.element.id) { index, decade in
                    if index > 0 {
                        Text("·")
                            .font(Theme.TypeScale.support())
                            .foregroundStyle(Theme.Palette.inkFaint)
                            .accessibilityHidden(true)
                    }
                    decadeLink(decade)
                }
                Spacer(minLength: 0)
            }
            .pageMargin()
        }
    }

    private func decadeLink(_ decade: BrowseFilter.Decade) -> some View {
        NavigationLink(value: BrowseFilter(period: .allTime, decade: decade)) {
            Text(decade.label)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Theme.Palette.ink)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Kicker and a way through, for the two blocks under the shelf. The head
    /// itself is the link, same as the shelf's, so "See all" is a label on a
    /// full-width target rather than a 40-point word.
    private func blockHead(_ kicker: String, seeAll: BrowseFilter, spoken: String) -> some View {
        NavigationLink(value: seeAll) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
                Text(kicker).kickerStyle()
                Spacer(minLength: 0)
                Text("See all")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.accent)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
            }
            .padding(.vertical, Theme.Space.tight)
            .contentShape(Rectangle())
            .pageMargin()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - A cover on a browse shelf

/// One book, cover first, with just enough type underneath to know what it is.
///
/// Used by the Home rail and the Browse grid so a book does not change shape
/// between the two — tapping does the same thing in both places, and only the
/// width differs.
///
/// **The text block is a fixed height, and that is a real fix rather than
/// tidiness.** Title and author were both sized to their content, so a
/// one-line title sat at one height and a two-line title beside it at another;
/// on a rail that meant the authors under adjacent covers were on different
/// baselines, and in the grid it meant ragged rows. `reservesSpace` gives
/// every card the same two lines of title whether it needs them or not, which
/// is what makes a shelf look like a shelf.
///
/// **What it deliberately does not carry**: a rank, a count, a rating from
/// anyone but you. This is a browse surface quoting somebody else's chart, and
/// a numeral under a cover would either be a number Dewey does not have or a
/// position in a list nobody asked to be ranked. Your own mark shows, when you
/// have made one, because that is the one fact on this screen Dewey owns.
struct BrowseCover: View {
    @Environment(DeweyStore.self) private var store

    let book: Book
    var width: CGFloat = 140

    private var status: ReadingStatus? { store.status(of: book.id) }
    private var rating: Rating? { store.myRating(for: book.id) }

    var body: some View {
        NavigationLink(value: book) {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                BookCoverView(book: book, width: width)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        // Two lines, always. Not `.fixedSize`, which is what
                        // let cards disagree about their own height.
                        .font(.system(.subheadline, design: .serif, weight: .medium))
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                    Text(book.author)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .lineLimit(1)
                }
                mine
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken)
    }

    /// Only ever your own relationship with the book, and only when there is
    /// one. A book you have never touched shows nothing here rather than an
    /// empty slot — on a shelf of ten strangers, a row of blanks reads as ten
    /// things failing to load.
    @ViewBuilder
    private var mine: some View {
        if rating != nil || status != nil {
            HStack(spacing: Theme.Space.tight) {
                if rating != nil { RatingMark(rating: rating) }
                if let status {
                    Image(systemName: status.symbol)
                        .font(.caption2)
                        .foregroundStyle(Theme.Palette.inkSoft)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var spoken: String {
        var parts = ["\(book.title), by \(book.author)"]
        if let rating { parts.append("You rated it \(rating.spoken)") }
        if let status { parts.append(status.title) }
        return parts.joined(separator: ". ")
    }
}
