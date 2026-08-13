import Foundation

/// Who put a book in your library, and why — captured once, at save time,
/// and never guessed afterward.
///
/// **Storage only.** The book page and the library row read this to say one
/// true thing when a person is genuinely behind the save — "Priya
/// recommended it," "From Priya's list" — and say nothing otherwise. There is
/// no rendered chain: a multi-hop "how it got to you" diagram used to draw
/// from this type, and it was removed because Dewey can answer "who sent
/// this" but not "how did this really reach you" — most saves have no
/// person behind them at all, and the app has no way to tell "found via
/// search" from "heard about it at a party" from "saw it on a shelf".
/// Guessing either would be exactly the kind of fabricated hop this type is
/// built to avoid.
///
/// Deliberately a small enum, not an attribution graph. The prototype needs to
/// answer "who surfaced this and why", not model an arbitrary chain of custody.
struct Provenance: Hashable, Codable {
    let origin: Origin
    /// Present when the origin carried an explicit reason — a direct
    /// recommendation, or a list with a premise.
    let reason: String?
    let date: Date

    enum Origin: Hashable, Codable {
        /// A person, and the surface they were on when you found it.
        case person(readerID: String, via: Via)
        /// You found it yourself, inside Dewey.
        case ownSearch
        /// You found it out in the world. The single-player case, and the one
        /// that makes a want-to-read list worth keeping.
        case outside(label: String)

        /// **The raw values are storage, the phrases are the product**, and the
        /// two have been allowed to diverge twice now.
        ///
        /// `shelf` keeps its spelling because every saved `Provenance` on disk
        /// carries the string "shelf"; renaming it would silently fail to decode
        /// a reader's whole library. What it *says* moved anyway: "from their
        /// shelf" was one of three live meanings of a word `Vocabulary` had
        /// already retired, and the thing it refers to is the reader's library.
        ///
        /// `review` is the same trade in the other direction. The case is now
        /// spelled for the product — a Reflection became a Review on 2026-08-09
        /// — and pinned to the raw value `"reflection"`, which is what is already
        /// written in every provenance record on every device. A `String` enum
        /// encodes its raw value, not its case name, so this one line is the
        /// whole of what keeps those files readable.
        enum Via: String, Hashable, Codable {
            case shelf
            case list
            case review = "reflection"
            case directRecommendation

            var phrase: String {
                switch self {
                case .shelf: "from their \(Vocabulary.library.lowercased())"
                case .list: "from their \(Vocabulary.list.lowercased())"
                case .review: "from their \(Judgement.ReviewCopy.title.lowercased())"
                case .directRecommendation: "recommended it to you"
                }
            }
        }
    }

    var readerID: String? {
        if case .person(let id, _) = origin { return id }
        return nil
    }

    var isFromAPerson: Bool { readerID != nil }
}
