import Foundation

/// Where a catalog answer becomes a Dewey book (§16).
///
/// The rules are the seed's rules: what the catalog asserts is recorded, what
/// it doesn't know stays `nil`, and nothing is invented to make a page look
/// fuller. The one thing minted here that the catalog never supplied is the
/// Dewey ID — handed in by the store, which is the only party that knows
/// whether this work has been seen before.
extension Book {

    /// A search hit, normalized. Deliberately thin: search results carry no
    /// description and no subjects, and this does not pretend otherwise —
    /// `enriched(with:)` fills those in when the work record arrives.
    static func imported(from result: CatalogSearchResult, deweyID: String) -> Book {
        Book(
            id: deweyID,
            title: result.title,
            author: result.author ?? "Unknown author",
            year: result.firstPublishYear,
            blurb: "",
            coverPalette: .derived(from: result.workID),
            reach: .derived(fromEditionCount: result.editionCount),
            openLibraryWorkID: result.workID,
            // The edition is recorded only when the jacket actually came from
            // one, so `openLibraryEditionID` never implies a pinned edition
            // Dewey did not choose.
            openLibraryEditionID: result.coverEditionID,
            remoteCoverID: result.coverID,
            // The seed's forty-one carry "English" because they are known
            // English-language editions. A work is not an edition; its
            // language is omitted rather than guessed.
            language: nil,
            editionCount: result.editionCount
        )
    }

    /// The work record applied on top — description and subjects, plus the
    /// timestamp the refresh policy runs on. Identity and reader-visible
    /// choices (the Dewey ID, the palette) never change under enrichment; a
    /// book that swapped covers between two opens would read as a different
    /// book.
    func enriched(with work: CatalogWork, at date: Date = Date()) -> Book {
        var book = self
        if let description = work.description, !description.isEmpty {
            book = book.replacingBlurb(description)
        }
        if book.genres.isEmpty {
            book.genres = Self.genres(fromSubjects: work.subjects)
        }
        // Filled, never replaced. A book that arrived with a jacket keeps the
        // one the reader has already seen; a book that arrived without one can
        // gain it when the catalog does. The typeset palette is untouched
        // either way — it was derived from the work ID and it is what shows
        // underneath.
        if book.remoteCoverID == nil, let cover = work.coverIDs.first {
            book.remoteCoverID = cover
        }
        book.catalogRefreshedAt = date
        return book
    }

    /// `blurb` is a `let` — the seed's blurbs are hand-written and immutable
    /// on purpose. Enrichment is the one place a blurb legitimately arrives
    /// late, so the swap rebuilds the value rather than opening the field to
    /// every caller.
    private func replacingBlurb(_ text: String) -> Book {
        var copy = Book(
            id: id, title: title, author: author, year: year,
            blurb: text, coverPalette: coverPalette, reach: reach
        )
        copy.openLibraryWorkID = openLibraryWorkID
        copy.openLibraryEditionID = openLibraryEditionID
        copy.remoteCoverID = remoteCoverID
        copy.catalogRefreshedAt = catalogRefreshedAt
        copy.series = series
        copy.seriesPosition = seriesPosition
        copy.genres = genres
        copy.themes = themes
        copy.characters = characters
        copy.setting = setting
        copy.pageCount = pageCount
        copy.publisher = publisher
        copy.language = language
        copy.isbn = isbn
        copy.deweyDecimal = deweyDecimal
        copy.publishDate = publishDate
        copy.editionCount = editionCount
        copy.translator = translator
        copy.narrator = narrator
        copy.illustrator = illustrator
        copy.editor = editor
        copy.relatedBookIDs = relatedBookIDs
        copy.adaptationNote = adaptationNote
        return copy
    }

    /// Open Library subjects, filtered to the ones that mean something.
    ///
    /// Raw subjects are a midden — "New York Times bestseller",
    /// "nyt:trade_fiction_paperback=2019-01-27", "Accessible book" — and the
    /// genre rail derives its chips from whatever lands here. Only subjects
    /// with a Dewey-shaped genre equivalent survive, capped at three, in the
    /// catalog's order. A book whose subjects are all noise gets none, which
    /// is honest.
    private static func genres(fromSubjects subjects: [String]) -> [String] {
        var out: [String] = []
        for subject in subjects {
            guard let genre = genreMap[subject.lowercased()] else { continue }
            if !out.contains(genre) { out.append(genre) }
            if out.count == 3 { break }
        }
        return out
    }

    /// The vocabulary the seed already speaks, keyed by the subject spellings
    /// Open Library actually uses.
    private static let genreMap: [String: String] = [
        "fiction": "Fiction",
        "literary fiction": "Literary Fiction",
        "science fiction": "Science Fiction",
        "fantasy": "Fantasy",
        "fantasy fiction": "Fantasy",
        "horror": "Horror",
        "dystopia": "Dystopia",
        "dystopias": "Dystopia",
        "historical fiction": "Historical",
        "mystery": "Mystery",
        "detective and mystery stories": "Mystery",
        "thriller": "Thriller",
        "suspense": "Thriller",
        "romance": "Romance",
        "poetry": "Poetry",
        "essays": "Essays",
        "short stories": "Short Stories",
        "biography": "Biography",
        "autobiography": "Memoir",
        "memoir": "Memoir",
        "memoirs": "Memoir",
        "young adult fiction": "Young Adult",
        "graphic novels": "Graphic Novel",
        "comics & graphic novels": "Graphic Novel",
        "translations into english": "Translated",
    ]
}

extension Book {
    /// The catalog's jacket for this book, sized for the surface asking.
    ///
    /// On `Book` rather than in the cover view so the one thing the design
    /// layer knows about the catalog is that a book may have a picture — not
    /// which host serves it or how its URLs are spelled.
    func remoteCoverURL(width: CGFloat) -> URL? {
        guard let remoteCoverID else { return nil }
        // The threshold is in points and the jackets are in pixels: Open
        // Library's M is about 180px wide, which covers a 60pt frame at 3×
        // and nothing larger. Anything above that asks for L — a 84pt strip
        // cover needs 252px on the phones this ships to, and an upscaled M
        // beside a crisp typeset cover looks like a mistake.
        return OpenLibraryClient.coverURL(remoteCoverID, size: width <= 60 ? .medium : .large)
    }
}

extension Book.Reach {
    /// An order of magnitude, read off the only ubiquity signal a search hit
    /// carries. Reprinted for a century versus one small-press run — the same
    /// judgement the seed makes by hand.
    static func derived(fromEditionCount count: Int?) -> Book.Reach {
        switch count ?? 0 {
        case ..<16: .uncommon
        case ..<101: .known
        default: .ubiquitous
        }
    }
}

extension CoverPalette {
    /// A stable typeset cover for a book Dewey has never hand-set.
    ///
    /// FNV-1a over the provider's work identifier — the same trick
    /// `DeweyStore.stableDigit` uses, for the same reason: `String.hashValue`
    /// is seeded per process, and a book that changed color every launch
    /// would read as broken rather than designed. Derived from the provider
    /// ID rather than the Dewey ID so the palette is decided the moment the
    /// result row renders, before any Dewey ID exists.
    static func derived(from providerID: String) -> CoverPalette {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in providerID.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100_0000_01b3
        }
        let tokens = ColorToken.allCases
        let base = tokens[Int(h % UInt64(tokens.count))]
        return CoverPalette(base: base, ink: base.legibleInk)
    }
}

private extension CoverPalette.ColorToken {
    /// The ink each base can actually carry. The pairings the seed uses:
    /// light ink on the dark grounds, dark ink on the pale ones.
    var legibleInk: CoverPalette.InkTone {
        switch self {
        case .bone, .ochre: .dark
        default: .light
        }
    }
}
