import Foundation

/// Open Library, spoken to politely (§16).
///
/// No API key and no token — the whole handshake is a User-Agent header
/// naming the app and a contact address, which is what earns the identified
/// tier (3 requests/second) instead of the anonymous one. Search is one
/// request with an explicit field list; a work's description and subjects
/// cost a second request that only the book page ever pays.
struct OpenLibraryClient: BookCatalogProvider {

    private static let searchBase = "https://openlibrary.org/search.json"
    private static let worksBase = "https://openlibrary.org/works"
    private static let trendingBase = "https://openlibrary.org/trending"

    /// Identified-tier courtesy, per Open Library's developer guidelines.
    private static let userAgent = "Dewey (jacksirianni@icloud.com)"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Requests

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    // MARK: - Search

    /// How many rows to ask for, and how many to keep.
    ///
    /// Asking for twice what is shown is what makes the re-ranking below
    /// possible: the book a reader means is frequently outside Open Library's
    /// own top twenty, and cannot be promoted if it was never fetched.
    private static let fetchLimit = 40
    private static let keepLimit = 20

    /// One request, and the row count is free.
    ///
    /// **This was briefly two concurrent requests, and that was slower.** The
    /// reasoning had been that the nested-edition join costs time proportional
    /// to the rows, so a wide request without editions could carry the row set
    /// while a narrow one supplied English titles and jackets. Measured against
    /// openlibrary.org, both halves of that were wrong: the server largely
    /// **serialises** requests from one client (two concurrent, 3.2s; the same
    /// two sequential, 3.9s — a fifth saved, not a half), and a single request
    /// with nested editions costs about the same at twenty rows as at forty
    /// (2.11s against 2.05s). The earlier reading that suggested otherwise was
    /// variance in Open Library's own latency, which is considerable.
    ///
    /// So: one request, forty rows, nested editions included. Forty is what
    /// makes the re-ranking work — the book a reader means is frequently
    /// outside Open Library's own top twenty — and it costs nothing over
    /// twenty. About two seconds is this catalog's floor; the store's query
    /// cache is what makes the second look at a query instant.
    func search(_ query: String) async throws -> [CatalogSearchResult] {
        let rows = try await docs(query: query, limit: Self.fetchLimit, withEditions: true)
        let results = rows.compactMap(Self.result(from:))
        return Array(ranked(collapsingDuplicates(results), for: query).prefix(Self.keepLimit))
    }

    /// One search or trending row, normalized — or `nil` where the row is
    /// unusable.
    ///
    /// A hit with no work key is unaddressable; nothing downstream could ever
    /// fetch, refresh, or dedupe it. Dropped rather than rendered as a dead
    /// end.
    ///
    /// Shared by `search` and `browse` because Open Library's trending
    /// endpoint returns **the same document shape** as search, down to the
    /// nested editions — so the English-title and English-jacket preferences
    /// apply to a browse shelf exactly as they do to a results row, and a
    /// second copy of this mapping would be a second place for them to drift.
    private static func result(from row: SearchDoc) -> CatalogSearchResult? {
        guard let workID = row.key.map(Self.trimWorkKey), !workID.isEmpty else { return nil }
        let cover = Self.preferredCover(row)
        return CatalogSearchResult(
            workID: workID,
            title: Self.preferredTitle(row),
            author: row.author_name?.first,
            authorKeys: row.author_key ?? [],
            firstPublishYear: row.first_publish_year,
            coverID: cover.id ?? row.cover_i,
            coverEditionID: cover.editionID,
            editionCount: row.edition_count
        )
    }

    /// Named fields keep the payload to what a results row renders. Notably
    /// absent: `isbn`, which returns every ISBN of every edition — hundreds
    /// of strings nobody asked for. The bare `editions` key is required
    /// alongside its subfields; asking for `editions.language` on its own
    /// returns nothing at all.
    private static let baseFields = "key,title,author_name,author_key,first_publish_year,cover_i,edition_count"
    private static let editionFields = ",editions,editions.key,editions.title,editions.language,editions.cover_i"

    private func docs(query: String, limit: Int, withEditions: Bool) async throws -> [SearchDoc] {
        var components = URLComponents(string: Self.searchBase)!
        components.queryItems = [
            // Free-text `q` rather than `title=`, so an author's name or a
            // series still finds books. Measured against the alternative:
            // `title=` loses "Convenience Store Woman" outright.
            .init(name: "q", value: query),
            .init(name: "fields", value: Self.baseFields + (withEditions ? Self.editionFields : "")),
            .init(name: "limit", value: "\(limit)"),
        ]
        let data = try await get(components.url!)
        return try JSONDecoder().decode(SearchPage.self, from: data).docs
    }

    // MARK: - Browse

    /// What the catalog says is being read, narrowed by whatever the reader
    /// asked for.
    ///
    /// **Two endpoints, and which one answers is decided by the question, not
    /// by preference.** Open Library measures trending over a rolling window
    /// and serves it from `/trending/{weekly,monthly,yearly}` — real counts of
    /// what its readers are opening — but that endpoint takes no filters at
    /// all: a `q` handed to it is ignored, and it will happily return the
    /// unfiltered chart under a heading that says Horror. So a windowed
    /// question with nothing narrowing it goes to trending, and everything
    /// else goes to search with `sort=readinglog`, which is a genuine count of
    /// how many Open Library readers have the book on a shelf and does filter.
    ///
    /// The two are different claims and the browse surface says which is on
    /// screen — see `BrowseFilter.sourceLine`. Nothing here blends them, and
    /// nothing here invents a windowed count for a subject the catalog cannot
    /// window.
    ///
    /// The provider's order is preserved. `ranked` exists to correct relevance
    /// against words a reader typed, and there are no words here; re-sorting
    /// a popularity chart would be Dewey substituting a signal of its own.
    func browse(_ query: CatalogBrowseQuery) async throws -> [CatalogSearchResult] {
        let rows = try await browseDocs(query)
        let results = rows.compactMap(Self.result(from:))
        return Array(collapsingDuplicates(results).prefix(query.limit))
    }

    /// Headroom over what the caller shows, so de-duplication has something to
    /// spend. Open Library holds several work records for popular books, and a
    /// shelf that asked for exactly ten would come back with eight.
    private static func fetchCount(for limit: Int) -> Int { limit + 12 }

    private func browseDocs(_ query: CatalogBrowseQuery) async throws -> [SearchDoc] {
        let fields = Self.baseFields + Self.editionFields
        let limit = Self.fetchCount(for: query.limit)

        if let window = Self.trendingPath(for: query) {
            var components = URLComponents(string: "\(Self.trendingBase)/\(window).json")!
            components.queryItems = [
                .init(name: "fields", value: fields),
                .init(name: "limit", value: "\(limit)"),
            ]
            let data = try await get(components.url!)
            return try JSONDecoder().decode(TrendingPage.self, from: data).works
        }

        var components = URLComponents(string: Self.searchBase)!
        components.queryItems = [
            .init(name: "q", value: Self.solrQuery(for: query)),
            .init(name: "fields", value: fields),
            // Open Library's count of readers who have shelved the work. Its
            // readers, not Dewey's — which is the whole reason this surface
            // exists and the reason its copy never claims otherwise.
            .init(name: "sort", value: "readinglog"),
            .init(name: "limit", value: "\(limit)"),
        ]
        let data = try await get(components.url!)
        return try JSONDecoder().decode(SearchPage.self, from: data).docs
    }

    /// The trending path this question maps onto, or `nil` if trending cannot
    /// honestly answer it.
    ///
    /// Any narrowing at all disqualifies it, because the endpoint silently
    /// ignores filters rather than refusing them.
    private static func trendingPath(for query: CatalogBrowseQuery) -> String? {
        guard query.subject == nil, query.years == nil else { return nil }
        switch query.window {
        case .week: return "weekly"
        case .month: return "monthly"
        case .year: return "yearly"
        case .allTime: return nil
        }
    }

    /// The narrowings, in Solr's syntax. `*:*` — everything — when there are
    /// none, which is what an all-time chart of the whole catalog is.
    private static func solrQuery(for query: CatalogBrowseQuery) -> String {
        var terms: [String] = []
        if let subject = query.subject {
            // Quoted, so a two-word subject stays one term. The set of
            // subjects is a fixed table in the app (`BrowseFilter.Genre`), so
            // there is no reader input reaching this string.
            terms.append("subject:\"\(subject)\"")
        }
        if let years = query.years {
            let from = years.from.map(String.init) ?? "*"
            let through = years.through.map(String.init) ?? "*"
            terms.append("first_publish_year:[\(from) TO \(through)]")
        }
        return terms.isEmpty ? "*:*" : terms.joined(separator: " AND ")
    }

    // MARK: - Choosing a jacket

    /// The cover a reader of this app expects to see.
    ///
    /// A work's own `cover_i` is whichever jacket Open Library holds at the
    /// work level, and for a translated or widely published novel that is
    /// frequently **not** the English one: *Red Rising* came back as the
    /// Spanish *Amanecer Rojo*, and measured across twenty popular titles four
    /// of nineteen were foreign-language jackets with several more
    /// indeterminate. A reader who searched in English, in an English app, and
    /// who owns the English paperback reads that as the wrong book.
    ///
    /// So an English *edition's* cover is preferred when the search response
    /// offers one, and the work-level cover is the fallback. This costs no
    /// extra request — the nested `editions` object rides along in the same
    /// search response — and it is not a claim that the English edition is the
    /// real one: the jacket shown is a genuine jacket of this work, chosen for
    /// the reader most likely to be looking at it.
    ///
    /// English is hardcoded because the app is. If Dewey is ever localised,
    /// this is the line that has to learn about the reader's language.
    private static func preferredCover(_ doc: SearchDoc) -> (id: Int?, editionID: String?) {
        if let english = englishEdition(doc), english.cover_i != nil {
            return (english.cover_i, english.key.map(Self.trimBookKey))
        }
        return (doc.cover_i, nil)
    }

    /// The title a reader of this app can recognise.
    ///
    /// A work record frequently carries the title in the language the book was
    /// **written** in, not the one the reader typed: Han Kang's novel is
    /// `채식주의자`, Tokarczuk's is `Prowadź swój pług przez kości umarłych`.
    /// That is correct cataloguing and useless here — it printed Korean on an
    /// English book page, and worse, it made the title unmatchable, so
    /// searching "Drive Your Plow Over the Bones of the Dead" appeared to find
    /// nothing while a study guide for an unrelated book took first place.
    ///
    /// So when the work's own title is not written in plain ASCII, an English
    /// edition's title is preferred. The ASCII test is the guard that keeps
    /// this from firing where it would do harm: a work titled "Study Guide The
    /// Lucifer Effect by Philip G. Zimbardo" has an edition titled merely
    /// "Study Guide", and swapping to that would throw information away. The
    /// cases the test lets through — an English title carrying an accent or a
    /// curly apostrophe — swap one English title for another, which is
    /// harmless.
    private static func preferredTitle(_ doc: SearchDoc) -> String {
        let work = doc.title ?? "Untitled"
        guard work.contains(where: { !$0.isASCII }),
              let english = englishEdition(doc),
              let title = english.title,
              title.count >= 2
        else { return work }
        return title
    }

    /// The first English edition in the nested list, whatever it can tell us.
    private static func englishEdition(_ doc: SearchDoc) -> EditionDoc? {
        (doc.editions?.docs ?? []).first { ($0.language ?? []).contains("eng") }
    }

    // MARK: - Making the results usable

    /// Open Library's relevance, corrected for the one thing it is bad at —
    /// without throwing away the thing it is good at.
    ///
    /// It fails hardest on a one-word title: searching *Drifts* or *Temporary*
    /// does not return Kate Zambreno's or Hilary Leichter's novel anywhere in
    /// the first twenty rows, because a thousand records contain the word. It
    /// is reliable, though, whenever the query is long or specific enough to
    /// be unambiguous, and its ordering is the better judgement there.
    ///
    /// **A first version of this ordering hard-ranked title matches above
    /// everything else, and it was worse than doing nothing for a whole class
    /// of query.** Because it compared folded whole strings, dropping a leading
    /// article stopped counting as a title match at all: searching "hobbit" put
    /// Tolkien's novel — 481 editions, Open Library's own first row — at
    /// position seven, behind two one-edition records literally titled
    /// "Hobbit". Worse, a query like "beloved" produced two dozen
    /// prefix-matching romance titles, which filled all twenty rows and pushed
    /// *Cry, the Beloved Country* out of the results entirely, unreachable
    /// because this surface has no pagination.
    ///
    /// So the two signals are **blended rather than stacked**. Every row keeps
    /// Open Library's rank as its baseline and earns a discount for looking
    /// like the thing asked for. A weak title match cannot leapfrog a strongly
    /// relevant row, and nothing that the catalog ranked highly is displaced
    /// out of the visible twenty by a pile of near-misses.
    ///
    /// - Titles are compared as **tokens with a leading article dropped**, so
    ///   "hobbit" and "The Hobbit" are the same title — which is how readers
    ///   type, and the case the string comparison could not see.
    /// - An exact title match is the one absolute: it goes to the front,
    ///   best-known copy first, because that is the fix this ordering exists
    ///   for.
    /// - Everything else is scored `catalogRank − promotion − popularity`,
    ///   where promotion rewards a title that starts with or contains the whole
    ///   query, and popularity is edition count, damped and capped so it
    ///   nudges rather than decides.
    private func ranked(_ results: [CatalogSearchResult], for query: String) -> [CatalogSearchResult] {
        let asked = Self.titleTokens(query)
        // A query with no letters or digits in it — punctuation, emoji — has no
        // title signal at all. Leave Open Library's order alone.
        guard !asked.isEmpty else { return results }

        return results.enumerated()
            .map { (offset, result) -> (score: Double, editions: Int, offset: Int, result: CatalogSearchResult) in
                let title = Self.titleTokens(result.title)
                let author = Self.titleTokens(result.author ?? "")
                let editions = result.editionCount ?? 0
                // Damped and capped: the difference between 1 and 40 editions
                // matters, the difference between 300 and 1,200 does not.
                let popularity = min(Double(editions) / 20, 8)

                // **The words the title is responsible for.** Readers type the
                // author's name alongside the title — "beloved toni morrison" —
                // and comparing that whole string against a title made the real
                // book unrecognisable while a study guide *called* "Beloved,
                // Toni Morrison" matched perfectly. Discounting the words this
                // row's author already accounts for leaves "beloved", which
                // Morrison's novel matches exactly.
                let residual = asked.filter { !author.contains($0) }

                // **The query is this author's name, exactly.** Then the reader
                // wants that author's books, and those must beat books *about*
                // them: searching "Kazuo Ishiguro" put Wai-chew Sim's critical
                // study first, because a work literally titled "Kazuo Ishiguro"
                // is an exact title match, and his own novels were six rows
                // down.
                //
                // Equality, not mere overlap — a looser test fired on any
                // author whose name happens to contain the words typed, and
                // "wolf hall" came back with Charlene **Wolf-Hall**'s
                // *Microbial Food Safety* above Hilary Mantel.
                if !author.isEmpty, author == asked {
                    return (-2_000 - popularity, editions, offset, result)
                }

                if !residual.isEmpty, title == residual {
                    // Exact, and popularity orders within: for the query above,
                    // both Morrison's novel and the study guide match exactly,
                    // and 107 editions against two settles it.
                    return (-1_000 - popularity, editions, offset, result)
                }

                let promotion: Double
                if residual.isEmpty {
                    // The author accounts for everything typed — a surname
                    // search, or a name the catalog spells differently. Strong,
                    // but an outright title match can still win.
                    promotion = 25
                } else {
                    // How much of the query this row accounts for at all,
                    // scaled rather than all-or-nothing. Partial credit is what
                    // rescues a work the catalog titles in another language:
                    // "the vegetarian han kang" against a work called
                    // `채식주의자` matches the author but not the title, and with
                    // a binary test it scored the same as a study guide for an
                    // unrelated book — which Open Library happened to rank
                    // first.
                    let explained = asked.filter { title.contains($0) || author.contains($0) }.count
                    let coverage = Double(explained) / Double(asked.count) * 14
                    let prefix = (title.count > residual.count && Array(title.prefix(residual.count)) == residual) ? 12.0 : 0
                    let containsAll = residual.allSatisfy(title.contains) ? 6.0 : 0
                    promotion = max(coverage, max(prefix, containsAll))
                }
                return (Double(offset) - promotion - popularity, editions, offset, result)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                if lhs.editions != rhs.editions { return lhs.editions > rhs.editions }
                // The original position last, so the sort is stable and Open
                // Library's ranking survives wherever we add nothing.
                return lhs.offset < rhs.offset
            }
            .map(\.result)
    }

    /// A title as comparable words, with a leading article dropped.
    ///
    /// Tokens rather than one folded string, because folding to letters and
    /// digits destroys the word boundaries this comparison needs: "thehobbit"
    /// tells you nothing about "hobbit", while `["the", "hobbit"]` minus its
    /// article is exactly `["hobbit"]`. Only a *leading* article goes — "Cry,
    /// the Beloved Country" keeps the one in the middle, which is part of the
    /// title.
    private static func titleTokens(_ s: String) -> [String] {
        // Diacritics folded, because readers type "Hernan Diaz" and the record
        // says "Hernán Díaz". Without this the author's own novel failed to
        // match its author's name, and an omnibus edition credited to an
        // unaccented duplicate author record won the query instead.
        let tokens = s.folding(options: [.diacriticInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        if tokens.count > 1, ["the", "a", "an"].contains(tokens[0]) {
            return Array(tokens.dropFirst())
        }
        return tokens
    }

    /// One row per book.
    ///
    /// Open Library holds several work records for the same book — *Checkout
    /// 19* exists twice, *Red Rising* twice — and returning both asks the
    /// reader to pick between two rows of one novel, then splits their ratings
    /// across whichever they happened to tap.
    ///
    /// **Matched on the provider's author identifiers, not on names.** Keying
    /// on the displayed author was wrong in a way that showed: *Red Rising*'s
    /// duplicate work record credits `["Renee Joiner", "Pierce Brown"]` — the
    /// audiobook's narrator first — so the two records keyed differently, both
    /// survived, and a reader could open a page for a Pierce Brown novel that
    /// said Renee Joiner underneath the title. Comparing the credit *sets*
    /// recognises them as one book, because they genuinely share an author id.
    ///
    /// The title must still agree, so Tolkien's *The Hobbit* and Charles
    /// Dixon's graphic adaptation stay separate — as do two unrelated books by
    /// one author. The record with more editions wins, being the canonical one
    /// (26 editions against 8, here, and it is the one crediting Brown alone).
    private func collapsingDuplicates(_ results: [CatalogSearchResult]) -> [CatalogSearchResult] {
        var kept: [CatalogSearchResult] = []
        for result in results {
            let title = Self.folded(result.title)
            let keys = Set(result.authorKeys)
            let match = kept.firstIndex { candidate in
                guard Self.folded(candidate.title) == title else { return false }
                // Either signal is enough, because the catalog duplicates both
                // kinds of record. Shared credit catches *Red Rising*, whose
                // two work records disagree about which name comes first;
                // matching names catches *Checkout 19*, where Open Library
                // holds **two author records for the same person** so the
                // identifiers are disjoint even though it is plainly one
                // Claire-Louise Bennett. Requiring both would fix neither.
                let candidateKeys = Set(candidate.authorKeys)
                if !keys.isEmpty, !candidateKeys.isEmpty, !keys.isDisjoint(with: candidateKeys) { return true }
                let name = Self.folded(result.author ?? "")
                // Two authorless stubs are not evidence of anything.
                guard !name.isEmpty else { return false }
                return Self.folded(candidate.author ?? "") == name
            }
            guard let existing = match else {
                kept.append(result)
                continue
            }
            let incumbent = kept[existing]
            let winner = (result.editionCount ?? 0) > (incumbent.editionCount ?? 0) ? result : incumbent
            let loser = (result.editionCount ?? 0) > (incumbent.editionCount ?? 0) ? incumbent : result
            // The fuller record wins, but a cover or a year the loser had and
            // the winner lacks is carried across. They are two records of one
            // book, so the jacket is genuinely this book's jacket — and
            // dropping it would show a typeset cover for a book Open Library
            // has a picture of.
            // The cover and the edition it came from travel together, so a
            // jacket borrowed from the losing record does not end up labelled
            // with the winner's edition.
            let cover: (id: Int?, editionID: String?) = winner.coverID != nil
                ? (winner.coverID, winner.coverEditionID)
                : (loser.coverID, loser.coverEditionID)
            kept[existing] = CatalogSearchResult(
                workID: winner.workID,
                title: winner.title,
                author: winner.author ?? loser.author,
                authorKeys: winner.authorKeys.isEmpty ? loser.authorKeys : winner.authorKeys,
                firstPublishYear: winner.firstPublishYear ?? loser.firstPublishYear,
                coverID: cover.id,
                coverEditionID: cover.editionID,
                editionCount: winner.editionCount ?? loser.editionCount
            )
        }
        return kept
    }

    /// Letters and digits only, folded — with `&` spelled out first, so the
    /// ampersand-versus-and disagreement between catalogs actually folds away.
    /// Deleting the `&` instead of expanding it left "Red, White & Royal Blue"
    /// and "Red, White and Royal Blue" as two different strings, which is the
    /// opposite of what this function is for.
    private static func folded(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .filter { $0.isLetter || $0.isNumber }
    }

    // MARK: - Work detail

    func work(_ workID: String) async throws -> CatalogWork {
        let data = try await get(URL(string: "\(Self.worksBase)/\(workID).json")!)
        let record = try JSONDecoder().decode(WorkRecord.self, from: data)
        return CatalogWork(
            workID: workID,
            description: CatalogText.cleanedDescription(record.description?.text),
            subjects: record.subjects ?? [],
            // Open Library writes -1 into `covers` for a jacket that was
            // removed, so the array is filtered rather than trusted.
            coverIDs: (record.covers ?? []).filter { $0 > 0 }
        )
    }

    /// The same search endpoint `search(_:)` already speaks, scoped to one
    /// work by key instead of free text — `q=key:/works/OLxxxxW` returns the
    /// identical row shape a free-text hit does (title, author, year, cover),
    /// verified directly against `openlibrary.org`. Not a second catalog
    /// backend: one more query this client already knows how to ask, and the
    /// only way a device with no local record of a book can turn a synced
    /// `olw:` reference back into one.
    func resolveWork(_ workID: String) async throws -> CatalogSearchResult? {
        let rows = try await docs(query: "key:/works/\(workID)", limit: 1, withEditions: true)
        return rows.compactMap(Self.result(from:)).first
    }

    // MARK: - Covers

    enum CoverSize: String {
        case small = "S", medium = "M", large = "L"
    }

    /// `covers.openlibrary.org` serves jackets by the numeric id search
    /// results already carry — no extra lookup.
    static func coverURL(_ coverID: Int, size: CoverSize) -> URL {
        URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-\(size.rawValue).jpg")!
    }

    // MARK: - Wire types

    /// `"/works/OL45883W"` → `"OL45883W"`. The path prefix is Open Library's
    /// routing, not part of the identifier.
    private static func trimWorkKey(_ key: String) -> String {
        key.hasPrefix("/works/") ? String(key.dropFirst("/works/".count)) : key
    }

    /// `"/books/OL26758016M"` → `"OL26758016M"`.
    private static func trimBookKey(_ key: String) -> String {
        key.hasPrefix("/books/") ? String(key.dropFirst("/books/".count)) : key
    }

    private struct SearchPage: Decodable {
        let docs: [SearchDoc]
    }

    /// The trending endpoint's envelope. Same rows as a search page, under a
    /// different key.
    private struct TrendingPage: Decodable {
        let works: [SearchDoc]
    }

    private struct SearchDoc: Decodable {
        let key: String?
        let title: String?
        let author_name: [String]?
        let author_key: [String]?
        let first_publish_year: Int?
        let cover_i: Int?
        let edition_count: Int?
        let editions: EditionsBlock?
    }

    /// The nested edition list Open Library returns inside a search hit.
    private struct EditionsBlock: Decodable {
        let docs: [EditionDoc]?
    }

    private struct EditionDoc: Decodable {
        let key: String?
        let title: String?
        let language: [String]?
        let cover_i: Int?
    }

    private struct WorkRecord: Decodable {
        let description: FlexibleText?
        let subjects: [String]?
        let covers: [Int]?
    }

    /// Open Library's oldest quirk: `description` is sometimes a bare string
    /// and sometimes `{"type": "/type/text", "value": "..."}`, depending on
    /// which era of editor last touched the record.
    private enum FlexibleText: Decodable {
        case plain(String)
        case typed(String)

        var text: String {
            switch self {
            case .plain(let s), .typed(let s): s
            }
        }

        init(from decoder: Decoder) throws {
            if let s = try? decoder.singleValueContainer().decode(String.self) {
                self = .plain(s)
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self = .typed(try container.decode(String.self, forKey: .value))
        }

        private enum CodingKeys: String, CodingKey { case value }
    }
}
