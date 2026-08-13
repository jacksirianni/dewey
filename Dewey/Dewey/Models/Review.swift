import Foundation

/// A published piece of writing about a book.
///
/// **This was a `Reflection` until 2026-08-09, and the argument for that name
/// was half right.** The claim was that the register is different — Dewey wants
/// what a book did to you, not a verdict rendered for an audience — and that is
/// still exactly what the product asks for. What the old name got wrong is that
/// a *word* cannot carry a register. Nobody calls the thing they write under a
/// book a reflection; the object was named after the tone the app hoped for,
/// which meant a reader had to work out what was being asked before they could
/// answer it. The walkthrough's own notes listed that word among the ones to
/// watch for exactly this reason, alongside "provenance" and "edition".
///
/// The register now lives where register actually lives — in the prompt. The
/// composer still asks **"What did it do to you?"**, the section is **Reviews**,
/// and the action is **Write a review**. A reader knows immediately what kind of
/// object they are making, and is still asked an expressive question about it.
///
/// **The rename is user-facing and stops at the storage layer.** `Provenance`
/// still writes the raw value `"reflection"` and `DiaryEntry` still writes the
/// coding keys `"reflection"`, `"reflectionIsSpoiler"` and `"reflectionIsDraft"`,
/// because a reader's saved library is worth more than internal tidiness — see
/// both types for the mappings that keep every existing file decoding.
///
/// It behaves like a review in every other respect too: it carries a rating, it
/// can be filtered and sorted, and it can spoil.
struct Review: Identifiable, Hashable, Codable {
    let id: String
    let bookID: String
    let readerID: String
    let text: String
    var rating: Rating?
    var isSpoiler: Bool = false
    var date: Date
    /// How many readers marked this as useful. Shown as a soft count on the
    /// review itself and never aggregated into a profile total — the point
    /// is to sort good writing to the top, not to score people.
    var appreciations: Int = 0
    /// Whether the writer marked this book a Favorite. Not their profile four.
    var isFavorite: Bool = false

    var preview: String {
        text.count <= 180 ? text : String(text.prefix(180)) + "…"
    }
}

/// How the community section on a book page is sliced.
///
/// Letterboxd splits "popular" and "recent" and that split alone does most of
/// the work — one answers "what's the best take", the other "what's happening".
/// Friends first is Dewey's addition, and it is the default, because a named
/// person you trust outranks a thousand strangers.
enum ReviewFilter: String, CaseIterable, Identifiable {
    case friends, popular, recent, positive, critical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friends: "Friends"
        case .popular: "Popular"
        case .recent: "Recent"
        case .positive: "Positive"
        case .critical: "Critical"
        }
    }
}

/// A short, unwritten reaction to a book. The quiet reader's entire vocabulary
/// — someone who will never write three paragraphs will still tap once.
enum ShortReaction: String, Codable, Hashable, CaseIterable, Identifiable {
    case stayedWithMe, couldNotPutDown, notForMe, madeMeCry, changedMyMind, wantedMore

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stayedWithMe: "Stayed with me"
        case .couldNotPutDown: "Couldn't put it down"
        case .notForMe: "Not for me"
        case .madeMeCry: "Made me cry"
        case .changedMyMind: "Changed my mind"
        case .wantedMore: "Wanted more"
        }
    }
}
