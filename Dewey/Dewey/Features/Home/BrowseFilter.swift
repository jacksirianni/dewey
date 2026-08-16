import Foundation

/// What the reader has asked the catalog for, in the reader's own words.
///
/// One value, three axes, and a `CatalogBrowseQuery` at the end of it. This is
/// the whole reason Browse is a single screen rather than a page per
/// discovery concept: "Popular this week", "Popular · Fantasy" and "Popular ·
/// Horror · 1980s" are not three surfaces, they are three values of this type.
/// A new axis — a language, a length, a translator — is a field here and a
/// control on `BrowseBooksView`, not another screen.
///
/// **The lens is fixed at Popular for now, and it is not a field.** There is
/// exactly one thing Dewey can honestly sort a shelf by today, which is how
/// widely a book is read *in the catalog it is quoting*. Adding an enum with
/// one case would be a promise that the second case is coming; when there is a
/// second honest lens, this is where it goes.
struct BrowseFilter: Hashable {

    /// How far back "popular" reaches.
    ///
    /// **The windowed cases and `allTime` are not the same question**, and the
    /// difference is visible to the reader rather than hidden: a window is what
    /// the catalog's readers are opening *now*, all-time is what they have
    /// shelved *ever*. Only the second can be narrowed — see `isNarrowed`.
    enum Period: String, CaseIterable, Identifiable, Hashable {
        case thisWeek, thisMonth, thisYear, allTime

        var id: String { rawValue }

        /// As it reads in the picker.
        var title: String {
            switch self {
            case .thisWeek: "This week"
            case .thisMonth: "This month"
            case .thisYear: "This year"
            case .allTime: "All time"
            }
        }

        /// As it reads after the word "Popular".
        var phrase: String {
            switch self {
            case .thisWeek: "this week"
            case .thisMonth: "this month"
            case .thisYear: "this year"
            case .allTime: "of all time"
            }
        }

        /// Whether the catalog can measure this window at all once a subject or
        /// a decade is in play. Nothing but `allTime` can — see
        /// `OpenLibraryClient.browse`.
        var survivesNarrowing: Bool { self == .allTime }

        var window: CatalogBrowseQuery.Window {
            switch self {
            case .thisWeek: .week
            case .thisMonth: .month
            case .thisYear: .year
            case .allTime: .allTime
            }
        }
    }

    /// A genre a reader would name, and the term the catalog indexes it under.
    ///
    /// **Eleven, hand-checked, and deliberately not a taxonomy.** Open
    /// Library's subject field is a midden — the same shelf is tagged
    /// "fiction", "Fiction, general", "nyt:trade_fiction_paperback=2019-01-27"
    /// — so the mapping is a short explicit table rather than anything derived.
    /// Each `subject` below was chosen by running it and reading the first ten
    /// results: bare "history" returns *The 48 Laws of Power*, "world history"
    /// returns *Sapiens*; "biography" returns celebrity memoir slush,
    /// "memoirs" returns *When Breath Becomes Air*.
    ///
    /// The display names are Dewey's and match `Book.genres` where they
    /// overlap. The subjects are the provider's and are the only thing here a
    /// provider swap would rewrite.
    struct Genre: Hashable, Identifiable {
        let name: String
        let subject: String

        var id: String { name }

        static let all: [Genre] = [
            Genre(name: "Literary Fiction", subject: "literary fiction"),
            Genre(name: "Fantasy", subject: "fantasy"),
            Genre(name: "Science Fiction", subject: "science fiction"),
            Genre(name: "Horror", subject: "horror"),
            Genre(name: "Mystery & Thriller", subject: "mystery and detective stories"),
            Genre(name: "Romance", subject: "romance"),
            Genre(name: "History", subject: "world history"),
            Genre(name: "Biography & Memoir", subject: "memoirs"),
            Genre(name: "Philosophy", subject: "philosophy"),
            Genre(name: "Essays", subject: "essays"),
            Genre(name: "Classics", subject: "classics"),
        ]

        /// The six Home offers as a way in.
        ///
        /// Home is a front table, not a catalogue: it shows enough to start
        /// somebody browsing and sends them to `BrowseBooksView` for the rest,
        /// where the whole set sits in a menu that costs no page at all. All
        /// eleven laid out on Home was five lines of pills above the fold's
        /// worth of controls — a taxonomy presented as a decision.
        ///
        /// Taken as a prefix of `all` rather than listed again, so a genre can
        /// never exist here and not in the browser it links to. Which six is
        /// therefore a question about the order of `all`: the broad fiction
        /// shapes lead it, and reordering that list is how you change this.
        static let featured: [Genre] = Array(all.prefix(6))
    }

    /// A span of first-publication years a reader would name.
    ///
    /// Eight buckets and a catch-all, which is as much history as a browse
    /// surface needs. Not a period engine: there is no "Victorian", no
    /// "post-war", nothing that requires an argument about where a period
    /// starts. A decade is a fact about a date.
    struct Decade: Hashable, Identifiable {
        let label: String
        let from: Int?
        let through: Int?

        var id: String { label }

        var span: CatalogBrowseQuery.YearSpan {
            CatalogBrowseQuery.YearSpan(from: from, through: through)
        }

        static let all: [Decade] = {
            var out = stride(from: 2020, through: 1950, by: -10).map { start in
                Decade(label: "\(start)s", from: start, through: start + 9)
            }
            // Open, because first-publication years in a catalog this size go
            // back four figures and then some — Plato is in here.
            out.append(Decade(label: "Before 1950", from: nil, through: 1949))
            return out
        }()

        /// The four Home offers on one line.
        ///
        /// Real decades, not a rounded-off "Earlier". A bucket named for a
        /// span the model does not have would be the page inventing a category
        /// so the row comes out even, and the reader who tapped it would get
        /// results that did not match the word. The other five are in the
        /// browser's menu, where they can also be combined with a genre.
        static let featured: [Decade] = Array(all.prefix(4))
    }

    var period: Period = .thisWeek
    var genre: Genre? = nil
    var decade: Decade? = nil

    /// How many books the shelf shows.
    var limit: Int = 24

    /// Whether anything the catalog cannot window is in play.
    var isNarrowed: Bool { genre != nil || decade != nil }

    /// The question, in the catalog's terms.
    var catalogQuery: CatalogBrowseQuery {
        CatalogBrowseQuery(
            window: period.window,
            subject: genre?.subject,
            years: decade?.span,
            limit: limit
        )
    }

    // MARK: - Narrowing

    /// Applying a genre or a decade **moves the period**, visibly, rather than
    /// quietly returning results that do not match the control above them.
    ///
    /// The catalog cannot tell you what horror is trending this week — its
    /// trending endpoint takes no filters, and hands back the unfiltered chart
    /// if you ask it to. Three ways out of that: fake it, hide the period
    /// control, or let the control say what actually happened. The third is the
    /// only honest one, and it is the only one the reader can undo — clear the
    /// genre and the windows come back.
    ///
    /// `BrowseBooksView` disables the windowed options while this holds, so the
    /// move is explained before it happens rather than after.
    mutating func apply(genre newGenre: Genre?) {
        genre = newGenre
        settlePeriod()
    }

    mutating func apply(decade newDecade: Decade?) {
        decade = newDecade
        settlePeriod()
    }

    private mutating func settlePeriod() {
        if isNarrowed, !period.survivesNarrowing { period = .allTime }
    }

    // MARK: - How it reads

    /// The shelf's name. "Popular this week", "Popular · Horror · 1980s".
    ///
    /// Built from the parts rather than written out per combination, because
    /// there are 4 × 12 × 10 of them and a table of strings would be wrong
    /// within a week.
    var headline: String {
        var parts: [String] = []
        if let genre { parts.append(genre.name) }
        if let decade { parts.append(decade.label) }
        guard !parts.isEmpty else { return "Popular \(period.phrase)" }
        return (["Popular"] + parts).joined(separator: " · ")
    }

    /// The short form, for a navigation bar that has one line.
    var shortHeadline: String {
        genre?.name ?? decade?.label ?? "Popular \(period.phrase)"
    }

    /// **Where the ordering came from, said out loud.**
    ///
    /// This is the honesty line, and it is not decoration. Dewey has nowhere
    /// near enough readers to publish a popularity chart of its own, so every
    /// figure behind this screen belongs to the catalogue it quotes, and the
    /// screen says so in the reader's own language rather than leaving them to
    /// assume the app has thousands of users it does not have.
    ///
    /// Two sentences because there are two genuinely different measurements
    /// underneath — a rolling window of what is being opened, and a standing
    /// count of what has been shelved — and a reader who switches between them
    /// should be able to see that the number changed meaning.
    var sourceLine: String {
        if isNarrowed || period == .allTime {
            return "Most widely read in \(Vocabulary.widerCatalogue.lowercased()), counted across every reader it knows about. Not Dewey's own figures."
        }
        return "What \(Vocabulary.widerCatalogue.lowercased()) has been opening \(period.phrase). Not Dewey's own figures."
    }

    /// Said when the windowed options are unavailable, immediately under them.
    static let narrowedPeriodNote = "A genre or a decade can only be counted over all time."
}

// MARK: - Loading a shelf

/// One answer, and **the question it answers**.
///
/// The same shape `SearchView` uses for its catalog section, and for the same
/// reason: carrying the query alongside the rows is what makes a stale shelf
/// impossible. Everything downstream compares it against the filter currently
/// on screen, so covers can only ever render under the heading that produced
/// them — a reader who taps Horror while the 1960s shelf is still in flight
/// never sees Asimov under the word Horror.
///
/// `books == nil` is a request that failed, which is a different sentence from
/// one that found nothing.
struct BrowseAnswer: Equatable {
    let query: CatalogBrowseQuery
    let books: [Book]?

    /// Where a shelf stands, from the reader's point of view. Four states,
    /// because "still asking", "nothing there", "couldn't reach it" and "here
    /// you are" need four different things on screen.
    enum Phase: Equatable { case loading, empty, failed, loaded([Book]) }

    /// Fresh only for this exact question. Anything else is still in the air.
    static func phase(of answer: BrowseAnswer?, for query: CatalogBrowseQuery) -> Phase {
        guard let answer, answer.query == query else { return .loading }
        guard let books = answer.books else { return .failed }
        return books.isEmpty ? .empty : .loaded(books)
    }
}
