import SwiftUI

/// A book as a complete cultural object.
///
/// Expanded from the walking prototype's four fields because a book page that
/// can't tell you the translator, the series position, or how long it is isn't
/// a destination — it's a stub. Letterboxd's film pages feel complete; this is
/// the books equivalent of that completeness.
///
/// Still not an edition model. Editions matter for passages and page numbers,
/// and the prototype has neither — `format` on a diary entry covers "how I read
/// it", which is the only edition question that actually changes the record.
struct Book: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let author: String

    /// First publication year, and `nil` where it isn't known. Optional since
    /// the catalog arrived: Open Library sometimes has no
    /// `first_publish_year`, and the app does not invent one.
    let year: Int?
    let blurb: String
    let coverPalette: CoverPalette
    let reach: Reach

    // Catalog identity (§16).
    //
    // `id` is Dewey's and only Dewey's. Seed books keep their slugs; imported
    // books get an ID minted at first sight and stable thereafter. The
    // provider's identifiers ride along as attributes, because an external
    // catalog is a source Dewey quotes, not the authority on what a book *is*
    // — a provider swap must never orphan a diary.
    var openLibraryWorkID: String? = nil
    var openLibraryEditionID: String? = nil

    /// Open Library cover reference. When present, surfaces may fetch the real
    /// jacket; the typeset palette stays underneath as the loading state and
    /// the permanent cover for books the catalog has no image for.
    var remoteCoverID: Int? = nil

    /// When the catalog last answered for this book. `nil` for seed books,
    /// which were never fetched and never go stale.
    var catalogRefreshedAt: Date? = nil

    // Cultural object
    var series: String? = nil
    var seriesPosition: Int? = nil
    var genres: [String] = []
    var themes: [String] = []

    /// Named characters, for the books that have them.
    ///
    /// Empty for essays, poetry, short-story collections, and the novels whose
    /// narrator is unnamed on purpose. A cast list assembled to fill the row
    /// would be worse than no row: the details table is the one part of a book
    /// page a reader can check against the book in their hands.
    var characters: [String] = []

    /// Where and when, in one line. Same rule — omitted rather than guessed.
    var setting: String? = nil

    // Details
    var pageCount: Int? = nil
    var publisher: String? = nil

    /// Optional since the catalog arrived. The seed's forty-one are all
    /// English-language editions and say so; an imported book's language is
    /// whatever the catalog actually asserts, which at the work level is
    /// frequently nothing — a work with editions in forty languages has no
    /// single honest value, and the row is omitted rather than guessed.
    var language: String? = "English"
    var isbn: String? = nil

    /// The classification the app is named after (§12.5.7). Dewey had gone
    /// three builds without ever showing a Dewey number, which is the sort of
    /// thing you only notice when somebody finally draws the details table.
    ///
    /// Class-accurate rather than transcribed from one library's record. Real
    /// catalogues disagree below the second decimal and the same book carries
    /// different numbers in different systems; "895.735 — Korean fiction,
    /// 1945–1999" is true in a way a borrowed full call number would only
    /// look like.
    var deweyDecimal: String? = nil

    /// First publication to the day, and `nil` wherever that day isn't
    /// genuinely known.
    ///
    /// `year` covers all forty-one books; this covers the ones with a real date
    /// to print. Serialised Victorians have no single publication day, and a
    /// translated novel has two dates that mean different things — the seed
    /// leaves both blank rather than picking one and asserting it.
    var publishDate: Date? = nil

    /// Roughly how many editions exist. An order of magnitude, not a count:
    /// every source gives a different number, and the only signal a reader
    /// takes from it is "reprinted for a century" versus "one small-press run".
    var editionCount: Int? = nil

    // People beyond the author. Books are less collaborative than film, but the
    // translator in particular is a first-class taste signal and almost every
    // reading app buries them.
    var translator: String? = nil
    var narrator: String? = nil
    var illustrator: String? = nil
    var editor: String? = nil

    // Lateral movement — the rabbit hole
    var relatedBookIDs: [String] = []
    var adaptationNote: String? = nil

    var subtitleLine: String {
        var parts: [String] = []
        if !author.isEmpty { parts.append(author) }
        if let year { parts.append(String(year)) }
        if let series, let n = seriesPosition { parts.append("\(series) #\(n)") }
        else if let series { parts.append(series) }
        // Empty parts are dropped rather than joined, so a record with no
        // author — only `Book.missing` has one — reads as a bare title
        // instead of a stray middle dot.
        return parts.joined(separator: " · ")
    }

    /// The release-build answer for an ID nothing can resolve (§16).
    ///
    /// Says what it is instead of impersonating a real record — the failure
    /// this replaces was `books[0]`, which rendered every dangling reference
    /// as a confident copy of *The Employees*. Debug builds assert before
    /// this is ever reached; see `DeweyStore.book(_:)`.
    static func missing(_ id: String) -> Book {
        Book(
            id: id, title: "Unknown book", author: "", year: nil, blurb: "",
            coverPalette: CoverPalette(base: .slate, ink: .light),
            reach: .uncommon, language: nil
        )
    }

    /// Rough cultural ubiquity. Used to phrase overlap honestly — agreeing on a
    /// book everyone has read says less than agreeing on one few have.
    enum Reach: String, Codable, Hashable {
        case ubiquitous, known, uncommon

        var weight: Double {
            switch self {
            case .ubiquitous: 0.35
            case .known: 0.7
            case .uncommon: 1.0
            }
        }
    }
}

/// Typeset covers. No network, no image rights, and a consistent house style
/// beats a wall of mismatched jacket art.
struct CoverPalette: Hashable, Codable {
    let base: ColorToken
    let ink: InkTone

    enum ColorToken: String, Codable, Hashable, CaseIterable {
        case clay, moss, dusk, ochre, slate, plum, sea, bone, ink, rust

        var color: Color {
            switch self {
            case .clay:  Color(red: 0.76, green: 0.42, blue: 0.33)
            case .moss:  Color(red: 0.36, green: 0.45, blue: 0.34)
            case .dusk:  Color(red: 0.35, green: 0.36, blue: 0.52)
            case .ochre: Color(red: 0.81, green: 0.62, blue: 0.27)
            case .slate: Color(red: 0.35, green: 0.40, blue: 0.44)
            case .plum:  Color(red: 0.44, green: 0.29, blue: 0.42)
            case .sea:   Color(red: 0.27, green: 0.48, blue: 0.49)
            case .bone:  Color(red: 0.87, green: 0.84, blue: 0.77)
            case .ink:   Color(red: 0.18, green: 0.19, blue: 0.23)
            case .rust:  Color(red: 0.63, green: 0.30, blue: 0.22)
            }
        }
    }

    enum InkTone: String, Codable, Hashable {
        case light, dark

        var color: Color {
            switch self {
            case .light: Color(red: 0.97, green: 0.96, blue: 0.93)
            case .dark:  Color(red: 0.12, green: 0.11, blue: 0.10)
            }
        }
    }
}
