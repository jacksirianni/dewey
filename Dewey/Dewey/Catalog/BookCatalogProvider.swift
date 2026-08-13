import Foundation

/// The seam between Dewey and whatever catalog is answering for it (§16).
///
/// Dewey's is the Letterboxd arrangement: an external catalog owns works,
/// editions and covers; Dewey owns readers, ratings, diaries, lists, rankings
/// and everything else with an opinion in it. Open Library is the first
/// provider behind this seam, not a permanent backbone — its own guidelines
/// discourage being a high-traffic third-party backend, and the protocol
/// exists so a future source can replace or supplement it without the rest of
/// the app noticing. One protocol, one implementation, no speculative tower.
///
/// What crosses the seam is normalized — these types, not provider-shaped
/// JSON. A view that learns what Open Library's `cover_i` is called has
/// already married it.
protocol BookCatalogProvider: Sendable {
    /// Free-text search, cheapest first look. Results carry only what a
    /// results row needs; the full record costs a second question.
    func search(_ query: String) async throws -> [CatalogSearchResult]

    /// The fuller record for one work — description and subjects, the fields
    /// search results never include.
    func work(_ workID: String) async throws -> CatalogWork
}

/// What a search hit knows before anyone has asked for the whole work.
///
/// Optional almost everywhere, because the catalog genuinely does not know —
/// and Dewey renders absences rather than inventing values (§4.9 all the way
/// down).
struct CatalogSearchResult: Identifiable, Hashable, Sendable {
    /// The provider's work identifier (e.g. `"OL45883W"`). An attribute of
    /// the result, never Dewey's identity — see `Book.openLibraryWorkID`.
    let workID: String
    let title: String
    let author: String?

    /// The provider's identifiers for everyone credited on the work.
    ///
    /// Carried because names are not identity and the credit list is not
    /// ordered by importance: Open Library holds a second work record for
    /// *Red Rising* whose first credited name is the audiobook's narrator.
    /// Two records naming the same person can be recognised as the same book
    /// through these where the strings would never have matched.
    let authorKeys: [String]

    let firstPublishYear: Int?

    /// Provider cover reference, when the catalog has a jacket at all.
    let coverID: Int?

    /// The edition the cover came from, when it came from a specific one
    /// rather than the work as a whole. Recorded so the stored book can say
    /// which edition it is quoting.
    let coverEditionID: String?
    /// Roughly how reprinted the work is. Feeds `Book.Reach`.
    let editionCount: Int?

    var id: String { workID }
}

/// The record a work fetch returns — the fields worth a second request.
struct CatalogWork: Sendable {
    let workID: String
    let description: String?
    let subjects: [String]

    /// Cover references on the work record. Carried so a book imported before
    /// the catalog had a jacket can gain one later: without it, a book whose
    /// search hit lacked `cover_i` would keep its typeset cover forever, and
    /// no refresh — TTL, manual, or otherwise — could ever change that.
    let coverIDs: [Int]
}
