import SwiftUI

/// The front door to the world of books, as opposed to yours.
///
/// **Home and Edition answer different questions and must never merge.**
/// The Edition asks *what is reaching me through people whose taste I trust* —
/// it is finite, attributed, and ends. Home asks *what is happening in books
/// right now, and what can I go and look at* — it is unattributed, external,
/// and browseable. The moment Home starts carrying what your friends are
/// reading it has eaten the Edition; the moment the Edition starts carrying
/// charts it has stopped being a letter from people.
///
/// So the register is different on purpose: a bookstore's front table, not a
/// dashboard. Covers at a size you can actually read, one shelf that goes
/// somewhere, and a way in to the rest of the catalogue. No counts, no
/// percentages, no badges, nothing that moves while you look at it.
///
/// **Every figure behind this screen belongs to somebody else** (§16). Dewey
/// has a few dozen readers and no business publishing a chart; what it can
/// honestly do is quote one, and say whose it is. `BrowseFilter.sourceLine`
/// is that sentence and it appears on both surfaces this screen leads to.
struct HomeView: View {
    @Environment(DeweyStore.self) private var store

    /// The hero's question. Fixed — the shelf is *the* week's shelf, and a
    /// reader who wants a different one is one tap from the browser where the
    /// controls live.
    private static let hero = BrowseFilter(period: .thisWeek, limit: 10)

    @State private var answer: BrowseAnswer?

    private var phase: BrowseAnswer.Phase {
        BrowseAnswer.phase(of: answer, for: Self.hero.catalogQuery)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.loose) {
                standfirst
                popularShelf
                browseBlock
            }
            .padding(.top, Theme.Space.base)
            .padding(.bottom, Theme.Space.vast)
        }
        .scrollIndicators(.hidden)
        .background(Theme.Palette.paper.ignoresSafeArea())
        .deweyNavigationTitle("Home")
        .task(id: Self.hero.catalogQuery) { await load() }
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

    // MARK: - Standfirst

    /// One line, and it is the line that stops this tab being Search with
    /// bigger covers. It says what Home is *for*, which is the half of the
    /// product that a grid of jackets cannot say on its own — and it says it
    /// by naming the thing Home is not, because the tab immediately to the
    /// right is that thing.
    private var standfirst: some View {
        Text("Books at large — what the world is reading, rather than the people you follow.")
            .font(Theme.TypeScale.prose())
            .foregroundStyle(Theme.Palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pageMargin()
    }

    // MARK: - Popular this week

    /// The front table.
    ///
    /// A rail rather than a grid: ten covers at 118 points is one screen-width
    /// and a swipe, where the same ten stacked would be most of the tab. It is
    /// also the shape that reads as *a selection somebody laid out* instead of
    /// search results, which is the difference this whole screen is trying to
    /// hold on to.
    private var popularShelf: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            shelfHead
            shelfContent
        }
    }

    /// The heading **is** the way in, rather than a separate "See all" under
    /// the rail. One target, on the words a reader is already reading, and it
    /// arrives before the covers rather than after ten of them.
    private var shelfHead: some View {
        NavigationLink(value: Self.hero) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.tight) {
                Text(Self.hero.headline).kickerStyle(Theme.Palette.ink)
                Image(systemName: "arrow.right")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                Spacer(minLength: 0)
            }
            .padding(.vertical, Theme.Space.tight)
            .contentShape(Rectangle())
            .pageMargin()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Self.hero.headline). Browse all.")
    }

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
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Theme.Space.base) {
                        ForEach(books) { book in
                            BrowseCover(book: book, width: 118)
                        }
                    }
                    .pageMargin()
                    .padding(.bottom, Theme.Space.tight)
                }
                Text(Self.hero.sourceLine)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .pageMargin()
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

    // MARK: - Browse

    /// The other half of a front table: the shelves behind it, labelled.
    ///
    /// Type, not covers, and that is deliberate. The rail above is the visual
    /// argument; putting a second wall of jackets under it would make the page
    /// noisy and would also be dishonest about what these are — a genre is a
    /// door, not a book. Chips are the app's existing word for "a way to
    /// narrow", used on the Library's status filter and Search's genre rail,
    /// so nothing new has to be learned here.
    ///
    /// Every chip is a `NavigationLink` carrying a whole `BrowseFilter`, which
    /// is why there is no separate screen per genre and no separate screen per
    /// decade: they push the same browser with a different value in it.
    private var browseBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                SectionHead(kicker: "Browse by genre")
                FlowLayout(spacing: Theme.Space.snug, lineSpacing: Theme.Space.tight) {
                    ForEach(BrowseFilter.Genre.all) { genre in
                        chip(genre.name, filter: BrowseFilter(period: .allTime, genre: genre))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .pageMargin()
            }

            VStack(alignment: .leading, spacing: Theme.Space.base) {
                SectionHead(kicker: "Browse by decade")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Space.snug) {
                        ForEach(BrowseFilter.Decade.all) { decade in
                            chip(decade.label, filter: BrowseFilter(period: .allTime, decade: decade))
                        }
                    }
                    .pageMargin()
                    .padding(.vertical, Theme.Space.hair)
                }
            }
        }
    }

    private func chip(_ title: String, filter: BrowseFilter) -> some View {
        NavigationLink(value: filter) {
            Text(title)
                // `ChipStyle` is a `ButtonStyle` and this is a link, so the
                // capsule is drawn here rather than borrowed. Same padding,
                // same radius, same 44pt floor as every other chip in the app.
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, Theme.Space.base)
                .padding(.vertical, Theme.Space.snug)
                .frame(minHeight: 44)
                .overlay(Capsule().stroke(Theme.Palette.rule, lineWidth: 0.5))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - A cover on a browse shelf

/// One book, cover first, with just enough type underneath to know what it is.
///
/// Used by the Home rail and the Browse grid so a book does not change shape
/// between the two — the covers are the same size, the title is the same
/// serif, and tapping does the same thing in both places.
///
/// **What it deliberately does not carry**: a rank, a count, a rating from
/// anyone but you. This is a browse surface quoting somebody else's chart, and
/// a numeral under a cover would either be a number Dewey does not have or a
/// position in a list nobody asked to be ranked. Your own mark shows, when you
/// have made one, because that is the one fact on this screen Dewey owns.
struct BrowseCover: View {
    @Environment(DeweyStore.self) private var store

    let book: Book
    var width: CGFloat = 118

    private var status: ReadingStatus? { store.status(of: book.id) }
    private var rating: Rating? { store.myRating(for: book.id) }

    var body: some View {
        NavigationLink(value: book) {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                BookCoverView(book: book, width: width)
                Text(book.title)
                    .font(.system(.subheadline, design: .serif, weight: .medium))
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(book.author)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .lineLimit(1)
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
