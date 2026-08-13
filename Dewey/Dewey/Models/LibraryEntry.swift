import Foundation

/// Your current relationship with one book.
///
/// The division of labour with `DiaryEntry` matters: this is **state** — where
/// the book sits right now and how it reached you. The diary is **history** —
/// dated acts of reading, one per read. Rating and review live on the
/// diary, because a reread can be rated differently from the first read and
/// flattening that loses the most interesting thing a reading record holds.
struct LibraryEntry: Identifiable, Hashable, Codable {
    let id: String
    let bookID: String
    var status: ReadingStatus
    /// The thing no other reading app has: how this book got here.
    var provenance: Provenance
    /// Optional, private, one line. Never prompted for.
    var note: String?
    var tags: [String] = []
    let savedAt: Date
}
