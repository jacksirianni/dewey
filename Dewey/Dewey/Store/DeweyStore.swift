import SwiftUI
import Observation

/// The prototype's single source of truth.
///
/// One store, not a repository/service/coordinator stack. The world is a few
/// hundred seeded objects held in memory; anything more elaborate would be
/// scaffolding around an empty room. When there is a backend, this is where it
/// plugs in.
@Observable
final class DeweyStore {

    // MARK: - Persisted state

    private(set) var library: [LibraryEntry] = []
    private(set) var diary: [DiaryEntry] = []
    private(set) var myLists: [BookList] = []
    /// Quotes and thoughts captured while a book is open. Unlike `library` and
    /// `diary`, no seed world carries any — the feature starts every account,
    /// fresh or seeded, with an empty page.
    private(set) var moments: [Moment] = []

    /// **Your Ranking — one of them** (§19).
    ///
    /// This was `[RankingContext]`, a list of independent orderings keyed by
    /// `.all` / `.year` / `.genre` / `.author` / `.list`, and the seed shipped
    /// two of them. Every question a screen wanted to ask — where does this book
    /// sit, what is my No. 1, which of these do I prefer — had as many answers
    /// as there were contexts holding the book. Genre and year views are now
    /// `RankingFilter` over this one array.
    private(set) var ranking = PersonalRanking()

    /// Whether Your Ranking appears on your profile. **Default on** (§19).
    ///
    /// A ranking is a taste artifact of the same standing as Favorite Books,
    /// Reviews and Lists, all of which are published without being asked about.
    /// The switch exists for the readers who want it and lives in an overflow
    /// menu on the ranked list; nothing in the primary flow mentions it.
    private(set) var isRankingPublic = true

    private(set) var recommendations: [Recommendation] = []

    /// **Your Favorite Books** — the four you chose to feature on your profile,
    /// in the order you chose them (§14).
    ///
    /// Held here rather than on `SeedData.me` because it is the one part of your
    /// profile you can edit, and it has to survive a relaunch. Every other
    /// reader's four are seeded and immutable.
    ///
    /// **Nothing writes this but `setFavoriteBooks(_:)`.** Marking a book a
    /// Favorite does not, rating it does not, ranking it does not. That
    /// independence is the feature: a reader with thirty Favorites still has to
    /// decide which four a stranger sees.
    private(set) var favoriteBookIDs: [String] = []

    /// Fires when someone picks up a book you sent. The one notification in
    /// Dewey that is a gift rather than a demand.
    var pendingClosure: Recommendation?

    /// Whether `send(bookID:to:reason:)` may schedule the closure banner —
    /// the simulated "they started it" reply that arrives on its own after a
    /// delay. Set by `RootView` from `AccountBackend.isReal` (see
    /// `onFavoriteBooksChanged` above for why a stored flag rather than a
    /// reference to `SessionStore`). Off by default: a context that never
    /// sets this explicitly gets the honest behaviour — nothing manufactured
    /// — rather than the fabricated one. `DebugActions.debugFireClosure()`
    /// is unaffected; it is an explicit, developer-triggered action, not
    /// something the send flow schedules on its own.
    var simulatesRecipientClosure = false

    // MARK: - The catalog (§16)

    /// The external catalog behind the provider seam. Open Library today;
    /// the seam exists so that sentence can change without this file caring.
    private let catalog: any BookCatalogProvider = OpenLibraryClient()

    /// Books pulled in from the catalog that the reader has *committed to* —
    /// saved, logged, rated, listed, ranked, or sent. Persisted, because the
    /// diary entries pointing at them are.
    ///
    /// This is the Letterboxd split made concrete: the catalog owns works and
    /// covers, Dewey owns everything with an opinion in it, and this
    /// dictionary is the narrow shelf where the two meet — one lightweight
    /// reference per book the reader actually touched, not a mirrored
    /// catalog.
    private(set) var importedBooks: [String: Book] = [:]

    /// Books the reader has merely *looked at* this session. In memory only:
    /// opening a page is a glance, not a commitment, and a glance does not
    /// join the permanent record. A durable action promotes the reference to
    /// `importedBooks`; quitting the app forgets it.
    private(set) var viewedRemoteBooks: [String: Book] = [:]

    // MARK: - Seeded world

    /// The whole shelf: the seeded forty-one plus everything the reader has
    /// imported. Computed rather than stored so browse and search see an
    /// import the moment it lands. Seed order first — the hand-set shelf keeps
    /// its arrangement — with imports following alphabetically.
    var books: [Book] {
        SeedData.books + importedBooks.values.sorted { $0.title < $1.title }
    }
    let readers = SeedData.readers
    let communityLists = SeedData.lists
    let allReviews = SeedData.reviews
    /// Ratings that predate the diary — the seeded reader's back catalogue.
    ///
    /// **Part of the world, not a global** (§13.7). This was
    /// `let myRatings = SeedData.myRatings`, a static the fresh account had no
    /// way to clear, so a brand-new reader who had rated two books saw "Rated 15
    /// books" on their profile and a "Keeps returning to" line derived from a
    /// stranger's taste. Anything the reader can see about themselves has to
    /// come out of the loaded world.
    private(set) var myRatings: [String: Double] = SeedData.myRatings

    // MARK: - Lifecycle

    /// Which world is loaded. Persisted, so a relaunch mid-evaluation comes
    /// back to the same account rather than silently reverting to the demo.
    private(set) var world: WorldMode = .seeded

    /// **Vestigial since §17. Nothing reads this to decide anything.**
    ///
    /// It was the cold start's only gate: `RootView` watched it and raised the
    /// onboarding cover. Onboarding is now gated on `SessionStore.phase`, and
    /// the authority for "has this reader done the taste steps" is
    /// `profiles.taste_onboarding_complete` on the server — which is the whole
    /// point, since a device-local boolean cannot know that the same person
    /// already onboarded on another phone.
    ///
    /// Kept, rather than deleted, only because it is a key in the persisted
    /// `State` and removing it would force a schema filename bump for a field
    /// nobody reads. It is still written so an older build could read the file
    /// back. **Do not add a reader.** If you want to know whether onboarding is
    /// outstanding, ask the session.
    private(set) var needsOnboarding: Bool = false

    /// Whose reading data is currently loaded, and the key its file is stored
    /// under. Nil while signed out (§18).
    ///
    /// **Everything below it is empty until an account is activated**, which is
    /// the whole correction. This class used to load a single, account-agnostic
    /// JSON file in `init()` — so the diary, library, ratings, rankings, lists
    /// and follows of whoever last used the device were already in memory before
    /// anyone signed in, and stayed there across a sign-out. A second reader
    /// signing in on the same phone inherited the first one's entire reading
    /// history. Verified on disk before it was fixed: the file carried three
    /// diary entries, four library rows and a follow set, and contained no
    /// account identifier of any kind.
    private(set) var activeAccount: UUID?

    /// Whether a pre-account `v4` file is still on disk, unreachable by any code
    /// path. Reported in the debug menu rather than acted on — see the note on
    /// `Persistence.url(for:)` for why it is neither read nor deleted.
    var hasOrphanedPreAccountData: Bool { Persistence.legacyFileExists }

    // MARK: - Adopting the pre-account file (§20)

    /// What is in the orphaned `v4` file, without applying any of it.
    ///
    /// **The counts exist so the decision is informed rather than blind.** The
    /// file is one snapshot of a device, and the single most important thing
    /// about it is not how many books it holds but which world it was written
    /// in: a `.seeded` file carries the demo corpus, and adopting it puts
    /// fourteen ranked books and somebody else's diary onto a real account.
    /// That may well be what the reader wants — it is the state their phone was
    /// actually in — but it is their call, and it cannot be their call unless
    /// the screen says so.
    struct PreAccountSnapshot: Equatable {
        let world: WorldMode
        let finished: Int
        let saved: Int
        let lists: Int
        let follows: Int
        let favoriteBooks: Int
        let ratings: Int

        var isEmpty: Bool {
            finished == 0 && saved == 0 && lists == 0
                && follows == 0 && favoriteBooks == 0 && ratings == 0
        }

        /// One line for a confirmation dialog. Only the non-zero parts, because
        /// "0 lists, 0 follows" is noise in a sentence somebody is reading to
        /// decide something.
        var summary: String {
            let parts: [String] = [
                finished > 0 ? "\(finished) logged" : nil,
                saved > 0 ? "\(saved) saved" : nil,
                ratings > 0 ? "\(ratings) rated" : nil,
                lists > 0 ? "\(lists) list\(lists == 1 ? "" : "s")" : nil,
                follows > 0 ? "\(follows) followed" : nil,
                // "1 Favorite Books" — the term is a fixed plural naming the
                // four on your profile, so it cannot be singularised without
                // saying something the app means differently. Counted against
                // the cap instead, which is how the State section above already
                // renders it.
                favoriteBooks > 0
                    ? "\(favoriteBooks) of \(Judgement.FavoriteBooksCopy.count) Favorite Books"
                    : nil,
            ].compactMap { $0 }
            return parts.isEmpty ? "Nothing in it" : parts.joined(separator: ", ")
        }
    }

    /// Nil when there is no file, or when this build can no longer decode it —
    /// a file that will not decode must not be offered, because the offer would
    /// silently adopt nothing and retire the only copy.
    var preAccountSnapshot: PreAccountSnapshot? {
        guard let state = Persistence.loadLegacy() else { return nil }
        return PreAccountSnapshot(
            world: state.world ?? .fresh,
            finished: state.diary.count,
            saved: state.library.count,
            lists: state.myLists.count,
            follows: (state.follows ?? []).count,
            favoriteBooks: (state.favoriteBookIDs ?? []).count,
            ratings: (state.myRatings ?? [:]).count
        )
    }

    /// Takes the pre-account file into the signed-in account, once.
    ///
    /// **Nothing is destroyed and nothing is automatic.** Those are the two
    /// properties this whole thing is built around, because the alternative to
    /// each is a way to lose a reading record:
    ///
    ///   * The account's current file is *moved aside* before it is replaced,
    ///     not overwritten. That is what lets adoption be offered even to an
    ///     account that has already logged something — the alternative was to
    ///     block it, which would have meant a reader who finished onboarding
    ///     before noticing their old library could never get it back.
    ///   * The source file is *renamed*, not deleted, so the offer stops being
    ///     made without the bytes going anywhere.
    ///
    /// **It is a whole-snapshot replacement, deliberately not a merge.** There
    /// is no identity to merge diary entries on — two logs of the same book on
    /// the same day are a legitimate pair, not a duplicate — and a merge that
    /// guessed would produce a reading record that is not a record of anything.
    /// Replacing is the only honest operation, and the backup is what makes it
    /// safe to offer.
    ///
    /// Returns false without changing anything if there is no account, no file,
    /// or the backup could not be written.
    @discardableResult
    func adoptPreAccountData() -> Bool {
        guard let activeAccount else { return false }
        guard let state = Persistence.loadLegacy() else { return false }
        // If the account's own record cannot be set aside, stop. Adopting over
        // it would be the one outcome this method exists to make impossible.
        guard Persistence.setAsideCurrentFile(for: activeAccount) else { return false }

        // Applied exactly as `activate(_:)` applies a restored file, including
        // the legacy-ranking migration — a `v4` file predates `PersonalRanking`
        // and carries the five-context shape, so going through any other path
        // would silently drop the reader's ordering.
        world = state.world ?? .fresh
        library = state.library
        diary = state.diary
        myLists = state.myLists
        ranking = state.ranking ?? Self.migrated(from: state.rankings ?? [])
        isRankingPublic = state.isRankingPublic ?? true
        recommendations = state.recommendations
        follows = state.follows ?? []
        favoriteBookIDs = state.favoriteBookIDs ?? []
        myRatings = state.myRatings ?? [:]
        importedBooks = state.importedBooks ?? [:]
        moments = state.moments ?? []
        // Not carried. It is vestigial, and this account has demonstrably
        // finished onboarding — it is signed in and adopting a file.
        needsOnboarding = false
        viewedRemoteBooks = [:]
        searchCache = [:]
        searchCacheOrder = []
        pendingClosure = nil

        persist()

        // Tell the account layer what changed, through the same closures every
        // other edit uses. Without this the server keeps the four and the follow
        // set the reader had *before* adopting, and the next reinstall quietly
        // undoes the whole thing.
        onFavoriteBooksChanged?(favoriteBookIDs)
        onFollowsChanged?(follows)

        Persistence.retireLegacyFile()
        return true
    }

    /// Deliberately loads nothing. See `activate(_:)`.
    ///
    /// Constructing the store no longer implies a reader. `DeweyApp` builds it
    /// at launch, before the session has been restored and possibly before
    /// anyone has ever signed in, and at that moment the only correct contents
    /// are none.
    init() {
        applyEmptyWorld()
    }

    // MARK: - Account activation

    /// Loads this account's reading data, or starts it a fresh one.
    ///
    /// **A new account always begins `.fresh`, never `DebugSettings.world`.**
    /// A first sign-in must not be able to land in the seeded corpus because a
    /// switch was left flipped in a menu — that is precisely the "silently
    /// creates sixty-one followers" outcome §17.7 removed from launch, and it
    /// would come straight back through this door. Switching worlds afterwards
    /// is an explicit act.
    func activate(_ account: UUID) {
        guard activeAccount != account else { return }
        activeAccount = account

        guard let restored = Persistence.load(for: account) else {
            load(SeedData.world(for: .fresh), as: .fresh)
            persist()
            return
        }

        world = restored.world ?? .fresh
        library = restored.library
        diary = restored.diary
        myLists = restored.myLists
        // New key first, legacy shape second. See `State.ranking`.
        ranking = restored.ranking ?? Self.migrated(from: restored.rankings ?? [])
        isRankingPublic = restored.isRankingPublic ?? true
        recommendations = restored.recommendations
        // Falls back to *nothing* rather than to the seeded fixtures. A restored
        // file missing a key belongs to a real account, and filling the gap with
        // demo data would be the same fabrication in a quieter place.
        follows = restored.follows ?? []
        needsOnboarding = restored.needsOnboarding ?? false
        favoriteBookIDs = restored.favoriteBookIDs ?? []
        myRatings = restored.myRatings ?? [:]
        importedBooks = restored.importedBooks ?? [:]
        moments = restored.moments ?? []
        viewedRemoteBooks = [:]
        searchCache = [:]
        searchCacheOrder = []
        pendingClosure = nil
    }

    /// Signing out. **Clears memory; leaves the file alone.**
    ///
    /// Both halves matter. Leaving it on disk is what makes signing back in on
    /// the same device find your library where you left it — nothing here syncs,
    /// so deleting would be the only copy gone. Clearing memory is what stops
    /// the next reader seeing it: without this, User B signing in without an app
    /// restart would be handed User A's diary directly out of RAM, no file
    /// involved.
    func deactivate() {
        activeAccount = nil
        applyEmptyWorld()
    }

    /// The signed-out world: nothing, from nobody.
    private func applyEmptyWorld() {
        world = .fresh
        library = []
        diary = []
        myLists = []
        ranking = PersonalRanking()
        isRankingPublic = true
        recommendations = []
        follows = []
        needsOnboarding = false
        favoriteBookIDs = []
        myRatings = [:]
        importedBooks = [:]
        moments = []
        viewedRemoteBooks = [:]
        searchCache = [:]
        searchCacheOrder = []
        pendingClosure = nil
        identity = nil
    }

    // MARK: - Worlds

    /// Tear the store down and rebuild it in `mode`, then persist.
    ///
    /// Both directions reset cleanly: this replaces every persisted collection
    /// rather than merging into it, so switching seeded → fresh → seeded lands
    /// on exactly the corpus a first launch would have produced.
    func load(world mode: WorldMode) {
        DebugSettings.shared.world = mode
        load(SeedData.world(for: mode), as: mode)
        pendingClosure = nil
        persist()
    }

    private func load(_ snapshot: SeedData.World, as mode: WorldMode) {
        world = mode
        library = snapshot.library
        diary = snapshot.diary
        myLists = snapshot.lists
        ranking = snapshot.ranking
        isRankingPublic = true
        recommendations = snapshot.recommendations
        myRatings = snapshot.myRatings
        follows = snapshot.follows
        needsOnboarding = snapshot.needsOnboarding
        favoriteBookIDs = snapshot.favoriteBookIDs
        // Imported books are part of the loaded world's record — every diary
        // entry and list item that referenced them is being replaced, and a
        // shelf that kept showing books nothing refers to would be a world
        // switch that only half happened.
        importedBooks = [:]
        moments = []
        viewedRemoteBooks = [:]
        // The cached answers hold books from the world being replaced.
        searchCache = [:]
        searchCacheOrder = []
    }

    // MARK: - Favorite Books

    /// Replace the four you feature on your profile.
    ///
    /// Capped rather than validated-and-rejected: a caller that hands over five
    /// gets the first four, because a picker that silently refuses a tap is
    /// worse than one that cannot offer a fifth in the first place. The UI
    /// enforces the cap at the tap; this is the backstop.
    /// Unresolvable IDs are dropped rather than refusing the whole edit: the
    /// four are a deliberate choice about several books, and one that Dewey
    /// can no longer answer for should cost its slot, not the other three.
    func setFavoriteBooks(_ ids: [String]) {
        let usable = ids.filter { promoteForWrite($0) }
        favoriteBookIDs = Array(usable.prefix(Judgement.FavoriteBooksCopy.count))
        persist()
        onFavoriteBooksChanged?(favoriteBookIDs)
    }

    // MARK: - Account sinks

    /// Where an edit goes after it has been saved locally (§17).
    ///
    /// **Set by `RootView`, called after `persist()`, and never awaited.** The
    /// direction is one-way and the ordering is deliberate: local is the
    /// authority, the write to disk has already happened, and the server is told
    /// afterwards as a courtesy. A reader toggling a follow on a plane gets the
    /// follow; the server finds out later, or does not.
    ///
    /// Closures rather than a reference to `SessionStore` so that `DeweyStore`
    /// still has no idea accounts exist — which is what keeps it constructible
    /// in a preview with no session in the environment.
    var onFavoriteBooksChanged: (([String]) -> Void)?
    var onFollowsChanged: ((Set<String>) -> Void)?

    /// Whether this book is one of the four on your profile. Deliberately not
    /// the same question as `isFavorite(_:)`.
    func isFeatured(_ bookID: String) -> Bool { favoriteBookIDs.contains(bookID) }

    /// Add or remove a book from your four. A tap on a full four does nothing —
    /// the reader has to take one out before putting one in, which is the
    /// decision the constraint exists to force.
    func toggleFeatured(_ bookID: String) {
        var next = favoriteBookIDs
        if let i = next.firstIndex(of: bookID) {
            next.remove(at: i)
        } else if next.count < Judgement.FavoriteBooksCopy.count {
            next.append(bookID)
        } else {
            return
        }
        setFavoriteBooks(next)
    }

    /// Marks the fresh-account onboarding as done. Idempotent.
    func completeOnboarding() {
        guard needsOnboarding else { return }
        needsOnboarding = false
        persist()
    }

    // MARK: - The edition

    /// This week's cards, filtered to the readers you actually follow (§13.7).
    ///
    /// The view used to render `SeedData.edition` directly, which was fine while
    /// there was one world and you followed everybody in it. In a fresh account
    /// it was a straightforward lie: five cards from four strangers, under a
    /// header reading "Five things from the readers you follow", in an app whose
    /// entire premise is that the people are the point.
    ///
    /// A `.readerSuggestion` card survives the filter *only* when its subject is
    /// someone you do not already follow — proposing a mind is the one card that
    /// is supposed to reach past your follow set, and proposing somebody already
    /// in it is noise.
    ///
    /// A direct recommendation survives if the recommendation is still live and
    /// its sender is followed.
    var edition: [EditionCard] {
        SeedData.edition.filter { card in
            if card.isReaderSuggestion {
                guard case .readerSuggestion(let id) = card else { return false }
                return !follows.contains(id)
            }
            if let recID = card.recommendationID {
                guard let rec = recommendation(recID) else { return false }
                return rec.fromReaderID.map { follows.contains($0) } ?? false
            }
            let ids = card.readerIDs
            return !ids.isEmpty && ids.allSatisfy { follows.contains($0) }
        }
    }

    // MARK: - Following

    /// Who you follow. In the seeded world this is everyone; in a fresh account
    /// it starts empty, which is the whole reason the first Edition has to be
    /// able to say so.
    private(set) var follows: Set<String> = Set(SeedData.readers.map(\.id))

    var followedReaders: [ReaderProfile] {
        SeedData.readers.filter { follows.contains($0.id) }
    }

    func isFollowing(_ readerID: String) -> Bool { follows.contains(readerID) }

    func toggleFollow(_ readerID: String) {
        if follows.contains(readerID) { follows.remove(readerID) } else { follows.insert(readerID) }
        persist()
        onFollowsChanged?(follows)
    }

    // MARK: - Lookup

    /// The one funnel nearly every surface resolves a book through.
    ///
    /// Imported first — an imported book is the freshest record Dewey holds —
    /// then the seed, then the session's transient cache. What it must never
    /// do is answer confidently with the wrong book: this used to coalesce to
    /// `books[0]`, so every dangling reference in the app rendered as *The
    /// Employees*, and once imports existed a reader's own diary could do it
    /// after a failed restore. An unresolvable ID now returns an explicit
    /// unknown, and says so in the log.
    ///
    /// **Loud, but not fatal — and that distinction was earned.** This was an
    /// `assertionFailure`, on the reasoning that a dangling ID is a bug and
    /// debug builds should stop on it. Then a debug world switch crashed the
    /// app: the switch replaced the library, and a `LibraryRow` for a removed
    /// entry evaluated its body one last time before SwiftUI dropped it,
    /// resolving an ID the store had legitimately just discarded. That window
    /// is ordinary SwiftUI behaviour on *any* removal — deleting a diary
    /// entry, dropping a book from a list — so a trap here converts routine
    /// view churn into a crash while doing nothing about the actual hazard.
    /// The hazard is a *durable record* pointing at nothing, and that is
    /// refused where it can be refused honestly: at the write, in
    /// `promoteForWrite`.
    func book(_ id: String) -> Book {
        if let known = importedBooks[id] ?? SeedData.find(id) ?? viewedRemoteBooks[id] {
            return known
        }
        #if DEBUG
        print("Dewey: unresolved book ID “\(id)” — nothing in the imported catalog, the seed, or the transient cache answers for it. Rendering the unknown-book placeholder.")
        #endif
        return .missing(id)
    }

    /// The freshest version of a book a view was handed by value.
    ///
    /// `BookDetailView` is pushed with a `Book` snapshot; enrichment and
    /// promotion write into this store's dictionaries after the push. A page
    /// that re-reads through this sees them land. Falls back to the snapshot
    /// itself — the value in hand beats a placeholder, and a transient book
    /// evicted by a world switch should still render as what it was.
    func book(resolving snapshot: Book) -> Book {
        importedBooks[snapshot.id] ?? SeedData.find(snapshot.id) ?? viewedRemoteBooks[snapshot.id] ?? snapshot
    }

    func reader(_ id: String?) -> ReaderProfile? { id.flatMap { SeedData.reader($0) } }

    /// The signed-in account, when there is one. Set by `RootView` as the
    /// session phase changes; nil while signed out and in previews.
    ///
    /// **`DeweyStore` does not fetch this and cannot.** It is handed the account
    /// because the alternative — a network call behind `me`, which is read on
    /// nearly every screen — would make the entire product state unavailable
    /// until an authentication round trip finished. See `SessionStore`.
    private(set) var identity: AccountProfile?

    func adoptIdentity(_ profile: AccountProfile?) {
        identity = profile
    }

    /// Your profile, as the rest of the app sees you.
    ///
    /// **The name and handle are real** (§17). They used to be `SeedData.me` —
    /// "You", `@you` — a constant that made every profile screen in the app a
    /// picture of a person who did not exist. They now come from the `profiles`
    /// row the reader created during first run, along with their join date.
    ///
    /// **The id is still `"me"`, and that is deliberate.** It is the sentinel
    /// local rows use to mean "mine": list `ownerID`s, ranking contexts and the
    /// diary all carry it, and promoting it to the account's UUID would be a
    /// migration of every locally-stored row in exchange for nothing a reader
    /// can see. The account's real identifier is `identity.userID`, which is
    /// what every server-facing call uses; this string never leaves the device.
    ///
    /// **Follower counts are zero rather than the seed's sixty-one.** A real
    /// account has no followers until real accounts can follow each other, and
    /// a number here would be the exact fabrication the cold start exists to
    /// avoid. `followingCount` is answered from the live follow set by the
    /// profile screen, which is a fact rather than a stored figure.
    var me: ReaderProfile {
        guard let identity else {
            // Signed out, or a preview. The seeded demo reader, unchanged.
            var profile = SeedData.me
            profile.favoriteBookIDs = favoriteBookIDs
            return profile
        }

        return ReaderProfile(
            id: "me",
            name: identity.displayName,
            handle: Handle.display(identity.handle),
            // Texture is a bio by another name and is explicitly not collected
            // yet. The seed's line is a placeholder, not a claim about you.
            texture: SeedData.me.texture,
            accent: SeedData.me.accent,
            // `allMyRatings` is the authority on your ratings — it folds the
            // diary in and this dictionary cannot. Empty here, as on the seed.
            ratings: [:],
            favoriteBookIDs: favoriteBookIDs,
            listIDs: [],
            followerCount: 0,
            followingCount: 0,
            memberSince: identity.createdAt
        )
    }

    /// Applies what the server holds for a newly signed-in account.
    ///
    /// **Only fills gaps; never overwrites.** Each collection is adopted only
    /// when the local one is empty, which makes this a fresh-install restore and
    /// nothing more. The alternative — letting the server win — would mean a
    /// reader whose taste onboarding failed to upload loses their four the next
    /// time they launch, and there is no reconciliation in this stage that could
    /// tell the two cases apart. Local remains the authority for everything it
    /// already owned (§17).
    func applyAccountState(favoriteBooks: [String], seedFollows: [String]) {
        var changed = false

        if favoriteBookIDs.isEmpty, !favoriteBooks.isEmpty {
            favoriteBookIDs = Array(
                favoriteBooks.filter { promoteForWrite($0) }
                    .prefix(Judgement.FavoriteBooksCopy.count)
            )
            changed = true
        }

        if follows.isEmpty, !seedFollows.isEmpty {
            // Filtered to readers this build actually knows about — a slug from
            // an older seed should cost a follow, not leave a dangling id that
            // every edition filter has to step over.
            let known = Set(SeedData.readers.map(\.id))
            follows = Set(seedFollows.filter { known.contains($0) })
            changed = true
        }

        if changed { persist() }
    }

    func list(_ id: String) -> BookList? {
        myLists.first { $0.id == id } ?? communityLists.first { $0.id == id }
    }

    var allLists: [BookList] { myLists + communityLists }

    func recommendation(_ id: String) -> Recommendation? {
        recommendations.first { $0.id == id }
    }

    // MARK: - Catalog operations (§16)

    /// How long a catalog answer is trusted before it is worth asking again.
    static let catalogTTL: TimeInterval = 7 * 24 * 60 * 60

    /// Search the external catalog and hand back Dewey books.
    ///
    /// Every result resolves through the work-ID index first, so a work
    /// Dewey has already seen — imported or merely viewed — comes back as
    /// the book it already is, with its Dewey ID and any activity intact.
    /// Only genuinely new works mint an ID, and they enter as transients:
    /// search is a glance, not a commitment.
    /// Answers already given, keyed by the words that produced them.
    ///
    /// A catalog search costs about a second and a half, and readers backspace:
    /// they type a word too many, delete it, and wait all over again for an
    /// answer Dewey was holding a moment ago. This is in memory only and dies
    /// with the session — it is a typing aid, not a cache of the catalog.
    private var searchCache: [String: [Book]] = [:]
    private var searchCacheOrder: [String] = []

    /// Whether this query can be answered without asking the catalog. Lets the
    /// search field skip its debounce when there is nothing to wait for.
    func hasCachedCatalogSearch(_ query: String) -> Bool { searchCache[query] != nil }

    @MainActor
    func searchCatalog(_ query: String) async throws -> [Book] {
        if let hit = searchCache[query] {
            // Re-resolve rather than returning the stored books: one of them
            // may have been imported since, and the row should show the rating
            // it now has.
            return hit.map { book(resolving: $0) }
        }
        let results = try await catalog.search(query)
        var out: [Book] = []
        var seen = Set<String>()
        for result in results {
            let book: Book
            if let existing = self.book(workID: result.workID) ?? knownBook(matching: result) {
                book = existing
            } else {
                book = Book.imported(from: result, deweyID: "dw-" + UUID().uuidString.lowercased())
                viewedRemoteBooks[book.id] = book
            }
            // Two catalog rows can resolve onto one Dewey book — Open Library
            // holds duplicate work records, and the title-and-author fallback
            // is a looser test than the client's own de-duplication. Returning
            // the same book twice would hand `ForEach` a repeated id, which is
            // undefined behaviour in SwiftUI, not merely an ugly list.
            guard seen.insert(book.id).inserted else { continue }
            out.append(book)
        }
        searchCache[query] = out
        searchCacheOrder.append(query)
        // A couple of dozen queries is more than a session of typing produces;
        // the oldest goes when it does.
        if searchCacheOrder.count > 24, let oldest = searchCacheOrder.first {
            searchCacheOrder.removeFirst()
            searchCache[oldest] = nil
        }
        return out
    }

    /// Identity of last resort for a catalog hit whose work ID Dewey does not
    /// already know.
    ///
    /// Open Library holds **more than one work record for the same book** —
    /// *Checkout 19* exists twice, under two identifiers, both attributed to
    /// Claire-Louise Bennett — and only one of them can be the identifier on
    /// file. Without this, the second record reads as a different book: a row
    /// of its own next to the reader's already-rated copy, and a permanent
    /// duplicate the moment they save it, with their ratings and diary split
    /// across two records of one novel.
    ///
    /// **The reader's own imports are checked, not just the seed.** Scanning
    /// only the forty-one left the duplicate hazard wide open for exactly the
    /// books the reader cares most about: import *The Idiot* from one work
    /// record, rate it, and a later search offering the other record would
    /// hand them a second, empty copy of a novel already in their diary.
    ///
    /// Title *and* author must agree, which is what keeps it from over-merging:
    /// Tolkien's *The Hobbit* and Charles Dixon's graphic adaptation share a
    /// title and stay separate books. The title comparison allows one to extend
    /// the other, because catalogs disagree about subtitles — "Citizen" and
    /// "Citizen: An American Lyric" are the same poem sequence.
    private func knownBook(matching result: CatalogSearchResult) -> Book? {
        guard let author = result.author else { return nil }
        let title = Self.normalized(result.title)
        guard title.count >= 5 else { return nil }
        let surname = Self.surname(author)
        guard !surname.isEmpty else { return nil }

        func matches(_ candidate: Book) -> Bool {
            let candidateTitle = Self.normalized(candidate.title)
            guard candidateTitle.hasPrefix(title) || title.hasPrefix(candidateTitle) else { return false }
            return Self.surname(candidate.author) == surname
        }

        return SeedData.books.first(where: matches)
            ?? importedBooks.values.first(where: matches)
            ?? viewedRemoteBooks.values.first(where: matches)
    }

    /// Letters and digits only, folded — with `&` spelled out first, because
    /// "Red, White & Royal Blue" and "Red, White and Royal Blue" are one book
    /// and two catalogs, and dropping the ampersand instead of expanding it
    /// makes them fold to strings neither of which prefixes the other.
    private static func normalized(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .filter { $0.isLetter || $0.isNumber }
    }

    /// The last word of a name, folded. Enough to match "J. A. Baker" against
    /// "Baker, J. A." without a name parser, and the only part of an author's
    /// name two catalogs reliably spell the same way.
    private static func surname(_ name: String) -> String {
        normalized(name.split(whereSeparator: { $0 == " " || $0 == "," }).last.map(String.init) ?? name)
    }

    /// The work-ID index, scanned rather than maintained. The seed is forty-one
    /// books and both dictionaries together hold at most a few dozen; an index
    /// that can drift is dearer than a scan that can't.
    ///
    /// **The seed is searched first, and that is the whole point.** A catalog
    /// hit for a seeded work must come back as the *seeded book* — same Dewey
    /// ID, same ratings, same diary, same place in the rankings. Before the
    /// seed carried work IDs, searching "Middlemarch" offered the reader a
    /// second, empty Middlemarch to save alongside the one they had already
    /// rated.
    func book(workID: String) -> Book? {
        SeedData.books.first { $0.openLibraryWorkID == workID }
            ?? importedBooks.values.first { $0.openLibraryWorkID == workID }
            ?? viewedRemoteBooks.values.first { $0.openLibraryWorkID == workID }
    }

    /// Can Dewey still answer for this ID at all?
    private func canResolve(_ bookID: String) -> Bool {
        importedBooks[bookID] != nil || SeedData.find(bookID) != nil || viewedRemoteBooks[bookID] != nil
    }

    /// The moment a glance becomes a commitment (§16) — and the gate that
    /// stops a commitment outliving the book it is about.
    ///
    /// Called at the top of every durable mutation: save, log, list, rank,
    /// send, note, the four. If the ID belongs to a transient it moves to the
    /// permanent record right before the activity referencing it is written;
    /// the caller's own `persist()` covers both. Idempotent, and a no-op for
    /// seed books and anything already imported.
    ///
    /// **`false` means refuse the write.** A book page pushed from search
    /// holds its own snapshot and keeps its buttons live, so a debug world
    /// switch — which clears the transients — leaves a live Add to Library
    /// button for a book the store no longer holds. Writing that entry would
    /// persist a diary pointing at nothing: an assertion on every later
    /// render in debug, and a permanent "Unknown book" row in release. That
    /// is precisely the dangling reference the unknown-ID work went in to
    /// eliminate, so the mutation stops here instead of moving the lie
    /// downstream.
    private func promoteForWrite(_ bookID: String) -> Bool {
        if importedBooks[bookID] != nil { return true }
        if let transient = viewedRemoteBooks.removeValue(forKey: bookID) {
            importedBooks[bookID] = transient
            return true
        }
        return SeedData.find(bookID) != nil
    }

    /// The refresh policy, in one place (§16). A page open never blocks on
    /// this — the book renders from what Dewey holds, and a fresh answer
    /// lands quietly if it lands at all.
    ///
    /// Asks the catalog only when it has never answered for this book
    /// (`catalogRefreshedAt == nil`) or the answer has outlived the TTL.
    /// Deliberately *not* re-asked just because a field is empty: an answer
    /// within the TTL that lacked a description is the catalog saying it has
    /// none, and hammering the same question does not change it.
    @MainActor
    func enrichIfNeeded(_ bookID: String) async {
        guard let current = importedBooks[bookID] ?? viewedRemoteBooks[bookID],
              current.openLibraryWorkID != nil else { return }
        if let refreshed = current.catalogRefreshedAt,
           Date().timeIntervalSince(refreshed) < Self.catalogTTL { return }
        await refreshCatalogMetadata(bookID)
    }

    /// The unconditional fetch — the TTL's escape hatch, reachable from the
    /// debug menu. Failure is silent by design: the page this feeds has
    /// already rendered from local state, and a toast about a background
    /// refresh would be the network narrating itself.
    @MainActor
    func refreshCatalogMetadata(_ bookID: String) async {
        guard let current = importedBooks[bookID] ?? viewedRemoteBooks[bookID],
              let workID = current.openLibraryWorkID else { return }
        guard let work = try? await catalog.work(workID) else { return }
        // Re-read after the await: a promotion may have moved the book while
        // the network was thinking.
        guard let latest = importedBooks[bookID] ?? viewedRemoteBooks[bookID] else { return }
        let enriched = latest.enriched(with: work)
        if importedBooks[bookID] != nil {
            importedBooks[bookID] = enriched
            persist()
        } else {
            viewedRemoteBooks[bookID] = enriched
        }
    }

    /// Every imported book, oldest answer first — the debug menu's refresh
    /// sweep works through these.
    @MainActor
    func refreshAllCatalogMetadata() async {
        for id in importedBooks.keys.sorted(by: { (importedBooks[$0]?.catalogRefreshedAt ?? .distantPast) < (importedBooks[$1]?.catalogRefreshedAt ?? .distantPast) }) {
            await refreshCatalogMetadata(id)
        }
    }

    // MARK: - Taste overlap

    func overlap(with reader: ReaderProfile) -> TasteOverlap {
        let mine = allMyRatings
        let sharedIDs = mine.keys.filter { reader.ratings[$0] != nil }
        let shared = sharedIDs.map { book($0) }.sorted { $0.reach.weight > $1.reach.weight }
        // 3.0 on the 0.1–10.0 scale, which is the 1.5 this was calibrated to on
        // the half-to-5 scale (§12.2). Three points apart is where two readers
        // stop having a preference and start having an argument — the threshold
        // has to be high enough that "divergent" means something.
        let divergent = sharedIDs
            .filter { abs((mine[$0] ?? 0) - (reader.ratings[$0] ?? 0)) >= 3.0 }
            .map { book($0) }
        return TasteOverlap(
            sharedBooks: shared,
            divergentBooks: divergent,
            weightedDepth: shared.reduce(0) { $0 + $1.reach.weight }
        )
    }

    /// Library Match — the third stat on a profile (§12.1).
    ///
    ///     coverage  = shared / min(my rated count, their rated count)
    ///     agreement = 1 − (mean absolute difference over shared books) / 10
    ///     match     = round(100 × (0.45 × coverage + 0.55 × agreement))
    ///
    /// The definition is written down here because §4.8 objected — correctly —
    /// that a bare percentage implies a precision the arithmetic doesn't have.
    /// That objection is answered by publishing the formula, not by refusing to
    /// show a number; `TasteOverlap` remains the evidence a reader reads once
    /// the number has got them to look.
    ///
    /// Two choices worth knowing. Coverage is measured against the **smaller**
    /// library, so a reader with forty books isn't punished for following one
    /// with four hundred. And agreement outweighs coverage, because reading all
    /// the same books and disagreeing about every one of them is not a match.
    ///
    /// Returns 0 with no overlap, and is capped at 99: a hundred percent would
    /// be a claim about a person rather than about two lists.
    func libraryMatch(with reader: ReaderProfile) -> Int {
        let mine = allMyRatings
        let sharedIDs = mine.keys.filter { reader.ratings[$0] != nil }
        guard !sharedIDs.isEmpty else { return 0 }

        let coverage = Double(sharedIDs.count)
            / Double(max(1, min(mine.count, reader.ratings.count)))
        let meanDifference = sharedIDs.reduce(0.0) { running, id in
            running + abs((mine[id] ?? 0) - (reader.ratings[id] ?? 0))
        } / Double(sharedIDs.count)

        // Divided by 4, not by the scale's full 10. Dividing by the range let
        // agreement bottom out around 0.6 — nobody's mean gap is eight points —
        // so every reader with any overlap scored 60-72% and the number stopped
        // discriminating between the reader who shares your taste and the one
        // the seed built to share almost none of it. On a ten-point scale two
        // readers who agree land within a point of each other, and a mean gap of
        // four points is not partial agreement, it is disagreement.
        let agreement = max(0, 1 - meanDifference / 4)

        let match = (100 * (0.45 * coverage + 0.55 * agreement)).rounded()
        return min(99, max(0, Int(match)))
    }

    /// Seeded history plus anything rated in-session.
    ///
    /// Routed through `myRating(for:)` so that every derived number — Library
    /// Match, the taste-overlap lists, the profile stats — agrees with what the
    /// book page shows. The previous version overlaid `diary` in array order,
    /// which is insertion order rather than `loggedOn` order, so on a reread the
    /// wrong entry could win; and it skipped entries with no rating, so a
    /// cleared rating left the stale seed value feeding Library Match.
    ///
    /// Assigning `nil` to a `Dictionary` subscript removes the key, which is
    /// exactly what a cleared rating should do here.
    var allMyRatings: [String: Double] {
        var combined = myRatings
        for bookID in Set(diary.map(\.bookID)) {
            combined[bookID] = myRating(for: bookID)?.value
        }
        return combined
    }

    // MARK: - Library state

    func entry(for bookID: String) -> LibraryEntry? {
        library.first { $0.bookID == bookID }
    }

    func status(of bookID: String) -> ReadingStatus? { entry(for: bookID)?.status }
    func isSaved(_ bookID: String) -> Bool { entry(for: bookID) != nil }

    /// The Library filters by `ReadingStatus` directly — there is no longer a
    /// coarser "shelf" grouping between the two (§13.3). Paused and Did Not
    /// Finish used to collapse into one bucket the Library called "Set Down",
    /// a phrase that appeared nowhere else in the app, so a reader who marked a
    /// book Paused went looking for it under Paused and found no such filter.
    func entries(withStatus status: ReadingStatus) -> [LibraryEntry] {
        library.filter { $0.status == status }.sorted { $0.savedAt > $1.savedAt }
    }

    /// The status the Library should open on.
    ///
    /// **Not the status with the most books** (§13.6, since revised). That
    /// heuristic opened the tab on `Finished` for any reader whose read pile
    /// outnumbered their in-progress pile — which is nearly everyone, since a
    /// reading life accumulates finished books for years but rarely holds more
    /// than a couple in progress at once. The seeded reader has one active
    /// read and eight finished books, and landed on the archive every time,
    /// with the one book they are *actually in the middle of* one tap away.
    /// That is a count winning over a life being lived.
    ///
    /// The order here is the same one the Library exists to communicate: what
    /// you're in the middle of, then what you're keeping for next, then
    /// whatever else has a book in it. `Reading` wins whenever it is
    /// non-empty, full stop — one active book still beats twenty finished
    /// ones. `Want to Read` is next, since a pile you're saving for later is
    /// closer to "current reading life" than a shelf of the past. Only once
    /// both are empty does this fall back to whichever remaining status has
    /// the most books, so a reader with nothing active or queued still opens
    /// on an informative filter rather than an arbitrary one.
    var busiestStatus: ReadingStatus {
        if library.contains(where: { $0.status == .reading }) { return .reading }
        if library.contains(where: { $0.status == .wantToRead }) { return .wantToRead }
        let ranked = ReadingStatus.allCases
            .map { status in (status, library.filter { $0.status == status }.count) }
            .filter { $0.1 > 0 }
        guard let top = ranked.max(by: { $0.1 < $1.1 }) else { return .wantToRead }
        return top.0
    }

    /// Your most recent rating for a book, from the diary.
    ///
    /// Once the diary has an entry for a book it is the sole authority on your
    /// rating of it — *including when that entry carries no rating*. The seed
    /// dictionary is a pre-diary history, consulted only for books the diary
    /// has never mentioned.
    ///
    /// This used to be `latestEntry?.rating ?? myRatings[bookID]`, which made
    /// clearing a rating impossible to observe: `§12.2.5`'s explicit Clear wrote
    /// `nil` to the entry, the `??` immediately fell through to the seed, and a
    /// number came straight back. Worse, `SeedData.myRatings` and the seeded
    /// diary are textured independently, so clearing Bluets did not restore the
    /// 9.3 the reader had been looking at — it produced 8.8, a value that had
    /// never been displayed anywhere and that the reader had never entered.
    func myRating(for bookID: String) -> Rating? {
        if let entry = latestEntry(for: bookID) { return entry.rating }
        return myRatings[bookID].flatMap(Rating.init)
    }

    /// Whether you have marked this book a Favorite in any diary entry.
    ///
    /// Says nothing about your profile. `isFeatured(_:)` answers that, and the
    /// two are deliberately allowed to disagree — see `favoriteBookIDs`.
    func isFavorite(_ bookID: String) -> Bool {
        entries(forBook: bookID).contains { $0.isFavorite }
    }

    func entries(forBook bookID: String) -> [DiaryEntry] {
        diary.filter { $0.bookID == bookID }.sorted { $0.loggedOn > $1.loggedOn }
    }

    func latestEntry(for bookID: String) -> DiaryEntry? {
        entries(forBook: bookID).first
    }

    // MARK: - Mutating the library

    /// Provenance is inferred at the moment of saving, never asked for. If
    /// the book reached you through a person, Dewey already knows — a form
    /// would defeat the entire idea.
    ///
    /// One source for this inference, called from wherever a reader can save
    /// a book without opening the book page first (a quick save from a
    /// search row, for instance) as well as from the book page itself — so a
    /// book saved from either place tells the same true story about how it
    /// arrived.
    ///
    /// **Nothing below the recommendation check guesses.** Two further
    /// inferences used to run here, and both stated a guess as a fact in the
    /// one place the product promises never to. If the book appeared on any
    /// public list, saving it attributed the save to that list's owner *and
    /// quoted their premise as the reason* — so a reader who searched for
    /// Middlemarch, read nothing but the title, and tapped Want to Read got a
    /// permanent provenance chain reading "Ana Beltrán → You" with Ana's
    /// sentence in quotation marks under it. A fallback below that attributed
    /// it to whichever follower happened to have rated it first.
    ///
    /// The premise of the feature is that Dewey already knows how a book
    /// reached its reader. It knows when somebody sent it — that is a real
    /// record, and it is the branch above. It does not know that a reader
    /// arrived from Ana's list, because nothing tells this call where the
    /// search that found the book started; it only knows the book is *also*
    /// on her list, which is a different sentence. A chain that is right most
    /// of the time is worth less than one a reader can believe, because a
    /// single fabricated hop is enough to make every honest one unreadable.
    func inferredProvenance(for bookID: String) -> Provenance {
        if let rec = recommendations.first(where: { $0.bookID == bookID && $0.isIncoming }),
           let senderID = rec.fromReaderID {
            return Provenance(
                origin: .person(readerID: senderID, via: .directRecommendation),
                reason: rec.reason.text,
                date: Date()
            )
        }
        return Provenance(origin: .ownSearch, reason: nil, date: Date())
    }

    /// `nil` when Dewey can no longer answer for the ID — see
    /// `promoteForWrite`. Every caller already discarded the result; the
    /// optional is there so a refused write cannot be mistaken for a saved
    /// one.
    @discardableResult
    func save(_ bookID: String, status: ReadingStatus = .wantToRead, provenance: Provenance, note: String? = nil) -> LibraryEntry? {
        guard promoteForWrite(bookID) else { return nil }
        if let existing = entry(for: bookID) {
            setStatus(status, for: bookID)
            return existing
        }
        let entry = LibraryEntry(
            id: UUID().uuidString, bookID: bookID, status: status,
            provenance: provenance, note: note, savedAt: Date()
        )
        library.append(entry)
        persist()
        return entry
    }

    func setStatus(_ status: ReadingStatus, for bookID: String) {
        guard promoteForWrite(bookID) else { return }
        if let i = library.firstIndex(where: { $0.bookID == bookID }) {
            library[i].status = status
        } else {
            save(bookID, status: status, provenance: Provenance(origin: .ownSearch, reason: nil, date: Date()))
            return
        }
        persist()
    }

    func remove(_ bookID: String) {
        library.removeAll { $0.bookID == bookID }
        diary.removeAll { $0.bookID == bookID }
        persist()
    }

    func setNote(_ note: String?, for bookID: String) {
        guard promoteForWrite(bookID) else { return }
        guard let i = library.firstIndex(where: { $0.bookID == bookID }) else { return }
        library[i].note = (note?.isEmpty ?? true) ? nil : note
        persist()
    }

    // MARK: - Diary

    /// Every entry, newest first.
    var diaryEntries: [DiaryEntry] {
        diary.sorted { $0.loggedOn > $1.loggedOn }
    }

    /// Grouped into months for the diary view. A record, not a scoreboard —
    /// there are no totals attached to these groups on purpose.
    var diaryByMonth: [(label: String, entries: [DiaryEntry])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: diaryEntries) { entry -> DateComponents in
            cal.dateComponents([.year, .month], from: entry.loggedOn)
        }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return groups
            .compactMap { key, value -> (Date, String, [DiaryEntry])? in
                guard let date = cal.date(from: key) else { return nil }
                return (date, f.string(from: date), value.sorted { $0.loggedOn > $1.loggedOn })
            }
            .sorted { $0.0 > $1.0 }
            .map { ($0.1, $0.2) }
    }

    /// `nil` when the write was refused — see `promoteForWrite`.
    ///
    /// **Only the newest reading may set the library's status**, which is the
    /// correction here. This used to push `entry.status` into the library
    /// unconditionally, on the reasonable-sounding rule that "the log is the
    /// authority on state" — true of the *latest* log and false of any other.
    /// The diary is explicitly a history with several entries per book
    /// (`DiaryEntry`), and it is editable: opening a 2019 entry to fix a typo
    /// and saving it re-asserted that entry's status, so a book finished last
    /// year and currently being reread silently dropped from Reading back to
    /// Finished — with nothing on screen connecting the two, because the reader
    /// was editing prose at the time.
    ///
    /// `latestEntry(for:)` is read *after* the write so a brand-new entry is
    /// included in the comparison; it sorts by `loggedOn`, which is the date the
    /// reader filed the reading under, not the order the rows happen to sit in
    /// the array. Backdating a forgotten read therefore also leaves the current
    /// status alone, which is the same rule seen from the other side.
    @discardableResult
    func log(_ entry: DiaryEntry) -> DiaryEntry? {
        guard promoteForWrite(entry.bookID) else { return nil }
        if let i = diary.firstIndex(where: { $0.id == entry.id }) {
            diary[i] = entry
        } else {
            diary.append(entry)
        }
        if latestEntry(for: entry.bookID)?.id == entry.id,
           status(of: entry.bookID) != entry.status {
            setStatus(entry.status, for: entry.bookID)
        }
        persist()
        return entry
    }

    func deleteEntry(_ id: String) {
        diary.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Moments

    /// A book's captured lines, newest first — read top to bottom the way the
    /// diary is, most recent thought first.
    func moments(forBook bookID: String) -> [Moment] {
        moments.filter { $0.bookID == bookID }.sorted { $0.capturedAt > $1.capturedAt }
    }

    /// `nil` when the write was refused — see `promoteForWrite`. A blank
    /// capture is refused too: an empty Moment is not a thing a reader meant
    /// to keep, just a sheet closed with nothing typed into it.
    @discardableResult
    func captureMoment(bookID: String, text: String, pageNumber: Int?) -> Moment? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, promoteForWrite(bookID) else { return nil }
        let moment = Moment(
            id: UUID().uuidString, bookID: bookID, text: trimmed,
            pageNumber: pageNumber, capturedAt: Date()
        )
        moments.append(moment)
        persist()
        return moment
    }

    func deleteMoment(_ id: String) {
        moments.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Lists

    func lists(containing bookID: String) -> [BookList] {
        allLists.filter { $0.bookIDs.contains(bookID) && ($0.isPublic || $0.ownerID == "me") }
    }

    @discardableResult
    func createList(title: String, premise: String, isOrdered: Bool, isPublic: Bool) -> BookList {
        let list = BookList(
            id: UUID().uuidString, title: title, premise: premise,
            ownerID: "me", isOrdered: isOrdered, isPublic: isPublic,
            items: [], createdAt: Date(), updatedAt: Date()
        )
        myLists.insert(list, at: 0)
        persist()
        return list
    }

    func updateList(_ list: BookList) {
        guard let i = myLists.firstIndex(where: { $0.id == list.id }) else { return }
        var updated = list
        updated.updatedAt = Date()
        myLists[i] = updated
        persist()
    }

    func deleteList(_ id: String) {
        myLists.removeAll { $0.id == id }
        persist()
    }

    func addToList(_ listID: String, bookID: String, note: String? = nil) {
        guard promoteForWrite(bookID) else { return }
        guard let i = myLists.firstIndex(where: { $0.id == listID }) else { return }
        guard !myLists[i].bookIDs.contains(bookID) else { return }
        myLists[i].items.append(.init(id: UUID().uuidString, bookID: bookID, note: note))
        myLists[i].updatedAt = Date()
        persist()
    }

    func removeFromList(_ listID: String, bookID: String) {
        guard let i = myLists.firstIndex(where: { $0.id == listID }) else { return }
        myLists[i].items.removeAll { $0.bookID == bookID }
        myLists[i].updatedAt = Date()
        persist()
    }

    /// Drag reorder, applied to the stored list rather than to a draft.
    ///
    /// The list *detail* can reorder now, not only the editor sheet — a reader
    /// arranging an argument wants to see the argument, at full size, with the
    /// covers and the notes, not a 34pt row in a grouped form. The editor keeps
    /// its own copy for the fields it edits; this is the direct path.
    func moveInList(_ listID: String, from offsets: IndexSet, to destination: Int) {
        guard let i = myLists.firstIndex(where: { $0.id == listID }) else { return }
        myLists[i].items.move(fromOffsets: offsets, toOffset: destination)
        myLists[i].updatedAt = Date()
        persist()
    }

    /// The one-line "why this one is here". Empty clears it rather than storing
    /// a blank, so `note(for:)` keeps meaning "there is something to read".
    func setListNote(_ note: String?, listID: String, bookID: String) {
        guard let i = myLists.firstIndex(where: { $0.id == listID }),
              let j = myLists[i].items.firstIndex(where: { $0.bookID == bookID }) else { return }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        myLists[i].items[j].note = (trimmed?.isEmpty ?? true) ? nil : trimmed
        myLists[i].updatedAt = Date()
        persist()
    }

    /// Every book the reader has shelved, most recently added first — the first
    /// thing a list picker should offer, because a list is usually assembled out
    /// of books you already have an opinion about.
    var libraryBooks: [Book] {
        library.sorted { $0.savedAt > $1.savedAt }.map { book($0.bookID) }
    }

    /// Candidates for a list picker: what you have read or shelved first, then
    /// the rest of what Dewey holds, minus anything already in the list.
    ///
    /// Local only, deliberately. Adding a book to a list is a durable write, and
    /// the import-on-durable-action rule means a catalogue result has to be
    /// promoted before it can be filed — which `addToList` already does through
    /// `promoteForWrite`. The picker's job is to make the *common* case instant,
    /// and the common case is a book Dewey already knows.
    func listCandidates(excluding existing: [String], query: String) -> [Book] {
        let taken = Set(existing)
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let mine = libraryBooks.map(\.id)
        let ordering = Dictionary(uniqueKeysWithValues: mine.enumerated().map { ($1, $0) })
        return books
            .filter { !taken.contains($0.id) }
            .filter {
                q.isEmpty
                    || $0.title.lowercased().contains(q)
                    || $0.author.lowercased().contains(q)
                    || ($0.series?.lowercased().contains(q) ?? false)
            }
            // Yours first, in library order; everything else alphabetically
            // behind them. `.max` puts non-library books after every library
            // one without a second sort key fighting the first.
            .sorted {
                let a = ordering[$0.id] ?? Int.max
                let b = ordering[$1.id] ?? Int.max
                return a == b ? $0.title < $1.title : a < b
            }
    }

    // MARK: - Your Ranking (§19)

    /// One-based position in Your Ranking, or `nil` if the book was never
    /// placed.
    func rank(of bookID: String) -> Int? { ranking.rank(of: bookID) }

    /// The denominator every position is quoted against. "No. 1" alone is
    /// unreadable — of what? — and No. 1 of 3 is a different claim from
    /// No. 1 of 300.
    var rankedCount: Int { ranking.count }

    /// Records the result of an insertion or a re-placement.
    ///
    /// The order array can carry a book placed straight from the log flow; every
    /// ID in it must survive a relaunch once the ranking does. All or nothing,
    /// and resolvability is checked before anything is promoted — a ranking is
    /// one ordered claim, and saving it with a hole in the middle would be worse
    /// than not saving it.
    func placeInRanking(_ bookID: String, order: [String], comparisons: Int) {
        guard order.allSatisfy(canResolve) else { return }
        for id in order { _ = promoteForWrite(id) }
        ranking.apply(order: order, placing: bookID, comparisons: comparisons, on: Date())
        persist()
    }

    /// Takes a book out of the order without placing it anywhere — the first
    /// half of a re-placement, so an insertion never compares a book with
    /// itself.
    func unplaceFromRanking(_ bookID: String) {
        guard ranking.contains(bookID) else { return }
        ranking.remove(bookID)
        persist()
    }

    func setRankingPublic(_ isPublic: Bool) {
        guard isRankingPublic != isPublic else { return }
        isRankingPublic = isPublic
        persist()
    }

    // MARK: Filtering

    /// The filters worth offering, derived from the books already in the order.
    ///
    /// Only chips that would actually hide something are built: a filter that
    /// returns the whole list, or one book, is a control that costs a tap and
    /// answers nothing. Genres before years before authors, which is the order
    /// of how often a reader wants each.
    ///
    /// **Takes the ranking rather than reading `self.ranking`**, so a stranger's
    /// list filters exactly like yours. Browsing someone else's taste and being
    /// unable to ask "what about their science fiction" is the question the
    /// whole artifact exists to answer.
    func rankingFilters(for ranking: PersonalRanking) -> [RankingFilter] {
        let ranked = ranking.order.map { book($0) }
        guard ranked.count > 2 else { return [.all] }

        var filters: [RankingFilter] = [.all]

        let genres = Dictionary(grouping: ranked.flatMap(\.genres), by: { $0 })
            .filter { $0.value.count >= 2 && $0.value.count < ranked.count }
            .keys.sorted()
        filters += genres.map { .genre($0) }

        let years = Dictionary(grouping: ranked.compactMap(\.year), by: { $0 })
            .filter { $0.value.count >= 2 && $0.value.count < ranked.count }
            .keys.sorted(by: >)
        filters += years.map { .year($0) }

        let authors = Dictionary(grouping: ranked.map(\.author), by: { $0 })
            .filter { $0.value.count >= 2 && $0.value.count < ranked.count }
            .keys.sorted()
        filters += authors.map { .author($0) }

        return filters
    }

    /// **The master order with rows hidden — never a re-ordering** (§19).
    ///
    /// Returns positions as well as IDs, and the position is the book's place in
    /// the *whole* ranking. A filtered view that renumbered from 1 would read as
    /// a second ranking of that genre, which is the thing this file stopped
    /// having five of.
    func rankedBooks(in ranking: PersonalRanking, matching filter: RankingFilter) -> [(position: Int, bookID: String)] {
        ranking.order.enumerated().compactMap { offset, id in
            let entry = book(id)
            let keep: Bool
            switch filter {
            case .all: keep = true
            case .genre(let g): keep = entry.genres.contains(g)
            case .year(let y): keep = entry.year == y
            case .author(let a): keep = entry.author == a
            }
            return keep ? (offset + 1, id) : nil
        }
    }

    // MARK: Tuning

    /// **Books whose position rests on almost nothing** (§19).
    ///
    /// The trigger for offering to tune, and deliberately a property of the
    /// *data* rather than of the calendar. Nothing here counts days since the
    /// reader last opened the app, and nothing schedules anything: a book
    /// qualifies because Dewey genuinely does not know much about where it goes,
    /// which is a fact a reader can act on and verify.
    ///
    /// Two ways to qualify:
    ///
    /// - **Thinly placed.** One comparison or none. A book placed on a single
    ///   tap sits where that tap put it; the reader said nothing about the books
    ///   around it. This is most of the list on a young ranking, which is
    ///   correct — that is exactly when tuning is worth doing.
    /// - **Stale.** Placed more than a year ago in a ranking that has grown by
    ///   half since. Its comparisons were against a library that no longer
    ///   exists, so the position is a claim about books that were not there.
    ///
    /// Worst-supported first, so a short session spends its questions where they
    /// buy the most.
    var tuningCandidates: [String] {
        let now = Date()
        let year: TimeInterval = 365 * 24 * 60 * 60
        return ranking.order
            .filter { id in
                let comparisons = ranking.comparisons(for: id)
                if comparisons <= 1 { return true }
                guard let placed = ranking.placedAt(id) else { return true }
                return now.timeIntervalSince(placed) > year && comparisons < 4
            }
            .sorted { ranking.comparisons(for: $0) < ranking.comparisons(for: $1) }
    }

    /// **Every book the reader has finished, from either record.**
    ///
    /// The library and the diary can each know about a finish the other does
    /// not: shelving a book Finished writes a `LibraryEntry` and no diary
    /// entry, and logging a read you never shelved writes the reverse. Anything
    /// asking "have they read this" has to consult both, and this is the one
    /// place that decides so no caller has to remember. `entries(withStatus:)`
    /// reads only the library, which is right for the Library tab's filter and
    /// wrong for this question.
    ///
    /// Diary order first — most recently logged is the likeliest thing a reader
    /// wants to place.
    var finishedBookIDs: [String] {
        var seen = Set<String>()
        let logged = diary.filter { $0.status == .finished }
            .sorted { $0.loggedOn > $1.loggedOn }
            .map(\.bookID)
        let shelved = entries(withStatus: .finished).map(\.bookID)
        return (logged + shelved).filter { seen.insert($0).inserted }
    }

    func hasFinished(_ bookID: String) -> Bool {
        status(of: bookID) == .finished || diary.contains { $0.bookID == bookID && $0.status == .finished }
    }

    /// Finished books that were never placed at all.
    ///
    /// Not tuning — there is nothing to tune — but the same screen offers them,
    /// because "several new books have not been well positioned" is the reader's
    /// experience of both and splitting it into two flows would be an
    /// implementation detail worn on the outside.
    var unrankedFinishedBooks: [String] {
        finishedBookIDs.filter { !ranking.contains($0) }
    }

    /// Whether the ranking is worth revisiting at all. Drives whether the offer
    /// is drawn — an invitation with nothing behind it is a nag.
    var hasTuningWork: Bool {
        ranking.count >= 3 && !(tuningCandidates.isEmpty && unrankedFinishedBooks.isEmpty)
    }

    // MARK: Other readers

    /// Another reader's ranking, for their profile.
    ///
    /// Yours comes out of the store because you can change it; theirs is seeded
    /// and immutable, like their ratings and their Favorite Books. Your own
    /// privacy switch is applied at the one place it matters — see
    /// `visibleRanking(for:)`.
    func ranking(for reader: ReaderProfile) -> PersonalRanking {
        reader.isMe ? ranking : PersonalRanking(order: reader.rankedBookIDs)
    }

    /// The ranking a given viewer is allowed to see. Your own switch hides it
    /// from *others*, never from you — a control that made your own list vanish
    /// would read as having deleted it.
    func visibleRanking(for reader: ReaderProfile) -> PersonalRanking? {
        if reader.isMe { return ranking }
        guard !reader.rankedBookIDs.isEmpty else { return nil }
        return PersonalRanking(order: reader.rankedBookIDs)
    }

    // MARK: Migration

    /// Folds the pre-§19 `[RankingContext]` shape down to one ordering.
    ///
    /// The all-books context wins; if a file somehow has none, the longest one
    /// does, because length is the best available proxy for "the list the reader
    /// was actually building". Books that appeared **only** in a secondary
    /// ranking are dropped rather than appended: they were never compared
    /// against the main library, so any position given to them here would be
    /// invented. They come back as `unrankedFinishedBooks` and can be placed for
    /// real.
    ///
    /// Comparison counts did not exist before this version, so every migrated
    /// book restores as thinly-placed. That is honest — Dewey has no evidence
    /// about these positions — and it means a returning reader's first tuning
    /// session is offered the whole list, which is the correct offer.
    private static func migrated(from legacy: [LegacyRankingContext]) -> PersonalRanking {
        let master = legacy.first { $0.kind == .all }
            ?? legacy.max { $0.order.count < $1.order.count }
        guard let master else { return PersonalRanking() }
        return PersonalRanking(order: master.order)
    }

    /// The persisted shape of a pre-§19 ranking. **Decoding only.** Nothing
    /// constructs one and nothing writes one; it exists so a file written by an
    /// older build still loads.
    struct LegacyRankingContext: Codable {
        let id: String
        let title: String
        let kind: Kind
        let order: [String]

        enum Kind: Hashable, Codable {
            case all
            case year(Int)
            case genre(String)
            case author(String)
            case list(String)
        }
    }

    // MARK: - Community (seeded)

    func reviews(for bookID: String) -> [Review] {
        allReviews.filter { $0.bookID == bookID }
    }

    /// **"Friends" now means friends.**
    ///
    /// It was `all.sorted { appreciations }` — byte-identical to `.popular`, so
    /// the book page's *default* filter, the one Dewey argues hardest for, was
    /// a relabelled popularity sort. A reader who followed nobody still got
    /// five strangers under a chip reading "Friends", and a reader who followed
    /// one person had no way to see only them. Same class of untruth §13.7 fixed
    /// on the Edition and the Lists index; this was the third surface asserting
    /// a relationship it never checked.
    func reviews(for bookID: String, filter: ReviewFilter) -> [Review] {
        let all = reviews(for: bookID)
        switch filter {
        case .friends:  return all.filter { isFollowing($0.readerID) }.sorted { $0.date > $1.date }
        case .popular:  return all.sorted { $0.appreciations > $1.appreciations }
        case .recent:   return all.sorted { $0.date > $1.date }
        // Doubled with the scale (§12.2). Left at 4 and 3 these read "positive"
        // as everything above a 0.4 and "critical" as nothing at all.
        case .positive: return all.filter { ($0.rating?.value ?? 0) >= 8 }.sorted { ($0.rating?.value ?? 0) > ($1.rating?.value ?? 0) }
        case .critical: return all.filter { ($0.rating?.value ?? 10) <= 6 }.sorted { ($0.rating?.value ?? 0) < ($1.rating?.value ?? 0) }
        }
    }

    /// How many of this book's reviews come from someone you follow. The book
    /// page uses it to decide whether offering a Friends/Everyone split is
    /// honest — a filter that would return the same rows as the one beside it
    /// is a control that does nothing.
    func friendReviewCount(_ bookID: String) -> Int {
        reviews(for: bookID).filter { isFollowing($0.readerID) }.count
    }

    /// Readers you follow who have rated this book.
    ///
    /// **It never checked the follow set** — the doc comment said "you follow"
    /// and the body said `readers`, which is every seeded reader. On a fresh
    /// account that put four strangers under a heading claiming they were
    /// people you chose.
    func readersWhoRead(_ bookID: String) -> [ReaderProfile] {
        readers.filter { $0.ratings[bookID] != nil && isFollowing($0.id) }
    }

    func readersCurrentlyReading(_ bookID: String) -> [ReaderProfile] {
        SeedData.currentlyReading[bookID]?
            .compactMap { reader($0) }
            .filter { isFollowing($0.id) } ?? []
    }

    /// Readers **you follow** who chose this book as one of their four Favorite
    /// Books. Same correction as `readersWhoRead`: the book page introduces this
    /// line with a named person's claim on a scarce slot, and a stranger's slot
    /// is not a claim on you.
    func readersWhoFavourited(_ bookID: String) -> [ReaderProfile] {
        readers.filter { $0.favoriteBookIDs.contains(bookID) && isFollowing($0.id) }
    }

    /// Twenty half-point buckets over 0.1…10.0 (§12.3).
    ///
    /// **Never sourced from `SeedData.distributions`.** Those arrays are
    /// invented per-book totals in the thousands (`severance` sums to
    /// exactly 4,050) with no reader behind a single one of them — Dewey has
    /// four named demo readers, not four thousand. Drawing the histogram from
    /// that data would show a real-looking crowd shape for a crowd that does
    /// not exist, so this always reports empty and the page falls back to its
    /// honest "hasn't been scored" state.
    func ratingDistribution(_ bookID: String) -> [Int] {
        Array(repeating: 0, count: DistributionHistogram.bucketCount)
    }

    /// The Dewey Score — the loudest number on a book page (§12.1).
    ///
    /// Each bucket is averaged at its **top edge**, which is the value the
    /// bucket is named after: bucket 15 spans 7.6…8.0 and a reader calls that
    /// one "the eights". Using the true midpoint instead would shave 0.2 off
    /// every book and make a unanimous 10 display as 9.8.
    ///
    /// The arithmetic needed no migration and this was checked rather than
    /// assumed: `range(of:).upperBound` is `(offset + 1) × 0.5`, which ran
    /// 0.5…5.0 over ten buckets and runs 0.5…10.0 over twenty. The bound is
    /// taken from `DistributionHistogram` so the store and the histogram cannot
    /// drift on where the bin edges are.
    func communityAverage(_ bookID: String) -> Double? {
        let dist = ratingDistribution(bookID)
        let total = dist.reduce(0, +)
        guard total > 0 else { return nil }
        let sum = dist.enumerated().reduce(0.0) {
            $0 + DistributionHistogram.range(of: $1.offset).upperBound * Double($1.element)
        }
        return sum / Double(total)
    }

    func communityCount(_ bookID: String) -> Int {
        ratingDistribution(bookID).reduce(0, +)
    }

    /// The paired stat tiles beside the score (§12.5.5).
    ///
    /// Both are derived from the book's rating total rather than seeded
    /// separately, so the three numbers on a book page cannot contradict each
    /// other — a book with 148 raters can't be shown with four hundred reviews.
    ///
    /// The ratio varies per book, because a flat 12% across forty-one books
    /// reads as a formula the moment anyone compares two pages. It varies
    /// *deterministically*, from the id's bytes: a shelf count that changed on
    /// every launch would be worse than looking invented, it would look broken.
    func communityReviewCount(_ bookID: String) -> Int {
        let raters = communityCount(bookID)
        guard raters > 0 else { return 0 }
        // 9–16% of raters write anything at all. Roughly what public reading
        // sites see, and the gap between a rating and a paragraph is the point.
        let percent = 9 + Self.stableDigit(bookID, salt: 0x52, modulo: 8)
        return max(1, raters * percent / 100)
    }

    /// Always a multiple of the rater count: shelving costs nothing, and
    /// finishing a book and putting a number on it costs a fortnight.
    func communityShelfCount(_ bookID: String) -> Int {
        let raters = communityCount(bookID)
        guard raters > 0 else { return 0 }
        // 2.8×–4.4×, in tenths so the multiplier isn't visibly a whole number.
        let tenths = 28 + Self.stableDigit(bookID, salt: 0x53, modulo: 17)
        return raters * tenths / 10
    }

    /// FNV-1a over the id's bytes, salted per call site.
    ///
    /// Not `String.hashValue`: Swift seeds that per process, so a book would
    /// carry a different shelf count every launch and the same demo screenshot
    /// would never reproduce.
    private static func stableDigit(_ id: String, salt: UInt64, modulo: Int) -> Int {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325 ^ salt
        for byte in id.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100_0000_01b3
        }
        return Int(h % UInt64(modulo))
    }

    // MARK: - Search

    struct SearchResults {
        var books: [Book] = []
        var readers: [ReaderProfile] = []
        var lists: [BookList] = []
        var authors: [String] = []
        var series: [String] = []

        var isEmpty: Bool {
            books.isEmpty && readers.isEmpty && lists.isEmpty && authors.isEmpty && series.isEmpty
        }
    }

    func search(_ query: String) -> SearchResults {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return SearchResults() }

        var r = SearchResults()
        r.books = books.filter {
            $0.title.lowercased().contains(q)
                || $0.author.lowercased().contains(q)
                || $0.genres.contains { $0.lowercased().contains(q) }
                || ($0.series?.lowercased().contains(q) ?? false)
        }
        r.readers = readers.filter {
            $0.name.lowercased().contains(q) || $0.handle.lowercased().contains(q)
        }
        r.lists = allLists.filter {
            ($0.isPublic || $0.ownerID == "me") &&
            ($0.title.lowercased().contains(q) || $0.premise.lowercased().contains(q))
        }
        r.authors = Array(Set(books.map(\.author).filter { $0.lowercased().contains(q) })).sorted()
        r.series = Array(Set(books.compactMap(\.series).filter { $0.lowercased().contains(q) })).sorted()
        return r
    }

    func books(byAuthor author: String) -> [Book] {
        books.filter { $0.author == author }
    }

    func books(inSeries series: String) -> [Book] {
        books.filter { $0.series == series }.sorted { ($0.seriesPosition ?? 0) < ($1.seriesPosition ?? 0) }
    }

    // MARK: - Provenance

    /// The one sentence Dewey can honestly say about where a book came from —
    /// **only** when a person is genuinely behind it. `nil` for a self-found or
    /// outside-Dewey save: there is no name to state, and no chain to draw in
    /// its place. See `Provenance`'s own note on why this stops at one line.
    func personAttributionText(for provenance: Provenance) -> String? {
        guard case .person(let readerID, let via) = provenance.origin else { return nil }
        let name = reader(readerID)?.name ?? "A reader"
        switch via {
        // Their library, not their shelf — see `Provenance.Origin.Via`.
        case .shelf: return "From \(name)'s \(Vocabulary.library.lowercased())"
        case .list: return "From \(name)'s \(Vocabulary.list.lowercased())"
        case .review: return "From \(name)'s \(Judgement.ReviewCopy.title.lowercased())"
        case .directRecommendation: return "\(name) recommended it"
        }
    }

    /// Books other people picked up because of you. The giver's reward.
    var discoveredThroughMe: [(book: Book, reader: ReaderProfile)] {
        recommendations
            .filter { !$0.isIncoming && $0.status == .startedByRecipient }
            .compactMap { rec in
                guard let r = reader(rec.toReaderID) else { return nil }
                return (book(rec.bookID), r)
            }
    }

    // MARK: - Recommendations

    var incoming: [Recommendation] {
        recommendations.filter { $0.isIncoming && $0.status == .waiting }
    }

    var sent: [Recommendation] { recommendations.filter { !$0.isIncoming } }

    func send(bookID: String, to readerID: String, reason: Recommendation.Reason) {
        guard promoteForWrite(bookID) else { return }
        let rec = Recommendation(
            id: UUID().uuidString, bookID: bookID, fromReaderID: nil, toReaderID: readerID,
            reason: reason, sentAt: Date(), status: .waiting, reply: nil, reaction: nil
        )
        recommendations.append(rec)
        persist()
        if simulatesRecipientClosure {
            scheduleClosure(for: rec.id)
        }
    }

    func respond(to recID: String, accept: Bool) {
        guard let i = recommendations.firstIndex(where: { $0.id == recID }) else { return }
        recommendations[i].status = accept ? .saved : .declined
        persist()
    }

    func react(_ reaction: Recommendation.Reaction?, to recID: String) {
        guard let i = recommendations.firstIndex(where: { $0.id == recID }) else { return }
        recommendations[i].reaction = recommendations[i].reaction == reaction ? nil : reaction
        persist()
    }

    func reply(_ text: String, to recID: String) {
        guard let i = recommendations.firstIndex(where: { $0.id == recID }) else { return }
        recommendations[i].reply = text.isEmpty ? nil : text
        persist()
    }

    /// Closure travels to the *giver*, never the receiver. "Someone started the
    /// book you recommended" is a gift; "you started Elena's book — tell her?"
    /// is a debt, and Dewey does not send it.
    ///
    /// The delay is long on purpose. At six seconds it landed while the send
    /// confirmation was still on screen and read as the system echoing your own
    /// tap rather than a person acting.
    ///
    /// Only reachable through `send(bookID:to:reason:)` when
    /// `simulatesRecipientClosure` is true — without a real recipient behind
    /// the account, the same timing that keeps this from reading as an echo
    /// of your own tap is what would make it read as a stranger's.
    private func scheduleClosure(for recID: String) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard let self, let i = self.recommendations.firstIndex(where: { $0.id == recID }) else { return }
            self.recommendations[i].status = .startedByRecipient
            withAnimation(Theme.Motion.gentle) { self.pendingClosure = self.recommendations[i] }
            self.persist()
        }
    }

    func dismissClosure() {
        withAnimation(Theme.Motion.standard) { pendingClosure = nil }
    }

    // MARK: - Reset

    /// Back to the start of the world currently loaded, not always the demo.
    func reset() {
        if let activeAccount { Persistence.clear(for: activeAccount) }
        load(SeedData.world(for: world), as: world)
        pendingClosure = nil
        persist()
    }

    /// Deletes this account's on-disk reading data and clears memory — the
    /// local-beta-account reset's other half, alongside `SessionStore`
    /// forgetting the identity. Unlike `deactivate()`, which leaves the file
    /// alone so a real sign-out can find it again, this is for the case where
    /// signing back in reaches the *same* local stand-in identity (a fixed
    /// UUID) and must not resurrect what was just reset.
    func forgetActiveAccountData() {
        if let activeAccount { Persistence.clear(for: activeAccount) }
        deactivate()
    }

    // MARK: - Debug hooks

    // TEMPORARY — the doors DebugActions.swift needs into private state.
    func debugAppend(_ rec: Recommendation) { recommendations.append(rec); persist() }

    func debugUpdate(_ id: String, _ mutate: (inout Recommendation) -> Void) {
        guard let i = recommendations.firstIndex(where: { $0.id == id }) else { return }
        mutate(&recommendations[i])
        persist()
    }

    // MARK: - Persistence

    /// **A no-op while signed out**, which is load-bearing rather than tidy.
    /// Every mutating method on this class calls `persist()`, and without the
    /// guard a stray write during the signed-out window would create a file
    /// belonging to no account — the exact shape of the bug §18 removed.
    func persist() {
        guard let activeAccount else { return }
        Persistence.save(for: activeAccount, .init(
            library: library, diary: diary, myLists: myLists,
            rankings: nil, recommendations: recommendations,
            world: world, follows: follows, needsOnboarding: needsOnboarding,
            favoriteBookIDs: favoriteBookIDs, myRatings: myRatings,
            importedBooks: importedBooks,
            ranking: ranking, isRankingPublic: isRankingPublic,
            moments: moments
        ))
    }
}

// MARK: - Local persistence

/// A JSON file in Documents. No SwiftData, no CloudKit, no migrations — the
/// prototype needs state to survive a relaunch during a demo and nothing more.
///
/// **The filename carries the schema, so bump it whenever meaning changes** —
/// not only when the shape does. `v3` was the 0.1–10.0 rating scale (§12.2), and
/// it had to move even though `State` decodes a `v2` file without complaint:
/// every rating in a `v2` diary is a half-to-5 value, which is still inside the
/// new range, so an old file restores as a reader who quietly disliked every
/// book they have ever finished. A decode that succeeds and means something
/// else is worse than one that fails, and a rename is the whole fix — an
/// unreadable name is a fresh seed, which is the correct outcome here.
private enum Persistence {
    /// Optional fields are **optional on purpose**. Synthesised `Codable` does
    /// not fall back to a property's default when a key is missing, so
    /// declaring them non-optional would make every file written before they
    /// were added fail to decode — which reads to the user as "the app wiped my
    /// library" rather than "a field was added". Optional plus a coalesce at the
    /// read site keeps old files loading as the world they were.
    ///
    /// **`v4` is the Favorite / Favorite Books split** (§14). The filename had
    /// to move: `DiaryEntry.isPartOfMe` became `isFavorite`, so a `v3` file
    /// carries a key nothing reads and omits one `DiaryEntry` requires. That
    /// decode fails outright, which is the correct outcome — but it would fail
    /// as a mystery under the old name. Under a new one it is a fresh seed on
    /// purpose.
    struct State: Codable {
        let library: [LibraryEntry]
        let diary: [DiaryEntry]
        let myLists: [BookList]

        /// **The pre-§19 five-ranking shape. Read, never written.**
        ///
        /// Optional so a file this build wrote — which omits the key entirely —
        /// still decodes, and present so a file an older build wrote still
        /// carries its ordering into `ranking` via `DeweyStore.migrated(from:)`.
        /// Written as `nil` deliberately: keeping a synthesised copy in step
        /// would mean two persisted answers to "what is your ranking", which is
        /// the bug in miniature.
        let rankings: [DeweyStore.LegacyRankingContext]?

        let recommendations: [Recommendation]
        let world: WorldMode?
        let follows: Set<String>?
        let needsOnboarding: Bool?
        /// The four you feature on your profile. Optional so a file written
        /// before the split restores as the seeded four rather than as nothing.
        let favoriteBookIDs: [String]?
        /// Your pre-diary back catalogue. Optional so a file written before this
        /// key existed restores as the seeded world it was written in.
        ///
        /// It had to be persisted at all because `init()`'s restore branch never
        /// touched `myRatings`, leaving it at its property initialiser — the demo
        /// reader's fourteen. A fresh account with three diary entries came back
        /// from a relaunch reading "3 Read" above "14 books rated", with a "Keeps
        /// returning to" line drawn from a stranger's history (§13.7).
        let myRatings: [String: Double]?

        /// The imported shelf (§16). Optional so every file written before the
        /// catalog existed restores as the world it was. This key is the whole
        /// ballgame for imports: the diary, lists and rankings above all store
        /// bare IDs, and an ID whose book did not survive the relaunch is a
        /// reader's record pointing at nothing.
        let importedBooks: [String: Book]?

        /// **Your Ranking** (§19). Optional so a file written before it existed
        /// restores through `rankings` above rather than as an empty list.
        let ranking: PersonalRanking?

        /// Optional so an older file restores as visible, which is the default
        /// and the state that file was written in.
        let isRankingPublic: Bool?

        /// Captured quotes and thoughts (see `Moment`). Optional so a file
        /// written before the feature existed restores as no captures rather
        /// than failing to decode.
        let moments: [Moment]?
    }

    /// **One directory per account** (§18).
    ///
    /// This was a single file at `Documents/dewey-prototype-v4.json`, with no
    /// account in the path and no account inside it. That was correct for a
    /// prototype with one imaginary reader and became a data-leak the moment
    /// two real people could sign into the same phone: signing out left the file
    /// exactly where it was, and the next reader's store loaded it.
    ///
    /// A directory rather than a suffixed filename so that deleting an account's
    /// data is one `removeItem` and so anything added later — caches, exports —
    /// has an obvious home that is already scoped correctly.
    private static func directory(for account: UUID) -> URL {
        URL.documentsDirectory
            .appending(path: "accounts", directoryHint: .isDirectory)
            .appending(path: account.uuidString, directoryHint: .isDirectory)
    }

    /// **`v5` is the account scoping**, and the version had to move even though
    /// the decoded shape is identical to `v4`. The rule at the top of this type
    /// is that the filename tracks *meaning*, not structure: a `v4` file is the
    /// reading record of nobody in particular, and silently adopting one into
    /// the first account that happens to sign in would hand a stranger's diary
    /// to a real reader. The old file is never read. It is also never deleted —
    /// it is somebody's actual reading history, and quietly destroying it would
    /// be the opposite mistake.
    private static func url(for account: UUID) -> URL {
        directory(for: account).appending(path: "state-v5.json")
    }

    static func save(for account: UUID, _ state: State) {
        do {
            try FileManager.default.createDirectory(
                at: directory(for: account), withIntermediateDirectories: true
            )
            try JSONEncoder().encode(state).write(to: url(for: account), options: .atomic)
        } catch {
            print("Dewey: could not persist — \(error.localizedDescription)")
        }
    }

    static func load(for account: UUID) -> State? {
        guard let data = try? Data(contentsOf: url(for: account)) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    static func clear(for account: UUID) {
        try? FileManager.default.removeItem(at: directory(for: account))
    }

    // MARK: - The pre-account file

    private static var legacyURL: URL {
        URL.documentsDirectory.appending(path: "dewey-prototype-v4.json")
    }

    /// Where an adopted file is parked (§20).
    ///
    /// **Renamed, not deleted, and that is what makes adoption one-time.**
    /// "One-time" has to mean the offer stops being made — otherwise the same
    /// file could be adopted into a second account, which is the original leak
    /// wearing a button. Moving it aside achieves that: `legacyFileExists` stops
    /// finding it, so the affordance disappears. Deleting would achieve it too,
    /// and would also throw away somebody's actual reading history on the
    /// strength of a single tap. The bytes stay, one `mv` from being recovered.
    private static var retiredLegacyURL: URL {
        URL.documentsDirectory.appending(path: "dewey-prototype-v4.adopted.json")
    }

    /// What the account's own file is moved to before an adoption overwrites it.
    ///
    /// A single slot rather than a timestamped series: adoption retires the
    /// source file, so it can happen at most once per account and there can only
    /// ever be one thing to have replaced.
    private static func replacedURL(for account: UUID) -> URL {
        directory(for: account).appending(path: "state-v5.replaced.json")
    }

    /// Whether a pre-account file is sitting on disk unreachable. Surfaced in
    /// the debug menu so its existence is stated rather than discovered.
    static var legacyFileExists: Bool {
        FileManager.default.fileExists(atPath: legacyURL.path())
    }

    /// Decodes it without applying it, so the reader can be told what is in the
    /// file before deciding. Nil if it is absent or no longer decodable — a
    /// file this build cannot read is one it must not offer to adopt.
    static func loadLegacy() -> State? {
        guard let data = try? Data(contentsOf: legacyURL) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    /// Moves the account's current file aside. Returns false only if a file was
    /// there and could not be moved — in which case the caller must not go on to
    /// overwrite it.
    static func setAsideCurrentFile(for account: UUID) -> Bool {
        let current = url(for: account)
        guard FileManager.default.fileExists(atPath: current.path()) else { return true }
        do {
            try? FileManager.default.removeItem(at: replacedURL(for: account))
            try FileManager.default.moveItem(at: current, to: replacedURL(for: account))
            return true
        } catch {
            print("Dewey: could not set aside the current file — \(error.localizedDescription)")
            return false
        }
    }

    /// Retires the pre-account file so the offer is not made twice.
    @discardableResult
    static func retireLegacyFile() -> Bool {
        do {
            try? FileManager.default.removeItem(at: retiredLegacyURL)
            try FileManager.default.moveItem(at: legacyURL, to: retiredLegacyURL)
            return true
        } catch {
            print("Dewey: could not retire the pre-account file — \(error.localizedDescription)")
            return false
        }
    }
}
