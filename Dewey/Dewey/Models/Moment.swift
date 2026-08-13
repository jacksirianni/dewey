import Foundation

/// A line worth keeping, captured while the book is still open.
///
/// Deliberately distinct from `LibraryEntry.note` — one line, one per book,
/// overwritten every time it is edited — and from `DiaryEntry.review`,
/// written once the reading is over and usually about the whole book. A
/// Moment is neither: there can be as many as the reader takes, each dated to
/// when it actually happened, and none of them wait for Finished.
struct Moment: Identifiable, Hashable, Codable {
    let id: String
    let bookID: String
    var text: String
    /// Where the reader was when it happened. Optional — a moment taken from
    /// an audiobook or a borrowed copy has no page to name.
    var pageNumber: Int?
    let capturedAt: Date
}
