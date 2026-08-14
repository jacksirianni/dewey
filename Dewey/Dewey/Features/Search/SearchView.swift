import SwiftUI
import UIKit

/// Handles are stored with the `@` in the seed, but a profile that renders
/// `@@priya` is the kind of detail that makes a prototype look unfinished.
private func atHandle(_ handle: String) -> String {
    handle.hasPrefix("@") ? handle : "@" + handle
}

// MARK: - Search

/// The discovery surface.
///
/// It is never blank. An empty query is not an absence of intent — it is a
/// reader standing in front of a shelf — so the resting state is a browsable
/// one: what the people you follow keep, and a rail of genres to pull on.
/// Search results are grouped by *kind of thing*, because "who else reads this"
/// and "which list is this in" are different questions and a single ranked blob
/// answers neither.
struct SearchView: View {
    @Environment(DeweyStore.self) private var store

    @State private var query: String = ""
    @State private var selectedGenre: String? = nil
    @FocusState private var fieldFocused: Bool

    // MARK: Remote search (§16)

    /// Where the wider-shelf request stands. Four states rather than a bool,
    /// because "no results" and "didn't answer" and "hasn't been asked" are
    /// three different sentences, and the section has to know which one it
    /// is honestly in.
    private enum RemoteSearch { case idle, searching, loaded, failed }

    /// One answer, and **the words it answers**. `books == nil` is a request
    /// that failed rather than one that found nothing.
    ///
    /// Carrying the query alongside the rows is what makes a stale section
    /// impossible: everything below compares it against what is in the field,
    /// so rows can only ever render under the query that produced them. The
    /// state this replaced was two properties written eagerly at the top of
    /// every keystroke's task — which SwiftUI faulted on ("onChange action
    /// tried to update multiple times per frame") and which still left the
    /// section describing itself as loaded while a newer request was in the
    /// air. One write, when an answer actually arrives.
    private struct RemoteAnswer {
        let query: String
        let books: [Book]?
    }

    @State private var remote: RemoteAnswer?

    /// Fresh only for the exact query in the field. Anything else is a request
    /// still in flight.
    private var remoteSearch: RemoteSearch {
        guard trimmed.count >= 3 else { return .idle }
        guard let remote, remote.query == trimmed else { return .searching }
        return remote.books == nil ? .failed : .loaded
    }

    private var remoteBooks: [Book] {
        guard let remote, remote.query == trimmed else { return [] }
        return remote.books ?? []
    }

    // MARK: Derived

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { trimmed.count >= 2 }

    private var results: DeweyStore.SearchResults { store.search(trimmed) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rule()
            ScrollView {
                if isSearching {
                    resultsBody
                } else {
                    browseBody
                }
            }
            .scrollDismissesKeyboard(.immediately)
            // The debounce lives in the task, not a timer: keying on the
            // trimmed query cancels the in-flight request the moment the
            // reader types again, and the 350ms sleep at the top of
            // `searchRemote` is what keeps a fast typist from costing Open
            // Library nineteen requests for one intention.
            .task(id: trimmed) {
                await searchRemote()
            }
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
        .deweyNavigationTitle("Search")
    }

    // MARK: Remote search

    /// Asks the catalog once the query is worth asking about. Three
    /// characters, not two like the local shelf — local search is free and
    /// instant, a network round-trip on "th" is neither.
    private func searchRemote() async {
        guard trimmed.count >= 3 else { return }
        let asked = trimmed
        do {
            // A cached answer is already in hand — waiting out a debounce to
            // hand it over is the one case where the pause is pure delay.
            if !store.hasCachedCatalogSearch(asked) {
                try await Task.sleep(for: .milliseconds(250))
            }
            let found = try await store.searchCatalog(asked)
            // Cancellation is cooperative, and nothing checks it for us once
            // the bytes have arrived: a task superseded while its response was
            // in flight still resumes here. The newer task owns this state.
            guard !Task.isCancelled else { return }
            remote = RemoteAnswer(query: asked, books: found)
        } catch is CancellationError {
            // Superseded before the request went out; the newer task owns it.
        } catch {
            guard !Task.isCancelled else { return }
            remote = RemoteAnswer(query: asked, books: nil)
        }
    }

    /// Remote rows the local sections haven't already answered. A book the
    /// reader imported yesterday resolves to its Dewey identity in
    /// `searchCatalog`, matches the local results row, and is dropped here —
    /// one book, one row, whichever shelf it is on.
    private var dedupedRemoteBooks: [Book] {
        let localIDs = Set(results.books.map(\.id))
        return remoteBooks.filter { !localIDs.contains($0.id) }
    }

    // MARK: Header

    /// The field, and nothing above it.
    ///
    /// A display-size **"Find"** used to sit here, and it was the only place
    /// this screen named itself — under a tab reading "Search", which made the
    /// discovery surface the one part of the app with two names. The name now
    /// lives in the navigation bar, once, as "Search", matching the tab; and
    /// what a search screen actually needs at the top is the field, which is
    /// forty points closer to the thumb for it.
    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            searchField
        }
        .padding(.top, Theme.Space.snug)
        .padding(.bottom, Theme.Space.base)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchField: some View {
        HStack(spacing: Theme.Space.snug) {
            Image(systemName: "magnifyingglass")
                .font(Theme.TypeScale.ui())
                .foregroundStyle(Theme.Palette.inkFaint)
                .accessibilityHidden(true)

            TextField("Books, readers, lists", text: $query)
                .textFieldStyle(.plain)
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($fieldFocused)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    // ~19pt of glyph before this. Padded inside the label and
                    // given a 44pt minimum; the negative trailing inset keeps
                    // the *visible* icon where it was in the capsule so the
                    // field does not grow to accommodate the target.
                    Image(systemName: "xmark.circle.fill")
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -Theme.Space.tight)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Theme.Space.base)
        .padding(.vertical, Theme.Space.snug + 2)
        .background(Theme.Palette.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.Palette.rule, lineWidth: 0.5))
        .pageMargin()
    }

    // MARK: Results

    @ViewBuilder
    private var resultsBody: some View {
        // The page is empty only when *both* shelves have finished answering
        // with nothing. While the catalog is still thinking, the remote
        // section says so — "Nothing for X" followed two beats later by
        // results would be the page contradicting itself.
        if results.isEmpty && dedupedRemoteBooks.isEmpty && remoteSearch != .searching {
            noResults
        } else {
            LazyVStack(alignment: .leading, spacing: Theme.Space.loose) {
                if !results.books.isEmpty { bookResults }
                if !results.readers.isEmpty { readerResults }
                if !results.lists.isEmpty { listResults }
                if !results.authors.isEmpty { authorResults }
                if !results.series.isEmpty { seriesResults }
                remoteSection
            }
            .padding(.top, Theme.Space.roomy)
            .padding(.bottom, Theme.Space.vast)
        }
    }

    /// The wider shelf (§16). Always below the local sections: the people you
    /// follow and the lists they keep are Dewey's answer, and the catalog's
    /// twenty million works are the appendix, not the argument.
    ///
    /// **It does not name the catalog.** The heading said "From Open Library",
    /// which told a reader the name of a supplier they have no relationship
    /// with and cannot act on — and it dated the screen to whichever provider
    /// happens to sit behind `BookCatalogProvider` today. What the reader needs
    /// to know is that these books are further away than the ones above.
    /// (Open Library asks only for a courtesy credit, not a required one; if it
    /// is ever wanted, the book page is the place for it.)
    ///
    /// **It used to say "the wider shelf", and that was the word's third live
    /// meaning.** `Vocabulary` had already retired "shelf" for meaning reading
    /// status and for meaning a curated list; this screen quietly gave it a
    /// third referent — the external catalog — while a provenance line one tab
    /// away used it for a fourth, a reader's own library. The heading now reads
    /// from `Vocabulary.widerCatalogue`, so the four strings below cannot drift
    /// apart from each other or from the rest of the app.
    ///
    /// Rendered through the same `BookRow` as local results, on purpose — a
    /// book already imported carries its rating and status marks right here,
    /// and a new one is plain. The rows differ by what Dewey knows, not by
    /// where they came from.
    @ViewBuilder
    private var remoteSection: some View {
        let books = dedupedRemoteBooks
        switch remoteSearch {
        case .idle:
            EmptyView()
        case .searching:
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                SectionHead(kicker: Vocabulary.widerCatalogue)
                Text("Looking further afield…")
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .pageMargin()
            }
        case .failed:
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                SectionHead(kicker: Vocabulary.widerCatalogue)
                Text("Couldn't reach the wider catalogue just now. Everything above is Dewey's own.")
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .pageMargin()
            }
        case .loaded:
            if !books.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.base) {
                    SectionHead(kicker: Vocabulary.widerCatalogue, trailing: "\(books.count)")
                    VStack(spacing: 0) {
                        ForEach(books) { book in
                            BookRow(book: book)
                            Rule().pageMargin()
                        }
                    }
                }
            }
        }
    }

    private var bookResults: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            SectionHead(kicker: "Books", trailing: "\(results.books.count)")
            VStack(spacing: 0) {
                ForEach(results.books) { book in
                    BookRow(book: book)
                    Rule().pageMargin()
                }
            }
        }
    }

    private var readerResults: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            SectionHead(kicker: "Readers", trailing: "\(results.readers.count)")
            VStack(spacing: 0) {
                ForEach(results.readers) { reader in
                    ReaderRow(reader: reader, overlap: store.overlap(with: reader))
                    Rule().pageMargin()
                }
            }
        }
    }

    private var listResults: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            SectionHead(kicker: "Lists", trailing: "\(results.lists.count)")
            VStack(spacing: 0) {
                ForEach(results.lists) { list in
                    ListRow(list: list, covers: covers(for: list))
                    Rule().pageMargin()
                }
            }
        }
    }

    private func covers(for list: BookList) -> [Book] {
        list.bookIDs.prefix(4).map { store.book($0) }
    }

    private var authorResults: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            SectionHead(kicker: "Authors", trailing: nil)
            VStack(spacing: 0) {
                ForEach(results.authors, id: \.self) { author in
                    plainRow(title: author, detail: countLine(store.books(byAuthor: author).count)) {
                        query = author
                    }
                    Rule().pageMargin()
                }
            }
        }
    }

    private var seriesResults: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            SectionHead(kicker: "Series", trailing: nil)
            VStack(spacing: 0) {
                ForEach(results.series, id: \.self) { series in
                    plainRow(title: series, detail: countLine(store.books(inSeries: series).count)) {
                        query = series
                    }
                    Rule().pageMargin()
                }
            }
        }
    }

    private func countLine(_ count: Int) -> String {
        "\(count) book\(count == 1 ? "" : "s")"
    }

    private func plainRow(title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.base) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, design: .serif, weight: .medium))
                        .foregroundStyle(Theme.Palette.ink)
                    Text(detail)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                }
                Spacer(minLength: Theme.Space.snug)
                Image(systemName: "arrow.up.left")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Theme.Space.snug + 2)
            .pageMargin()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The line under the headline tells the truth about how far the search
    /// actually reached (§16). Three different absences: the catalog was
    /// asked and had nothing, the catalog didn't answer, or the query is
    /// still too short to have asked at all — and the old "one shelf, not
    /// every shelf" copy stopped being true the day search learned to reach
    /// Open Library.
    private var noResults: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("Nothing for \u{201C}\(trimmed)\u{201D}")
                .font(Theme.TypeScale.title())
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(noResultsDetail)
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
        .padding(.top, Theme.Space.loose)
    }

    private var noResultsDetail: String {
        switch remoteSearch {
        case .loaded:
            "Nothing in Dewey, and nothing in the wider catalogue either. Try a different spelling, an author, or the name of someone you follow."
        case .failed:
            "The wider catalogue couldn't be reached, so this is Dewey's own only. Try an author, a genre, or the name of someone you follow."
        case .idle, .searching:
            "Try an author, a genre, or the name of someone you follow — a longer search looks further afield too."
        }
    }

    // MARK: Browse (empty query)

    private var browseBody: some View {
        LazyVStack(alignment: .leading, spacing: Theme.Space.loose) {
            followedSection
            genreRail
            browseList
        }
        .padding(.top, Theme.Space.roomy)
        .padding(.bottom, Theme.Space.vast)
    }

    /// The four each followed reader chose for their profile. Attributed,
    /// because an unattributed grid of covers is an algorithm and an attributed
    /// one is a shelf.
    ///
    /// **Nothing here is recent**, and the heading used to say it was. This
    /// reads `favoriteBookIDs` — a deliberately chosen, rarely changed four —
    /// and labelled it "Recently added by readers you follow", which is a claim
    /// about time that the data cannot support and the opposite of what the
    /// four are for. A reader could sit on this screen for a month and see the
    /// same twelve covers under a heading promising news.
    private var followedFavorites: [(book: Book, reader: ReaderProfile)] {
        var seen = Set<String>()
        var out: [(book: Book, reader: ReaderProfile)] = []
        // **Followed readers only.** The heading says "of readers you follow"
        // and this iterated `store.readers`, which is every seeded reader — so
        // the browse surface was built from four strangers under a claim that
        // they were people the reader had chosen. Same defect the Edition was
        // fixed for in §13.7 and the Lists index in this pass; this was the
        // third surface asserting a relationship it never checked.
        for reader in store.readers where store.isFollowing(reader.id) {
            for id in reader.favoriteBookIDs.prefix(4) where !seen.contains(id) {
                seen.insert(id)
                out.append((store.book(id), reader))
            }
        }
        return Array(out.prefix(12))
    }

    @ViewBuilder
    private var followedSection: some View {
        let items = followedFavorites
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                SectionHead(kicker: "\(Judgement.FavoriteBooksCopy.title) of readers you follow")
                LazyVGrid(columns: browseColumns, alignment: .leading, spacing: Theme.Space.roomy) {
                    ForEach(Array(items.enumerated()), id: \.offset) { pair in
                        attributedCover(book: pair.element.book, reader: pair.element.reader)
                    }
                }
                .pageMargin()
            }
        }
    }

    private var browseColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 92), spacing: Theme.Space.base, alignment: .topLeading)]
    }

    /// Cover and attribution, no rating. "Recently added" is a browse surface —
    /// the reader is being shown what turned up, not asked to weigh twelve books
    /// against each other — and the number on offer belongs to a third party who
    /// is already named by the avatar and first name directly underneath. The
    /// attribution *is* the recommendation here; a loose figure above it just
    /// argues with the person's face.
    private func attributedCover(book: Book, reader: ReaderProfile) -> some View {
        NavigationLink(value: book) {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                BookCoverView(book: book, width: 84)
                HStack(spacing: 4) {
                    ReaderAvatarView(reader: reader, size: 16)
                    Text(reader.name.split(separator: " ").first.map(String.init) ?? reader.name)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .lineLimit(1)
                }
            }
            .frame(width: 84, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var allGenres: [String] {
        var seen = Set<String>()
        for book in store.books {
            for genre in book.genres { seen.insert(genre) }
        }
        return seen.sorted()
    }

    @ViewBuilder
    private var genreRail: some View {
        let genres = allGenres
        if !genres.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                SectionHead(kicker: "Browse by shape", trailing: nil)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Space.tight) {
                        genreChip(title: "Everything", genre: nil)
                        ForEach(genres, id: \.self) { genre in
                            genreChip(title: genre, genre: genre)
                        }
                    }
                    .pageMargin()
                }
            }
        }
    }

    private func genreChip(title: String, genre: String?) -> some View {
        Button {
            withAnimation(Theme.Motion.standard) {
                selectedGenre = genre
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(title)
        }
        .buttonStyle(ChipStyle(selected: selectedGenre == genre))
    }

    private var browseBooks: [Book] {
        guard let genre = selectedGenre else { return store.books }
        return store.books.filter { $0.genres.contains(genre) }
    }

    private var browseList: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            SectionHead(kicker: selectedGenre ?? Vocabulary.everything, trailing: "\(browseBooks.count)")
            VStack(spacing: 0) {
                ForEach(browseBooks) { book in
                    BookRow(book: book)
                    Rule().pageMargin()
                }
            }
        }
    }
}

// MARK: - Profile

/// A reader, told in books.
///
/// `nil` means you. The two cases share one view on purpose: the profile you
/// present and the profile you inspect should make the same claims in the same
/// order, or the thing you are showing people is not the thing they are reading.
///
/// **The shelf layout, 2026-08-06 (§15).** Three registers: an identity block
/// carrying the texture line, a ruled band of figures, and the collections as
/// cover rails with the record set as type beneath them.
///
/// It reached this shape in two moves. It was first twelve sections in one
/// continuous scroll, which §12.5.1 collapsed into a five-row disclosure index
/// on the principle that a profile should be navigable rather than endured —
/// correct about the problem, wrong about the axis. Three of those five rows
/// hold a *row of covers*, which is horizontal: a rail costs one screen-width
/// and no scroll, so collapsing them bought nothing and cost a reader sight of
/// the four books they chose deliberately to be seen. The rails are open now.
/// The one row that genuinely was a long vertical list — the books you both
/// have read — is the one that kept a heading of its own.
///
/// The counts in the band are §12.1's reversal of "no follower count, no
/// percentage", with Read added in front of them: this is a reading app, and
/// the first figure on a reader's page should be how much they have read.
/// They are a doorway, not the argument. The argument is underneath — the books
/// you both read with both ratings beside each other, and the one you disagree
/// hardest about.
struct ProfileView: View {
    var reader: ReaderProfile? = nil

    @Environment(DeweyStore.self) private var store
    @Environment(SessionStore.self) private var session

    private var profile: ReaderProfile { reader ?? store.me }
    private var isMe: Bool { profile.isMe }

    /// Presents the picker. Only ever true on your own profile — the four are
    /// the one part of a profile you can edit, and only yours.
    @State private var isChoosingFavoriteBooks = false

    /// Confirmation for the local beta account's reset control. See
    /// `accountSection`.
    @State private var confirmingBetaReset = false

    /// How many shared books the overlap section lists before it starts
    /// counting instead. See `overlapContent`.
    private static let sharedRowLimit = 6

    /// The ranked preview's ordinal gutter. See `rankedRow`.
    @ScaledMetric(relativeTo: .title3) private var rankColumn: CGFloat = 26

    /// Read by `latelyRow`, which cannot stay on one line at accessibility
    /// sizes without losing the date off the end of it.
    @Environment(\.dynamicTypeSize) private var typeSize

    /// **The shelf layout** (§15). Identity, a band of figures, the collections
    /// as cover rails, then the record.
    ///
    /// This replaced a five-row disclosure index (§12.5.1), which was the right
    /// fix aimed at the wrong axis. Five *stacked vertical* sections was a
    /// punishing scroll, so they were collapsed behind taps — but three of those
    /// rows contain a row of covers, which is **horizontal**. A rail costs one
    /// screen-width and no scroll at all, and a collection you have to tap to
    /// see is a collection nobody sees. Only the row that genuinely is a long
    /// vertical list survived collapsing, and it now carries its own section
    /// head rather than a chevron.
    ///
    /// The order is not arbitrary: who you are, how much you have read, what
    /// you chose to show, what you mean to read, what you actually did last.
    /// Claims first, evidence after.
    ///
    /// **Your page and a stranger's diverge on purpose.** Yours can show a
    /// reading list and a diary because the store holds them; theirs cannot —
    /// Dewey does not publish what other readers plan to read, and there is no
    /// diary for anyone but you. In their place a stranger gets the two things
    /// that answer "is this taste worth trusting": everything they have rated,
    /// and the books you have both read.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.roomy) {
                // **Ordered by the question the page exists to answer** (§19.2):
                // *what is this person's taste?* Claims first, evidence after,
                // and intent last.
                //
                // Who they are, the four they chose, what they have been
                // reading, what they prefer, what they collected, what they
                // wrote. Everything above the fold is taste; everything below
                // it is either supporting detail or something other than taste.
                identityBlock
                statsBand
                favoriteBooksSection
                favoriteMomentsSection
                favoriteReviewsSection

                if isMe {
                    latelySection
                } else {
                    readSection
                    bothReadSection
                }

                // **Moved up from ninth** (§19.2). Your Ranking is the most
                // distinctive taste artifact on the page and it was sitting
                // below the reviews, under two sections a stranger scrolls
                // past — on a page whose first job is to answer what someone
                // prefers, the answer to that question was the last thing on
                // it.
                rankedSection

                listsSection
                reviewsSection

                if isMe {
                    // **Below the taste sections, not above them.** This was
                    // fourth, directly under the chosen four, which meant the
                    // page's second claim about a reader was a shelf of books
                    // they have not read yet. A reading list is intent, not
                    // taste, and it is the one section here the Library tab
                    // already renders in full with its own filter.
                    wantToReadSection
                    distributionSection
                    discoveredSection
                    accountSection
                }
            }
            .padding(.top, Theme.Space.base)
            .padding(.bottom, Theme.Space.vast)
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
        // Your own page is titled for the tab that reaches it; a stranger's is
        // titled for the person, because by then you are deep in a stack and the
        // bar is wayfinding rather than branding. Either way the bar is no
        // longer empty, which is what made its material read as a grey band
        // that had failed to load.
        .deweyNavigationTitle(isMe ? "You" : firstName)
        .sheet(isPresented: $isChoosingFavoriteBooks) {
            FavoriteBooksPicker()
        }
        .confirmationDialog(
            "Reset your beta account?",
            isPresented: $confirmingBetaReset,
            titleVisibility: .visible
        ) {
            Button("Reset beta account", role: .destructive) {
                store.forgetActiveAccountData()
                session.forgetLocalAccount()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("""
                 This clears your Dewey beta data on this device — your name, \
                 your library, everything you've logged — and takes you back \
                 to the beginning. This can't be undone.
                 """)
        }
    }

    // MARK: Identity

    /// Avatar on its own line, name at full display size underneath it.
    ///
    /// The avatar used to sit *beside* the name, which capped the name at
    /// whatever width was left over — roughly two thirds of the measure — so a
    /// two-word name wrapped on the smallest phone and a three-word one wrapped
    /// twice. Above the name instead, it costs 64 points of height and gives
    /// the name the whole measure, which is the difference between a heading
    /// and a masthead.
    ///
    /// **The texture line moved here out of an "About" disclosure.** It is one
    /// sentence about how a person reads, it is the single thing most likely to
    /// make a stranger's page worth staying on, and it was behind a tap.
    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            ReaderAvatarView(reader: profile, size: 64)
                .padding(.bottom, Theme.Space.tight)

            Text(profile.name)
                .font(Theme.TypeScale.display())
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(handleLine)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)

            Text(profile.texture)
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Space.tight)

            if !recurringGenres.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
                    Text("Keeps returning to").kickerStyle()
                    Text(recurringGenres.formatted(.list(type: .and)))
                        .font(Theme.TypeScale.support())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .padding(.top, Theme.Space.hair)
            }

            // **Follow, first placement** (§12.9.1) — under the identity, above
            // the band that counts followers.
            //
            // It belongs to the person rather than to the figures: the question
            // it answers is "do I want this reader in my editions", which the
            // name, the texture line and "Keeps returning to" have just spent
            // four lines answering, and which the follower tally underneath
            // does not bear on at all. Putting it inside the block also means
            // it arrives before the rules rather than floating between two
            // ruled edges, where a lone capsule reads as part of the table.
            //
            // Above the fold, and that is the point of having it here as well
            // as at the end of the overlap. Following is cheap, reversible and
            // frequently the reason a reader opened the page; making the only
            // way to do it a scroll past five sections would be charging for a
            // decision that costs nothing.
            //
            // `isMe` is the guard the whole control hangs on. Your own page
            // must never offer it — following yourself is not a state the store
            // should be able to reach.
            if !isMe {
                FollowButton(reader: profile, firstName: firstName)
                    .padding(.top, Theme.Space.base)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
    }

    /// Handle and joining year on one line. The year, never a month and never a
    /// day: the exact date is account plumbing, and what this is for is saying
    /// how long the shelf below took to build.
    ///
    /// The year is absent on your own profile in a fresh account (§13.7).
    /// `ReaderProfile.me` carries a 2024 join date because the *demo* reader has
    /// a history; a reader who opened the app ten minutes ago has none, and
    /// printing one is the app inventing a past for them.
    private var handleLine: String {
        guard let joinedYear else { return atHandle(profile.handle) }
        return "\(atHandle(profile.handle)) · joined \(joinedYear)"
    }

    private var joinedYear: String? {
        if isMe, store.world == .fresh { return nil }
        return profile.memberSince.formatted(.dateTime.year())
    }

    // MARK: Honest counts

    /// **Your own numbers come from the store, not from the seed** (§13.7).
    ///
    /// `ReaderProfile.me` is a fixture and carries 61 followers and 143
    /// following. In the seeded world that is the demo reader's network and it
    /// is fine. In a fresh account it is fabrication of exactly the kind this
    /// mode exists to eliminate — nobody follows a reader who signed up this
    /// morning, and Following is a number the reader has just been building
    /// themselves, one tap at a time.
    ///
    /// Other people's profiles keep their own figures either way. They are
    /// other people; their histories are not affected by the state of yours.
    private var shownFollowerCount: Int {
        isMe && store.world == .fresh ? 0 : profile.followerCount
    }

    /// **Your own Following is counted, never looked up** — in every world.
    ///
    /// This was gated on `store.world == .fresh`, so in the seeded world it fell
    /// through to `profile.followingCount`, which `DeweyStore.me` hardcodes to 0
    /// for any signed-in account. The result was a profile reading "Following 0"
    /// on a device whose Edition, two taps away, was headed "5 things from the
    /// readers you follow" and whose Lists index had a whole section called
    /// "From readers you follow". One fact, three surfaces, and the one that
    /// states it as a number was the one that had it wrong.
    ///
    /// There was never a reason to read this off a fixture. Following is a set
    /// the store holds and the reader built one tap at a time; its size is a
    /// fact about the device, not a property of a seeded persona. Followers is
    /// the opposite case and keeps its guard: nobody can follow you until real
    /// accounts can follow each other, so there is nothing local to count and
    /// zero is the honest answer.
    private var shownFollowingCount: Int {
        isMe ? store.follows.count : profile.followingCount
    }

    // MARK: The figures

    /// Read, Followers, Following — and Library Match on someone else's page.
    ///
    /// **Read is new to this band** (§15), and it is the figure that belongs
    /// here most. This is a reading app: the first number on a reader's page
    /// should be how much they have read, not how many people are watching.
    /// It used to be a tally on a collapsed disclosure row, which is where
    /// numbers go to be ignored — the two social counts sat above it in the
    /// masthead, so the page opened by stating a reader's audience and hid
    /// their reading one tap down. That is the priority §12.1 reversed once
    /// already, in the other direction, and it had drifted back.
    ///
    /// Library Match is withheld on your own profile. A match with yourself is
    /// either 99 or meaningless depending on how you round it, and either way
    /// it is not information.
    ///
    /// Ruled above and below with hairlines between the figures, rather than
    /// three numbers floating on paper. The band is the page's one piece of
    /// table-setting and it earns its keep editorially: it separates the claim
    /// above it from the evidence below.
    /// **Three columns, until three columns means three hyphens** (§19.2).
    ///
    /// Each figure gets a third of the measure, which is plenty at default type
    /// and nowhere near enough at an accessibility size: "Followers" in a
    /// 110-point column came out as "Fol-", "low-", "ers" stacked over three
    /// lines, and "Following" beside it did the same. A band whose whole job is
    /// to be read at a glance was the least legible thing on the page for the
    /// readers who most need it legible.
    ///
    /// Above the accessibility sizes it becomes rows: figure left, caption
    /// right, one per line, each caption with the full measure. The hairlines
    /// turn from column separators into row separators, which is the same
    /// editorial job in the other axis.
    private var statsBand: some View {
        Group {
            if typeSize.isAccessibilitySize { stackedBand } else { columnBand }
        }
        .padding(.vertical, Theme.Space.base)
        .overlay(alignment: .top) { Rule() }
        .overlay(alignment: .bottom) { Rule() }
        .pageMargin()
    }

    /// One source for both layouts, so a figure cannot exist in one and not the
    /// other.
    private var statEntries: [(figure: String, caption: String, label: String, value: String)] {
        var entries: [(figure: String, caption: String, label: String, value: String)] = [
            (readCount.formatted(), "Read", "Books read", "\(readCount)"),
            (shownFollowerCount.formatted(), "Followers", "Followers", "\(shownFollowerCount)"),
            (shownFollowingCount.formatted(), "Following", "Following", "\(shownFollowingCount)"),
        ]
        if !isMe {
            let match: Int = store.libraryMatch(with: profile)
            entries.append(("\(match)%", "Match", "Library match with \(firstName)", "\(match) percent"))
        }
        return entries
    }

    private var columnBand: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(Array(statEntries.enumerated()), id: \.offset) { index, entry in
                if index > 0 { bandDivider }
                stat(entry.figure, caption: entry.caption, label: entry.label, value: entry.value)
            }
        }
    }

    private var stackedBand: some View {
        VStack(spacing: 0) {
            ForEach(Array(statEntries.enumerated()), id: \.offset) { index, entry in
                if index > 0 { Rule() }
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.base) {
                    Text(entry.figure)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(entry.caption)
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Theme.Space.snug)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.label)
                .accessibilityValue(entry.value)
            }
        }
    }

    /// Sized to the figures rather than stretched to the band, so the rules
    /// read as column separators instead of a table grid.
    private var bandDivider: some View {
        Rectangle()
            .fill(Theme.Palette.rule)
            .frame(width: 0.5, height: 32)
            .accessibilityHidden(true)
    }

    /// The figure is serif and one step below the name; the caption is serif
    /// too, because a sans-serif label under a serif numeral is the exact
    /// dashboard tell this app is spending its whole budget avoiding.
    private func stat(_ figure: String, caption: String, label: String, value: String) -> some View {
        VStack(spacing: Theme.Space.hair) {
            Text(figure)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.system(.caption, design: .serif))
                .foregroundStyle(Theme.Palette.inkFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    // MARK: The sections

    /// The honest-empty line used wherever a section has nothing in it. §4.9:
    /// an absence of data is not a verdict, and saying so costs one sentence.
    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(Theme.TypeScale.support())
            .foregroundStyle(Theme.Palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pageMargin()
    }

    /// Your reading list, as a rail. Yours only — `wantToReadBooks` reads the
    /// signed-in library, and Dewey does not publish what other readers plan to
    /// read.
    private var wantToReadSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            SectionHead(
                kicker: ReadingStatus.wantToRead.title,
                trailing: wantToReadBooks.isEmpty ? nil : "\(wantToReadBooks.count)"
            )
            wantToReadContent
        }
    }

    /// Everything a stranger has put a number on. Only ever shown on their
    /// page: on yours the same ground is covered by the diary underneath, and
    /// by the Library tab, which is the place built for browsing all of it.
    private var readSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            SectionHead(kicker: "Read", trailing: "\(readCount)")
            readContent
        }
    }

    /// §12.5.2, and the most on-thesis thing on a stranger's page — which is
    /// why it is the one section that came out of the disclosure index with a
    /// section head rather than being folded into a rail. It is a vertical list
    /// of paired ratings; there is nothing horizontal about it to rescue.
    /// **No trailing count on the head.** `overlap.headline` is the very next
    /// line and it already says "4 books in common", in prose, with a qualifier
    /// underneath it. As a collapsed disclosure row the tally and the headline
    /// never appeared together; open by default they stack, and the section
    /// opens by stating the same number twice in two registers.
    private var bothReadSection: some View {
        let overlap: TasteOverlap = store.overlap(with: profile)
        return VStack(alignment: .leading, spacing: Theme.Space.snug) {
            SectionHead(kicker: "Books you both have read")
            overlapContent(overlap)
        }
    }

    /// Three genres, derived from what they have actually rated rather than
    /// declared. A self-described taste is a bio; a tallied one is evidence,
    /// and evidence is the only thing this page is allowed to argue from.
    private var recurringGenres: [String] {
        let ids: [String] = isMe ? Array(store.allMyRatings.keys) : Array(profile.ratings.keys)
        var tally: [String: Int] = [:]
        for id in ids {
            for genre in store.book(id).genres { tally[genre, default: 0] += 1 }
        }
        return tally
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(3)
            .map(\.key)
    }

    // MARK: Favorite Books — the four

    /// **The four this reader chose**, read straight off the profile and in the
    /// order they chose them.
    ///
    /// **Nothing here is computed** (§14). Not the top four ratings, not the
    /// head of the ranking, not the four most recently marked Favorite. This
    /// section briefly folded the diary's Favorite marks in for your own
    /// profile, on the reasoning that the store is the authority on what you
    /// have marked since the seed. It is — but "what you have marked" was never
    /// the question this section asks. Folding them in meant a reader who loved
    /// thirty books had four of them picked by recency, and the profile changed
    /// under them every time they logged one. Favorite is the mark; Favorite
    /// Books are the choice. This reads only the choice.
    private var chosenFavoriteBooks: [Book] {
        profile.favoriteBookIDs.map { store.book($0) }
    }

    /// Exactly four slots, filled or not. Three covers and an empty frame says
    /// "one still to choose"; three covers alone says "this is the list", which
    /// is a different and wrong claim.
    private var favoriteBookSlots: [Book?] {
        let chosen = chosenFavoriteBooks
        return (0..<Judgement.FavoriteBooksCopy.count).map { i in
            i < chosen.count ? chosen[i] : nil
        }
    }

    /// **Always open** (§15). This was a disclosure row, which meant the four
    /// books a reader deliberately chose to be seen were the one thing on the
    /// page you could not see. Four covers is a rail, not a scroll — there was
    /// never anything to collapse.
    ///
    /// The edit control lives in the section head rather than under the covers.
    /// A full-width button below a rail reads as "load more"; a quiet word on
    /// the heading line reads as what it is, and it is the only editing
    /// affordance on the whole page.
    private var favoriteBooksSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack(alignment: .firstTextBaseline) {
                Text(Judgement.FavoriteBooksCopy.title).kickerStyle()
                Spacer(minLength: Theme.Space.snug)
                if isMe {
                    Button { isChoosingFavoriteBooks = true } label: {
                        Text(editVerb)
                            .font(Theme.TypeScale.meta())
                            .foregroundStyle(Theme.Palette.accent)
                            // Caption type is roughly 26×15pt of glyph, and
                            // `.plain` hit-tests the label's bounds and nothing
                            // else — so without this the one editing control on
                            // the page was also the smallest target on it, at a
                            // third of the 44×44 minimum. Padded inside the
                            // label so the tappable area grows while the text
                            // stays on the heading's baseline.
                            .padding(.vertical, Theme.Space.snug)
                            .padding(.leading, Theme.Space.base)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Spoken as whatever it *says*. Hardcoding "Edit" here left
                    // a reader who has chosen nothing looking at "Choose" while
                    // VoiceOver said "Edit Favorite Books", and put the control
                    // out of reach of Voice Control entirely — "tap Choose"
                    // matches no label (WCAG 2.5.3, Label in Name).
                    .accessibilityLabel("\(editVerb) \(Judgement.FavoriteBooksCopy.title)")
                    .accessibilityHint("Opens the picker")
                } else if !chosenFavoriteBooks.isEmpty {
                    Text("\(chosenFavoriteBooks.count)")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                }
            }
            .pageMargin()

            favoriteBooksContent
        }
    }

    /// One source for the control's word, so what it says and what it announces
    /// cannot drift apart again.
    private var editVerb: String {
        chosenFavoriteBooks.isEmpty
            ? Judgement.FavoriteBooksCopy.choose
            : Judgement.FavoriteBooksCopy.edit
    }

    /// The subtitle stays — without it, four covers look like a truncated list
    /// rather than a deliberate one.
    ///
    /// Empty slots are shown to you and withheld from everyone else. On your own
    /// page a gap is an invitation; on a stranger's it is just an absence, and
    /// four outlines where a person's taste should be reads as a broken profile
    /// rather than an unfinished one.
    @ViewBuilder
    private var favoriteBooksContent: some View {
        if chosenFavoriteBooks.isEmpty && !isMe {
            emptyLine(Judgement.FavoriteBooksCopy.emptyTheirs(firstName))
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                Text(isMe ? Judgement.FavoriteBooksCopy.definition
                          : Judgement.FavoriteBooksCopy.profileBlurb)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .pageMargin()

                favoriteBooksRow
            }
        }
    }

    private var favoriteBooksRow: some View {
        ViewThatFits(in: .horizontal) {
            favoriteBookCovers(width: 88).pageMargin()
            favoriteBookCovers(width: 72).pageMargin()
            ScrollView(.horizontal, showsIndicators: false) {
                favoriteBookCovers(width: 96).pageMargin()
            }
        }
    }

    /// Your own four render every slot; everyone else's render only what they
    /// chose, so a reader with three does not appear to have a hole in them.
    private func favoriteBookCovers(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.snug) {
            ForEach(Array(favoriteBookSlots.enumerated()), id: \.offset) { slot in
                if let book = slot.element {
                    NavigationLink(value: book) {
                        VStack(alignment: .leading, spacing: Theme.Space.tight) {
                            BookCoverView(book: book, width: width)
                            CoverRatingSlot(rating: rating(of: book.id))
                        }
                        .frame(width: width, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(favoriteSlotSpoken(book))
                } else if isMe {
                    emptyFavoriteSlot(width: width, position: slot.offset + 1)
                }
            }
        }
    }

    /// Title, author, rating, then the claim the slot is making.
    ///
    /// A `NavigationLink` merges into one element, so an `accessibilityLabel`
    /// on it *replaces* what its children contributed rather than adding to it.
    /// The label used to be title-plus-claim, which silently threw away the
    /// author `BookCoverView` speaks and the score `CoverRatingSlot` draws — so
    /// a sighted reader saw four covers with four numbers under them and a
    /// VoiceOver reader got four titles. Everything visible in the slot is
    /// spoken, in the order it is read.
    private func favoriteSlotSpoken(_ book: Book) -> String {
        var parts: [String] = ["\(book.title), by \(book.author)"]
        if let rating = rating(of: book.id) { parts.append(rating.spoken) }
        parts.append(isMe
                     ? "One of your \(Judgement.FavoriteBooksCopy.title)"
                     : Judgement.FavoriteBooksCopy.spokenSlot(firstName))
        return parts.joined(separator: ", ")
    }

    /// An outline, not a placeholder cover. A grey rectangle the shape of a book
    /// reads as a book that failed to load; an outline with a word in it reads
    /// as a decision nobody has made yet.
    private func emptyFavoriteSlot(width: CGFloat, position: Int) -> some View {
        Button {
            isChoosingFavoriteBooks = true
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                RoundedRectangle(cornerRadius: Theme.Radius.cover)
                    .strokeBorder(
                        Theme.Palette.rule,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
                    .frame(width: width, height: width * 1.5)
                    .overlay {
                        Text(Judgement.FavoriteBooksCopy.choose)
                            .font(Theme.TypeScale.meta())
                            .foregroundStyle(Theme.Palette.inkFaint)
                    }
                CoverRatingSlot(rating: nil)
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose Favorite Book \(position) of \(Judgement.FavoriteBooksCopy.count)")
        .accessibilityHint("Opens the picker")
    }

    // MARK: Why they matter

    /// One captured Moment per favorite book, in the order the four were
    /// chosen. This is the one place on the page where a favorite explains
    /// itself instead of just sitting there rated — the cover says *what*,
    /// this says *why*, in the reader's own words instead of a number.
    ///
    /// **Yours only, and not because of a privacy check on the book.**
    /// `store.moments` holds nothing but the signed-in reader's own captures —
    /// there is no fixture data standing in for a stranger's — so gating on
    /// `isMe` states plainly what would otherwise be true by accident of the
    /// data model. Nothing changes about who can see a Moment: it was already
    /// visible only to the reader who caught it, on the book's own page and in
    /// the log sheet, and this is one more private-only place it can surface.
    ///
    /// Capped at three, and silent when it finds none. A reader with four
    /// favorites and zero captures gets no nudge here — Moments already have
    /// their own invitation on a book you are reading, and repeating it under
    /// a section that is supposed to be evidence would turn evidence into an
    /// ad for itself.
    private var favoriteBookMoments: [(book: Book, moment: Moment)] {
        guard isMe else { return [] }
        return chosenFavoriteBooks
            .compactMap { book in store.moments(forBook: book.id).first.map { (book, $0) } }
            .prefix(3)
            .map { $0 }
    }

    @ViewBuilder
    private var favoriteMomentsSection: some View {
        let items = favoriteBookMoments
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                SectionHead(kicker: "Why they matter")
                VStack(alignment: .leading, spacing: Theme.Space.base) {
                    ForEach(items, id: \.moment.id) { item in
                        favoriteMomentRow(item.book, item.moment)
                    }
                }
                .pageMargin()
            }
        }
    }

    /// The same rule-bar quote the log sheet's "From your Moments" prompt
    /// uses (`LogSheet.momentRow`) — one visual language for a caught line,
    /// wherever it resurfaces. The caption names the book rather than the
    /// page, because on a book's own page the book is given; here, across
    /// four of them, it is the thing being said.
    private func favoriteMomentRow(_ book: Book, _ moment: Moment) -> some View {
        NavigationLink(value: book) {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(moment.text)
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.ink)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
                Text(book.title)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .lineLimit(1)
            }
            .padding(.leading, Theme.Space.snug)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Theme.Palette.rule)
                    .frame(width: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(moment.text). From \(book.title).")
        .accessibilityHint("Opens the book")
    }

    // MARK: In their words

    /// One published `Review` per favorite book, in the order the four were
    /// chosen. `favoriteBookMoments` above answers "why they matter" from a
    /// private capture; this answers the same question from a piece of
    /// writing the reader chose to let others see.
    ///
    /// **Nothing here is a new privacy surface.** A review only appears once
    /// it already passes `DiaryEntry.hasPublishedReview` — the same test
    /// `reviewsSection` uses further down this page — which means the reader
    /// already chose "People who follow me" or "Everyone" over "Only me" in
    /// the log sheet's existing "Who can see it" control. This section does
    /// not ask that question again; it just gives one already-shared answer
    /// a more deliberate home, next to the book the reader picked to
    /// represent their taste, instead of leaving it to surface only in a
    /// chronological list of recent writing.
    ///
    /// A favorite whose review is still Only Me, still a draft, or blank
    /// simply is not here — silently, the same way an empty favorite slot or
    /// a favorite with no Moment is silent elsewhere on this page. There is
    /// no "share this" nudge in its place: the invitation already lives in
    /// the log sheet, and repeating it here would turn a page about a
    /// reader's taste into a reminder to produce more of it.
    private var favoriteBookReviews: [(book: Book, text: String)] {
        if isMe {
            return chosenFavoriteBooks
                .compactMap { book in
                    store.diaryEntries
                        .first { $0.bookID == book.id && $0.hasPublishedReview }
                        .map { (book, $0.review ?? "") }
                }
                .prefix(3)
                .map { $0 }
        }
        let reviews = store.allReviews.filter { $0.readerID == profile.id }
        return chosenFavoriteBooks
            .compactMap { book in
                reviews.first { $0.bookID == book.id }.map { (book, $0.preview) }
            }
            .prefix(3)
            .map { $0 }
    }

    @ViewBuilder
    private var favoriteReviewsSection: some View {
        let items = favoriteBookReviews
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                SectionHead(kicker: isMe ? "In your words" : "In their words")
                VStack(alignment: .leading, spacing: Theme.Space.base) {
                    ForEach(items, id: \.book.id) { item in
                        favoriteReviewRow(item.book, item.text)
                    }
                }
                .pageMargin()
            }
        }
    }

    /// The same rule-bar quote `favoriteMomentRow` uses, set upright rather
    /// than italic — a Moment is a caught line, a review is considered prose,
    /// and the two should not read identically. Capped at six lines for the
    /// same reason `reviewCard` caps at six: this is evidence a favorite
    /// earned its place, not the whole review.
    private func favoriteReviewRow(_ book: Book, _ text: String) -> some View {
        NavigationLink(value: book) {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(text)
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                Text(book.title)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .lineLimit(1)
            }
            .padding(.leading, Theme.Space.snug)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Theme.Palette.rule)
                    .frame(width: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(text). From \(book.title).")
        .accessibilityHint("Opens the book")
    }

    private var firstName: String {
        profile.name.split(separator: " ").first.map(String.init) ?? profile.name
    }

    /// This profile's rating for a book — mine from the store, theirs from the
    /// profile itself.
    private func rating(of bookID: String) -> Rating? {
        if isMe { return store.myRating(for: bookID) }
        return profile.ratings[bookID].flatMap(Rating.init)
    }

    // MARK: Books you both have read

    /// §12.5.2. The most on-thesis thing on the page, and the reason the index
    /// exists at all: it now has a name a stranger can find rather than being
    /// an unlabelled strip two thirds of the way down a scroll.
    ///
    /// Both ratings stay side by side and the sharpest disagreement stays under
    /// them. The Library Match percentage upstairs is what gets someone to open
    /// this row; this is what they read once they have.
    private func overlapContent(_ overlap: TasteOverlap) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            VStack(alignment: .leading, spacing: 2) {
                // Stepped down from `title()`: as a section head it was the
                // loudest thing in view, and inside a disclosure row it would
                // now be louder than the row that opened it.
                Text(overlap.headline)
                    .font(Theme.TypeScale.cardTitle())
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let qualifier = overlap.qualifier {
                    Text(qualifier)
                        .font(Theme.TypeScale.support())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .pageMargin()

            if overlap.sharedBooks.isEmpty {
                Text("Nothing you have both rated yet. That is not a verdict — it is an empty column.")
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .pageMargin()
            } else {
                VStack(spacing: 0) {
                    ForEach(overlap.sharedBooks.prefix(Self.sharedRowLimit)) { book in
                        sharedRow(book)
                        Rule().pageMargin()
                    }
                }
                // **Says so when it is showing fewer than it counted.**
                //
                // The headline above reads "7 books in common" and this list is
                // capped at six, with no row, count or link acknowledging the
                // seventh. A reader can subtract, and what they conclude is that
                // the number is wrong — on the one section of a stranger's page
                // whose entire job is to be checkable evidence for the Library
                // Match figure at the top.
                //
                // A count rather than a "show all": these are ordered by reach,
                // so the six shown are the six worth arguing from, and the tail
                // is context rather than something to page through.
                if overlap.count > Self.sharedRowLimit {
                    Text("Showing \(Self.sharedRowLimit) of \(overlap.count), the least widely read first.")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                        .pageMargin()
                        .padding(.top, Theme.Space.snug)
                }
                divergenceNote(overlap)
                followClose
            }
        }
    }

    /// **Follow, second placement** (§12.9.1) — the end of the argument.
    ///
    /// This section is the only thing on the page that gives a reader a real
    /// reason to follow someone: the books you have both read with both
    /// ratings beside each other, and the one you are furthest apart on. It
    /// ended on "A library that only agrees with you is a sales pitch" and then
    /// stopped — the case fully made and nothing to make it *to*. Sending a
    /// reader who has just been persuaded back up five sections to act on it is
    /// the friction landing at the exact moment intent is highest.
    ///
    /// **Yes, the same control twice on one page, on purpose.** The rule it
    /// looks like it breaks belongs to `PrimaryButtonStyle` — one filled button
    /// per screen — and this is a chip. Two *different* affordances for one
    /// action would be the real fault, so these are one component, one label,
    /// one state: whichever the reader meets first, the other is already
    /// showing the answer when they reach it. A long scroll repeating its
    /// action at the end is ordinary, and this scroll is long.
    ///
    /// **Only where there is an argument.** This hangs off the branch with
    /// shared books in it. With no overlap the section says so honestly and has
    /// persuaded nobody of anything, so there is nothing here to collect on —
    /// and the control at the top is still where it was. No `isMe` check:
    /// `bothReadSection` is already inside `body`'s stranger-only branch, and a
    /// second guard would imply it might not be.
    private var followClose: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text(FollowCopy.mechanic)
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            FollowButton(reader: profile, firstName: firstName)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.base)
        .pageMargin()
    }

    private func sharedRow(_ book: Book) -> some View {
        NavigationLink(value: book) {
            HStack(alignment: .center, spacing: Theme.Space.base) {
                BookCoverView(book: book, width: 40, scalesWithType: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.system(.body, design: .serif, weight: .medium))
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(2)
                    Text(book.author)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .lineLimit(1)
                }
                Spacer(minLength: Theme.Space.snug)
                VStack(alignment: .trailing, spacing: Theme.Space.tight) {
                    labelledRating("You", store.allMyRatings[book.id].flatMap(Rating.init))
                    labelledRating(firstName, profile.ratings[book.id].flatMap(Rating.init))
                }
            }
            .padding(.vertical, Theme.Space.snug)
            .pageMargin()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Kept, and the one place the unrated case had to be given a shape.
    ///
    /// "Books you both have read" is the most on-thesis comparison in the app —
    /// your number stacked over theirs, on the same book — so the numeral stays.
    /// But read is not the same as rated, and an unrated book left the label
    /// stranded: a bare "You" with nothing after it, which reads as a row that
    /// failed to load rather than a fact.
    ///
    /// The dash comes from `RatingMark.Unrated.stated` rather than being drawn
    /// here. It was hand-rolled — an em dash in `meta()`, sans-serif, against a
    /// serif numeral — which is the drift the shared mark exists to prevent, and
    /// it is the only surface in the app that needs the case, so the case had
    /// zero callers and this had a private copy of it.
    private func labelledRating(_ label: String, _ value: Rating?) -> some View {
        HStack(spacing: Theme.Space.tight) {
            Text(label)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
            RatingMark(rating: value, unrated: .stated)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func divergenceNote(_ overlap: TasteOverlap) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            if let first = overlap.divergentBooks.first {
                Text("Where you part ways")
                    .kickerStyle()
                Text("You and \(firstName) are furthest apart on \u{201C}\(first.title).\u{201D} A library that only agrees with you is a sales pitch.")
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Where you part ways")
                    .kickerStyle()
                Text("Nothing sharp yet. You have not read enough of the same books to disagree properly.")
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.snug)
        .pageMargin()
    }

    // MARK: Read

    /// The whole shelf, not the twelve covers the strip shows. Mine is the
    /// diary's distinct books; theirs is everything they have put a number on,
    /// which is the only record of their reading Dewey holds.
    private var readCount: Int {
        if isMe { return Set(store.diaryEntries.map(\.bookID)).count }
        return profile.ratings.count
    }

    private var recentlyRead: [Book] {
        if isMe {
            var seen = Set<String>()
            var out: [Book] = []
            for entry in store.diaryEntries where !seen.contains(entry.bookID) {
                seen.insert(entry.bookID)
                out.append(store.book(entry.bookID))
            }
            return Array(out.prefix(12))
        }
        let sorted = profile.ratings.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
        }
        return sorted.prefix(12).map { store.book($0.key) }
    }

    /// The row is called "Read" for both cases, but the two orderings are not
    /// the same claim — mine is chronological, theirs is a ranking — so the
    /// line that used to be the section kicker survives as the subtitle. A
    /// strip whose order you can't infer is decoration.
    @ViewBuilder
    private var readContent: some View {
        let books = recentlyRead
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text(isMe ? "Most recent first, out of the diary." : "Highest rated first.")
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .pageMargin()
            if books.isEmpty {
                emptyLine(isMe
                          ? "Nothing logged yet. Finishing a book puts it here."
                          : "\(firstName) hasn't rated anything yet.")
            } else {
                CoverStrip(books: books, rating: { rating(of: $0.id) })
            }
        }
    }

    // MARK: Lately

    /// The last three things you did, set as typeset lines rather than cards.
    ///
    /// **No covers here, on purpose** (§15). This section sits directly beneath
    /// two rails of them, and a third block turns the page into a contact
    /// sheet — the eye stops finding covers meaningful somewhere around the
    /// twelfth. A title, a date and a mark is the whole of what a diary line
    /// needs to say, and dropping to type is what lets the rails above it read
    /// as deliberate rather than as the page's default gesture.
    ///
    /// It used to be called "Reading diary" and carried a 40pt cover per row.
    /// The heading changed because the link underneath it already says "the
    /// whole diary": a section headed *Reading diary* that is followed by a
    /// link to the reading diary is a section that cannot say what it is.
    @ViewBuilder
    private var latelySection: some View {
        let entries = Array(store.diaryEntries.prefix(3))
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            SectionHead(kicker: "Lately")
            if entries.isEmpty {
                emptyLine("Nothing logged yet. Finishing a book puts it here.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        latelyRow(entry)
                        if index < entries.count - 1 { Rule().pageMargin() }
                    }
                }
                NavigationLink {
                    DiaryView()
                } label: {
                    HStack(spacing: Theme.Space.tight) {
                        Text("The whole diary")
                        Image(systemName: "arrow.right")
                    }
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.accent)
                    // Inside the label so the target grows rather than a
                    // transparent box floating over a smaller one.
                    .padding(.vertical, Theme.Space.snug)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pageMargin()
            }
        }
    }

    /// **The trailing edge is the date, on every row, always** (§19.2).
    ///
    /// It used to be the date *and then whatever the entry happened to have*:
    /// `entry.rating != nil ? RatingMark : status`. So a shelf of three
    /// consecutive entries read
    ///
    ///     The Peregrine        Aug 9   Finished
    ///     Bluets               Jul 10  9.3
    ///     Piranesi             Jun 30  10
    ///
    /// — a right-hand column where the same position means a reading status on
    /// one line and an opinion out of ten on the next, with nothing to mark the
    /// switch. A column is a promise that everything in it answers one question,
    /// and this one answered two.
    ///
    /// So: the date trails, alone, in one style. **Your Score moves to the
    /// leading group and sits with the book**, which is where it belongs on
    /// every other surface in the app — it is a fact about the book, not about
    /// when the log was filed. The Diary tab has always been laid out this way
    /// (`DiaryRow`, date gutter on the left, score under the author); this row
    /// was the one place that disagreed with it.
    ///
    /// **"Finished" is gone**, and its absence is the information. This is a
    /// reverse-chronological list of completed readings, so "Finished" was true
    /// of nearly every row and told a reader nothing; the statuses worth a word
    /// are the ones that break the pattern — a book still being read, paused, or
    /// put down. `DiaryRow` reached the same conclusion first.
    private func latelyRow(_ entry: DiaryEntry) -> some View {
        let book: Book = store.book(entry.bookID)
        return NavigationLink(value: book) {
            Group {
                if typeSize.isAccessibilitySize { stackedLately(entry, book) } else { inlineLately(entry, book) }
            }
            .padding(.vertical, Theme.Space.snug + 1)
            .pageMargin()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(latelySpoken(entry, book))
    }

    private func inlineLately(_ entry: DiaryEntry, _ book: Book) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
            Text(book.title)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(1)
                .layoutPriority(1)
            latelyMarks(entry)
            Spacer(minLength: Theme.Space.snug)
            latelyDate(entry)
        }
    }

    /// **One line becomes two before the date falls off the end.**
    ///
    /// At an accessibility size the single-line row could not hold a title, a
    /// score and a date: the title has layout priority, so what got dropped was
    /// the date — truncated to "J…" on one row and pushed off the screen
    /// entirely on the next. Which is the priority this pass just established,
    /// inverted, on exactly the readers least able to absorb it.
    ///
    /// Stacked, the title gets the measure and the second line keeps the
    /// arrangement the row is *for*: score with the book on the left, date
    /// alone on the right. The trailing edge still means one thing; it just
    /// means it one line lower.
    private func stackedLately(_ entry: DiaryEntry, _ book: Book) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(book.title)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
                latelyMarks(entry)
                Spacer(minLength: Theme.Space.snug)
                latelyDate(entry)
            }
        }
    }

    /// Attached to the book, never to the date.
    @ViewBuilder
    private func latelyMarks(_ entry: DiaryEntry) -> some View {
        if entry.rating != nil { RatingMark(rating: entry.rating) }
        if entry.isFavorite { FavoriteMark(filled: true, size: 12) }
        if entry.status != .finished {
            Text(entry.status.title)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .lineLimit(1)
        }
    }

    private func latelyDate(_ entry: DiaryEntry) -> some View {
        Text(entry.loggedOn.formatted(.dateTime.month(.abbreviated).day()))
            .font(Theme.TypeScale.meta())
            .foregroundStyle(Theme.Palette.inkFaint)
            .lineLimit(1)
            .fixedSize()
    }

    /// Spoken as one sentence. Read as separate elements this is a title, a
    /// bare month-and-day, a number and an unlabelled glyph — four fragments
    /// that only mean anything together.
    private func latelySpoken(_ entry: DiaryEntry, _ book: Book) -> String {
        var parts: [String] = [book.title]
        if let rating = entry.rating { parts.append(rating.spoken) }
        if entry.isFavorite { parts.append(Judgement.FavoriteCopy.title) }
        if entry.isReread { parts.append("Reread") }
        // Spoken in the drawn order, so a VoiceOver reader and a sighted reader
        // hear and see the same row — and, like the drawn row, the status is
        // only worth a word when it is not the one every entry here has.
        if entry.status != .finished { parts.append(entry.status.title) }
        parts.append(entry.loggedOn.formatted(.dateTime.month(.wide).day()))
        return parts.joined(separator: ", ")
    }

    // MARK: Reviews

    /// All of them, newest first. `reviewsSection` below shows a preview of
    /// this; `AllReviewsView` shows the whole thing — one source so the two
    /// cannot disagree about what counts as published.
    private var allReviewTexts: [(id: String, bookID: String, text: String, rating: Rating?)] {
        publishedReviews(store, for: profile)
    }

    private var reviewTexts: [(id: String, bookID: String, text: String, rating: Rating?)] {
        Array(allReviewTexts.prefix(3))
    }

    /// **The one collection on this page that used to have no way past its
    /// preview.** Favorite Books opens a picker, Lists opens `ListsIndexView`,
    /// Ranking opens `RankedListView` — three taps to "see everything I've
    /// curated." Reviews showed three and stopped: a reader's fourth published
    /// review, written and deliberately shared, simply fell off the page with
    /// nothing pointing at where it went. This closes that seam the same way
    /// the other two do, from data already on hand.
    @ViewBuilder
    private var reviewsSection: some View {
        let items = reviewTexts
        let total = allReviewTexts.count
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                SectionHead(kicker: Judgement.ReviewCopy.plural, trailing: nil)
                VStack(spacing: Theme.Space.base) {
                    ForEach(items, id: \.id) { item in
                        reviewCard(item.bookID, item.text, item.rating)
                    }
                }
                .pageMargin()

                if total > items.count {
                    NavigationLink {
                        AllReviewsView(reader: isMe ? nil : profile)
                    } label: {
                        HStack(spacing: Theme.Space.tight) {
                            Text("See all \(total)")
                            Image(systemName: "arrow.right")
                        }
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.accent)
                        .padding(.vertical, Theme.Space.snug)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pageMargin()
                }
            }
        }
    }

    /// No rating on the card. One reader, one book, one piece of writing — there
    /// is nothing here to compare against, and the card's kicker is already the
    /// book title, so the number was answering a question the surface does not
    /// ask. It was also the first thing above six lines of prose: 66pt of rules
    /// standing in front of the only content the card exists to show.
    ///
    /// `rating` is still accepted so `reviewTexts` does not have to be
    /// reshaped and so putting the mark back is a one-line change. It is
    /// deliberately unused.
    private func reviewCard(_ bookID: String, _ text: String, _ rating: Rating?) -> some View {
        let book: Book = store.book(bookID)
        return NavigationLink(value: book) {
            CardShell(kicker: book.title) {
                VStack(alignment: .leading, spacing: Theme.Space.snug) {
                    Text(text)
                        .font(Theme.TypeScale.prose())
                        .foregroundStyle(Theme.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Lists

    private var visibleLists: [BookList] {
        if isMe { return store.myLists }
        let owned = store.allLists.filter { $0.ownerID == profile.id && $0.isPublic }
        if !owned.isEmpty { return owned }
        return profile.listIDs.compactMap { store.list($0) }.filter(\.isPublic)
    }

    /// §12.5.3. The same lists the old profile rendered as three-line rows with
    /// a fanned stack of four thumbnails, now as titled horizontal cover rows.
    ///
    /// A list is a claim about taste, and covers are what a claim about taste
    /// looks like. The old row was a table of contents for a page nobody
    /// turned to; this is the collection itself, and it is the single biggest
    /// density win the wireframe had. It replaces the "Lists" section rather
    /// than joining it — the same lists twice on one screen is a bug, not
    /// preservation. The title still navigates to the list, every cover still
    /// navigates to its book.
    ///
    /// **The heading is a destination now, and that closed a hole in the
    /// product.** `ListsIndexView` — a complete screen with its own masthead,
    /// a Yours section, a From-readers-you-follow section and a New List sheet
    /// — existed in the codebase and was reachable from **nowhere**. No tab, no
    /// push, no `deweyDestinations` entry. The only route to a list at all was
    /// this rail or a book page, and the only way to *make* one was the "New
    /// list" disclosure buried inside Add to List, on a book page, which means
    /// a reader could not create a list without first deciding which book went
    /// in it. Both are now one tap from a profile.
    ///
    /// **Your own page renders the section even when it is empty**, which is the
    /// half that matters: on a fresh account there are no lists, so a section
    /// that hides itself when empty is a door that only appears once you are
    /// already through it. A stranger's page keeps hiding it — an absent
    /// collection is not an invitation to anybody but its owner.
    @ViewBuilder
    private var listsSection: some View {
        let lists = visibleLists
        if !lists.isEmpty || isMe {
            VStack(alignment: .leading, spacing: Theme.Space.roomy) {
                listsHead(count: lists.count)
                if lists.isEmpty {
                    emptyLine("No lists yet. A list needs a premise before it needs books.")
                } else {
                    // **Two rails, then the heading takes over.**
                    //
                    // Every list rendered a full titled cover rail, so a reader
                    // with eight lists had eight of them stacked in the middle
                    // of their profile and the sections underneath were
                    // unreachable without a long scroll. The head already
                    // states the total and opens `ListsIndexView`, so nothing
                    // here is hidden without being counted — which is the
                    // condition for capping anything.
                    ForEach(lists.prefix(Self.listRailLimit)) { list in
                        listRail(list)
                    }
                }
            }
        }
    }

    /// How many list rails the profile draws before deferring to the heading.
    /// Two is enough to show what a list looks like here without the section
    /// becoming the page.
    private static let listRailLimit = 2

    /// The kicker, the count, and the way in. A chevron rather than a worded
    /// link because the row *is* the heading — a second "See all" underneath it
    /// would be two controls for one destination, which is the pattern this
    /// pass has been removing everywhere else.
    private func listsHead(count: Int) -> some View {
        NavigationLink {
            ListsIndexView()
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(Vocabulary.lists).kickerStyle()
                Spacer(minLength: Theme.Space.snug)
                if count > 0 {
                    Text("\(count)")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                }
                Image(systemName: "chevron.right")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Theme.Space.tight)
            .pageMargin()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMe ? "Your lists" : "\(firstName)'s lists")
        .accessibilityValue(count == 1 ? "1 list" : "\(count) lists")
        .accessibilityHint("Opens every list")
    }

    private func listRail(_ list: BookList) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            NavigationLink(value: list) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(list.title)
                            .font(.system(.body, design: .serif, weight: .semibold))
                            .foregroundStyle(Theme.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                        Text(list.premise)
                            .font(Theme.TypeScale.meta())
                            .foregroundStyle(Theme.Palette.inkFaint)
                            .lineLimit(1)
                    }
                    Spacer(minLength: Theme.Space.tight)
                    Text(list.subtitle)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .layoutPriority(1)
                    Image(systemName: "chevron.right")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .accessibilityHidden(true)
                }
                .pageMargin()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(list.title). \(list.premise)")
            .accessibilityValue(list.subtitle)
            .accessibilityHint("Opens the list")

            // No ratings on a list rail. A list is sold by its title and its
            // premise — both of which sit immediately above this row — and the
            // FromListCard doc puts it plainly: the premise "tells you more
            // about whether you want this than any rating could". A row of loose
            // numerals under the covers competes with the sentence that is doing
            // the actual work. The Read and Favorite Books rails keep theirs,
            // because those strips are asking what the reader made of them.
            CoverStrip(books: listCovers(list), rating: { _ in nil })
        }
    }

    /// Eight covers. Past that the row stops being a rail and starts being a
    /// scroll, and the count beside the title already says how much is missing.
    private func listCovers(_ list: BookList) -> [Book] {
        list.bookIDs.prefix(8).map { store.book($0) }
    }

    // MARK: Reading List

    /// Only your own want-shelf is knowable: `store.entries(withStatus:)` reads the
    /// signed-in library, and pointing it at someone else's profile would show
    /// them your books under their name.
    private var wantToReadBooks: [Book] {
        guard isMe else { return [] }
        return store.entries(withStatus: .wantToRead).map { store.book($0.bookID) }
    }

    @ViewBuilder
    private var wantToReadContent: some View {
        let books = wantToReadBooks
        if !books.isEmpty {
            CoverStrip(books: Array(books.prefix(12)), rating: { _ in nil })
        } else if isMe {
            emptyLine("Nothing waiting. Saving a book out of the edition puts it here.")
        } else {
            emptyLine("Dewey doesn't publish what other readers plan to read \u{2014} only what they finished, and what they kept.")
        }
    }

    // MARK: Ranking

    /// **Your Ranking is on the profile, and so is theirs** (§19).
    ///
    /// This was `if isMe`, which made a ranking the one taste artifact on this
    /// page a stranger could not see — beside their Favorite Books, their
    /// reviews, their lists and everything they had rated. A private ranking is
    /// not a ranking of standing; it is a preference the reader keeps in a
    /// drawer, and the whole reason to spend five taps building one is that it
    /// says something about you to somebody else.
    ///
    /// Hiding it is `DeweyStore.isRankingPublic`, off in an overflow menu on the
    /// list itself. When it is off, your own page still draws the section and
    /// says so — a section that silently disappeared from your own profile
    /// would read as data loss.
    @ViewBuilder
    private var rankedSection: some View {
        let ranking = store.ranking(for: profile)
        if !ranking.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                SectionHead(
                    kicker: isMe ? Judgement.RankingCopy.title : "\(firstName)'s Ranking",
                    trailing: "\(ranking.count)"
                )
                if isMe, !store.isRankingPublic {
                    Text(Judgement.RankingPrivacyCopy.hidden)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .pageMargin()
                }
                rankedPreview(ranking)
                NavigationLink {
                    RankedListView(reader: isMe ? nil : profile)
                } label: {
                    HStack(spacing: Theme.Space.tight) {
                        Text("See the whole order")
                        Image(systemName: "arrow.right")
                    }
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.accent)
                    .padding(.vertical, Theme.Space.snug)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pageMargin()
            }
        }
    }

    private func rankedPreview(_ ranking: PersonalRanking) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(ranking.order.prefix(3).enumerated()), id: \.offset) { pair in
                rankedRow(position: pair.offset + 1, book: store.book(pair.element))
                Rule().pageMargin()
            }
        }
    }

    /// The ordinal carries this row and nothing answers it. §12.4 is explicit
    /// that a ranking and a rating are different questions — one is a forced
    /// ordering, the other a valuation — and the ranking was produced by
    /// pairwise choices that never read a number. Printing the valuation beside
    /// the ordering invites the reader to check the two against each other,
    /// which is precisely the reading a ranking exists not to be.
    private func rankedRow(position: Int, book: Book) -> some View {
        NavigationLink(value: book) {
            HStack(alignment: .center, spacing: Theme.Space.base) {
                Text("\(position)")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    // Scaled, like the ranked list's own gutter and the diary's
                    // date column. 26 points held two `.title3` digits at
                    // default type and clipped the second one as soon as a
                    // reader turned text up.
                    .frame(width: rankColumn, alignment: .trailing)
                BookCoverView(book: book, width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.system(.body, design: .serif, weight: .medium))
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(1)
                    Text(book.author)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .lineLimit(1)
                }
                Spacer(minLength: Theme.Space.snug)
            }
            .padding(.vertical, Theme.Space.snug)
            .pageMargin()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Rating distribution

    /// Twenty half-point bins (§12.3), binned by the same statics the book
    /// page's community histogram uses.
    ///
    /// The arithmetic that used to live here — `value * 2`, rounded, ten bins,
    /// out-of-range silently discarded — put every rating above 5.0 on the
    /// floor the moment the scale became 0.1–10.0, which zeroed the total and
    /// hid the section entirely rather than drawing it wrong. Delegating to
    /// `DistributionHistogram` means there is one definition of where a bin
    /// starts and it is not in this file.
    private var myBuckets: [Int] {
        var buckets = Array(repeating: 0, count: DistributionHistogram.bucketCount)
        for value in store.allMyRatings.values {
            buckets[DistributionHistogram.bucket(for: value)] += 1
        }
        return buckets
    }

    @ViewBuilder
    private var distributionSection: some View {
        let buckets = myBuckets
        let total = buckets.reduce(0, +)
        if total > 0 {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                SectionHead(kicker: "How you score", trailing: nil)
                VStack(alignment: .leading, spacing: Theme.Space.snug) {
                    DistributionHistogram(counts: buckets, height: 68)
                    // The count sits on its own line, not between the axis
                    // anchors. Wedged in the middle it squeezed the two figures
                    // that actually have to hold their positions, and it is a
                    // caption about the whole block rather than part of the
                    // scale — the same layout the book page's Dewey Score block
                    // was fixed for, still standing here.
                    HStack {
                        Text(Rating.clamping(Rating.range.lowerBound).compact)
                        Spacer(minLength: 0)
                        Text(Rating.clamping(Rating.range.upperBound).compact)
                    }
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .lineLimit(1)
                    .accessibilityHidden(true)

                    Text("\(total) book\(total == 1 ? "" : "s") scored")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .pageMargin()
            }
        }
    }

    // MARK: Discovered through you

    /// Kept, deliberately. It is the one number on this page that no other
    /// reading app has, and it is the only one that required something of you.
    ///
    /// Its old subtitle claimed to be "the only count in Dewey worth keeping",
    /// which stopped being true the moment §12.1 put Followers and Following at
    /// the top. Amended rather than deleted — the claim underneath it survives
    /// the arrival of the other three, it just has to share the page now.
    @ViewBuilder
    private var discoveredSection: some View {
        let items = store.discoveredThroughMe
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Discovered through you").kickerStyle()
                    Text("Books someone else is reading because you handed them over. There are three other numbers at the top of this page. This is the one that cost you something.")
                        .font(Theme.TypeScale.support())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .pageMargin()

                VStack(spacing: Theme.Space.snug) {
                    ForEach(Array(items.enumerated()), id: \.offset) { pair in
                        discoveredRow(book: pair.element.book, reader: pair.element.reader)
                    }
                }
                .pageMargin()
            }
        }
    }

    private func discoveredRow(book: Book, reader: ReaderProfile) -> some View {
        NavigationLink(value: book) {
            HStack(alignment: .top, spacing: Theme.Space.base) {
                BookCoverView(book: book, width: 52, scalesWithType: true)
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    Text("\(reader.name) started reading it.")
                        .font(Theme.TypeScale.proseLarge())
                        .foregroundStyle(Theme.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    ProvenanceLine(text: "\(book.title) — because of you", reader: reader)
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.Space.base)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Theme.Palette.accent.opacity(0.35), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Account

    /// **Only while this account is the local beta stand-in.** A real,
    /// Supabase-backed account has no local equivalent of deleting itself —
    /// that needs the server — so this control does not exist at all once
    /// `SupabaseConfig.plist` is present; there is nothing here to accidentally
    /// mistake for production account management. See `AccountServices`.
    ///
    /// Deliberately last, below every taste section, and deliberately quiet:
    /// this is not a feature of the profile, it is a way out of a testing mode
    /// most readers who see this page will never be in.
    @ViewBuilder
    private var accountSection: some View {
        if session.backend == .localTesting {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                Rule()

                Button(role: .destructive) {
                    confirmingBetaReset = true
                } label: {
                    Text("Reset beta account")
                        .font(Theme.TypeScale.ui())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Palette.accent)

                Text("Clears your Dewey data on this device and starts over. There's no account service connected to this build yet, so nothing beyond this device is affected.")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .pageMargin()
            .padding(.top, Theme.Space.loose)
        }
    }
}

// MARK: - Published reviews

/// Every review a reader has actually put in front of other people, newest
/// first. Yours reads the diary directly — a review is "published" the
/// moment `hasPublishedReview` says so, which is the same visibility choice
/// the log sheet's "Who can see it" control already made, not a second gate.
/// Someone else's reads the seeded `allReviews`, the only record Dewey holds
/// of a stranger's writing.
///
/// One function so `ProfileView`'s preview and `AllReviewsView`'s full list
/// can never disagree about what counts.
private func publishedReviews(
    _ store: DeweyStore,
    for profile: ReaderProfile
) -> [(id: String, bookID: String, text: String, rating: Rating?)] {
    if profile.isMe {
        return store.diaryEntries
            .filter { $0.hasPublishedReview }
            .map { entry in
                (id: entry.id, bookID: entry.bookID, text: entry.review ?? "", rating: entry.rating)
            }
    }
    return store.allReviews
        .filter { $0.readerID == profile.id }
        .sorted { $0.date > $1.date }
        .map { review in
            (id: review.id, bookID: review.bookID, text: review.preview, rating: review.rating)
        }
}

/// **Where the preview on a profile leads once there is more than three.**
///
/// `ProfileView.reviewsSection` used to be the one taste collection on the
/// page with no way past its own cap — Favorite Books opens a picker, Lists
/// opens `ListsIndexView`, Ranking opens `RankedListView`, and Reviews just
/// stopped at three with nothing pointing further. A reader's fourth
/// published review was already real, already shared, and already
/// permanently invisible from the one page that argues their taste. This is
/// that page's missing "see everything" seam, built the same way the other
/// two are: a title, a count, and the full list — no new field, no new
/// privacy surface, just the existing published reviews in full.
struct AllReviewsView: View {
    var reader: ReaderProfile? = nil

    @Environment(DeweyStore.self) private var store

    private var profile: ReaderProfile { reader ?? store.me }
    private var isMe: Bool { profile.isMe }

    private var firstName: String {
        profile.name.split(separator: " ").first.map(String.init) ?? profile.name
    }

    private var reviews: [(id: String, bookID: String, text: String, rating: Rating?)] {
        publishedReviews(store, for: profile)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                Text(countLine)
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .pageMargin()

                VStack(spacing: Theme.Space.base) {
                    ForEach(reviews, id: \.id) { item in
                        reviewCard(item.bookID, item.text)
                    }
                }
                .pageMargin()
            }
            .padding(.top, Theme.Space.snug)
            .padding(.bottom, Theme.Space.vast)
        }
        .background(Theme.Palette.paper)
        .navigationTitle(Judgement.ReviewCopy.plural)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var countLine: String {
        let n = reviews.count
        let noun = n == 1 ? Judgement.ReviewCopy.title.lowercased() : Judgement.ReviewCopy.plural.lowercased()
        return isMe ? "\(n) \(noun) you've published." : "\(n) \(noun) from \(firstName)."
    }

    /// Full text, unlike the six-line preview on a profile — a reader who
    /// tapped through here came to read, not to be teased further.
    private func reviewCard(_ bookID: String, _ text: String) -> some View {
        let book: Book = store.book(bookID)
        return NavigationLink(value: book) {
            CardShell(kicker: book.title) {
                Text(text)
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared pieces

/// Section heading. Kicker on the left, an optional count on the right — the
/// count is a scale cue, never a score.
private struct SectionHead: View {
    let kicker: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(kicker).kickerStyle()
            Spacer(minLength: Theme.Space.snug)
            if let trailing {
                Text(trailing)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
            }
        }
        .pageMargin()
    }
}

/// The book row used by every list on these two screens. Cover, title,
/// subtitle, your rating, where it sits on your shelves — and, for a book
/// that sits nowhere yet, a one-tap way to start.
private struct BookRow: View {
    @Environment(DeweyStore.self) private var store
    let book: Book

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.base) {
            NavigationLink(value: book) {
                HStack(alignment: .center, spacing: Theme.Space.base) {
                    BookCoverView(book: book, width: 52, scalesWithType: true)
                    VStack(alignment: .leading, spacing: Theme.Space.tight) {
                        Text(book.title)
                            .font(Theme.TypeScale.cardTitle())
                            .foregroundStyle(Theme.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                        Text(book.subtitleLine)
                            .font(Theme.TypeScale.meta())
                            .foregroundStyle(Theme.Palette.inkFaint)
                            .lineLimit(2)
                        trailingMarks
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            // Only while the book has nowhere to sit yet. The moment it does,
            // `trailingMarks` above already carries the same badge every other
            // saved row shows, and a second control offering to do again what
            // is already done would be the row arguing with itself.
            if store.status(of: book.id) == nil {
                wantToReadButton
            }
        }
        .padding(.vertical, Theme.Space.snug + 2)
        .pageMargin()
    }

    /// **The one-tap save this row was missing.**
    ///
    /// Before this, the only way to act on a book met in Search was to open
    /// its page — and the page's own primary action sits several sections
    /// down, past the Dewey Score and, on a book with any community activity,
    /// past reviews too. For the lightest and most common intent a reader has
    /// here — "I want to remember this" — that is a real tax on the exact
    /// path this screen exists to end in: interesting book found, book now
    /// belongs somewhere.
    ///
    /// It sets exactly what the book page's own "Want to Read" button sets,
    /// through the same `DeweyStore.inferredProvenance(for:)` the page now
    /// shares with this row — so a book that turns out to have been sent by
    /// someone still remembers that correctly, even though the reader never
    /// opened its page to see the offer.
    ///
    /// A bookmark outline, not a labelled button: `ReadingStatus.wantToRead`
    /// already draws as this exact glyph everywhere else a status is marked,
    /// so the row asks for nothing a reader has not already learned to read.
    private var wantToReadButton: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(Theme.Motion.standard) {
                store.save(book.id, status: .wantToRead, provenance: store.inferredProvenance(for: book.id))
            }
        } label: {
            Image(systemName: "bookmark")
                .font(Theme.TypeScale.ui())
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ReadingStatus.wantToRead.title)
        .accessibilityHint("Adds \(book.title) to your reading list")
    }

    /// The rating stays and becomes a numeral. Search results and Browse are the
    /// definition of a comparison surface — the reader is running down a column
    /// of candidates — so the value earns its place here in a way it does not on
    /// an editor row or a single review.
    ///
    /// But the `.regular` mark could not deliver the value. Ten capsules 66pt
    /// wide, no numeral: 7.8 and 9.7 draw as the same dash, so the one object on
    /// this line that carried information was the one that could not be read.
    /// It also shared the line with a status capsule and a bookmark glyph —
    /// three shapes competing under a two-line subtitle beside a 52pt cover. The
    /// numeral says the number, in a quarter of the width, and lets the badge
    /// and the glyph be the only shapes on the row.
    @ViewBuilder
    private var trailingMarks: some View {
        let mine: Rating? = store.myRating(for: book.id)
        let status: ReadingStatus? = store.status(of: book.id)
        if mine != nil || status != nil {
            HStack(spacing: Theme.Space.snug) {
                if mine != nil {
                    RatingMark(rating: mine)
                }
                if let status {
                    StatusBadge(status: status)
                }
                if store.isFavorite(book.id) {
                    FavoriteMark(filled: true, size: 13)
                }
            }
            .padding(.top, Theme.Space.hair)
        }
    }
}

private struct StatusBadge: View {
    let status: ReadingStatus

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: status.symbol)
                .font(.caption2)
            Text(status.title)
                .font(Theme.TypeScale.kicker())
        }
        .foregroundStyle(Theme.Palette.inkSoft)
        .padding(.horizontal, Theme.Space.tight + 1)
        .padding(.vertical, 3)
        .overlay(Capsule().stroke(Theme.Palette.rule, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
}

/// The Follow / Following control (§12.9.1).
///
/// **Why `ChipStyle`, and not a new style.** Onboarding's suggestion rows
/// already draw this exact action with `ChipStyle(selected:)`, and its two
/// states map onto the two the style has: outlined-and-quiet for the offer,
/// filled-with-ink for the fact. A reader who followed three people on their
/// first evening should meet the same object on a profile a week later — a
/// fourth button style invented for the one action the app is built around
/// would say the two taps were different taps. `PrimaryButtonStyle` was the
/// alternative and is wrong twice over: it is full-width, which makes following
/// the loudest thing on someone else's page, and it is the one filled button,
/// which by its own rule appears once per screen — and this control appears
/// twice (see `ProfileView.body`).
///
/// **44×44.** `ChipStyle` pads a `.subheadline` label by `snug` top and bottom,
/// which lands at roughly 40pt at default Dynamic Type — under the minimum, and
/// only at default and smaller, since the label grows from there. The label
/// carries a `minHeight` so the *capsule itself* grows to 44 rather than a
/// transparent hit box floating over a smaller target, and the `contentShape`
/// backstops the unselected state, whose background is a stroke rather than a
/// fill. Four points wider than onboarding's chips, deliberately: the target
/// minimum is not negotiable and those are the ones out of line.
private struct FollowButton: View {
    @Environment(DeweyStore.self) private var store

    let reader: ReaderProfile
    /// Passed in rather than re-derived, so the name spoken here is the same one
    /// `ProfileView` prints in "You and Priya are furthest apart on …".
    let firstName: String

    private var isFollowing: Bool { store.isFollowing(reader.id) }

    /// The platform's minimum touch target. Not a `Theme.Space` token because it
    /// is not a spacing decision — it is a fixed accessibility floor that Dewey
    /// does not get to have an opinion about.
    private static let minimumTarget: CGFloat = 44

    /// What the label has to measure for the capsule around it to clear 44.
    ///
    /// Derived from `ChipStyle`'s own vertical padding rather than written down
    /// as 24, so that if that padding is ever retuned this follows it instead of
    /// silently going back under the minimum.
    private static var labelHeight: CGFloat { minimumTarget - 2 * Theme.Space.snug }

    var body: some View {
        Button {
            store.toggleFollow(reader.id)
        } label: {
            Text(FollowCopy.verb(isFollowing: isFollowing))
                .frame(minHeight: Self.labelHeight)
        }
        .buttonStyle(ChipStyle(selected: isFollowing))
        .contentShape(Rectangle())
        // Spoken as what it says, plus who it is about. The visible word is a
        // prefix of the label on purpose — Voice Control matches on the label,
        // so "tap Follow" has to reach a control that draws "Follow".
        .accessibilityLabel(FollowCopy.spokenLabel(firstName, isFollowing: isFollowing))
        .accessibilityValue(FollowCopy.state(isFollowing: isFollowing))
        .accessibilityHint(FollowCopy.hint(isFollowing: isFollowing))
    }
}

/// **No follow control on this row, and that is a decision** (§12.9.1).
///
/// It was the obvious place to put one — this is where you meet readers you do
/// not know, onboarding puts a chip on a row that looks almost exactly like
/// this, and one tap is cheaper than a push and a scroll. Three reasons it does
/// not go here anyway:
///
/// 1. **It would argue from the number.** All this row shows of a stranger is
///    `overlap.headline` — a count. §12.1 is explicit that the figures are the
///    doorway and the evidence is underneath: both ratings side by side, and
///    the book you disagree hardest about. A chip here lets a reader build the
///    follow graph — which *is* the product — off a tally in a list, without
///    ever seeing the argument. The profile is one tap away and has it.
/// 2. **The row is a `NavigationLink`.** A button nested inside one is a
///    coin-toss for the hit test at the boundary, and the link merges its
///    children into a single accessibility element, so the chip stops being
///    separately reachable — the same merge that quietly ate the author and the
///    rating out of a Favorite Books slot until `favoriteSlotSpoken` put them
///    back.
/// 3. **Reader rows are one column of three.** Books, readers and lists stack
///    in the same results list; an inline action on only one kind makes that
///    kind read as the actionable one.
///
/// Onboarding is the deliberate exception, not the precedent: it has no profiles
/// to push to yet, it has just computed a real reason per row ("Also read
/// Bluets"), and building the first follow set fast is that screen's whole job.
private struct ReaderRow: View {
    let reader: ReaderProfile
    let overlap: TasteOverlap

    var body: some View {
        NavigationLink(value: reader) {
            HStack(alignment: .top, spacing: Theme.Space.base) {
                ReaderAvatarView(reader: reader, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(reader.name)
                        .font(.system(.body, design: .serif, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                    Text(atHandle(reader.handle))
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                    Text(reader.texture)
                        .font(Theme.TypeScale.support())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Theme.Space.hair)
                    Text(overlap.headline)
                        .font(Theme.TypeScale.kicker())
                        .foregroundStyle(overlap.isMeaningful ? Theme.Palette.accent : Theme.Palette.inkFaint)
                        .padding(.top, Theme.Space.hair)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, Theme.Space.snug + 2)
            .pageMargin()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ListRow: View {
    let list: BookList
    let covers: [Book]

    var body: some View {
        NavigationLink(value: list) {
            HStack(alignment: .center, spacing: Theme.Space.base) {
                coverStack
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.title)
                        .font(.system(.body, design: .serif, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    Text(list.premise)
                        .font(Theme.TypeScale.support())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(list.subtitle)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .padding(.top, Theme.Space.hair)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, Theme.Space.snug + 2)
            .pageMargin()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var coverStack: some View {
        HStack(spacing: -14) {
            ForEach(Array(covers.enumerated()), id: \.offset) { pair in
                BookCoverView(book: pair.element, width: 30)
                    .zIndex(Double(covers.count - pair.offset))
            }
        }
        .frame(width: 30 + CGFloat(max(covers.count - 1, 0)) * 16, alignment: .leading)
    }
}

/// A rating numeral under a cover, in a slot that holds its line whether or not
/// there is a rating to draw.
///
/// Cover rails and grids align on the row *below* the cover, so an unrated book
/// has to occupy the height a rated one would or the covers step up and down.
/// That is why these slots have a fixed height — but the height they had was
/// 6pt, sized for the ten short rules that used to live here. The numeral that
/// replaced them is a `.caption`, well over twice that at default Dynamic Type
/// and unbounded at accessibility sizes, and SwiftUI does not clip: the glyph
/// drew straight through the gap below while every enclosing stack went on
/// reporting 6pt. Reserving the line with a hidden numeral in the same font
/// makes the slot track the type instead of a guess, which is the only version
/// that survives a reader turning text size up.
// MARK: - Choosing your four

/// **Where the four are actually chosen** (§14).
///
/// The whole reason this screen exists is that nothing else in Dewey is allowed
/// to choose them. Ratings do not, rankings do not, and the Favorite mark on the
/// log sheet does not — a reader who loves thirty books still has to sit here
/// and pick four, and being made to pick is the feature rather than a cost of
/// it.
///
/// Favorites are marked in this list but **never preselected**. Showing the mark
/// makes the books a reader loves findable among everything they have logged;
/// preselecting them would be the app filling the slots and calling it a choice.
private struct FavoriteBooksPicker: View {
    @Environment(DeweyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Edited locally and committed on Done, so backing out of the sheet leaves
    /// the profile exactly as it was. A picker that writes on every tap makes
    /// "cancel" a lie.
    @State private var selection: [String] = []
    @State private var didLoad = false

    private var cap: Int { Judgement.FavoriteBooksCopy.count }

    /// Everything the reader has logged or shelved, most recently touched first.
    /// Ordered by diary recency rather than alphabetically because the book you
    /// want is nearly always one you have thought about lately.
    private var candidates: [Book] {
        var seen = Set<String>()
        var out: [Book] = []
        for entry in store.diaryEntries where !seen.contains(entry.bookID) {
            seen.insert(entry.bookID)
            out.append(store.book(entry.bookID))
        }
        for entry in store.library where !seen.contains(entry.bookID) {
            seen.insert(entry.bookID)
            out.append(store.book(entry.bookID))
        }
        return out
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 92), spacing: Theme.Space.base, alignment: .topLeading)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.roomy) {
                    header

                    if candidates.isEmpty {
                        Text("Nothing to choose from yet. Log a book and it will show up here.")
                            .font(Theme.TypeScale.prose())
                            .foregroundStyle(Theme.Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Space.roomy) {
                            ForEach(candidates) { book in
                                candidateCell(book)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Theme.Space.base)
                .padding(.bottom, Theme.Space.vast)
                .pageMargin()
            }
            .background(Theme.Palette.paper.ignoresSafeArea())
            .navigationTitle(Judgement.FavoriteBooksCopy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.setFavoriteBooks(selection)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Once, so re-rendering the sheet does not discard edits in progress.
            guard !didLoad else { return }
            selection = store.favoriteBookIDs
            didLoad = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text(Judgement.FavoriteBooksCopy.question)
                .font(Theme.TypeScale.title())
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(Judgement.FavoriteBooksCopy.definition)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
            Text(remainingLine)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkSoft)
                .accessibilityLabel(remainingLine)
        }
    }

    /// States the cap before a reader hits it. A picker that goes silent on the
    /// fifth tap has already failed to explain itself.
    private var remainingLine: String {
        selection.count == cap
            ? "All \(cap) chosen. Take one out to swap it."
            : "\(selection.count) of \(cap) chosen."
    }

    private func candidateCell(_ book: Book) -> some View {
        let index = selection.firstIndex(of: book.id)
        let isChosen = index != nil
        let isFull = selection.count >= cap
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(Theme.Motion.standard) {
                if let index {
                    selection.remove(at: index)
                } else if !isFull {
                    selection.append(book.id)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                BookCoverView(book: book, width: 88)
                    .overlay(alignment: .topTrailing) {
                        if isChosen {
                            // The position, not a tick — the order a reader
                            // picks them in is the order the profile shows them,
                            // and this is the only place that is visible.
                            Text("\((index ?? 0) + 1)")
                                .font(Theme.TypeScale.metaNumeral())
                                .foregroundStyle(Theme.Palette.paper)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Theme.Palette.accent))
                                .padding(4)
                        }
                    }
                    .opacity(isChosen || !isFull ? 1 : 0.4)
                HStack(spacing: 4) {
                    Text(book.title)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if store.isFavorite(book.id) {
                        FavoriteMark(filled: true, size: 11)
                    }
                }
            }
            .frame(width: 88, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(!isChosen && isFull)
        .accessibilityLabel(book.title)
        .accessibilityValue(isChosen
            ? "Chosen, number \((index ?? 0) + 1) of \(cap)"
            : (isFull ? "Not chosen. All \(cap) slots are full." : "Not chosen"))
        .accessibilityHint(isChosen ? "Removes it from your Favorite Books"
                                    : "Adds it to your Favorite Books")
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
    }
}

private struct CoverRatingSlot: View {
    let rating: Rating?

    var body: some View {
        ZStack(alignment: .leading) {
            Text(verbatim: "0")
                .font(Theme.TypeScale.metaNumeral())
                .hidden()
            RatingMark(rating: rating)
        }
    }
}

/// Horizontal cover rail with a rating under each spine.
///
/// Used where the strip is answering "what did they make of these" — Read, and
/// the chosen four. It is *not* used for shelves and reading lists,
/// which are sold by their title and premise; callers there pass no rating and
/// the slot stays empty, which keeps the rails the same height.
private struct CoverStrip: View {
    let books: [Book]
    var width: CGFloat = 76
    var rating: (Book) -> Rating?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Theme.Space.snug) {
                ForEach(books) { book in
                    NavigationLink(value: book) {
                        VStack(alignment: .leading, spacing: Theme.Space.tight) {
                            BookCoverView(book: book, width: width)
                            CoverRatingSlot(rating: rating(book))
                        }
                        .frame(width: width, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .pageMargin()
        }
    }
}
