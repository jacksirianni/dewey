import SwiftUI

/// The cold start (§13.7).
///
/// The prototype had only ever booted into the seeded world — fourteen ranked
/// books, sixty-one followers, a populated diary — which is the right world for
/// showing what Dewey *is* and the wrong one for answering the question the app
/// could not otherwise answer: what a stranger sees on the first launch, when
/// "readers you follow" is nobody and the Edition has nothing to draw on. For a
/// product whose entire premise is other people's taste, that is the screen that
/// decides whether anyone reaches the second one.
///
/// **Nothing here is fabricated.** No starter follower count, no sample diary,
/// no invented activity. Every number this flow produces is one the reader just
/// created, and every suggested reader is suggested for a reason computed from
/// the books they actually picked — `DeweyStore.overlap(with:)`, the same
/// function the profile uses. If the overlap is one book, it says one book.
///
/// The welcome screen shows Dewey's own catalogue and one named reader's shelf,
/// which is not an exception to that rule but the shape of it: the promise is
/// that the flow never invents *your* library, and showing somebody else's,
/// attributed to them, is the opposite of inventing yours.
///
/// Four steps, each skippable, in the order that makes the next one possible:
/// books → ratings → Favorite Books → people. The last step is where Dewey stops
/// looking like every other reading app, so the flow is arranged to reach it
/// with something real to say.
///
/// **These four steps are unchanged by account creation** (§17). What changed is
/// what comes before them: a first launch now runs welcome → sign in → name and
/// handle, and only then arrives here, at `.pick`. `FirstRunFlow` owns that
/// sequence and constructs this view with `startingAt: .pick`; the `.welcome`
/// step it skips is the same `WelcomeView` the flow drew as its own first screen.
/// Constructed without an argument — which is what the debug menu does when it
/// re-runs onboarding on its own — all six steps still run in their original
/// order.
struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(DeweyStore.self) private var store

    @State private var step: Step
    @State private var picked: Set<String> = []
    @State private var ratings: [String: Rating] = [:]
    @State private var favorite: Set<String> = []

    init(startingAt: Step = .welcome, onFinish: @escaping () -> Void) {
        _step = State(initialValue: startingAt)
        self.onFinish = onFinish
    }

    /// Internal rather than private so `FirstRunFlow` can name `.pick`. Nothing
    /// outside this file advances it.
    enum Step: Int, CaseIterable {
        case welcome, pick, rate, favorite, people, done
    }

    /// Four, matching the display constraint on every profile.
    private static let favoriteCap = 4

    /// Enough to compute a believable overlap, few enough to be one screen of
    /// tapping. Below three, every suggested reader shares one book and the
    /// reasons all read alike.
    private static let minimumPicks = 3

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.roomy) {
                    stepBody
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // The welcome step opens on a full-bleed band of covers, which
                // wants to sit up against the navigation bar rather than a
                // finger's width below it — the gap reads as the screen not
                // having started yet. Every other step opens on a text head,
                // which does want the air.
                .padding(.top, step == .welcome ? Theme.Space.snug : Theme.Space.loose)
                .padding(.bottom, Theme.Space.vast)
                .pageMargin()
            }
            .background(Theme.Palette.paper)
            // **The action is pinned** rather than sitting under the content.
            // The book grid is the whole catalogue, so on the picking steps the
            // button was roughly two thousand points below the fold: a reader
            // who had chosen four books had no way to know they were finished
            // short of scrolling past thirty-seven more covers.
            .safeAreaInset(edge: .bottom) { footer }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step != .done {
                        Button("Skip") { finish() }
                            .font(Theme.TypeScale.ui())
                            .foregroundStyle(Theme.Palette.inkSoft)
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case .welcome: WelcomeView()
        case .pick: pickStep
        case .rate: rateStep
        case .favorite: favoriteBooksStep
        case .people: peopleStep
        case .done: doneStep
        }
    }

    // MARK: - Footer

    /// One pinned action per step, over a material so the grid scrolling
    /// underneath stays legible against it.
    private var footer: some View {
        VStack(spacing: 0) {
            Rule()
            Button(footerTitle) { footerAction() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(footerDisabled)
                .pageMargin()
                .padding(.vertical, Theme.Space.base)
        }
        .background(.regularMaterial)
    }

    private var footerTitle: String {
        switch step {
        case .welcome: "Get started."
        case .pick:
            picked.count < Self.minimumPicks
                ? "Pick \(Self.minimumPicks - picked.count) more"
                : "Next"
        case .rate: "Next"
        case .favorite: favorite.isEmpty ? "Skip this" : "Next"
        case .people: "Finish"
        case .done: "Open Dewey"
        }
    }

    private var footerDisabled: Bool {
        step == .pick && picked.count < Self.minimumPicks
    }

    private func footerAction() {
        switch step {
        case .welcome: advance(to: .pick)
        case .pick: advance(to: .rate)
        case .rate: advance(to: .favorite)
        case .favorite: advance(to: .people)
        case .people: commitAndFinish()
        case .done: finish()
        }
    }

    // MARK: - Chrome

    private func head(_ kicker: String, _ title: String, _ blurb: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text(kicker).kickerStyle()
            Text(title)
                .font(Theme.TypeScale.title())
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(blurb)
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func advance(to next: Step) {
        withAnimation(Theme.Motion.standard) { step = next }
    }

    // MARK: - 2. Books you know

    /// Deliberately the whole catalogue rather than a curated "popular" set. A
    /// starter grid that pre-decides what a new reader likes is how a taste
    /// product acquires a house style on day one.
    private var pickStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            head(
                "One of four",
                "Pick a few you've read.",
                "Anything you have an opinion about. Three or four is plenty to start."
            )

            bookGrid(selection: picked) { id in
                if picked.contains(id) {
                    picked.remove(id)
                    ratings[id] = nil
                    favorite.remove(id)
                } else {
                    picked.insert(id)
                }
            }

        }
    }

    // MARK: - 3. Ratings

    private var rateStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            head(
                "Two of four",
                "What did you think?",
                Judgement.ScoreCopy.onboardingExplainer
            )

            VStack(spacing: 0) {
                ForEach(pickedBooks) { book in
                    ratingRow(book)
                    Rule()
                }
            }

        }
    }

    private func ratingRow(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack(alignment: .top, spacing: Theme.Space.base) {
                BookCoverView(book: book, width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(Theme.TypeScale.cardTitle())
                        .foregroundStyle(Theme.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(book.author)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkSoft)
                }
                Spacer(minLength: 0)
                if let rating = ratings[book.id] {
                    Text(rating.compact)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                        .accessibilityHidden(true)
                }
            }

            RatingSlider(rating: Binding(
                get: { ratings[book.id] },
                set: { ratings[book.id] = $0 }
            ))
        }
        .padding(.vertical, Theme.Space.base)
    }

    // MARK: - 4. Favorite Books

    /// **This step chooses the profile four, not the Favorite mark** (§14).
    /// The two are separate concepts and this is the one with a number attached:
    /// the cap is enforced here rather than explained away, because the
    /// constraint is the feature — four forces a real choice and reads as
    /// identity. Marking books Favorite is unlimited and belongs to the log
    /// sheet, where a reader meets it one book at a time.
    private var favoriteBooksStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            head(
                "Three of four",
                Judgement.FavoriteBooksCopy.title,
                Judgement.FavoriteBooksCopy.question
            )

            // "not the ones you rated highest" → "scored". The verb, not the
            // term: interpolating `ScoreCopy.title` here produced "the ones you
            // gave the highest Your Score", which is what mechanically swapping
            // a possessive noun into a verb phrase gets you. The concept is
            // named on the previous step, where the reader is actually setting
            // one; here it only has to be the same word.
            Text("Four, and they go on your profile. Not the best books you've read, and not the ones you scored highest — the four you want a stranger to see first. It is meant to be hard.")
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)

            bookGrid(selection: favorite, limitedTo: pickedBooks) { id in
                if favorite.contains(id) {
                    favorite.remove(id)
                } else if favorite.count < Self.favoriteCap {
                    favorite.insert(id)
                }
            }

        }
    }

    // MARK: - 5. People

    /// **The step the product exists for**, and the one that must not lie.
    ///
    /// Each suggestion carries a reason derived from the books the reader just
    /// picked, via the same `overlap(with:)` the profile uses. Readers with no
    /// overlap are not shown at all rather than shown with a vague reason — "you
    /// might like them" is the sentence this app was built to avoid.
    private var peopleStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            head(
                "Four of four",
                "People who've read them too.",
                "Dewey's editions come from the readers you follow. These are suggested because of what you just picked — nothing else."
            )

            if suggestedReaders.isEmpty {
                Text("Nobody in Dewey has read those yet. That is a real answer, not an empty screen — search is the way in, and the edition fills up as you follow people.")
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(suggestedReaders, id: \.reader.id) { suggestion in
                        readerRow(suggestion)
                        Rule()
                    }
                }
            }

        }
    }

    private func readerRow(_ suggestion: Suggestion) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.base) {
            ReaderAvatarView(reader: suggestion.reader, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.reader.name)
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.ink)
                Text(suggestion.reason)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.Space.snug)

            // The words come from `FollowCopy` rather than being spelled here,
            // now that the profile draws the same control (§12.9.1). Two
            // screens holding their own copy of one two-state label is how the
            // same action ends up reading "Following" here and "Followed"
            // there. The chip is otherwise unchanged.
            Button(FollowCopy.verb(isFollowing: store.isFollowing(suggestion.reader.id))) {
                store.toggleFollow(suggestion.reader.id)
            }
            .buttonStyle(ChipStyle(selected: store.isFollowing(suggestion.reader.id)))
        }
        .padding(.vertical, Theme.Space.base)
    }

    /// A reader, and the honest reason they are on screen.
    private struct Suggestion {
        let reader: ReaderProfile
        let reason: String
        let shared: Int
    }

    private var suggestedReaders: [Suggestion] {
        SeedData.readers.compactMap { reader in
            let shared = picked.filter { reader.ratings[$0] != nil }
            guard !shared.isEmpty else { return nil }
            let titles = shared.prefix(2).map { store.book($0).title }
            let reason: String
            switch shared.count {
            case 1: reason = "Also read \(titles[0])"
            case 2: reason = "Also read \(titles[0]) and \(titles[1])"
            default: reason = "\(shared.count) books in common, including \(titles[0])"
            }
            return Suggestion(reader: reader, reason: reason, shared: shared.count)
        }
        .sorted { $0.shared > $1.shared }
    }

    // MARK: - 6. Done

    /// The last teaching moment: a book already saved from someone the reader
    /// followed, with the concrete things Dewey lets them do with it next.
    private var doneStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            head(
                "Ready",
                "That's you, started.",
                savedBook == nil
                    ? "Your library is yours now. Follow a few more readers and the first edition builds itself."
                    : "One book is already waiting. Score it, rank it, or pass it to someone else when you're done."
            )

            if let savedBook {
                HStack(alignment: .top, spacing: Theme.Space.base) {
                    BookCoverView(book: savedBook.book, width: 58)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(savedBook.book.title)
                            .font(Theme.TypeScale.cardTitle())
                            .foregroundStyle(Theme.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("From \(savedBook.from)'s library")
                            .font(Theme.TypeScale.meta())
                            .foregroundStyle(Theme.Palette.accent)
                    }
                    Spacer(minLength: 0)
                }
            }

        }
    }

    @State private var savedBook: (book: Book, from: String)?

    /// Guards `commitPicks()` against running twice — once from the People
    /// step's "Finish" and again from `.done`'s "Open Dewey", or from Skip
    /// landing after either.
    @State private var hasCommittedPicks = false

    // MARK: - Book grid

    private var pickedBooks: [Book] {
        SeedData.books.filter { picked.contains($0.id) }
    }

    private func bookGrid(
        selection: Set<String>,
        limitedTo subset: [Book]? = nil,
        toggle: @escaping (String) -> Void
    ) -> some View {
        let books = subset ?? SeedData.books
        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 86), spacing: Theme.Space.snug)],
            spacing: Theme.Space.base
        ) {
            ForEach(books) { book in
                Button { toggle(book.id) } label: {
                    VStack(spacing: Theme.Space.tight) {
                        BookCoverView(book: book, width: 86)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Theme.Palette.accent, lineWidth: 3)
                                    .opacity(selection.contains(book.id) ? 1 : 0)
                            )
                        Text(book.title)
                            .font(Theme.TypeScale.meta())
                            .foregroundStyle(selection.contains(book.id)
                                             ? Theme.Palette.ink : Theme.Palette.inkSoft)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(book.title) by \(book.author)")
                .accessibilityAddTraits(selection.contains(book.id) ? [.isSelected] : [])
            }
        }
    }

    // MARK: - Commit

    /// Writes what the reader chose into the store, then saves one book from a
    /// followed reader's library so the provenance line has something true to
    /// say.
    ///
    /// **Idempotent**, because it now has two callers. It used to run only from
    /// the People step's "Finish", which quietly assumed a reader always
    /// reaches `.done` before leaving. Skip proved that wrong: the toolbar's
    /// "Skip" button is offered on every step up to and including People, and
    /// it called `finish()` directly — so a reader who picked books, rated
    /// them, and chose their four favorites, then tapped Skip instead of
    /// Finish because they didn't want to follow anyone yet, had every one of
    /// those choices discarded and landed in the exact empty account this flow
    /// exists to prevent. Both paths now call this.
    private func commitPicks() {
        guard !hasCommittedPicks else { return }
        hasCommittedPicks = true

        for id in picked {
            _ = store.log(DiaryEntry(
                id: UUID().uuidString,
                bookID: id,
                status: .finished,
                loggedOn: Date(),
                rating: ratings[id]
            ))
        }

        // The four go to the profile and **only** to the profile (§14). This
        // used to also stamp `isFavorite` on each of those diary entries, which
        // quietly made the two concepts agree on day one and taught the reader
        // they were the same thing. They are not: Favorite is unlimited and
        // lives on the log sheet, and a reader who ends onboarding with four
        // chosen books and no Favorites has an accurate account of what they
        // have actually told Dewey.
        store.setFavoriteBooks(Array(favorite))

        if let suggestion = suggestedReaders.first(where: { store.isFollowing($0.reader.id) }),
           let pick = suggestion.reader.ratings.keys.first(where: { !picked.contains($0) }) {
            let book = store.book(pick)
            _ = store.save(
                pick,
                status: .wantToRead,
                provenance: Provenance(
                    origin: .person(readerID: suggestion.reader.id, via: .shelf),
                    reason: nil,
                    date: Date()
                )
            )
            savedBook = (book, suggestion.reader.name.split(separator: " ").first.map(String.init)
                         ?? suggestion.reader.name)
        }
    }

    private func commitAndFinish() {
        commitPicks()
        advance(to: .done)
    }

    /// Reached from the toolbar's "Skip" on any step, and from `.done`'s "Open
    /// Dewey". Commits first — see `commitPicks()` — so leaving early never
    /// throws away picks, ratings, or favorites the reader already made.
    private func finish() {
        commitPicks()
        store.completeOnboarding()
        onFinish()
    }
}
