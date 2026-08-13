import Foundation

/// The seeded world.
///
/// Forty-one real books with real metadata, four readers written to be people
/// rather than personas, and enough lists, reviews and diary history that
/// the app has somewhere to go. One reader (Tobias) deliberately shares almost
/// nothing with the user: Dewey has to be able to say "nothing in common yet"
/// without flinching, and a world where every reader is a great match would be
/// lying about the thing the product is for.
enum SeedData {

    // MARK: - Dates

    static func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: day)) ?? Date(timeIntervalSince1970: 1_750_000_000)
    }

    // MARK: - Books

    /// The seeded forty-one, each carrying its Open Library work identifier.
    ///
    /// The identifiers are attached here rather than typed into forty-one
    /// literals below, because they are not editorial content — they are the
    /// join between Dewey's hand-set shelf and the catalog, and they belong in
    /// one table where they can be checked.
    ///
    /// **Why the seed needs them at all** (§16). Without a work ID a seeded
    /// book cannot be recognised as the same book the catalog is offering, so
    /// searching "Middlemarch" returned Dewey's *Middlemarch* under Books and
    /// Open Library's *Middlemarch* under the catalog section — and saving the
    /// second one minted a permanent duplicate with its own ratings, diary and
    /// place in the rankings. The reader's activity would split across two
    /// records of one novel. With the identifiers present, a catalog hit for a
    /// seeded work resolves *to the seeded book*, ratings and history intact.
    ///
    /// It changes nothing else: seeded books are never fetched and never
    /// refresh — `enrichIfNeeded` only knows books the reader imported — so
    /// this is identity, not a network dependency.
    static let books: [Book] = seededBooks.map { book in
        var identified = book
        identified.openLibraryWorkID = openLibraryWorkIDs[book.id]
        return identified
    }

    /// Resolved by ISBN against Open Library and verified title-by-title
    /// against the seed's own author and year. Where a work's canonical record
    /// is in its original language — *De ansatte*, 채식주의자, 地球星人 — the
    /// identifier is that work's, which is correct: a work is the novel, not
    /// the translation Dewey happens to describe.
    private static let openLibraryWorkIDs: [String: String] = [
        "employees": "OL25803688W",
        "severance": "OL19748973W",
        "convenience": "OL19744024W",
        "earthlings": "OL24350404W",
        "vegetarian": "OL17334243W",
        "human-acts": "OL17764836W",
        "fifth-season": "OL17363125W",
        "obelisk-gate": "OL17842279W",
        "temporary": "OL20717458W",
        "bullshit-jobs": "OL20153626W",
        "sixth-extinction": "OL16820830W",
        "consider-lobster": "OL2943594W",
        "entangled-life": "OL20758206W",
        "argonauts": "OL19999589W",
        "bluets": "OL5814581W",
        "red-white-royal": "OL20090688W",
        "slouching": "OL43100620W",
        "white-album": "OL8262105W",
        "trick-mirror": "OL20088523W",
        "tenth-december": "OL16599873W",
        "her-body": "OL19636245W",
        "cloud-cuckoo": "OL24164954W",
        "cloud-atlas": "OL482454W",
        "middlemarch": "OL20867W",
        "mill-floss": "OL20938W",
        "friday-black": "OL19763775W",
        "interpreter-maladies": "OL2001058W",
        "whereabouts": "OL34860829W",
        "what-we-talk": "OL1865851W",
        "deaf-republic": "OL20152493W",
        "h-is-hawk": "OL8868108W",
        "postcolonial-love": "OL20818319W",
        "peregrine": "OL2395963W",
        "citizen": "OL17062866W",
        "dont-call-us-dead": "OL19636242W",
        "averno": "OL8035191W",
        "checkout-19": "OL25277537W",
        "drifts": "OL20760165W",
        "piranesi": "OL20893680W",
        "song-achilles": "OL16509148W",
        "station-eleven": "OL17202418W",
    ]

    private static let seededBooks: [Book] = [
        b("employees", "The Employees", "Olga Ravn", 2018, .uncommon, .clay, .light,
          "A workplace novel set on a spaceship, told entirely in employee statements. Very short, very strange.",
          g: ["Literary Fiction", "Science Fiction"], t: ["Work", "What counts as a person"],
          setting: "The Six-Thousand Ship, twenty-second century",
          pages: 136, pub: "Lolli Editions", isbn: "9781999924799",
          ddc: "839.8138", editions: 9, tr: "Martin Aitken",
          rel: ["severance", "temporary", "convenience"]),
        b("severance", "Severance", "Ling Ma", 2018, .known, .moss, .light,
          "An office satire that turns into an apocalypse without ever changing its tone.",
          g: ["Literary Fiction", "Dystopia"], t: ["Work", "Routine"],
          chars: ["Candace Chen", "Bob", "Jonathan"], setting: "New York City, 2011",
          pages: 291, pub: "Farrar, Straus and Giroux", isbn: "9780374261597",
          ddc: "813.6", published: d(2018, 8, 14), editions: 24,
          rel: ["employees", "temporary", "station-eleven"]),
        b("convenience", "Convenience Store Woman", "Sayaka Murata", 2016, .known, .bone, .dark,
          "A woman finds the only place she makes sense, and it is a convenience store.",
          g: ["Literary Fiction", "Translated"], t: ["Work", "Belonging"],
          chars: ["Keiko Furukura", "Shiraha"], setting: "Tokyo",
          pages: 163, pub: "Grove Press", isbn: "9780802128256",
          ddc: "895.636", editions: 41, tr: "Ginny Tapley Takemori",
          rel: ["employees", "vegetarian", "earthlings"]),
        b("earthlings", "Earthlings", "Sayaka Murata", 2018, .known, .moss, .light,
          "Begins as a story about a strange childhood and ends somewhere you will not be ready for.",
          g: ["Literary Fiction", "Translated", "Horror"], t: ["Belonging", "Estrangement"],
          chars: ["Natsuki", "Yuu", "Tomoya"], setting: "Akishina, Nagano, and Tokyo",
          pages: 247, pub: "Grove Press", isbn: "9780802157003",
          ddc: "895.636", editions: 27, tr: "Ginny Tapley Takemori",
          rel: ["convenience", "vegetarian"]),
        b("vegetarian", "The Vegetarian", "Han Kang", 2007, .known, .plum, .light,
          "A woman stops eating meat. Three people try to explain what that means and all of them are wrong.",
          g: ["Literary Fiction", "Translated"], t: ["The body", "Refusal"],
          chars: ["Yeong-hye", "In-hye", "Mr Cheong"], setting: "Seoul",
          pages: 188, pub: "Portobello Books", isbn: "9781846275623",
          ddc: "895.735", editions: 63, tr: "Deborah Smith",
          rel: ["convenience", "earthlings", "human-acts"]),
        b("human-acts", "Human Acts", "Han Kang", 2014, .known, .slate, .light,
          "The Gwangju uprising, told through everyone it touched, including the dead.",
          g: ["Literary Fiction", "Translated", "Historical"], t: ["Violence", "Memory"],
          chars: ["Dong-ho", "Eun-sook", "Jeong-dae"], setting: "Gwangju, South Korea, 1980",
          pages: 218, pub: "Portobello Books", isbn: "9781846275968",
          ddc: "895.735", editions: 34, tr: "Deborah Smith",
          rel: ["vegetarian", "citizen"]),
        b("fifth-season", "The Fifth Season", "N. K. Jemisin", 2015, .known, .rust, .light,
          "A world that ends regularly, and the people engineered to hold it together.",
          g: ["Fantasy", "Science Fiction"], t: ["Power", "Survival"],
          chars: ["Essun", "Damaya", "Syenite", "Alabaster", "Hoa", "Schaffa"], setting: "The Stillness",
          pages: 468, pub: "Orbit", isbn: "9780316229296",
          ddc: "813.6", published: d(2015, 8, 4), editions: 31,
          series: "The Broken Earth", pos: 1, rel: ["obelisk-gate", "piranesi"]),
        b("obelisk-gate", "The Obelisk Gate", "N. K. Jemisin", 2016, .known, .plum, .light,
          "The middle book that is somehow better than the first.",
          g: ["Fantasy", "Science Fiction"], t: ["Power", "Parenthood"],
          chars: ["Essun", "Nassun", "Alabaster", "Schaffa", "Hoa"], setting: "The Stillness",
          pages: 448, pub: "Orbit", isbn: "9780316229265",
          ddc: "813.6", published: d(2016, 8, 16), editions: 22,
          series: "The Broken Earth", pos: 2, rel: ["fifth-season"]),
        b("temporary", "Temporary", "Hilary Leichter", 2020, .uncommon, .ochre, .dark,
          "A woman cycles through increasingly surreal temp jobs looking for permanence.",
          g: ["Literary Fiction", "Surreal"], t: ["Work", "Precarity"],
          pages: 208, pub: "Coffee House Press", isbn: "9781566895743",
          ddc: "813.6", editions: 5,
          rel: ["employees", "severance"]),
        b("bullshit-jobs", "Bullshit Jobs", "David Graeber", 2018, .known, .slate, .light,
          "An argument that a great many jobs are pointless, and that everyone quietly knows it.",
          g: ["Nonfiction", "Anthropology"], t: ["Work", "Meaning"],
          pages: 335, pub: "Simon & Schuster", isbn: "9781501143311",
          ddc: "306.36", published: d(2018, 5, 15), editions: 29,
          rel: ["severance", "employees"]),
        b("sixth-extinction", "The Sixth Extinction", "Elizabeth Kolbert", 2014, .known, .sea, .light,
          "Reporting from the front of an extinction event, told one species at a time.",
          g: ["Nonfiction", "Science"], t: ["Loss", "Deep time"],
          pages: 319, pub: "Henry Holt", isbn: "9780805092998",
          ddc: "576.84", published: d(2014, 2, 11), editions: 38,
          rel: ["entangled-life", "peregrine"]),
        b("consider-lobster", "Consider the Lobster", "David Foster Wallace", 2005, .known, .clay, .light,
          "Essays that start somewhere trivial and end somewhere uncomfortable.",
          g: ["Essays", "Nonfiction"], t: ["Attention", "Ethics"],
          pages: 343, pub: "Little, Brown", isbn: "9780316156110",
          ddc: "814.6", published: d(2005, 12, 13), editions: 26,
          rel: ["trick-mirror", "slouching"]),
        b("entangled-life", "Entangled Life", "Merlin Sheldrake", 2020, .known, .moss, .light,
          "Fungi, and the argument that they quietly reorganise how you think about individuality.",
          g: ["Nonfiction", "Science"], t: ["Deep time", "What counts as a person"],
          pages: 358, pub: "Bodley Head", isbn: "9781847925190",
          ddc: "579.5", editions: 33,
          rel: ["sixth-extinction", "h-is-hawk"]),
        b("argonauts", "The Argonauts", "Maggie Nelson", 2015, .known, .plum, .light,
          "Theory and memoir folded together until the seam disappears.",
          g: ["Memoir", "Essays"], t: ["The body", "Love"],
          pages: 143, pub: "Graywolf Press", isbn: "9781555977078",
          ddc: "814.6", published: d(2015, 5, 5), editions: 17,
          rel: ["bluets", "trick-mirror"]),
        b("bluets", "Bluets", "Maggie Nelson", 2009, .uncommon, .dusk, .light,
          "Two hundred and forty numbered fragments about the colour blue and a heartbreak.",
          g: ["Essays", "Poetry"], t: ["Grief", "Colour"],
          pages: 112, pub: "Wave Books", isbn: "9781933517407",
          ddc: "811.6", editions: 11,
          rel: ["argonauts", "averno"]),
        b("red-white-royal", "Red, White & Royal Blue", "Casey McQuiston", 2019, .known, .rust, .light,
          "The First Son and a prince. Entirely unserious and completely committed to it.",
          g: ["Romance", "Contemporary"], t: ["Love", "Duty"],
          chars: ["Alex Claremont-Diaz", "Prince Henry", "Nora Holleran", "June Claremont-Diaz"],
          setting: "Washington, D.C. and London",
          pages: 421, pub: "St. Martin's Griffin", isbn: "9781250316776",
          ddc: "813.6", published: d(2019, 5, 14), editions: 36,
          rel: ["song-achilles"], adaptation: "Adapted for film in 2023."),
        b("slouching", "Slouching Towards Bethlehem", "Joan Didion", 1968, .known, .bone, .dark,
          "California in the sixties, reported by someone unwilling to be charmed.",
          g: ["Essays", "Nonfiction"], t: ["America", "Disillusion"],
          setting: "California, the 1960s",
          pages: 238, pub: "Farrar, Straus and Giroux", isbn: "9780374521721",
          ddc: "814.54", editions: 44,
          rel: ["white-album", "trick-mirror"]),
        b("white-album", "The White Album", "Joan Didion", 1979, .known, .slate, .light,
          "The sequel to the sixties, written by someone who no longer trusts narrative.",
          g: ["Essays", "Nonfiction"], t: ["America", "Disillusion"],
          setting: "California, the 1960s and 1970s",
          pages: 224, pub: "Simon & Schuster", isbn: "9780374522216",
          ddc: "814.54", editions: 31,
          rel: ["slouching"]),
        b("trick-mirror", "Trick Mirror", "Jia Tolentino", 2019, .known, .ochre, .dark,
          "Essays on self-delusion, including the author's own.",
          g: ["Essays", "Nonfiction"], t: ["The internet", "Self-delusion"],
          pages: 303, pub: "Random House", isbn: "9780525510543",
          ddc: "814.6", published: d(2019, 8, 6), editions: 21,
          rel: ["consider-lobster", "argonauts"]),
        b("tenth-december", "Tenth of December", "George Saunders", 2013, .known, .sea, .light,
          "Stories that are cruel for most of their length and then abruptly, devastatingly kind.",
          g: ["Short Stories", "Literary Fiction"], t: ["Kindness", "Class"],
          pages: 251, pub: "Random House", isbn: "9780812993806",
          ddc: "813.6", published: d(2013, 1, 8), editions: 28,
          rel: ["friday-black", "her-body"]),
        b("her-body", "Her Body and Other Parties", "Carmen Maria Machado", 2017, .known, .plum, .light,
          "Horror, fairy tale, and an episode guide to a show that does not exist.",
          g: ["Short Stories", "Horror"], t: ["The body", "Violence"],
          pages: 245, pub: "Graywolf Press", isbn: "9781555977887",
          ddc: "813.6", published: d(2017, 10, 3), editions: 19,
          rel: ["tenth-december", "friday-black"]),
        b("cloud-cuckoo", "Cloud Cuckoo Land", "Anthony Doerr", 2021, .known, .sea, .light,
          "Five timelines held together by one damaged manuscript.",
          g: ["Literary Fiction", "Historical"], t: ["Books", "Deep time"],
          chars: ["Anna", "Omeir", "Zeno Ninis", "Seymour Stuhlman", "Konstance"],
          setting: "Constantinople in 1453, Idaho in 2020, and a ship in transit",
          pages: 622, pub: "Scribner", isbn: "9781982168438",
          ddc: "813.6", published: d(2021, 9, 28), editions: 23,
          rel: ["cloud-atlas", "piranesi"]),
        b("cloud-atlas", "Cloud Atlas", "David Mitchell", 2004, .known, .dusk, .light,
          "Six nested stories, each interrupted at its midpoint and resumed in reverse.",
          g: ["Literary Fiction", "Science Fiction"], t: ["Deep time", "Power"],
          chars: ["Adam Ewing", "Robert Frobisher", "Luisa Rey", "Timothy Cavendish", "Sonmi~451", "Zachry"],
          setting: "Six settings, from the 1850s Pacific to a post-collapse Hawai'i",
          pages: 509, pub: "Sceptre", isbn: "9780340822784",
          ddc: "823.92", editions: 58,
          rel: ["cloud-cuckoo"], adaptation: "Adapted for film in 2012."),
        b("middlemarch", "Middlemarch", "George Eliot", 1872, .ubiquitous, .moss, .light,
          "A provincial town, and the gap between what people intend and what they do.",
          g: ["Classics", "Literary Fiction"], t: ["Marriage", "Ambition"],
          chars: ["Dorothea Brooke", "Tertius Lydgate", "Edward Casaubon", "Will Ladislaw",
                  "Rosamond Vincy", "Fred Vincy", "Mary Garth"],
          setting: "Middlemarch, a Midlands town, 1829–1832",
          pages: 904, pub: "Penguin Classics", isbn: "9780141439549",
          ddc: "823.8", editions: 312,
          rel: ["mill-floss"]),
        b("mill-floss", "The Mill on the Floss", "George Eliot", 1860, .known, .bone, .dark,
          "A brother and sister, and a river that has been waiting the whole book.",
          g: ["Classics", "Literary Fiction"], t: ["Family", "Duty"],
          chars: ["Maggie Tulliver", "Tom Tulliver", "Philip Wakem", "Stephen Guest"],
          setting: "St Ogg's, on the River Floss",
          pages: 544, pub: "Penguin Classics", isbn: "9780141439624",
          ddc: "823.8", editions: 187,
          rel: ["middlemarch"]),
        b("friday-black", "Friday Black", "Nana Kwame Adjei-Brenyah", 2018, .known, .clay, .light,
          "Stories set half a step into a future that is mostly just the present, louder.",
          g: ["Short Stories", "Speculative"], t: ["Race", "Consumption"],
          pages: 194, pub: "Mariner Books", isbn: "9781328911247",
          ddc: "813.6", published: d(2018, 10, 23), editions: 14,
          rel: ["tenth-december", "her-body"]),
        b("interpreter-maladies", "Interpreter of Maladies", "Jhumpa Lahiri", 1999, .known, .ochre, .dark,
          "Quiet stories about distance — between countries, and between people in the same room.",
          g: ["Short Stories", "Literary Fiction"], t: ["Migration", "Marriage"],
          setting: "Calcutta and the north-eastern United States",
          pages: 198, pub: "Houghton Mifflin", isbn: "9780395927205",
          ddc: "813.54", editions: 52,
          rel: ["tenth-december", "whereabouts"]),
        b("whereabouts", "Whereabouts", "Jhumpa Lahiri", 2018, .uncommon, .bone, .dark,
          "A year of small solitary scenes, written by the author in Italian and translated back by her.",
          g: ["Literary Fiction", "Translated"], t: ["Solitude", "Cities"],
          setting: "An unnamed Italian city",
          pages: 157, pub: "Knopf", isbn: "9780593318317",
          ddc: "853.92", editions: 16, tr: "Jhumpa Lahiri",
          rel: ["interpreter-maladies", "drifts"]),
        b("what-we-talk", "What We Talk About When We Talk About Love", "Raymond Carver", 1981, .known, .bone, .dark,
          "Stories stripped until only the pressure is left.",
          g: ["Short Stories"], t: ["Marriage", "Drink"],
          setting: "The Pacific Northwest",
          pages: 176, pub: "Knopf", isbn: "9780679723059",
          ddc: "813.54", editions: 43,
          rel: ["tenth-december"]),
        b("deaf-republic", "Deaf Republic", "Ilya Kaminsky", 2019, .uncommon, .dusk, .light,
          "A poem sequence that works like a play: a town goes deaf as an act of resistance.",
          g: ["Poetry"], t: ["Violence", "Silence"],
          chars: ["Alfonso", "Sonya", "Momma Galya", "Petya"], setting: "Vasenka, an occupied town",
          pages: 76, pub: "Graywolf Press", isbn: "9781555978310",
          ddc: "811.6", editions: 8,
          rel: ["citizen", "dont-call-us-dead"]),
        b("h-is-hawk", "H is for Hawk", "Helen Macdonald", 2014, .known, .moss, .light,
          "Grief, and a goshawk, and the refusal to treat either as a metaphor for the other.",
          g: ["Memoir", "Nature"], t: ["Grief", "Animals"],
          chars: ["Mabel", "T. H. White"], setting: "Cambridgeshire",
          pages: 300, pub: "Jonathan Cape", isbn: "9780224097000",
          ddc: "598.944", editions: 29,
          rel: ["peregrine", "entangled-life"]),
        b("postcolonial-love", "Postcolonial Love Poem", "Natalie Diaz", 2020, .uncommon, .clay, .light,
          "Desire, water rights, and the body as contested territory.",
          g: ["Poetry"], t: ["The body", "Land"],
          pages: 105, pub: "Graywolf Press", isbn: "9781644450147",
          ddc: "811.6", editions: 7,
          rel: ["citizen", "deaf-republic"]),
        b("peregrine", "The Peregrine", "J. A. Baker", 1967, .uncommon, .slate, .light,
          "One man follows falcons for a winter and slowly stops writing like a man.",
          g: ["Nature", "Nonfiction"], t: ["Animals", "Obsession"],
          setting: "The Essex coast, one winter",
          pages: 191, pub: "New York Review Books", isbn: "9781590172476",
          ddc: "598.9", editions: 18,
          rel: ["h-is-hawk", "sixth-extinction"]),
        b("citizen", "Citizen: An American Lyric", "Claudia Rankine", 2014, .known, .bone, .dark,
          "The accumulation of small racist encounters, set down without raising its voice.",
          g: ["Poetry", "Essays"], t: ["Race", "America"],
          pages: 169, pub: "Graywolf Press", isbn: "9781555976903",
          ddc: "811.6", published: d(2014, 10, 7), editions: 24,
          rel: ["deaf-republic", "human-acts"]),
        b("dont-call-us-dead", "Don't Call Us Dead", "Danez Smith", 2017, .uncommon, .dusk, .light,
          "Poems about being Black, queer, and alive in a country that keeps testing all three.",
          g: ["Poetry"], t: ["Race", "The body"],
          pages: 96, pub: "Graywolf Press", isbn: "9781555977856",
          ddc: "811.6", editions: 6,
          rel: ["citizen", "postcolonial-love"]),
        b("averno", "Averno", "Louise Glück", 2006, .uncommon, .dusk, .light,
          "Persephone, rewritten by someone unconvinced by every previous version.",
          g: ["Poetry"], t: ["Myth", "Grief"],
          chars: ["Persephone"],
          pages: 96, pub: "Farrar, Straus and Giroux", isbn: "9780374530747",
          ddc: "811.6", editions: 12,
          rel: ["bluets", "song-achilles"]),
        b("checkout-19", "Checkout 19", "Claire-Louise Bennett", 2021, .uncommon, .ochre, .dark,
          "A life told entirely through what its narrator read, and what reading did to her.",
          g: ["Literary Fiction", "Experimental"], t: ["Books", "Girlhood"],
          pages: 240, pub: "Riverhead", isbn: "9780593087930",
          ddc: "823.92", editions: 9,
          rel: ["drifts", "whereabouts"]),
        b("drifts", "Drifts", "Kate Zambreno", 2020, .uncommon, .dusk, .light,
          "A book about failing to write a book, which is not the joke it sounds like.",
          g: ["Literary Fiction", "Experimental"], t: ["Writing", "Solitude"],
          pages: 208, pub: "Riverhead", isbn: "9780593087251",
          ddc: "813.6", editions: 6,
          rel: ["checkout-19", "whereabouts"]),
        b("piranesi", "Piranesi", "Susanna Clarke", 2020, .known, .sea, .light,
          "A man lives in an infinite house of statues and tides, and is perfectly happy there.",
          g: ["Fantasy", "Literary Fiction"], t: ["Solitude", "Memory"],
          chars: ["Piranesi", "The Other", "16"], setting: "The House",
          pages: 245, pub: "Bloomsbury", isbn: "9781635575637",
          ddc: "823.92", published: d(2020, 9, 15), editions: 26,
          rel: ["fifth-season", "cloud-cuckoo"]),
        b("song-achilles", "The Song of Achilles", "Madeline Miller", 2011, .known, .rust, .light,
          "The Iliad, retold by the person standing next to it, and it will wreck you.",
          g: ["Historical", "Romance", "Myth"], t: ["Love", "Myth"],
          chars: ["Patroclus", "Achilles", "Thetis", "Briseis", "Chiron", "Odysseus"],
          setting: "Greece and Troy, the Bronze Age",
          pages: 378, pub: "Bloomsbury", isbn: "9780062060624",
          ddc: "813.6", editions: 47,
          rel: ["averno", "red-white-royal"]),
        b("station-eleven", "Station Eleven", "Emily St. John Mandel", 2014, .known, .sea, .light,
          "After the collapse, a troupe walks the Great Lakes performing Shakespeare. Survival is insufficient.",
          g: ["Literary Fiction", "Dystopia"], t: ["Art", "Survival"],
          chars: ["Kirsten Raymonde", "Arthur Leander", "Jeevan Chaudhary", "Miranda Carroll",
                  "Clark Thompson", "The Prophet"],
          setting: "The Great Lakes, before and twenty years after the Georgia Flu",
          pages: 333, pub: "Knopf", isbn: "9780385353304",
          ddc: "813.6", published: d(2014, 9, 9), editions: 42,
          rel: ["severance", "cloud-atlas"], adaptation: "Adapted as a limited series in 2021."),
    ]

    /// Optional on purpose (§16). This used to coalesce to `books[0]`, which
    /// meant an unresolved ID silently rendered as *The Employees* — a lie
    /// with a straight face, and exactly the failure the catalog work would
    /// have multiplied. The store owns the failure policy now; the seed just
    /// answers the question it was asked.
    static func find(_ id: String) -> Book? { books.first { $0.id == id } }

    // MARK: - Readers

    static let readers: [ReaderProfile] = [priya, marcus, ana, tobias].map { reader in
        var textured = reader
        textured.ratings = reader.ratings.reduce(into: [:]) { out, pair in
            out[pair.key] = SeedData.textured(pair.value, reader.id + pair.key)
        }
        return textured
    }

    /// Nudges a seeded rating off its whole number by a small, stable amount.
    ///
    /// The migration doubled the old half-to-5 rungs, so every seeded rating
    /// landed exactly on a whole number. The corpus rendered as 9 / 10 / 8 / 9 /
    /// 10 on every shelf, which made the new scale look like a ten-point integer
    /// scale and hid the one thing §12.2 exists to provide. The seed is fiction
    /// either way; fiction that reads as a considered judgement is truer to the
    /// product than fiction that reads as a rounded one.
    ///
    /// Deterministic — FNV-1a over the key, never `Int.random` and never
    /// `String.hashValue` (which is seeded per process and would give a book a
    /// different rating on every launch).
    ///
    /// **A rating at the ceiling holds, exactly.** This used to clamp after
    /// nudging, so half the perfect 10s in the corpus came out as 9.6–9.9: the
    /// four negative offsets moved them and the clamp only caught the positive
    /// ones. §12.8.4 lists "a clean 10 stays a clean 10" as acceptance, and it
    /// is the right acceptance — a 10 is the one rating in the seed that says
    /// something categorical, and texturing it away turns "the best book I have
    /// read" into "very good indeed". Nothing else in the corpus needs a 10 to
    /// stay a 10 in order to look considered; the other ninety-odd ratings do
    /// all of that work.
    static func textured(_ value: Double, _ key: String) -> Double {
        guard value < Rating.range.upperBound else { return Rating.range.upperBound }

        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in key.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
        let steps = Int(hash % 8)
        // -0.4…-0.1 and +0.1…+0.4, never 0 — a whole number here would be the
        // artefact this function exists to remove.
        let offset = Double(steps < 4 ? steps - 4 : steps - 3) / 10
        let nudged = value + offset
        // Reflect rather than clamp at either end. Clamping parks the value on
        // 10.0 or 0.1 — a whole number, and at the top a *false perfect score*,
        // which are the two outcomes this function exists to avoid. Reflecting
        // keeps the nudge the same size, keeps it deterministic, and keeps it
        // off the whole.
        let placed = Rating.range.contains(nudged) ? nudged : value - offset
        // One decimal. Binary floating point makes 9.0 + 0.1 = 9.099999…, and
        // this value is read as a Double by library-match arithmetic before any
        // `Rating` gets to snap it.
        return (placed * 10).rounded() / 10
    }

    // Ratings below are on the 0.1–10.0 scale (§12.2). They were seeded on the
    // half-to-5 scale and migrated by doubling on 2026-08-04, which is exactly
    // right: the old scale's ten rungs are the new scale's whole numbers, so
    // every seeded opinion kept its meaning and none of them landed on a tenth
    // a reader could not have reached.

    static let priya = ReaderProfile(
        id: "priya", name: "Priya Raghunathan", handle: "@priya",
        texture: "Reads one book at a time, slowly, and re-reads more than she reads.",
        accent: .clay,
        ratings: [
            "employees": 10.0, "severance": 9.0, "convenience": 10.0, "vegetarian": 9.0,
            "fifth-season": 8.0, "obelisk-gate": 9.0, "temporary": 10.0, "bullshit-jobs": 7.0,
            "checkout-19": 9.0, "tenth-december": 6.0, "drifts": 8.0, "earthlings": 7.0,
            "whereabouts": 8.0, "piranesi": 9.0,
        ],
        favoriteBookIDs: ["employees", "severance", "convenience", "fifth-season"],
        // Severance is a 9 of hers and it is still the one she would pick, over
        // two tens. The Fifth Season is an 8 at No. 4, above a book she gave
        // full marks. Neither is a mistake in the corpus — see
        // `ReaderProfile.rankedBookIDs`.
        rankedBookIDs: [
            "severance", "convenience", "employees", "fifth-season", "temporary",
            "piranesi", "checkout-19", "obelisk-gate", "vegetarian", "drifts",
            "whereabouts", "earthlings", "bullshit-jobs", "tenth-december",
        ],
        listIDs: ["work-strange", "spite"],
        followerCount: 412, followingCount: 168,
        memberSince: d(2019, 3, 8)
    )

    static let marcus = ReaderProfile(
        id: "marcus", name: "Marcus Lindqvist", handle: "@marcus",
        texture: "Two books going at once and abandons both if they stop earning it.",
        accent: .sea,
        ratings: [
            "sixth-extinction": 10.0, "consider-lobster": 10.0, "entangled-life": 9.0,
            "argonauts": 9.0, "bluets": 8.0, "red-white-royal": 8.0, "slouching": 10.0,
            "trick-mirror": 9.0, "white-album": 9.0, "peregrine": 8.0, "middlemarch": 5.0,
            "severance": 7.0, "piranesi": 10.0, "station-eleven": 8.0,
        ],
        // Four, like everyone else. Marcus used to carry five, back when this
        // list was an unlimited mark that the profile truncated for display;
        // now it *is* the profile's four and a fifth would be a bug rather than
        // a demonstration. His other loves live on his diary entries as
        // Favorites, where there is no cap at all — which is the distinction
        // the corpus is now here to show.
        favoriteBookIDs: ["sixth-extinction", "consider-lobster", "argonauts", "piranesi"],
        // Red, White & Royal Blue is an 8 sitting fifth, above three of his
        // four tens. That is the clearest case in the corpus of preference and
        // judgement pulling apart, and it is the reason a stranger reading his
        // profile learns something a sorted list of scores could not tell them.
        rankedBookIDs: [
            "piranesi", "argonauts", "consider-lobster", "sixth-extinction",
            "red-white-royal", "white-album", "slouching", "entangled-life",
            "trick-mirror", "peregrine", "bluets", "station-eleven", "severance",
            "middlemarch",
        ],
        listIDs: ["essays-pressed", "abandoned"],
        followerCount: 4_204, followingCount: 311,
        memberSince: d(2017, 11, 19)
    )

    static let ana = ReaderProfile(
        id: "ana", name: "Ana Beltrán", handle: "@ana",
        texture: "Reads short story collections almost exclusively, plus Middlemarch every January.",
        accent: .plum,
        ratings: [
            "tenth-december": 10.0, "her-body": 10.0, "friday-black": 9.0, "middlemarch": 10.0,
            "mill-floss": 8.0, "cloud-cuckoo": 7.0, "interpreter-maladies": 9.0,
            "what-we-talk": 8.0, "checkout-19": 10.0, "whereabouts": 9.0, "song-achilles": 8.0,
            "earthlings": 9.0, "station-eleven": 7.0,
        ],
        favoriteBookIDs: ["tenth-december", "her-body", "friday-black", "middlemarch"],
        // The Song of Achilles is an 8 at No. 3, over two tens. Middlemarch is
        // a ten *and* first, which matters too: a corpus where score and
        // ranking always disagree would be as unbelievable as one where they
        // never do.
        rankedBookIDs: [
            "middlemarch", "her-body", "song-achilles", "tenth-december",
            "checkout-19", "friday-black", "interpreter-maladies", "mill-floss",
            "whereabouts", "what-we-talk", "earthlings", "cloud-cuckoo",
            "station-eleven",
        ],
        listIDs: ["collections-ruined", "lied-about"],
        followerCount: 1_367, followingCount: 94,
        memberSince: d(2018, 6, 24)
    )

    static let tobias = ReaderProfile(
        id: "tobias", name: "Tobias Nkemelu", handle: "@tobias",
        texture: "Poetry, mostly, and the kind of nature writing that isn't really about nature.",
        accent: .dusk,
        ratings: [
            "deaf-republic": 10.0, "citizen": 10.0, "postcolonial-love": 9.0, "peregrine": 10.0,
            "h-is-hawk": 8.0, "dont-call-us-dead": 9.0, "averno": 9.0, "bluets": 9.0,
            "human-acts": 9.0,
        ],
        favoriteBookIDs: ["deaf-republic", "citizen", "peregrine", "postcolonial-love"],
        // Bluets is a 9 above two tens. The shortest ranking in the corpus, and
        // deliberately: nine books is what a reader who joined in 2023 has
        // placed, and the profile has to read well at that size too.
        rankedBookIDs: [
            "deaf-republic", "bluets", "citizen", "peregrine", "averno",
            "h-is-hawk", "postcolonial-love", "dont-call-us-dead", "human-acts",
        ],
        listIDs: ["poems-for-people"],
        followerCount: 38, followingCount: 217,
        memberSince: d(2023, 9, 2)
    )

    static let me = ReaderProfile(
        id: "me", name: "You", handle: "@you",
        texture: "Working it out.",
        accent: .ochre,
        // Empty on purpose — `DeweyStore.allMyRatings` is the authority on your
        // own ratings, because it folds the diary in and this dictionary cannot.
        ratings: [:],
        favoriteBookIDs: ["severance", "tenth-december", "her-body", "piranesi"],
        // Empty for the same reason: `DeweyStore.ranking` is the authority on
        // your own ordering, because you can change it and this cannot.
        // Ordered after `favoriteBookIDs` to match the declaration order the
        // memberwise initialiser requires.
        rankedBookIDs: [],
        listIDs: [],
        followerCount: 61, followingCount: 143,
        memberSince: d(2024, 10, 6)
    )

    static func reader(_ id: String) -> ReaderProfile? {
        (readers + [me]).first { $0.id == id }
    }

    // MARK: - Lists

    static let lists: [BookList] = [
        list("work-strange", "Books that made work feel strange", "Not books about jobs. Books that left me noticing I have one.",
             "priya", ordered: false, [
                ("employees", "Ninety minutes. I sat on the train afterwards for a while."),
                ("severance", "The bit where she keeps going into the office is the horror."),
                ("convenience", "The only one of these with a happy ending, arguably."),
                ("temporary", nil),
                ("bullshit-jobs", "More convincing in the first half than the second."),
             ], created: d(2025, 3, 11), updated: d(2026, 6, 2)),

        list("spite", "Novels I finished out of spite", "Books that lost me by page forty and were not allowed to win.",
             "priya", ordered: true, [
                ("cloud-cuckoo", "Six hundred pages and I resented four hundred of them. Fine ending. Still angry."),
                ("mill-floss", "The flood is doing a lot of heavy lifting."),
                ("drifts", "I understand what it's doing. I didn't enjoy being right about it."),
                ("cloud-atlas", "Everyone told me the middle section was the point. It was not."),
             ], created: d(2025, 9, 4), updated: d(2026, 5, 19)),

        list("essays-pressed", "Essays I've pressed on strangers", "Physically handed over. I have lost four of these copies and regret none of it.",
             "marcus", ordered: true, [
                ("consider-lobster", "Start with the lobster one. Obviously."),
                ("slouching", "Everyone quotes the same three lines and misses that she's mostly tired."),
                ("argonauts", "Lent this to my brother. He has not spoken to me about it, which I take as a good sign."),
                ("trick-mirror", nil),
                ("white-album", "The sequel nobody asked for and everybody needed."),
             ], created: d(2024, 11, 8), updated: d(2026, 7, 14)),

        list("abandoned", "Books I abandoned and do not feel bad about", "Life is short and page 60 is a perfectly good place to stop.",
             "marcus", ordered: false, [
                ("middlemarch", "Got to the third Casaubon chapter and put it down like a hot pan."),
                ("cloud-atlas", "Two nested stories in I realised I did not care about anyone."),
                ("earthlings", "I know what happens. I was told what happens. That was enough."),
                ("mill-floss", nil),
                ("drifts", "Reader, I drifted."),
             ], created: d(2025, 6, 21), updated: d(2026, 4, 30)),

        list("collections-ruined", "Collections that ruined novels for me", "After these, three hundred pages started to feel like padding.",
             "ana", ordered: true, [
                ("tenth-december", "\"Victory Lap\" is the best forty pages of the decade and I will not be debating this."),
                ("her-body", "The episode guide. That's it. That's the entry."),
                ("friday-black", "The fifth story, not the first. Everyone gets this wrong."),
                ("interpreter-maladies", "Quiet in a way that took me three tries to hear."),
                ("what-we-talk", "Half of this is Gordon Lish and I've made peace with it."),
             ], created: d(2024, 8, 2), updated: d(2026, 7, 28)),

        list("lied-about", "Books I have lied about finishing", "A confession in six parts. I have now actually finished two of them.",
             "ana", ordered: false, [
                ("cloud-atlas", "Lied at a dinner party in 2019. Still haven't."),
                ("bullshit-jobs", "Read the introduction and one interview and formed strong opinions."),
                ("peregrine", "Genuinely intend to. Genuinely have not."),
                ("middlemarch", "The exception — I do reread this every January. The lie was in 2016."),
             ], created: d(2026, 1, 9), updated: d(2026, 6, 11)),

        list("poems-for-people", "Poems for people who don't read poems", "Each of these got someone who'd sworn off poetry to finish a whole book of it.",
             "tobias", ordered: true, [
                ("deaf-republic", "Give people this one first. It reads like a play and it moves."),
                ("citizen", "The second person does the work. You are in it before you notice."),
                ("postcolonial-love", nil),
                ("dont-call-us-dead", "\"summer, somewhere\" — read that and then decide."),
                ("averno", "The hardest of these. Save it for someone who's already been converted."),
             ], created: d(2025, 2, 17), updated: d(2026, 3, 22)),

        list("doorstops", "Doorstops worth the wrist pain", "Over four hundred pages and every one of them earned.",
             "tobias", ordered: false, [
                ("middlemarch", "Nine hundred pages and not one of them wasted."),
                ("fifth-season", nil),
                ("cloud-atlas", "Structurally showing off, and it gets away with it."),
                ("song-achilles", "Not long. Feels long in the good way, at the end."),
             ], created: d(2025, 11, 30), updated: d(2026, 2, 8)),
    ]

    static let myLists: [BookList] = [
        list("my-devastated", "Books that devastated me on public transport", "Ranked by how hard it was to keep a straight face.",
             "me", ordered: true, [
                ("song-achilles", "Overground, Highbury to Dalston. Not subtle about it."),
                ("her-body", "Bus. Had to stop and look out the window for a stop and a half."),
                ("tenth-december", "\"Victory Lap\". On the tube. Absolute state."),
                ("employees", "Train. Sat there after everyone got off."),
             ], created: d(2026, 2, 14), updated: d(2026, 7, 30)),

        list("my-next", "Next, probably", "The pile. Honest about the fact that half of these will not happen.",
             "me", ordered: false, [
                ("piranesi", "Three people now. Fine. I get it."),
                ("deaf-republic", "Tobias made a case for this and I have not stopped thinking about it."),
                ("entangled-life", nil),
                ("checkout-19", nil),
             ], created: d(2026, 5, 3), updated: d(2026, 8, 1)),
    ]

    // MARK: - Reviews

    static let reviews: [Review] = [
        r("rf1", "employees", "priya", "It's a novel written as HR statements, which sounds unbearable and takes ninety minutes. I finished it on a train and then sat there. Nobody in it is sure whether they're a person, and neither was I by the end.", 10.0, d(2026, 6, 2), 128, favorite: true),
        r("rf2", "severance", "priya", "The apocalypse is not the horror. The horror is that she keeps going into the office.", 9.0, d(2026, 4, 18), 96),
        r("rf3", "convenience", "priya", "Everyone reads this as sad. I think it's the only book I've read where someone actually gets what they want.", 10.0, d(2025, 11, 12), 74, favorite: true),
        r("rf4", "temporary", "priya", "Same joke as Severance told faster and meaner. A hundred pages shorter, too, which is its own argument.", 10.0, d(2026, 7, 21), 41),
        r("rf5", "tenth-december", "priya", "Everyone says the last story destroyed them. I found it a bit tidy. A six of admiration and no love, which is the worst kind of book to argue about.", 6.0, d(2026, 3, 5), 63),
        r("rf6", "fifth-season", "priya", "Four hundred pages of geology as a metaphor for who gets to be a person. The second-person sections are doing something I've not seen work before.", 8.0, d(2025, 8, 30), 55),

        r("rf7", "consider-lobster", "marcus", "He goes to a lobster festival and comes back with a question nobody at the festival wanted asked. That's the whole method and it works every time.", 10.0, d(2026, 5, 9), 112, favorite: true),
        r("rf8", "slouching", "marcus", "Everyone quotes the same three lines and misses that she is mostly writing about being tired. I've abandoned better-argued books. This one just refuses to be agreed with.", 10.0, d(2026, 6, 27), 143),
        r("rf9", "middlemarch", "marcus", "Got to the third Casaubon chapter and put it down like a hot pan. I am aware this is a me problem. I do not intend to fix it.", 5.0, d(2026, 1, 22), 87),
        r("rf10", "red-white-royal", "marcus", "Yes. I've read Didion this year and I'm telling you this is the one I'd take to a hospital waiting room. Grow up.", 8.0, d(2026, 2, 11), 156, favorite: true),
        r("rf11", "piranesi", "marcus", "I finished it and immediately started it again, which I have done twice in my life. The house is the best character in anything I read this year.", 10.0, d(2026, 7, 3), 134, favorite: true),
        r("rf12", "entangled-life", "marcus", "Hopeful science writing that isn't stupid about it. Rare combination.", 9.0, d(2025, 10, 14), 38),
        r("rf13", "severance", "marcus", "Fine. Bit pleased with itself. The office stuff is better than the apocalypse stuff and I don't think that's intentional.", 7.0, d(2026, 4, 2), 29),

        r("rf14", "friday-black", "ana", "The first story is the one people talk about and the fifth is the one that got me. It's set in a shop on Black Friday and it is barely exaggerating. I put it down twice and picked it up both times.", 9.0, d(2026, 5, 30), 118),
        r("rf15", "her-body", "ana", "The episode guide to a show that doesn't exist is the single best thing in short fiction this decade and I will take that to arbitration.", 10.0, d(2026, 6, 14), 167, favorite: true),
        r("rf16", "middlemarch", "ana", "Ninth read. Every January. This year Dorothea seemed younger than me for the first time and I had to put it down for a day.", 10.0, d(2026, 1, 28), 201, favorite: true),
        r("rf17", "tenth-december", "ana", "\"Victory Lap\" is forty of the best pages written this century. The rest is very good. Those forty pages are something else.", 10.0, d(2025, 12, 3), 145),
        r("rf18", "cloud-cuckoo", "ana", "Six hundred pages that wanted to be five short stories. I say this with love, having finished all six hundred.", 7.0, d(2026, 3, 19), 52),
        r("rf19", "checkout-19", "ana", "A life told entirely through what she read. If that sentence appeals to you, you will finish it in two days. If it doesn't, don't.", 10.0, d(2026, 7, 26), 71),
        r("rf20", "earthlings", "ana", "I cannot warn you adequately and I would not want to. Read the first eighty pages and make your own decision.", 9.0, d(2026, 4, 8), 94, spoiler: true),
        r("rf21", "interpreter-maladies", "ana", "Quiet in a way that took me three tries to hear. Worth the three tries.", 9.0, d(2025, 9, 17), 33),

        r("rf22", "peregrine", "tobias", "He watched falcons for ten winters and the prose slowly stops belonging to a person. By the last section the sentences aren't observing the bird any more. I don't know a stranger book.", 10.0, d(2026, 6, 20), 108, favorite: true),
        r("rf23", "deaf-republic", "tobias", "A town goes deaf as an act of resistance. It reads like a play and moves like one. Give it to someone who says they don't read poetry and watch what happens.", 10.0, d(2026, 5, 2), 122, favorite: true),
        r("rf24", "citizen", "tobias", "The second person does all the work. You are inside it before you've noticed you agreed to be.", 10.0, d(2025, 11, 25), 89),
        r("rf25", "h-is-hawk", "tobias", "Grief and a goshawk, and it refuses to let either stand in for the other. That refusal is the whole book.", 8.0, d(2026, 2, 26), 47),
        r("rf26", "bluets", "tobias", "Two hundred and forty numbered fragments about blue. Should not work. Works.", 9.0, d(2026, 7, 9), 66),
        r("rf27", "human-acts", "tobias", "The chapter narrated by the body is the hardest thing I have read and I would not remove a sentence of it.", 9.0, d(2026, 3, 30), 78, spoiler: true),
        r("rf28", "averno", "tobias", "The hardest of hers. Save it for someone already converted.", 9.0, d(2025, 10, 5), 24),

        r("rf29", "song-achilles", "ana", "You know how it ends. You have known how it ends for three thousand years. It will still take you apart.", 8.0, d(2026, 4, 25), 138, spoiler: true),
        r("rf30", "station-eleven", "marcus", "\"Survival is insufficient\" is on a caravan and also, apparently, on a lot of tote bags now. The book is better than its merchandise.", 8.0, d(2026, 1, 15), 57),
        r("rf31", "whereabouts", "priya", "She wrote it in Italian and translated it back herself, which explains the strange flatness. I liked the flatness.", 8.0, d(2026, 6, 8), 42),
        r("rf32", "vegetarian", "priya", "Three men explain a woman to us and every one of them is wrong. The structure is the argument.", 9.0, d(2025, 7, 19), 85),
    ]

    // MARK: - You

    /// History from before the diary starts, on the 0.1–10.0 scale (§12.2).
    /// Migrated by doubling — see the note above the readers.
    ///
    /// Every value here is a whole number, and that is honest rather than lazy:
    /// these are ratings a person gave on a five-point scale years ago, and
    /// inventing a decimal for them would fabricate a precision they never had.
    /// Tenths appear as soon as anything is rated on the slider.
    static let myRatings: [String: Double] = myRatingsRaw.reduce(into: [:]) { out, pair in
        out[pair.key] = textured(pair.value, "me" + pair.key)
    }

    private static let myRatingsRaw: [String: Double] = [
        "severance": 10.0, "convenience": 9.0, "vegetarian": 8.0, "employees": 9.0,
        "tenth-december": 10.0, "sixth-extinction": 8.0, "trick-mirror": 7.0,
        "her-body": 8.0, "song-achilles": 10.0, "middlemarch": 7.0, "piranesi": 10.0,
        "station-eleven": 8.0, "friday-black": 9.0, "cloud-atlas": 5.0, "bluets": 9.0,
        "interpreter-maladies": 8.0,
    ]

    // MARK: - Worlds

    /// Everything `DeweyStore` owns, as one snapshot.
    ///
    /// Introduced so the two worlds are described in the same shape and can be
    /// swapped wholesale. Anything the store persists belongs here; if a new
    /// persisted collection is added and *not* added to this type, switching
    /// worlds would leave the old world's copy of it behind.
    struct World {
        var library: [LibraryEntry] = []
        var diary: [DiaryEntry] = []
        var lists: [BookList] = []
        /// **One ranking, not a list of them** (§19).
        var ranking = PersonalRanking()
        var recommendations: [Recommendation] = []
        var follows: Set<String> = []
        var needsOnboarding: Bool = false
        /// The four you feature on your profile. Empty in a fresh account —
        /// nobody starts with four books they have chosen, and seeding them
        /// would be the app choosing on the reader's behalf, which is the one
        /// thing this list must never do.
        var favoriteBookIDs: [String] = []
        /// Ratings predating the diary. Empty in a fresh account — see
        /// `DeweyStore.myRatings`.
        var myRatings: [String: Double] = [:]
    }

    static func world(for mode: WorldMode) -> World {
        switch mode {
        case .seeded: seededWorld
        case .fresh: freshWorld
        }
    }

    /// The demo corpus. What the prototype has always booted into.
    static let seededWorld = World(
        library: myLibrary,
        diary: myDiary,
        lists: myLists,
        ranking: myRanking,
        recommendations: [incomingRecommendation],
        // Everyone except Tobias, who is the edition's `.readerSuggestion`.
        // A suggestion card proposes somebody you do *not* follow, so seeding a
        // follow for him would filter his own card out of the demo edition —
        // and, less mechanically, "here is a reader you might like" about
        // somebody already on your list is nonsense. The seeded reader having
        // one un-followed person in the corpus is also just truer to how the
        // network looks in use.
        follows: Set(readers.map(\.id)).subtracting(["tobias"]),
        needsOnboarding: false,
        favoriteBookIDs: SeedData.me.favoriteBookIDs,
        myRatings: SeedData.myRatings
    )

    /// **Day one, and genuinely empty.**
    ///
    /// Every default on `World` is the honest one, so this is a literal with no
    /// arguments — which is the point. There is no starter library, no
    /// pre-followed reader, no sample list, and above all no fabricated
    /// follower count: `ReaderProfile.me` carries 61 followers and a 2024 join
    /// date because the demo reader has a history, and a fresh account must not
    /// borrow it. Surfaces that show those numbers read them from the store's
    /// own state in this mode, not from the seeded profile.
    ///
    /// `needsOnboarding` is the only thing set, and since §17 it decides
    /// nothing: the first run is gated on `SessionStore.phase`, and whether the
    /// taste steps are outstanding is answered by the server. It is left set so
    /// the persisted shape is unchanged — see `DeweyStore.needsOnboarding`.
    static let freshWorld = World(needsOnboarding: true)

    static let myLibrary: [LibraryEntry] = [
        le("l1", "temporary", .wantToRead, .person(readerID: "priya", via: .directRecommendation), "Priya's reason was very specific", d(2026, 8, 1)),
        le("l2", "piranesi", .finished, .person(readerID: "marcus", via: .review), nil, d(2026, 6, 30)),
        le("l3", "deaf-republic", .wantToRead, .person(readerID: "tobias", via: .list), nil, d(2026, 7, 12)),
        le("l4", "song-achilles", .finished, .outside(label: "A bookshop in Lisbon"), nil, d(2026, 4, 20)),
        le("l5", "severance", .finished, .ownSearch, nil, d(2025, 9, 2)),
        le("l6", "her-body", .finished, .person(readerID: "ana", via: .list), nil, d(2026, 6, 1)),
        le("l7", "checkout-19", .wantToRead, .person(readerID: "ana", via: .review), nil, d(2026, 7, 27)),
        le("l8", "entangled-life", .reading, .person(readerID: "marcus", via: .shelf), "Slow going, good going", d(2026, 7, 20)),
        le("l9", "middlemarch", .paused, .outside(label: "Everyone, constantly"), "Page 340. Will return.", d(2026, 1, 30)),
        le("l10", "cloud-atlas", .didNotFinish, .ownSearch, "Two sections in. Not for me.", d(2025, 11, 8)),
        le("l11", "friday-black", .finished, .person(readerID: "ana", via: .review), nil, d(2026, 5, 31)),
        le("l12", "bluets", .finished, .person(readerID: "tobias", via: .review), nil, d(2026, 7, 10)),
        le("l13", "tenth-december", .finished, .ownSearch, nil, d(2025, 6, 14)),
        le("l14", "station-eleven", .finished, .outside(label: "A podcast, ages ago"), nil, d(2026, 1, 20)),
    ]

    static let myDiary: [DiaryEntry] = [
        de("d1", "piranesi", .finished, s: d(2026, 6, 24), f: d(2026, 6, 30), r: 10.0, favorite: true,
           refl: "Marcus was right and I resent it slightly. The house is the best character I've met all year.",
           tags: ["fantasy"], fmt: .print),
        de("d2", "bluets", .finished, s: d(2026, 7, 8), f: d(2026, 7, 10), r: 9.0,
           refl: "Read it in one sitting on a Sunday. Two hundred and forty fragments and I've already gone back to eleven of them.",
           tags: ["poetry", "sunday"], fmt: .print),
        de("d3", "her-body", .finished, s: d(2026, 5, 20), f: d(2026, 6, 1), r: 8.0,
           refl: "The episode guide story is doing something I didn't know was allowed.", fmt: .ebook),
        de("d4", "friday-black", .finished, s: d(2026, 5, 24), f: d(2026, 5, 31), r: 9.0, fmt: .print),
        de("d5", "song-achilles", .finished, s: d(2026, 4, 12), f: d(2026, 4, 20), r: 10.0, favorite: true,
           refl: "Read the last thirty pages on the Overground and was not subtle about it.",
           tags: ["myth"], fmt: .print),
        de("d6", "station-eleven", .finished, s: d(2026, 1, 12), f: d(2026, 1, 20), r: 8.0, fmt: .audiobook),
        de("d7", "middlemarch", .paused, s: d(2026, 1, 2), f: nil, r: 7.0,
           note: "Page 340. Not abandoned. Paused.", fmt: .print),
        de("d8", "cloud-atlas", .didNotFinish, s: d(2025, 11, 1), f: d(2025, 11, 8), r: 5.0,
           refl: "Two nested stories in and I realised I didn't care what happened to anyone. Life's short.",
           fmt: .print),
        de("d9", "severance", .finished, s: d(2025, 8, 20), f: d(2025, 9, 2), r: 10.0, favorite: true,
           refl: "The office bits are scarier than the apocalypse bits and I don't think that's an accident.",
           tags: ["work"], fmt: .print, visibility: .followers),
        de("d10", "tenth-december", .finished, s: d(2025, 6, 2), f: d(2025, 6, 14), r: 10.0,
           refl: "\"Victory Lap\" — I had to put the book down and walk around.", fmt: .print),
        de("d11", "interpreter-maladies", .finished, s: d(2025, 5, 10), f: d(2025, 5, 22), r: 8.0, fmt: .print),
        de("d12", "trick-mirror", .finished, s: d(2025, 4, 1), f: d(2025, 4, 14), r: 7.0,
           refl: "Sharp, and I think it knows it's sharp, which cost it a point.", fmt: .ebook),
        de("d13", "convenience", .finished, s: d(2025, 2, 18), f: d(2025, 2, 24), r: 9.0, fmt: .print),
        de("d14", "employees", .finished, s: d(2025, 2, 14), f: d(2025, 2, 16), r: 9.0,
           refl: "Ninety minutes and I sat on the train afterwards.", fmt: .print),
        de("d15", "vegetarian", .finished, s: d(2025, 1, 8), f: d(2025, 1, 19), r: 8.0, fmt: .print),
        de("d16", "sixth-extinction", .finished, s: d(2024, 11, 12), f: d(2024, 11, 28), r: 8.0, fmt: .audiobook),
        // Rereads — the reason the diary is worth keeping.
        de("d17", "severance", .finished, s: d(2026, 3, 1), f: d(2026, 3, 9), r: 9.0,
           refl: "Second read. Slightly less devastating, slightly more impressive. Fair trade.", reread: true, fmt: .ebook,
           visibility: .followers),
        de("d18", "tenth-december", .finished, s: d(2026, 2, 2), f: d(2026, 2, 11), r: 10.0,
           refl: "Still \"Victory Lap\". Always \"Victory Lap\".", reread: true, fmt: .print),
    ]

    /// **The demo reader's one ranking** (§19).
    ///
    /// This was two — an all-books ordering and a "2026 so far" ordering — and
    /// they disagreed: Bluets sat sixth in one and third in the other. Two
    /// answers to one question is what the whole of §19 is about, and a corpus
    /// that shipped the contradiction was teaching it.
    ///
    /// **It also used to be the ratings, sorted.** Every book sat in score
    /// order, which made the ranked list a second rendering of the diary and
    /// quietly argued that a ranking is what you get when you sort your scores.
    /// The order below was written by hand to disagree in the places that
    /// matter:
    ///
    /// - **Her Body and Other Parties is an 8.0 at No. 3**, above Piranesi — a
    ///   10 and one of the four on the profile. This is the case the app has to
    ///   be able to state without flinching.
    /// - **Employees is a 9 at No. 6**, above Tenth of December and Friday
    ///   Black, both rated higher.
    /// - Cloud Atlas is last and is also the lowest score, because a corpus
    ///   where the two never agree is as false as one where they always do.
    static let myRanking = PersonalRanking(
        order: [
            "song-achilles", "severance", "her-body", "piranesi", "bluets",
            "employees", "tenth-december", "friday-black", "convenience",
            "station-eleven", "interpreter-maladies", "vegetarian",
            "middlemarch", "cloud-atlas",
        ],
        // Deliberately uneven, because a ranking in real use is. The top of the
        // list was placed carefully and the tail was not, which is what gives
        // "Tune your ranking" something honest to offer on first launch — see
        // `DeweyStore.tuningCandidates`. Five books sit on one comparison or
        // none, and Middlemarch's four are old enough to be worth revisiting.
        placements: [
            "song-achilles":        .init(comparisons: 5, placedAt: d(2026, 4, 20)),
            "severance":            .init(comparisons: 4, placedAt: d(2026, 3, 9)),
            "her-body":             .init(comparisons: 5, placedAt: d(2026, 6, 1)),
            "piranesi":             .init(comparisons: 5, placedAt: d(2026, 6, 30)),
            "bluets":               .init(comparisons: 4, placedAt: d(2026, 7, 10)),
            "employees":            .init(comparisons: 3, placedAt: d(2025, 2, 16)),
            "tenth-december":       .init(comparisons: 2, placedAt: d(2026, 2, 11)),
            "friday-black":         .init(comparisons: 1, placedAt: d(2026, 5, 31)),
            "convenience":          .init(comparisons: 1, placedAt: d(2025, 2, 24)),
            "station-eleven":       .init(comparisons: 3, placedAt: d(2026, 1, 20)),
            "interpreter-maladies": .init(comparisons: 1, placedAt: d(2025, 5, 22)),
            "vegetarian":           .init(comparisons: 0, placedAt: d(2025, 1, 19)),
            "middlemarch":          .init(comparisons: 3, placedAt: d(2025, 1, 30)),
            "cloud-atlas":          .init(comparisons: 1, placedAt: d(2025, 11, 8)),
        ]
    )

    // MARK: - The incoming recommendation

    static let incomingRecommendation = Recommendation(
        id: "rec-priya-temporary", bookID: "temporary",
        fromReaderID: "priya", toReaderID: nil,
        reason: .written("You gave Severance a ten. This is the same joke, told faster and meaner, and it's a hundred pages shorter."),
        sentAt: d(2026, 8, 1), status: .waiting, reply: nil, reaction: nil
    )

    // MARK: - The weekly edition

    static let edition: [EditionCard] = [
        .directRecommendation(recommendationID: incomingRecommendation.id),
        .fromList(readerID: "marcus", listID: "essays-pressed", bookID: "slouching"),
        .review(readerID: "ana", reviewID: "rf15"),
        .convergence(bookID: "checkout-19", readerIDs: ["priya", "ana"]),
        .favoriteBook(readerID: "priya", bookID: "fifth-season"),
        .readerSuggestion(readerID: "tobias"),
    ]

    // MARK: - Community shape

    /// The hand-tuned community shapes, still in the ten half-point buckets of
    /// the old 0.5–5.0 scale. Shapes vary on purpose — beloved books skew right,
    /// divisive ones go bimodal, obscure ones stay thin.
    ///
    /// **These stay at ten and are widened on read** (see `distributions`). The
    /// alternative was hand-writing forty-one twenty-element literals: eight
    /// hundred numbers nobody can review, and a very good place for a typo to
    /// live undetected for a year. Ten readable arrays plus one function that
    /// can be reasoned about is the same data with a much smaller surface to be
    /// wrong on.
    private static let halfScaleDistributions: [String: [Int]] = [
        "severance":            [4, 11, 28, 74, 186, 402, 811, 1240, 906, 388],
        "employees":            [3, 6, 14, 31, 68, 122, 198, 241, 176, 98],
        "convenience":          [6, 14, 32, 88, 214, 486, 968, 1402, 1011, 462],
        "vegetarian":           [22, 41, 88, 172, 341, 596, 902, 1104, 812, 498],
        "earthlings":           [88, 102, 141, 186, 244, 312, 388, 402, 366, 421],
        "fifth-season":         [8, 16, 34, 72, 168, 364, 742, 1288, 1402, 1103],
        "obelisk-gate":         [5, 9, 21, 48, 112, 268, 566, 942, 1024, 702],
        "temporary":            [2, 5, 12, 26, 51, 88, 132, 148, 96, 44],
        "tenth-december":       [4, 9, 22, 58, 142, 322, 688, 1102, 988, 604],
        "her-body":             [14, 26, 52, 108, 226, 412, 702, 908, 766, 512],
        "friday-black":         [3, 7, 18, 42, 96, 208, 402, 588, 466, 262],
        "middlemarch":          [42, 58, 96, 168, 302, 508, 812, 1188, 1402, 1602],
        "mill-floss":           [18, 28, 52, 96, 172, 288, 402, 466, 388, 244],
        "cloud-atlas":          [66, 82, 128, 206, 344, 522, 788, 1002, 866, 702],
        "cloud-cuckoo":         [24, 38, 72, 142, 268, 442, 668, 802, 604, 366],
        "piranesi":             [12, 18, 36, 72, 152, 322, 682, 1204, 1466, 1288],
        "song-achilles":        [18, 24, 48, 96, 188, 388, 802, 1466, 1808, 2104],
        "station-eleven":       [16, 26, 54, 118, 244, 488, 866, 1204, 1002, 622],
        "consider-lobster":     [8, 14, 28, 62, 128, 246, 402, 508, 402, 246],
        "slouching":            [12, 18, 36, 78, 158, 288, 466, 566, 448, 302],
        // Added 2026-08-04: the only book in the corpus with no distribution.
        // Harmless while the average was a caption; not harmless now the Dewey
        // Score is the headline and this page would have opened on an em dash.
        // Shaped off Slouching, thinner and a shade more divisive — it is the
        // harder book and fewer people finish it.
        "white-album":          [14, 20, 40, 82, 152, 262, 388, 442, 336, 214],
        "trick-mirror":         [26, 38, 68, 128, 246, 402, 588, 662, 466, 268],
        "argonauts":            [14, 22, 42, 88, 168, 288, 424, 488, 388, 244],
        "bluets":               [8, 12, 24, 48, 92, 158, 244, 302, 266, 188],
        "sixth-extinction":     [6, 10, 22, 52, 118, 244, 448, 602, 488, 268],
        "entangled-life":       [4, 8, 18, 42, 96, 206, 402, 566, 488, 288],
        "h-is-hawk":            [16, 24, 46, 92, 178, 302, 448, 502, 388, 226],
        "peregrine":            [12, 16, 28, 52, 94, 148, 208, 244, 226, 188],
        "citizen":              [8, 12, 26, 56, 118, 226, 402, 566, 522, 388],
        "deaf-republic":        [3, 5, 11, 24, 52, 108, 202, 288, 302, 246],
        "postcolonial-love":    [2, 4, 9, 20, 44, 88, 156, 208, 202, 162],
        "dont-call-us-dead":    [2, 4, 8, 18, 40, 82, 148, 202, 196, 154],
        "averno":               [4, 6, 12, 26, 52, 96, 148, 176, 158, 118],
        "checkout-19":          [18, 24, 42, 72, 118, 168, 208, 222, 176, 132],
        "drifts":               [22, 28, 44, 68, 96, 122, 138, 132, 96, 62],
        "whereabouts":          [16, 22, 38, 66, 108, 158, 202, 218, 172, 112],
        "red-white-royal":      [42, 52, 84, 148, 268, 466, 802, 1102, 1002, 866],
        "interpreter-maladies": [6, 10, 22, 52, 118, 244, 466, 668, 566, 344],
        "what-we-talk":         [12, 18, 34, 68, 132, 244, 402, 502, 402, 244],
        "human-acts":           [6, 9, 18, 40, 88, 176, 322, 466, 424, 288],
        "bullshit-jobs":        [18, 26, 48, 92, 168, 268, 388, 424, 322, 188],
    ]

    /// The distributions as the app reads them: twenty half-point buckets over
    /// 0.1–10.0, matching `DistributionHistogram.bucketCount` (§12.3).
    ///
    /// `static let` rather than a function, so the widening runs once per launch
    /// instead of once per scroll past a book page.
    static let distributions: [String: [Int]] = halfScaleDistributions.mapValues(widened)

    /// Spreads a ten-bucket distribution across twenty.
    ///
    /// Old bucket `i` meant "(i+1) × 0.5 out of 5", which doubles to "(i+1) out
    /// of 10" — new bucket `2i + 1`. Putting every count there and nowhere else
    /// leaves all ten even buckets empty and the histogram renders as a comb, so
    /// each count is spread 20 / 60 / 20 across `2i`, `2i+1` and `2i+2`. The
    /// spread is also the truer reading: a crowd that produced whole numbers on
    /// a five-point scale did not hold whole-number opinions, it was handed a
    /// form with five boxes.
    ///
    /// The centre bucket takes the **remainder** after both side shares are
    /// rounded, so the total is invariant. `communityCount` is printed beside
    /// the score, and a reader count that moves by three because of rounding is
    /// the kind of thing somebody notices exactly once and never trusts again.
    /// A share that would fall off the top of the array folds back into the
    /// centre for the same reason.
    static func widened(_ halfScale: [Int]) -> [Int] {
        let n = DistributionHistogram.bucketCount
        var split = Array(repeating: 0, count: n)

        // Each old bucket owns exactly two new ones, so split it evenly between
        // them. The first attempt spread each old bucket 20/60/20 across three
        // new ones, which looks reasonable and is not: every ODD bucket drew
        // from one old bucket while every EVEN bucket drew from two, so on
        // smooth data the odds landed about 1.5x the evens and the histogram
        // alternated tall/short down its whole length. On the app's headline
        // block that reads as broken data. An even split cannot do that — the
        // pair is equal by construction.
        for (i, count) in halfScale.enumerated() {
            let lo = 2 * i, hi = 2 * i + 1
            guard hi < n else { break }
            split[lo] = count / 2
            split[hi] = count - count / 2
        }

        // An even split is a staircase, so round it off with one [1,2,1] pass.
        var out = split
        for i in 0..<n {
            let left = split[max(i - 1, 0)]
            let right = split[min(i + 1, n - 1)]
            out[i] = (left + 2 * split[i] + right) / 4
        }

        // Integer division sheds a few counts. communityCount is displayed to
        // the reader ("604 readers rated it") and must match the seed exactly,
        // so the shortfall goes back to the peak, where it is invisible.
        let target = halfScale.reduce(0, +)
        let drift = target - out.reduce(0, +)
        if drift != 0, let peak = out.indices.max(by: { out[$0] < out[$1] }) {
            out[peak] += drift
        }
        return out
    }

    static let currentlyReading: [String: [String]] = [
        "checkout-19": ["priya"],
        "piranesi": ["ana"],
        "middlemarch": ["ana"],
        "entangled-life": ["tobias"],
        "song-achilles": ["marcus"],
        "deaf-republic": ["priya"],
    ]

    // MARK: - Builders

    /// `ddc`, `published`, `chars` and `setting` are all omitted wherever the
    /// real value isn't known for that book. A details table is the one part of
    /// a book page a reader can hold the book up against, so a blank row costs
    /// far less than a plausible wrong one.
    private static func b(
        _ id: String, _ title: String, _ author: String, _ year: Int,
        _ reach: Book.Reach, _ base: CoverPalette.ColorToken, _ ink: CoverPalette.InkTone,
        _ blurb: String,
        g: [String] = [], t: [String] = [],
        chars: [String] = [], setting: String? = nil,
        pages: Int? = nil, pub: String? = nil, isbn: String? = nil,
        ddc: String? = nil, published: Date? = nil, editions: Int? = nil,
        tr: String? = nil, narr: String? = nil, ill: String? = nil,
        series: String? = nil, pos: Int? = nil,
        rel: [String] = [], adaptation: String? = nil
    ) -> Book {
        Book(id: id, title: title, author: author, year: year, blurb: blurb,
             coverPalette: CoverPalette(base: base, ink: ink), reach: reach,
             series: series, seriesPosition: pos, genres: g, themes: t,
             characters: chars, setting: setting,
             pageCount: pages, publisher: pub, language: "English", isbn: isbn,
             deweyDecimal: ddc, publishDate: published, editionCount: editions,
             translator: tr, narrator: narr, illustrator: ill, editor: nil,
             relatedBookIDs: rel, adaptationNote: adaptation)
    }

    private static func list(
        _ id: String, _ title: String, _ premise: String, _ owner: String,
        ordered: Bool, _ entries: [(String, String?)],
        created: Date, updated: Date, isPublic: Bool = true
    ) -> BookList {
        BookList(
            id: id, title: title, premise: premise, ownerID: owner,
            isOrdered: ordered, isPublic: isPublic,
            items: entries.enumerated().map { i, e in
                BookList.Item(id: "\(id)-\(i)", bookID: e.0, note: e.1)
            },
            createdAt: created, updatedAt: updated
        )
    }

    private static func r(
        _ id: String, _ bookID: String, _ readerID: String, _ text: String,
        _ rating: Double, _ date: Date, _ appreciations: Int,
        spoiler: Bool = false, favorite: Bool = false
    ) -> Review {
        Review(id: id, bookID: bookID, readerID: readerID, text: text,
                   rating: Rating(textured(rating, id + bookID)), isSpoiler: spoiler, date: date,
                   appreciations: appreciations, isFavorite: favorite)
    }

    private static func le(
        _ id: String, _ bookID: String, _ status: ReadingStatus,
        _ origin: Provenance.Origin, _ note: String?, _ saved: Date
    ) -> LibraryEntry {
        LibraryEntry(id: id, bookID: bookID, status: status,
                     provenance: Provenance(origin: origin, reason: nil, date: saved),
                     note: note, tags: [], savedAt: saved)
    }

    private static func de(
        _ id: String, _ bookID: String, _ status: ReadingStatus,
        s: Date?, f: Date?, r: Double? = nil, favorite: Bool = false,
        refl: String? = nil, note: String? = nil, reread: Bool = false,
        tags: [String] = [], fmt: ReadingFormat? = nil,
        // Private by default, same as a real entry — most of the demo
        // account's reading is never explicitly shared. Only the couple of
        // entries the demo relies on to show a published reflection pass
        // `.followers` explicitly (see the "severance" calls below).
        visibility: Visibility = .onlyMe
    ) -> DiaryEntry {
        DiaryEntry(
            id: id, bookID: bookID, status: status,
            startedOn: s, finishedOn: f, loggedOn: f ?? s ?? Date(timeIntervalSince1970: 1_750_000_000),
            isReread: reread, rating: r.map { textured($0, id + bookID) }.flatMap(Rating.init), isFavorite: favorite,
            review: refl, reviewIsSpoiler: false, reviewIsDraft: false,
            visibility: visibility, privateNote: note, tags: tags, format: fmt
        )
    }
}
