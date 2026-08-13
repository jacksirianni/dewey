import Foundation

/// A list.
///
/// The most under-served object in every reading app and the best rabbit hole
/// on Letterboxd. A list earns its place by having a **premise** — "My
/// Favourites" is a folder, "Books that made work feel strange" is an argument.
///
/// Ordered lists matter more than they look: putting things in an order forces a
/// claim, and a claim is what makes a list worth reading and worth arguing with.
///
/// **They are "ordered", not "ranked" (§19).** The word was `ranked` in every
/// user-facing string here, and `Judgement.RankingCopy.title` is now "Your
/// Ranking" — a single, app-wide, comparison-built ordering of everything the
/// reader has finished. A list badge reading "4 books · ranked" sitting one tab
/// from that is the "Shelves means two things" bug in a new place: a reader has
/// no way to know whether a ranked list is part of Your Ranking, feeds it, or
/// competes with it. It is none of those. A list is hand-arranged by dragging,
/// it is scoped to its own premise, and there can be any number of them.
struct BookList: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    /// One line. The argument the list is making.
    var premise: String
    var ownerID: String          // "me" for the user's own

    /// Whether the list's order is a claim, so rows get a numbered gutter and
    /// can be dragged.
    ///
    /// **The on-disk key is still `isRanked`.** Renaming the property to match
    /// the reader's word is the point of the change; renaming the *stored key*
    /// would fail the decode of every list already saved, to settle a question
    /// about vocabulary. Same trade `Rating` makes — see `CodingKeys`.
    var isOrdered: Bool
    var isPublic: Bool
    var items: [Item]
    let createdAt: Date
    var updatedAt: Date

    struct Item: Identifiable, Hashable, Codable {
        let id: String
        let bookID: String
        /// Why this one is here. Where the personality lives.
        var note: String?
    }

    var bookIDs: [String] { items.map(\.bookID) }
    var count: Int { items.count }

    var subtitle: String {
        var parts: [String] = ["\(count) book\(count == 1 ? "" : "s")"]
        if isOrdered { parts.append("ordered") }
        if !isPublic { parts.append("private") }
        return parts.joined(separator: " · ")
    }

    func note(for bookID: String) -> String? {
        items.first { $0.bookID == bookID }?.note
    }

    /// Stated so the on-disk shape is legible from the type, and so `isOrdered`
    /// keeps writing and reading the key it always has.
    private enum CodingKeys: String, CodingKey {
        case id, title, premise, ownerID, isPublic, items, createdAt, updatedAt
        case isOrdered = "isRanked"
    }

    func position(of bookID: String) -> Int? {
        guard isOrdered, let i = items.firstIndex(where: { $0.bookID == bookID }) else { return nil }
        return i + 1
    }
}
