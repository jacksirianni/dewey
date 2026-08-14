import SwiftUI

/// Four places, because Dewey turned out to be four products held together by
/// one idea.
///
/// The earlier two-tab shell (an edition and a library) was honest about the
/// size of the seeded world but dishonest about the shape of the product. Search
/// is not a lesser version of the edition — it is the only way to reach a book
/// nobody has handed you yet, and burying it inside a feed made the app feel
/// like it only knew about thirty-one books. The profile is not settings; it is
/// the argument you are making about yourself, and an argument needs an address.
///
/// What still isn't here: badges, unread counts, anything numeric on a tab. The
/// edition ends and the library waits. Neither of them should be able to nag.
struct RootView: View {
    @Environment(DeweyStore.self) private var store
    @Environment(SessionStore.self) private var session

    // TEMPORARY — prototype controls, reachable from the Library toolbar.
    #if DEBUG
    @State private var showingDebug = false
    #endif

    /// **The four tabs, or the cold start — never both** (§17).
    ///
    /// This used to be a `fullScreenCover` over the tabs, driven by a single
    /// local boolean mirroring `store.needsOnboarding`. With accounts there is
    /// nothing behind the cover worth presenting *over*: a signed-out reader has
    /// no library, no edition and no profile, and building the tab hierarchy
    /// underneath meant every one of those screens ran its `onAppear` against a
    /// store with no identity in it. Swapping the whole subtree is also what
    /// removes the presentation animation on a cold launch — a returning reader
    /// goes from the restoring screen straight to their edition, with no sheet
    /// sliding away in between.
    ///
    /// `SessionStore.phase` is the only input. There is no local mirror of it,
    /// which is the bug the old `.constant(store.needsOnboarding)` binding had in
    /// a different shape: two sources of truth for one question, and no way for
    /// the cover to close itself.
    var body: some View {
        Group {
            if session.phase.isReady {
                tabs
            } else {
                FirstRunFlow()
            }
        }
        // Runs once, before anything is drawn. `SessionStore` opens on
        // `.restoring` precisely so this has somewhere to happen.
        .task { await session.restore() }
        // The store is handed the account rather than fetching it — see
        // `DeweyStore.adoptIdentity`. Keyed on the phase so it also fires when a
        // reader signs out, which clears the identity and returns `store.me` to
        // the seeded placeholder.
        .task(id: session.phase) { await adoptAccount() }
    }

    /// Pushes the account into the store, and on the first launch of a
    /// reinstall pulls back what the server holds.
    private func adoptAccount() async {
        // Wired here rather than in `DeweyApp` because both objects are already
        // in hand and the direction stays visible: an edit is saved locally
        // first, then told to the server. `SessionStore` ignores these until the
        // phase is `.ready`.
        store.onFavoriteBooksChanged = { [session] in session.pushFavoriteBooks($0) }
        store.onFollowsChanged = { [session] in session.pushSeedFollows(Array($0)) }

        // **The reading data is swapped before the identity is** (§18). Local
        // state is keyed by account: activating loads this reader's file and
        // deactivating empties the store, so no diary, library or rating can
        // survive across a change of account. Doing it in the other order would
        // leave a frame where the previous reader's shelves are on screen under
        // the new reader's name.
        switch session.phase {
        case .restoring, .unconfigured:
            break                                   // Nothing decided yet.
        case .signedOut:
            store.deactivate()
        case .needsIdentity(let userID, _):
            store.activate(userID)
        case .needsTasteOnboarding(let profile), .ready(let profile):
            store.activate(profile.userID)
        }

        store.adoptIdentity(session.phase.profile)

        guard session.phase.isReady, let remote = await session.remoteState() else { return }
        store.applyAccountState(
            favoriteBooks: remote.favoriteBooks,
            seedFollows: remote.seedFollows
        )
    }

    private var tabs: some View {
        TabView {
            editionTab
            searchTab
            libraryTab
            profileTab
        }
        .background(Theme.Palette.paper)
        // **The floating tab bar needs a backdrop** (§13.6).
        //
        // Left to its default it is translucent over whatever is beneath it,
        // and the Search tab is a grid of full-bleed, fully saturated covers —
        // so "Edition" sat over a purple spine, "Search" over a red one and
        // "You" over a green one, and the labels stopped being readable
        // exactly on the screen with the most colour in it. A material gives
        // the bar its own surface in both light and dark without making it
        // opaque.
        .toolbarBackground(.regularMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        // Same problem one edge up: content scrolled under the navigation title
        // with nothing behind it, so a book title or the word "Dewey" sat on
        // top of whatever paragraph happened to be passing underneath. On
        // nearly every screen in the walkthrough there was illegible text
        // mashed behind the title.
        //
        // **The material was declared and never made visible**, which is why
        // that was still happening. `.toolbarBackground(_:for:)` sets *what* the
        // bar draws; `.toolbarBackground(.visible, for:)` sets *whether* it
        // draws at all, and without the second one the decision falls back to
        // the scroll-edge heuristic — which reports "at the top, draw nothing"
        // for a `ScrollView` far more readily than for a `List`, and every tab
        // here is a `ScrollView`. The tab bar below got both lines and was
        // legible; the navigation bar got one and was not.
        .toolbarBackground(.regularMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        // Closure is app-wide: it can land while you are anywhere, and it is
        // never a screen you have to navigate to. The banner owns its own top
        // inset so it clears the navigation bar rather than covering the back
        // button — an arriving gift must never trap you on a screen.
        .overlay(alignment: .top) { closureOverlay }
    }

    // MARK: - Tabs

    private var editionTab: some View {
        NavigationStack {
            WeeklyEditionView()
                .deweyDestinations()
        }
        .tabItem { Label("Edition", systemImage: "newspaper") }
    }

    private var searchTab: some View {
        NavigationStack {
            SearchView()
                .deweyDestinations()
        }
        .tabItem { Label("Search", systemImage: "magnifyingglass") }
    }

    private var libraryTab: some View {
        NavigationStack {
            LibraryView()
                .deweyDestinations()
                #if DEBUG
                .debugMenu(isPresented: $showingDebug)
                #endif
        }
        .tabItem { Label("Library", systemImage: "books.vertical") }
    }

    private var profileTab: some View {
        NavigationStack {
            ProfileView()
                .deweyDestinations()
        }
        .tabItem { Label("You", systemImage: "person") }
    }

    // MARK: - Closure

    @ViewBuilder
    private var closureOverlay: some View {
        if let closure = store.pendingClosure {
            ClosureBanner(recommendation: closure)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
        }
    }
}

// MARK: - Routing

/// One place where routing is declared, so every stack in the app can push the
/// same things without repeating itself. Values, not screens: a card in the
/// edition and a row in a shelf both push `Book`, and neither knows what a book
/// page looks like.
extension View {
    func deweyDestinations() -> some View {
        self
            .navigationDestination(for: Book.self) { BookDetailView(book: $0) }
            .navigationDestination(for: ReaderProfile.self) { ProfileView(reader: $0) }
            .navigationDestination(for: BookList.self) { ListDetailView(list: $0) }
            // No destination for a ranking. There is exactly one per reader
            // (§19), so it is reached as a destination closure from the profile
            // that owns it rather than as a value that has to carry which one
            // it is.
    }
}

// MARK: - Library

/// Everything that is yours, in two readings of the word.
///
/// **Books** is state — where each book sits right now, filtered by
/// `ReadingStatus`. **Diary** is history — dated acts of reading. They are the
/// same books seen from different angles, so they belong behind one control
/// rather than in two tabs; splitting them would imply they were different
/// collections.
///
/// **This mode used to be called "Shelves"** and filtered by a coarser
/// `ReadingStatus.Shelf` grouping, in which Paused and Did Not Finish collapsed
/// into a bucket named "Set Down" — a phrase that appeared nowhere else in the
/// app. A reader who marked a book Paused came here looking for Paused and
/// found no such filter. Worse, "Shelves" here meant *reading status* while
/// "Bookshelves" on the profile meant *curated lists*: one word, two meanings,
/// one tab apart (§13.3). The filter is now the five real statuses, and the
/// word "shelf" is gone from the reader's vocabulary entirely.
///
/// The library row is where Dewey's one irreplaceable detail lives: the
/// provenance line sits *above the author*, which is a deliberate inversion. Six
/// months after saving something, "Priya recommended it" is the fact that gets
/// you to open the book. The author is the second-most interesting thing on the
/// line.
struct LibraryView: View {
    @Environment(DeweyStore.self) private var store

    @State private var mode: Mode = .books

    /// Nil until first paint, then the reader's choice for the rest of the
    /// session.
    ///
    /// The default used to be a hardcoded `.reading`, which in the seeded corpus
    /// is exactly one book above an empty screen — the tab's first impression
    /// was a near-empty page (§13.6). It now opens on whatever best represents
    /// the reader's current reading life — `Reading` first, then `Want to
    /// Read` — a property of the reader's library rather than of the code, and
    /// one that holds equally well for a fresh account. See
    /// `DeweyStore.busiestStatus` for why this is no longer a raw book count.
    ///
    /// **Resolved once, on appear, rather than on every render** — see
    /// `resolveDefaultStatus`.
    @State private var status: ReadingStatus?

    private var selectedStatus: ReadingStatus { status ?? store.busiestStatus }

    /// Pins the default the first time the tab is drawn.
    ///
    /// `selectedStatus` falls back to `store.busiestStatus`, which is computed
    /// from the library *as it currently stands*. While `status` stayed nil —
    /// which it does until the reader taps a chip, i.e. for the whole of a
    /// normal first session — that fallback was re-evaluated on every render,
    /// so the selected filter was not a selection at all. It was a live query.
    ///
    /// The reader saw the filter move on its own. Save two books, both land in
    /// Want to Read, Library opens there; mark one Reading and come back, and
    /// the highlighted chip has jumped to Reading with the other book gone from
    /// the page. Nothing was tapped. It is at its worst in exactly the state a
    /// new reader is in, because that is when the counts are small enough for
    /// one log to change which status is busiest.
    ///
    /// Resolving on appear keeps the good half of the idea — the tab still
    /// opens on whatever status best represents the reader's current reading
    /// life rather than a hardcoded one — and makes it a default instead of a
    /// rule. Only nil is filled, so a reader's own tap is never overwritten,
    /// including when they come back to the tab.
    private func resolveDefaultStatus() {
        guard status == nil else { return }
        status = store.busiestStatus
    }

    /// The book a Moment is being captured for, from a tap on `rows`' quiet
    /// action. Not `Bool` + a separately-tracked entry: `.sheet(item:)` wants
    /// one optional, and a book is all `MomentCaptureSheet` needs.
    @State private var capturingBook: Book?

    private enum Mode: String, CaseIterable, Identifiable {
        case books, diary

        var id: String { rawValue }

        var title: String {
            switch self {
            case .books: "Books"
            case .diary: "Diary"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            modePicker
            Rule()
            content
        }
        .background(Theme.Palette.paper)
        .onAppear(perform: resolveDefaultStatus)
        // "Library", not "Your library" — the tab directly beneath says
        // "Library", and a screen that disagrees with its own tab about its name
        // is the smallest possible version of the vocabulary problem this pass
        // exists to fix. Read from `Vocabulary` so the two cannot part again.
        .deweyNavigationTitle(Vocabulary.library)
        // The same sheet `BookDetailView` opens for "Capture a Moment" — see
        // `captureMomentAction`. No second composer for the same act.
        .sheet(item: $capturingBook) { MomentCaptureSheet(book: $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .books: books
        case .diary: DiaryView()
        }
    }

    // MARK: - Mode

    /// Underlined serif labels rather than a segmented control. A system
    /// segmented control reads as a settings affordance; this reads as a section
    /// head on a page, which is what it is.
    private var modePicker: some View {
        HStack(spacing: Theme.Space.roomy) {
            ForEach(Mode.allCases) { option in
                modeButton(option)
            }
            Spacer(minLength: 0)
        }
        .pageMargin()
        .padding(.top, Theme.Space.tight)
    }

    private func modeButton(_ option: Mode) -> some View {
        let isCurrent: Bool = (option == mode)
        return Button {
            guard !isCurrent else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(Theme.Motion.standard) { mode = option }
        } label: {
            VStack(spacing: Theme.Space.tight) {
                Text(option.title)
                    .font(.system(.subheadline, design: .serif, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Theme.Palette.ink : Theme.Palette.inkSoft)
                Capsule()
                    .fill(Theme.Palette.ink)
                    .frame(height: 2)
                    .opacity(isCurrent ? 1 : 0)
            }
            // The Library's primary navigation, at roughly 40x28pt of glyph
            // before this — the whole tab hangs off these two words and neither
            // reached the 44pt floor.
            //
            // Vertical padding only. Horizontal padding here widens the VStack,
            // and the underline capsule is *inside* it, so the rule stopped
            // hugging its word and overhung it by a few points on each side —
            // which reads as a misaligned underline rather than a bigger button.
            // Height is what was short anyway; "Books" and "Diary" are already
            // wide enough at this type size.
            .padding(.top, Theme.Space.snug)
            .frame(minHeight: 44, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Books

    private var entries: [LibraryEntry] {
        store.entries(withStatus: selectedStatus)
    }

    /// **A library with nothing in it gets a sentence, not a filter bar.**
    ///
    /// The chips rendered unconditionally, so a reader who had saved nothing met
    /// five working controls over an empty page — five ways to slice nought
    /// books — under a line telling them the *current* filter was empty, which
    /// implies the others might not be. Filters are for narrowing something
    /// down; there is nothing to narrow, and offering them makes the tab read as
    /// a broken query rather than a library waiting to be started.
    private var books: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if store.library.isEmpty {
                    emptyLibrary
                } else {
                    statusChips
                    if entries.isEmpty {
                        emptyStatus
                    } else {
                        rows
                    }
                }
            }
            .padding(.bottom, Theme.Space.vast)
        }
        .scrollIndicators(.hidden)
        .background(Theme.Palette.paper)
    }

    /// Nothing saved at all — distinct from a filter that happens to be empty.
    ///
    /// Points at the two places books actually come from, because the honest
    /// answer to "why is this empty" is "you have not saved anything yet" and
    /// the useful half is where to go. It does not contradict the Diary's empty
    /// state one tap away: that one is about writing, this one is about saving.
    private var emptyLibrary: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            // "Nothing in your library" — not "on your shelves". `Vocabulary`
            // retired that word and this empty state, written in this same pass,
            // reached straight back for it.
            Text("Nothing in your \(Vocabulary.library.lowercased()) yet")
                .font(Theme.TypeScale.title())
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Save a book from your edition, or find one in Search. Whatever you keep remembers who it came from.")
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
        .padding(.top, Theme.Space.loose)
    }

    /// The status filter. It wraps; it does not scroll sideways.
    ///
    /// A horizontal scroller sliced its longest label mid-word at the right
    /// margin on first paint (§12.9). Being scrollable did not rescue it: a cut
    /// word reads as a broken row, and the reader has to already suspect the row
    /// scrolls before the cut means anything. Wrapping states the whole set at
    /// once — and nothing here depends on a name's length, so "Did Not Finish",
    /// a translation, or a large text size moves the wrap point instead of
    /// cutting a word.
    ///
    /// Five chips now rather than four, because Paused and Did Not Finish are no
    /// longer merged. That is one more line of wrap on a narrow phone and it is
    /// the correct trade: a reader can now find a book under the name they filed
    /// it with.
    private var statusChips: some View {
        FlowLayout(spacing: Theme.Space.snug, lineSpacing: Theme.Space.tight) {
            ForEach(ReadingStatus.allCases) { option in
                statusChip(option)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
        .padding(.vertical, Theme.Space.base)
    }

    private func statusChip(_ option: ReadingStatus) -> some View {
        let isCurrent: Bool = (option == selectedStatus)
        return Button(option.title) {
            guard !isCurrent else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(Theme.Motion.standard) { status = option }
        }
        .buttonStyle(ChipStyle(selected: isCurrent))
        // Only bites when a label has to wrap inside its capsule — a long name
        // or a large text size. Ragged-right inside a symmetrical capsule looks
        // like a mistake; centred looks like a chip.
        .multilineTextAlignment(.center)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    private var rows: some View {
        ForEach(entries) { entry in
            VStack(alignment: .leading, spacing: 0) {
                NavigationLink(value: store.book(entry.bookID)) {
                    LibraryRow(entry: entry)
                }
                .buttonStyle(.plain)
                if entry.status == .reading {
                    captureMomentAction(for: entry)
                }
                Rule().pageMargin()
            }
        }
    }

    /// The one active-reading action the Library offers, and the only reason
    /// a Reading row looks different from any other. It is a sibling of the
    /// `NavigationLink` above, not nested inside its label — a `Button` inside
    /// a `NavigationLink`'s label has no reliable tap target of its own
    /// outside a `List`'s row-selection handling, and this screen is a plain
    /// `ScrollView`. Keeping it a separate row is also what keeps the tap-
    /// through to Book Detail untouched: `LibraryRow` stays exactly what it
    /// was, a book row, and this is bolted on beside it rather than into it.
    ///
    /// Gated to `.reading` for the same reason `BookDetailView.captureMomentRow`
    /// is: Dewey does not do the reading, so the one thing worth surfacing
    /// here, mid-book, is a fast way back to the sheet that catches a line
    /// before it's gone — not a generic "Continue", which would promise an
    /// in-app continuation this row cannot give.
    private func captureMomentAction(for entry: LibraryEntry) -> some View {
        Button {
            capturingBook = store.book(entry.bookID)
        } label: {
            Label("Capture a Moment", systemImage: "quote.opening")
                .font(Theme.TypeScale.meta())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.Palette.accent)
        .pageMargin()
        .padding(.bottom, Theme.Space.base)
        .accessibilityHint("Opens a quick note for a line or thought from this book")
    }

    /// Empty is a sentence, not a graphic. Each status says something slightly
    /// different because "nothing here" means something different on each one —
    /// an empty Paused filter is permission, not a failure state.
    private var emptyStatus: some View {
        Text(selectedStatus.emptyLine)
            .font(Theme.TypeScale.prose())
            .foregroundStyle(Theme.Palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pageMargin()
            .padding(.top, Theme.Space.loose)
    }
}

// MARK: - Library row

/// One book, as it sits in your library.
///
/// Order on the line is the argument: title, then who put it there (when
/// somebody genuinely did), then who wrote it. The rating is a score circle
/// at the trailing edge (§12.5.6), not an inline mark: a shelf you can't scan
/// for "what did I think of this" is a list of homework, and only a fixed
/// column answers that in one pass — set inline under titles of every length,
/// the same numbers never line up.
///
/// **The attribution line only appears for a genuine person-originated
/// save.** It used to print "You found this yourself" for every self-found
/// book — which is most of them — occupying the row's one signature slot
/// with a sentence that says nothing. A self-found book now gives that space
/// straight back to the title/author hierarchy.
///
/// `entry.savedAt` is deliberately absent (§12.7). The wireframe put "Added on
/// 19 May 2017" on the main line. It is real information, but it is not what
/// makes someone open a book six months later, and it would be competing with
/// the line that is. It belongs on the book's detail view.
private struct LibraryRow: View {
    let entry: LibraryEntry

    @Environment(DeweyStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize

    private var book: Book { store.book(entry.bookID) }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.base) {
            // `scalesWithType` because this cover sits beside prose — see
            // `BookCoverView` for why rails and grids do not get it.
            BookCoverView(book: book, width: 58, scalesWithType: true)
            // Details take the slack rather than a Spacer, so the score sits on
            // the margin and every row's numeral lands at the same x. A Spacer
            // between them would also be charged the stack's spacing twice,
            // costing the title 16pt it doesn't have on a small phone.
            details
                .frame(maxWidth: .infinity, alignment: .leading)
            // **The trailing column is dropped at accessibility sizes**, and the
            // rating moves inside `details` as its own line.
            //
            // The fixed column is the right answer at every size where a column
            // can exist, and at AX2 one cannot: the cover and the score together
            // left the middle column about 150 points wide, so "From Tobias
            // Nkemelu's review" — the signature line this row is built
            // around — broke across five lines, one or two words each, and a
            // single book filled more than a screen. Alignment is worth having
            // only while there is a measure left to align things in.
            if !typeSize.isAccessibilitySize {
                score
            }
        }
        .pageMargin()
        .padding(.vertical, Theme.Space.base)
        .contentShape(Rectangle())
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(book.title)
                .font(Theme.TypeScale.cardTitle())
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            // The signature detail, when there is one. Above the author,
            // and present only for a genuine person-originated save.
            if let provenanceText {
                ProvenanceLine(text: provenanceText, reader: provenanceReader)
            }

            Text(book.author)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)

            // The rating, where the trailing column has been given up. Labelled,
            // because out of the column it has nothing to identify it — a loose
            // "9.3" under an author reads as a page count.
            if typeSize.isAccessibilitySize, let rating {
                HStack(spacing: Theme.Space.tight) {
                    Text(Judgement.ScoreCopy.title)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                    RatingMark(rating: rating)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Judgement.ScoreCopy.title), \(rating.spoken)")
            }

            marks

            if let note = entry.note, !note.isEmpty {
                noteLine(note)
            }
        }
    }

    // MARK: - Score

    /// Your own rating, in a fixed trailing column.
    ///
    /// **It was a `ScoreCircle`, and that was the app's one live contradiction
    /// about rating visuals.** The circle is the crowd's verdict everywhere else
    /// in Dewey — it is the Dewey Score, and it appears in exactly one other
    /// place, at the top of a book page, above "4,182 readers rated it". Drawing
    /// your own opinion in it here meant the Library was the single surface where
    /// the same object meant the opposite thing, and it meant your rating was
    /// rendered one way in this list and another way in every other list in the
    /// app — search results, browse, a list's rows, the diary, a profile rail.
    ///
    /// The column survives, because the column was the good part of §12.5.6: a
    /// library you cannot scan for "what did I think of this" is a list of
    /// homework, and only a fixed column answers that in one pass. A right-
    /// aligned numeral of fixed width does that as well as a ring did, and it is
    /// the same figure the rest of the app draws.
    ///
    /// Unrated shows nothing — not a zero, not a dash, not an empty frame. A gap
    /// in the column reads as "no opinion recorded"; anything drawn there reads
    /// as an opinion, and the whole point of the number is that it is one. The
    /// `Unrated` case that *would* draw a dash exists for stacked pairs, where a
    /// missing figure strands its label; here the row's own "Unrated" word does
    /// that job, in words, for everybody.
    ///
    /// The spoken label says whose it is, because VoiceOver has no column to
    /// look at.
    @ViewBuilder
    private var score: some View {
        if let rating {
            // Drawn through `RatingMark`, not hand-set here. The type this used
            // to specify locally was the only place in the app a personal score
            // was written in a font a view file chose — which is how one value
            // ends up with two typographic treatments.
            RatingMark(rating: rating, prominence: .column)
                .lineLimit(1)
                .frame(minWidth: scoreColumn, alignment: .trailing)
                .accessibilityLabel("\(Judgement.ScoreCopy.title), \(rating.spoken)")
        }
    }

    /// Wide enough for "10", and it grows with the type rather than pinning the
    /// column at a size that clips the moment a reader turns text up.
    @ScaledMetric(relativeTo: .title3) private var scoreColumn: CGFloat = 30

    // MARK: - Marks

    private var rating: Rating? { store.myRating(for: entry.bookID) }
    private var isFavorite: Bool { store.isFavorite(entry.bookID) }

    /// Shown when a finished book carries no rating. Not a nag — a blank on a
    /// finished shelf is information, and leaving it invisible makes the shelf
    /// look like it has an opinion it doesn't have. The empty score slot says
    /// the same thing, but only to a reader who has already noticed the column;
    /// the word says it to everyone, which is why both stay.
    private var showsUnrated: Bool {
        rating == nil && entry.status == .finished
    }

    /// The rating is no longer among these. What is left is categorical rather
    /// than numeric — the things a numeral could not have said.
    ///
    /// The status itself is no longer among them either. Paused and Did Not
    /// Finish used to share one filter, so each row had to name which of the two
    /// it was; now that the filter *is* the status, repeating it on every row
    /// under a chip that already says it would be the book page's four-times
    /// problem in miniature (§13.2).
    private var hasMarks: Bool {
        isFavorite || showsUnrated
    }

    @ViewBuilder
    private var marks: some View {
        if hasMarks {
            HStack(spacing: Theme.Space.snug) {
                if isFavorite {
                    FavoriteMark(filled: true, size: 15)
                }
                if showsUnrated {
                    Text("Not scored").kickerStyle()
                }
            }
            .padding(.top, Theme.Space.hair)
        }
    }

    /// The private note. Serif, because you wrote it, and set behind a hairline
    /// so it reads as marginalia rather than metadata.
    private func noteLine(_ note: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.snug) {
            Rectangle()
                .fill(Theme.Palette.rule)
                .frame(width: 2)
                .accessibilityHidden(true)
            Text(note)
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, Theme.Space.hair)
    }

    // MARK: - Provenance

    private var provenanceReader: ReaderProfile? {
        store.reader(entry.provenance.readerID)
    }

    /// `nil` for a self-found or outside-Dewey save — see `DeweyStore.personAttributionText`.
    private var provenanceText: String? {
        store.personAttributionText(for: entry.provenance)
    }
}
