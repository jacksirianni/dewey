import Foundation

/// Where a book sits in your reading life — the book's **Status**.
///
/// Five states, not three. Paused and Did Not Finish are separate because
/// abandoning a book is a real act of taste — collapsing them into "not
/// finished" is what makes other reading apps feel like compliance software.
///
/// **One name per state, everywhere** (§13.3). These five titles are the only
/// strings the app may use for a status: the log sheet, the book page, the
/// Library filter, search rows, the diary and every accessibility label all
/// read from `title`. There is deliberately no abbreviated form — "Want" and
/// "DNF" used to exist for narrow rows and meant a reader saw three different
/// names for one state depending on where they were standing. A row too narrow
/// for "Did Not Finish" is a layout problem, not a vocabulary problem.
///
/// There is also deliberately no `Shelf` grouping. Paused and Did Not Finish
/// used to collapse into a Library-only bucket called "Set Down" — a word that
/// appeared nowhere else in the app, so a reader who marked a book Paused went
/// to the Library and could not find a Paused filter. The Library now filters
/// by these five states directly.
enum ReadingStatus: String, Codable, Hashable, CaseIterable, Identifiable {
    case wantToRead, reading, finished, paused, didNotFinish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wantToRead: "Want to Read"
        case .reading: "Reading"
        case .finished: "Finished"
        case .paused: "Paused"
        case .didNotFinish: "Did Not Finish"
        }
    }

    var symbol: String {
        switch self {
        case .wantToRead: "bookmark"
        case .reading: "book"
        case .finished: "checkmark"
        case .paused: "pause"
        case .didNotFinish: "xmark"
        }
    }

    /// What the Library says when this filter has nothing in it. Written so an
    /// empty Paused or Did Not Finish reads as permission rather than failure.
    var emptyLine: String {
        switch self {
        case .wantToRead: "Nothing saved yet. Books you keep will remember who sent them."
        case .reading: "Nothing in progress."
        case .finished: "Nothing finished yet."
        case .paused: "Nothing paused. Putting a book down is allowed."
        case .didNotFinish: "Nothing abandoned. That's allowed too."
        }
    }
}

enum ReadingFormat: String, Codable, Hashable, CaseIterable, Identifiable {
    case print, ebook, audiobook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .print: "Print"
        case .ebook: "Ebook"
        case .audiobook: "Audiobook"
        }
    }

    var symbol: String {
        switch self {
        case .print: "book.closed"
        case .ebook: "ipad"
        case .audiobook: "headphones"
        }
    }
}

/// Who can see a piece of writing.
enum Visibility: String, Codable, Hashable, CaseIterable, Identifiable {
    case onlyMe, followers, everyone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onlyMe: "Only me"
        case .followers: "People who follow me"
        case .everyone: "Everyone on Dewey"
        }
    }

    var symbol: String {
        switch self {
        case .onlyMe: "lock"
        case .followers: "person.2"
        case .everyone: "globe"
        }
    }
}

/// One dated act of reading.
///
/// A book can have several — a reread is a new entry, not an edit. That is the
/// whole reason the diary is worth keeping: it records that you read *Middlemarch*
/// at 22 and again at 34, and that you felt differently both times.
///
/// Nothing here is required except the book and the date. You can log a finish
/// with no rating, no review and no tags in about five seconds, and the
/// sheet never asks twice.
struct DiaryEntry: Identifiable, Hashable, Codable {
    let id: String
    let bookID: String

    var status: ReadingStatus
    var startedOn: Date?
    var finishedOn: Date?
    /// The date this entry files under in the diary. Defaults to the finish
    /// date, then to when it was logged.
    var loggedOn: Date

    var isReread: Bool = false
    var rating: Rating?
    /// **Favorite** — a book this reader loves. Deliberately separate from
    /// `rating` (see `Rating` for why) and deliberately separate from
    /// `ReaderProfile.favoriteBookIDs`, the four they feature on their profile.
    /// Marking this changes nothing on the profile; it is unlimited by design.
    var isFavorite: Bool = false

    /// The reader's own published writing about this reading.
    ///
    /// **Distinct from `privateNote`, permanently.** A review is something a
    /// reader may publish and other readers may find; a note is one line for
    /// themselves that never leaves the device. The rename of Reflection to
    /// Review did not merge them and must not: they are two objects with two
    /// audiences, and the composer asks for them in two different places.
    var review: String?
    var reviewIsSpoiler: Bool = false
    var reviewIsDraft: Bool = false
    /// **Private unless chosen otherwise.** The default is `.onlyMe`, not
    /// `.followers` — Dewey's rule is that a reflection is private until the
    /// reader explicitly shares it, and that has to hold for entries decoded
    /// from disk too, not just freshly created ones. See `init(from:)` below:
    /// a legacy entry — one persisted before this field existed, so its JSON
    /// has no `"visibility"` key — decodes to `.onlyMe`, not to this
    /// property's Swift-side default. (Swift's synthesized `Decodable` does
    /// **not** fall back to a stored property's default value for an absent
    /// key — it throws — so that fallback has to be written by hand.) Do not
    /// change this to `.followers`: doing so would make every pre-existing
    /// review "shared" the moment its entry is next decoded, with no action
    /// from the reader who wrote it.
    var visibility: Visibility = .onlyMe

    /// Private always, never published, never prompted for.
    var privateNote: String?

    var tags: [String] = []
    var format: ReadingFormat?

    var hasPublishedReview: Bool {
        guard let review, !review.isEmpty else { return false }
        return !reviewIsDraft && visibility != .onlyMe
    }

    var isLogged: Bool {
        status == .finished || status == .didNotFinish
    }

    // MARK: Codable

    /// **Stated rather than synthesised, so the rename could not eat a diary.**
    ///
    /// Synthesised `CodingKeys` are the property names, so renaming `reflection`
    /// to `review` on 2026-08-09 would have changed the on-disk key with it —
    /// and `review` is a non-optional-defaulted `String?`, so the decode would
    /// have *succeeded*, silently, with every review in every existing entry
    /// dropped to nil. That is the worst shape a migration can take: no error,
    /// no crash, just a reader's writing quietly gone.
    ///
    /// The three keys below are therefore pinned to their original spellings.
    /// Every other key is written out too, because a partial `CodingKeys` is not
    /// a thing — listing one means listing all — and because an enumerated set
    /// is the only version a future rename cannot break by accident.
    ///
    /// The encoded shape is byte-identical to what shipped. Only the Swift-side
    /// names moved.
    private enum CodingKeys: String, CodingKey {
        case id, bookID, status, startedOn, finishedOn, loggedOn
        case isReread, rating, isFavorite
        case review = "reflection"
        case reviewIsSpoiler = "reflectionIsSpoiler"
        case reviewIsDraft = "reflectionIsDraft"
        case visibility, privateNote, tags, format
    }
}

/// **Hand-written so a missing `visibility` key decodes private, not
/// shared.** Every other defaulted property here (`isReread`, `isFavorite`,
/// `reviewIsSpoiler`, `reviewIsDraft`, `tags`) is decoded the same
/// defensive way, for the same reason `CodingKeys` is stated rather than
/// synthesised: a struct cannot mix a synthesised decoder with a
/// hand-written one, so writing this at all means writing all of it.
/// Nothing here is a migration system — it is one `init` that reads a
/// fixed, already-shipped shape and falls back to each property's existing
/// Swift-side default when a key is absent. Only `visibility`'s fallback is
/// privacy-load-bearing; the rest just match what the property declaration
/// already says.
///
/// **In an extension, deliberately.** A custom initializer written inside
/// the struct's own body suppresses the compiler's memberwise initializer —
/// the one every call site (`LogSheet.buildEntry`, `SeedData.de`, onboarding,
/// `mutateLatestEntry`) uses to construct a `DiaryEntry` from named
/// arguments. An initializer added in an extension does not.
extension DiaryEntry {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        bookID = try c.decode(String.self, forKey: .bookID)
        status = try c.decode(ReadingStatus.self, forKey: .status)
        startedOn = try c.decodeIfPresent(Date.self, forKey: .startedOn)
        finishedOn = try c.decodeIfPresent(Date.self, forKey: .finishedOn)
        loggedOn = try c.decode(Date.self, forKey: .loggedOn)
        isReread = try c.decodeIfPresent(Bool.self, forKey: .isReread) ?? false
        rating = try c.decodeIfPresent(Rating.self, forKey: .rating)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        review = try c.decodeIfPresent(String.self, forKey: .review)
        reviewIsSpoiler = try c.decodeIfPresent(Bool.self, forKey: .reviewIsSpoiler) ?? false
        reviewIsDraft = try c.decodeIfPresent(Bool.self, forKey: .reviewIsDraft) ?? false
        // The privacy-critical fallback: absent means private, never shared.
        visibility = try c.decodeIfPresent(Visibility.self, forKey: .visibility) ?? .onlyMe
        privateNote = try c.decodeIfPresent(String.self, forKey: .privateNote)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        format = try c.decodeIfPresent(ReadingFormat.self, forKey: .format)
    }
}
