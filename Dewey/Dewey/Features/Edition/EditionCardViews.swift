import SwiftUI

// MARK: - Shared helpers

/// A reader's rating for one book, as a `Rating` rather than a raw Double.
///
/// Pure view convenience — the model stores ratings as `[String: Double]` because
/// that is what overlap arithmetic wants, but every surface that *shows* one wants
/// the mark, and the mark takes a `Rating`.
private extension ReaderProfile {
    func rating(for bookID: String) -> Rating? {
        guard let value = ratings[bookID] else { return nil }
        return Rating(value)
    }
}

/// Cover, title, author — the block that appears on four of the five cards. A
/// rating rides along only when a caller passes one, and callers are expected to
/// have a reason.
///
/// Factored out because the rating is meant to be the repeated motif: if it lives
/// in one place, it cannot drift into five slightly different treatments.
///
/// The numeral, not the rules. This row previously drew a `.regular` mark — ten
/// accent-tinted capsules, 66pt wide, under the author. Two problems, both
/// measured: at `.regular` the partial capsule is shorter than it is thick for
/// any tenth up to .3, and at the top of the scale a 9.9 differs from a 10.0 by
/// half a point of length, so the mark could not actually tell 9.2 from 8.6 —
/// which is the exact distinction DirectRecommendationCard passes it to make.
/// And 66pt of accent colour under a 76pt cover was the loudest thing on a card
/// whose payload is the sender's reason. The numeral says the value in a quarter
/// the width and steps back.
///
/// **The `tint` went with the accent capsules** (§13.5). It survived the switch
/// to a numeral and kept colouring it, which is worse rather than better: a
/// single figure in the sender's colour reads as a claim about the *book*, and
/// on ConvergenceCard — two readers' scores side by side, one warm, one cool —
/// it reads as one of them being the better verdict. The rating is the one
/// figure that must mean the same thing everywhere, so it is always ink. The
/// sender is still identified, in the avatar and the name, where colour answers
/// "who" without being mistaken for "how good".
struct CardBookRow: View {
    let book: Book
    var width: CGFloat = 64
    var rating: Rating?

    var body: some View {
        NavigationLink(value: book) {
            // **The hole beside the cover** (§12.9), on the edition's most
            // repeated row.
            //
            // A 76pt cover is 114pt tall and a title-plus-author-plus-score
            // column is rarely more than 70, so top-aligning the two dumped
            // every leftover point underneath the text: a stack of type at the
            // top and empty card against the cover's lower half. The book page
            // hero was fixed for exactly this and this row was not.
            //
            // Nothing is measured. The text column takes the height of whichever
            // column is taller and centres inside it, so the two share one
            // optical centre; when the text is the taller one the centring is a
            // no-op and the row is top-aligned exactly as before. Holds at every
            // Dynamic Type size and for a one-word or five-line title.
            HStack(alignment: .top, spacing: Theme.Space.base) {
                BookCoverView(book: book, width: width, scalesWithType: true)
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    Text(book.title)
                        .font(Theme.TypeScale.cardTitle())
                        .foregroundStyle(Theme.Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(book.author)
                        .font(Theme.TypeScale.support())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if rating != nil {
                        RatingMark(rating: rating)
                            .padding(.top, Theme.Space.hair)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 1. Direct recommendation

/// Someone chose this for you specifically. The strongest claim on attention in
/// the product, so it opens the edition and is the only card with a filled
/// action button.
///
/// The reason is given more weight than the blurb — the point is not that the
/// book exists, it is that this person thought of you when they saw it.
struct DirectRecommendationCard: View {
    let recommendation: Recommendation
    @Environment(DeweyStore.self) private var store

    private var book: Book { store.book(recommendation.bookID) }
    private var sender: ReaderProfile? { store.reader(recommendation.fromReaderID) }

    var body: some View {
        CardShell(kicker: EditionCard.directRecommendation(recommendationID: recommendation.id).kicker) {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                if let sender {
                    senderRow(sender)
                }

                // Their rating rides along with the book. A recommendation from
                // someone who gave it a 9.2 is a different object from one they
                // merely finished — and on the 0.1–10.0 scale (§12.2) that
                // distinction is finer than it was: 9.2 and 8.6 used to round to
                // the same handful of stars and now visibly do not.
                CardBookRow(
                    book: book,
                    width: 76,
                    rating: sender?.rating(for: book.id)
                )

                reasonBlock

                RecommendationResponseRow(recommendation: recommendation)
            }
        }
    }

    private func senderRow(_ sender: ReaderProfile) -> some View {
        NavigationLink(value: sender) {
            HStack(spacing: Theme.Space.snug) {
                ReaderAvatarView(reader: sender, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(sender.name) sent you this")
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.ink)
                    Text(sender.texture)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    /// The reason, set as prose and given room. This is the payload.
    private var reasonBlock: some View {
        Text(recommendation.reason.text)
            .font(Theme.TypeScale.prose())
            .foregroundStyle(Theme.Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, Theme.Space.snug)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(sender?.accent.color.opacity(0.45) ?? Theme.Palette.rule)
                    .frame(width: 2)
            }
    }
}

// MARK: - 2. From a list

/// A book with a premise attached. The list title is doing the work — "Books
/// that made work feel strange" tells you more about whether you want this than
/// any rating could.
struct FromListCard: View {
    let reader: ReaderProfile
    let list: BookList
    let book: Book

    var body: some View {
        CardShell(kicker: EditionCard.fromList(readerID: reader.id, listID: list.id, bookID: book.id).kicker) {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                listHeader

                // No rating here, unlike the direct recommendation above. This
                // card ends on a ProvenanceLine — "Ana's list" — and that line
                // plus the list title is the whole claim, per §7.2 and the
                // header comment on this struct. A tinted number sitting above
                // the provenance out-argues it, and the premise the card was
                // built to sell is the thing it should be answering to.
                CardBookRow(book: book, width: 64)

                // Why this one is on the list, when the owner said so. The list's
                // premise is the argument; the note is the evidence.
                if let note = list.note(for: book.id) {
                    Text(note)
                        .font(Theme.TypeScale.prose())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                NavigationLink(value: reader) {
                    ProvenanceLine(text: "\(reader.name)'s list", reader: reader)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var listHeader: some View {
        NavigationLink(value: list) {
            VStack(alignment: .leading, spacing: 3) {
                Text(list.title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.leading)
                Text(list.premise)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 3. Review

/// Someone wrote something. The one card that leads with prose, set large and
/// serif because it is the only thing on the screen a person actually made.
struct ReviewCard: View {
    let reader: ReaderProfile
    let review: Review
    let book: Book

    /// The review's own rating first — it is the one attached to *this*
    /// piece of writing — and their shelf rating only as a fallback.
    private var shownRating: Rating? {
        review.rating ?? reader.rating(for: book.id)
    }

    var body: some View {
        CardShell(kicker: EditionCard.review(readerID: reader.id, reviewID: review.id).kicker) {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                Text(review.text)
                    .font(Theme.TypeScale.proseLarge())
                    .foregroundStyle(Theme.Palette.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Rule()

                HStack(spacing: Theme.Space.snug) {
                    readerSide
                    Spacer(minLength: 0)
                    bookSide
                }
            }
        }
    }

    /// Name and mark travel together. A verdict without a face is a score; a face
    /// without a verdict makes you open the card to find out what they thought.
    private var readerSide: some View {
        NavigationLink(value: reader) {
            HStack(spacing: Theme.Space.tight) {
                ReaderAvatarView(reader: reader, size: 26)
                Text(reader.name)
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .lineLimit(1)
                if shownRating != nil {
                    RatingMark(rating: shownRating)
                }
                if review.isFavorite {
                    FavoriteMark(filled: true, size: 13)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var bookSide: some View {
        NavigationLink(value: book) {
            HStack(spacing: Theme.Space.tight) {
                Text(book.title)
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.accent)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 4. Convergence

/// Several people hold the same book. Consolidated into one card rather than
/// repeated — four identical rows would read as noise, and the fact that it is
/// *several* readers is itself the entire signal.
struct ConvergenceCard: View {
    let book: Book
    let readers: [ReaderProfile]

    private var names: String {
        switch readers.count {
        case 0: "Several readers"
        case 1: readers[0].name
        case 2: "\(readers[0].name) and \(readers[1].name)"
        default: "\(readers[0].name), \(readers[1].name) and \(readers.count - 2) more"
        }
    }

    private var rated: [ReaderProfile] {
        readers.filter { $0.rating(for: book.id) != nil }
    }

    var body: some View {
        CardShell(kicker: EditionCard.convergence(bookID: book.id, readerIDs: readers.map(\.id)).kicker) {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                CardBookRow(book: book, width: 64)

                attributionRow

                // Convergence without verdicts is just a coincidence. The marks
                // are what turn "three people have it" into something you can act
                // on — including when they disagree, which is the interesting case.
                if !rated.isEmpty {
                    Rule()
                    ratingsRow
                }
            }
        }
    }

    /// Attribution survives consolidation — you can always see who, not just how
    /// many.
    private var attributionRow: some View {
        HStack(spacing: -8) {
            ForEach(readers) { r in
                ReaderAvatarView(reader: r, size: 26)
                    .overlay(Circle().stroke(Theme.Palette.card, lineWidth: 2))
            }
            Text(names)
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .padding(.leading, Theme.Space.base)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ratingsRow: some View {
        FlowLayout(spacing: Theme.Space.base) {
            ForEach(rated) { reader in
                ratingPair(reader)
            }
        }
    }

    private func ratingPair(_ reader: ReaderProfile) -> some View {
        HStack(spacing: Theme.Space.tight) {
            Text(firstName(reader))
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
            RatingMark(rating: reader.rating(for: book.id))
        }
        .accessibilityElement(children: .combine)
    }

    private func firstName(_ reader: ReaderProfile) -> String {
        reader.name.split(separator: " ").first.map(String.init) ?? reader.name
    }
}

// MARK: - 4b. Favorite book

/// One of the four books a reader chose to feature on their profile. No
/// premise, no prose — the claim is just that this book made their cut, and
/// that claim carries on its own.
struct FavoriteBookCard: View {
    let reader: ReaderProfile
    let book: Book

    var body: some View {
        CardShell(kicker: EditionCard.favoriteBook(readerID: reader.id, bookID: book.id).kicker) {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                CardBookRow(book: book, width: 76, rating: reader.rating(for: book.id))

                NavigationLink(value: reader) {
                    ProvenanceLine(
                        text: "One of \(reader.name)'s four \(Judgement.FavoriteBooksCopy.title)",
                        reader: reader
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 5. Reader suggestion

/// A person, not a book.
///
/// Note the honesty here: Tobias shares nothing with the seeded user, and the
/// card says so rather than inventing a match. A product that manufactures
/// overlap to fill a card has already broken the only promise it makes.
struct ReaderSuggestionCard: View {
    let reader: ReaderProfile
    @Environment(DeweyStore.self) private var store

    private var overlap: TasteOverlap { store.overlap(with: reader) }

    /// **Four**, not five. The constraint is the whole point of the row.
    private var favoriteBookIDsShown: [String] {
        Array(reader.favoriteBookIDs.prefix(4))
    }

    var body: some View {
        CardShell(kicker: EditionCard.readerSuggestion(readerID: reader.id).kicker) {
            NavigationLink(value: reader) {
                VStack(alignment: .leading, spacing: Theme.Space.base) {
                    identityRow
                    favoriteRow
                    Rule()
                    overlapLine
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var identityRow: some View {
        HStack(spacing: Theme.Space.snug) {
            ReaderAvatarView(reader: reader, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(reader.name)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Theme.Palette.ink)
                Text(reader.texture)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
    }

    /// The four covers, each carrying what they gave it. Four books and four
    /// marks say more about a stranger's taste than any biography would.
    private var favoriteRow: some View {
        HStack(alignment: .top, spacing: Theme.Space.snug) {
            ForEach(favoriteBookIDsShown, id: \.self) { id in
                favoriteBookCover(id)
            }
            Spacer(minLength: 0)
        }
    }

    private func favoriteBookCover(_ id: String) -> some View {
        VStack(spacing: Theme.Space.tight) {
            BookCoverView(book: store.book(id), width: 46)
            RatingMark(rating: reader.rating(for: id))
        }
    }

    /// **Branches on nothing-in-common, not on `isMeaningful`.**
    ///
    /// `TasteOverlap.isMeaningful` is `count >= 2`, which is the right test for
    /// "is this worth arguing from" and the wrong one for "is this true". With
    /// exactly one shared book the card printed "Nothing in common yet" about a
    /// reader whose book was already in the library — while `overlap.headline`,
    /// used on that same reader's profile one tap away, said "One book in
    /// common". The two screens contradicted each other about a fact the reader
    /// could check.
    ///
    /// `headline` already handles nought, one and many correctly, so the honest
    /// version is to print it and reserve the suggested-because sentence for a
    /// genuinely empty overlap.
    private var overlapText: String {
        guard overlap.count > 0 else {
            return "Nothing in common yet — suggested because two readers you've looked at both follow them."
        }
        let head: String = "\(overlap.headline) with you"
        if let qualifier: String = overlap.qualifier {
            return head + ", " + qualifier + "."
        }
        return head + "."
    }

    private var overlapLine: some View {
        Text(overlapText)
            .font(Theme.TypeScale.support())
            .foregroundStyle(Theme.Palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Dispatch

/// Dispatches to the right card. Each card type exists because it carries a
/// genuinely different kind of context — if two of them could be merged without
/// losing meaning, one of them should not exist.
///
/// Every case guards its lookups. A card whose seed ids have drifted renders as
/// nothing rather than crashing the edition around it.
struct EditionCardView: View {
    let card: EditionCard
    @Environment(DeweyStore.self) private var store

    var body: some View {
        switch card {
        case .directRecommendation(let recID):
            if let rec = store.recommendation(recID) {
                DirectRecommendationCard(recommendation: rec)
            }

        case .fromList(let readerID, let listID, let bookID):
            if let reader = store.reader(readerID), let list = store.list(listID) {
                FromListCard(reader: reader, list: list, book: store.book(bookID))
            }

        case .review(let readerID, let reviewID):
            if let reader = store.reader(readerID),
               let review = store.allReviews.first(where: { $0.id == reviewID }) {
                ReviewCard(
                    reader: reader,
                    review: review,
                    book: store.book(review.bookID)
                )
            }

        case .convergence(let bookID, let readerIDs):
            ConvergenceCard(
                book: store.book(bookID),
                readers: readerIDs.compactMap { store.reader($0) }
            )

        case .favoriteBook(let readerID, let bookID):
            if let reader = store.reader(readerID) {
                FavoriteBookCard(reader: reader, book: store.book(bookID))
            }

        case .readerSuggestion(let readerID):
            if let reader = store.reader(readerID) {
                ReaderSuggestionCard(reader: reader)
            }
        }
    }
}
