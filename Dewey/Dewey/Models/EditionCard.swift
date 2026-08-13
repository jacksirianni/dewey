import Foundation

/// One item in the Weekly Edition.
///
/// Weekly, not daily, and the arithmetic chose it rather than the taste: thirty
/// people reading twenty books a year produce about eleven finish-events a week
/// and about one and a half a day. A daily surface is empty most days; a weekly
/// one is an edition. It also makes silence legible — a quiet week reads as a
/// short edition rather than a broken screen.
///
/// Every card carries provenance. If we cannot say why an item is here and
/// whose taste it represents, it does not belong in the edition.
enum EditionCard: Identifiable, Hashable {

    /// Someone chose this for you, specifically. Highest claim on attention,
    /// so it opens the edition.
    case directRecommendation(recommendationID: String)

    /// A book from a list with a premise. The premise is the context.
    case fromList(readerID: String, listID: String, bookID: String)

    /// Someone wrote something short and worth reading about a book.
    case review(readerID: String, reviewID: String)

    /// Consolidated: several people you follow hold the same book. One card,
    /// not four — repetition in a feed reads as noise, and the fact that it is
    /// *several* people is itself the signal.
    case convergence(bookID: String, readerIDs: [String])

    /// One of the four books a reader chose to feature on their own profile
    /// (`ReaderProfile.favoriteBookIDs`). Not a rating, not a mention in
    /// passing — the deliberate, capped-at-four claim "this is who I am as a
    /// reader". Surfacing it here is the cheapest honest provenance the app
    /// has: no new judgement is invented, an existing one is just carried
    /// into the edition.
    case favoriteBook(readerID: String, bookID: String)

    /// A person, not a book. Sometimes the useful thing to surface is a mind.
    case readerSuggestion(readerID: String)

    var id: String {
        switch self {
        case .directRecommendation(let r): "rec-\(r)"
        case .fromList(let reader, let list, let book): "list-\(reader)-\(list)-\(book)"
        case .review(let reader, let r): "refl-\(reader)-\(r)"
        case .convergence(let book, _): "conv-\(book)"
        case .favoriteBook(let reader, let book): "fav-\(reader)-\(book)"
        case .readerSuggestion(let reader): "reader-\(reader)"
        }
    }

    /// Shown above each card. Never a timestamp — "3h ago" imports a currency
    /// books do not have, and would quietly turn a weekly rhythm into a race.
    var kicker: String {
        switch self {
        case .directRecommendation: "For you"
        case .fromList: "From a list"
        case .review: "Someone wrote"
        case .convergence: "Turning up more than once"
        case .favoriteBook: "One of their four"
        case .readerSuggestion: "A reader"
        }
    }
}

// MARK: - Who a card is about

extension EditionCard {
    /// The readers this card depends on.
    ///
    /// An edition is *"five things from the readers you follow"*, so a card
    /// whose people you do not follow has no business in it. Used by
    /// `DeweyStore.edition` to filter the seeded run against the reader's actual
    /// follow set (§13.7) — without which a fresh account was handed five cards
    /// from four strangers under a header claiming they were people it followed.
    ///
    /// `.readerSuggestion` is the deliberate exception and is handled at the
    /// call site: its entire purpose is to propose somebody the reader does
    /// *not* follow yet.
    var readerIDs: [String] {
        switch self {
        case .directRecommendation: []      // resolved through the recommendation
        case .fromList(let reader, _, _): [reader]
        case .review(let reader, _): [reader]
        case .convergence(_, let readers): readers
        case .favoriteBook(let reader, _): [reader]
        case .readerSuggestion: []
        }
    }

    var isReaderSuggestion: Bool {
        if case .readerSuggestion = self { return true }
        return false
    }

    var recommendationID: String? {
        if case .directRecommendation(let id) = self { return id }
        return nil
    }
}
