import SwiftUI

/// The first screen, and the only one that has to sell anything.
///
/// **Moved out of `OnboardingView` unchanged** when account creation landed
/// (§17). It is now the first step of a longer sequence — welcome, sign in,
/// name and handle, then the four taste steps — and two different containers
/// need to draw it: `FirstRunFlow`, which follows it with sign-in, and
/// `OnboardingView`, which still owns all six taste steps and is what the debug
/// menu re-runs. One implementation, two footers. The copy, the cover band and
/// the reader card are exactly what they were.
///
/// It used to be three lines of type on an otherwise empty page: a kicker,
/// "Books, from people.", and a paragraph about a reading record that
/// remembers where every book came from. Both halves of that were wrong.
///
/// Wrong about the *product*, first. Provenance is one of the things Dewey
/// does, not the thing it is. The app a stranger is being handed rates,
/// ranks, reviews, lists, follows and recommends, and a first screen that
/// names only the quietest of those describes something narrower and more
/// solemn than what is behind the button.
///
/// Wrong about the *screen*, second. Three lines on a page the height of a
/// phone is mostly paper, and paper asks the reader to take the copy's word
/// for what the app looks like. A reading app is a visual object — covers,
/// scores, people — and it can simply show itself.
///
/// So the screen opens with the product: two full-bleed rows of the
/// catalogue's typeset covers, then a fragment of a real reader's profile
/// with her Favorite Books and the scores she gave them.
///
/// **Ranking is named in the copy and deliberately not pictured.** There is
/// no seeded ranking for any reader but the demo user's own, and the demo
/// user is exactly who a cold-start reader is not — putting "Everything,
/// ranked" on this screen would be the one fabrication the flow refuses.
/// Dressing the Favorite Books up as a ranking was the other candidate and
/// is worse: `Judgement.FavoriteBooksCopy` says in as many words that they
/// are *not* their top-ranked, so the card would contradict the vocabulary
/// the rest of the app teaches. A picture that lies to fill a gap costs
/// more than the gap.
struct WelcomeView: View {
    /// Four, matching the display constraint on every profile.
    private static let favoriteCap = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            coverBand

            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                Text("Dewey").kickerStyle()
                Text("A better way to keep books.")
                    .font(Theme.TypeScale.display())
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                // **"Rank your favorites" was three concepts in three words**
                // (§19.2), on the first screen anybody ever sees.
                //
                // Ranking is not about Favorites: `PersonalRanking` orders
                // everything a reader has finished, `Judgement.FavoriteCopy` is
                // an unlimited mark, and `FavoriteBooksCopy` is the four on the
                // profile. The sentence merged all three and taught a
                // definition the rest of the app then spends its time undoing.
                // "Rate" went with it — the act is scoring now, everywhere.
                //
                // What it says instead is the pair, in the order the app
                // introduces them, and nothing about Favorites at all. Ranking
                // is genuinely learned later — after a first log, where the
                // offer explains itself — so naming it here is a promise the
                // screen can keep without defining anything.
                Text(
                    """
                    Score what you read, rank it among your books, build lists, \
                    and discover what to read next through people whose taste \
                    you trust.
                    """
                )
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            }

            readerCard
        }
    }

    // MARK: - The shelf

    /// Intrinsic geometry, not layout spacing — the same category of constant as
    /// `RatingMark.Size` or `BookCoverView.width`, so it lives here rather than
    /// in `Theme.Space`.
    private static let bandCoverWidth: CGFloat = 54

    /// Height of the band: two cover rows and the gap between them. Stated
    /// rather than measured because the band is drawn in an overlay, and an
    /// overlay cannot report a height to its parent.
    private static var bandHeight: CGFloat {
        Self.bandCoverWidth * BookCoverView.aspectRatio * 2 + Theme.Space.tight
    }

    /// Two rows of covers running off both edges of the screen.
    ///
    /// The covers are typeset by `BookCoverView`, so this is not an illustration
    /// of a library — it is the same drawing code every shelf, grid and search
    /// result in the app uses, at a smaller width. What a reader sees here is
    /// what they will see for the rest of the product.
    private var coverBand: some View {
        // **Drawn in an overlay on a bounded box, then clipped** (§13.6).
        //
        // The rows are deliberately far wider than any screen, and hanging them
        // directly in the page's `VStack` meant that intrinsic width propagated
        // all the way up: the enclosing `ScrollView` sized its content to the
        // widest row, so the *entire welcome screen* became wider than the
        // display. At default type it merely bled; at accessibility sizes the
        // headline and the paragraph were both sliced down the middle, on both
        // edges, on the first screen a new reader ever sees.
        //
        // `Color.clear` accepts whatever width it is offered and states its own
        // height, so the parent is sized by the page rather than by the shelf.
        // The overlay draws over the top of that box and `clipped()` trims the
        // overflow. Same picture, no influence on layout.
        Color.clear
            .frame(height: Self.bandHeight)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    coverRow(Self.bandRows.top, offset: -Self.bandCoverWidth * 0.30)
                    coverRow(Self.bandRows.bottom, offset: -Self.bandCoverWidth * 0.78)
                }
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipped()
            // Cancels the page margin so the shelf reaches both edges and keeps
            // going. A band that stops politely inside the text column reads as
            // a picture of some books; one that runs off the page reads as a
            // library with more in it than fits.
            .padding(.horizontal, -Theme.Space.margin)
        // The rows are offset by different fractions of a cover so the seam
        // between them never lines up into a grid. Thirds and quarters were
        // both tried and both still read as a table.
        //
        // Texture, not information: VoiceOver reading thirty-odd titles before
        // reaching the headline would make the first screen unusable, and the
        // card below says the same thing in one sentence.
        .accessibilityHidden(true)
    }

    private func coverRow(_ books: [Book], offset: CGFloat) -> some View {
        HStack(spacing: Theme.Space.tight) {
            ForEach(books) { book in
                BookCoverView(book: book, width: Self.bandCoverWidth)
            }
        }
        // Wider than any screen, on purpose. `fixedSize` stops the stack
        // squeezing the covers down to fit, and the leading-aligned frame keeps
        // the row anchored at the edge so all of the overflow happens on the
        // right, where the scroll view clips it.
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .leading)
        .offset(x: offset)
    }

    /// The whole catalogue, dealt alternately into two rows.
    ///
    /// Dealt rather than hand-listed. A hardcoded set of ids would rot silently
    /// as the seed changes — an unknown id used to come back as the first book
    /// in the corpus, and the shelf would have quietly filled up with copies
    /// of The Employees. Dealing also means every book Dewey knows about is on
    /// the first screen, which is the honest version of the claim the band is
    /// making.
    private static let bandRows: (top: [Book], bottom: [Book]) = {
        let indexed = Array(SeedData.books.enumerated())
        return (
            indexed.filter { $0.offset.isMultiple(of: 2) }.map(\.element),
            indexed.filter { !$0.offset.isMultiple(of: 2) }.map(\.element)
        )
    }()

    // MARK: - The reader

    /// A named reader rather than a composite.
    ///
    /// The card is only worth anything if the person on it is somebody the
    /// reader can actually go and find, and Priya is a few steps away — she is a
    /// suggestion on the People step for anyone who picks the books she has
    /// read. An invented reader on the welcome screen would be the first thing
    /// the app ever told them, and it would be untrue.
    private static let specimenReader: ReaderProfile =
        SeedData.readers.first { $0.id == "priya" } ?? SeedData.priya

    /// Her four, in her order, with the scores she gave them.
    ///
    /// Read from `SeedData.readers` rather than `SeedData.priya` so the ratings
    /// are the textured ones the rest of the app shows. The raw seed is whole
    /// numbers, and a card of 10 / 9 / 10 / 8 would advertise a ten-point
    /// integer scale — the exact impression `SeedData.textured` exists to undo.
    private var readerCard: some View {
        CardShell(kicker: "A reader you might follow") {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                HStack(spacing: Theme.Space.snug) {
                    ReaderAvatarView(reader: Self.specimenReader, size: 38)
                    VStack(alignment: .leading, spacing: Theme.Space.hair) {
                        Text(Self.specimenReader.name)
                            .font(Theme.TypeScale.cardTitle())
                            .foregroundStyle(Theme.Palette.ink)
                        Text("\(Self.specimenReader.handle) · \(Self.specimenReader.followerCount.formatted()) followers")
                            .font(Theme.TypeScale.meta())
                            .foregroundStyle(Theme.Palette.inkSoft)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)

                Text(Self.specimenReader.texture)
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Rule().padding(.vertical, Theme.Space.hair)

                Text(Judgement.FavoriteBooksCopy.title).kickerStyle()

                HStack(alignment: .top, spacing: Theme.Space.tight) {
                    ForEach(Self.specimenBooks) { book in
                        favoriteSlot(book)
                    }
                }
            }
        }
    }

    /// `compactMap` over the optional lookup (§16): the specimen four are
    /// Priya's seed slugs and all resolve today, but a dangling one should
    /// cost the band a cover, not render as somebody else's book.
    private static let specimenBooks: [Book] =
        specimenReader.favoriteBookIDs.prefix(Self.favoriteCap).compactMap(SeedData.find)

    /// A cover with its score under it — the same slot the library and the
    /// profile use, which is why the numeral rather than the rules mark: at this
    /// width `RatingMark` renders ten strokes barely longer than they are thick
    /// and 6.0 stops being distinguishable from 10.0 (§12.8.2).
    ///
    /// The width is taken from the layout rather than computed from the screen.
    /// `BookCoverView` needs a number, and the arithmetic version of that number
    /// — page width less two page margins, less the card's padding, less three
    /// gaps — is four constants that have to be kept in agreement with three
    /// other files, and is wrong the moment the app is on an iPad, in a split
    /// view, or in any window that is not the full screen. The aspect-ratio box
    /// asks the layout what it actually got and matches the cover's own 1:1.5.
    private func favoriteSlot(_ book: Book) -> some View {
        VStack(spacing: Theme.Space.tight) {
            GeometryReader { geo in
                BookCoverView(book: book, width: geo.size.width)
            }
            .aspectRatio(1.0 / 1.5, contentMode: .fit)

            RatingMark(rating: Self.specimenRating(book))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.favoriteSlotLabel(book))
    }

    private static func specimenRating(_ book: Book) -> Rating? {
        specimenReader.ratings[book.id].flatMap(Rating.init)
    }

    private static func favoriteSlotLabel(_ book: Book) -> String {
        let score = specimenRating(book).map { ", \($0.spoken)" } ?? ""
        return "\(book.title) by \(book.author)\(score)"
    }
}
