import SwiftUI

/// A finite, weekly edition, built from the readers you follow.
///
/// Weekly rather than daily because the arithmetic says so. Thirty people
/// reading twenty books a year produce roughly eleven finish-events a week and
/// about one and a half a day — a daily surface is empty most days, a weekly
/// one is an edition. It also lets a quiet week read as a short edition rather
/// than a broken screen.
///
/// What is deliberately absent: infinite scroll, timestamps, unread counts,
/// trending, follower counts, any number that could be improved. The edition
/// ends, and the ending is designed.
struct WeeklyEditionView: View {
    @Environment(DeweyStore.self) private var store

    #if DEBUG
    @State private var showingDebug = false   // TEMPORARY — prototype controls
    #endif

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Space.roomy) {
                header
                yourShelf

                if isColdStart {
                    coldStart
                    // The suggestions are the cold start's one actionable thing,
                    // so they are shown *with* it rather than instead of it.
                    ForEach(cards) { card in
                        EditionCardView(card: card)
                            .pageMargin()
                    }
                } else if cards.isEmpty {
                    quietWeek
                } else {
                    ForEach(cards) { card in
                        EditionCardView(card: card)
                            .pageMargin()
                    }

                    EditionEndView(readerCount: store.readers.count)
                }
            }
            .padding(.bottom, Theme.Space.roomy)
        }
        .background(Theme.Palette.paper)
        .scrollIndicators(.hidden)
        // "Edition", not "Dewey" — the tab directly above says "Edition", and a
        // screen that answers to the app's own name instead of its tab's is the
        // same vocabulary problem `LibraryView` already fixed once (§13.3). This
        // title dates from when the edition was the app's only front surface;
        // now that Home exists, four of five tabs title themselves after
        // themselves, and this was the one holdout still claiming to be Dewey.
        .deweyNavigationTitle("Edition")
        #if DEBUG
        .debugMenu(isPresented: $showingDebug)
        #endif
    }

    /// This week's cards, filtered to who you actually follow (§13.7).
    private var cards: [EditionCard] { store.edition }

    /// **Following nobody is the cold start, whatever survives the filter.**
    ///
    /// The screen branched on `cards.isEmpty`, which is not the same question.
    /// `DeweyStore.edition` keeps a `.readerSuggestion` card precisely *because*
    /// its subject is somebody you do not follow — so a brand-new account with
    /// an empty follow set still had a card, took the populated branch, and got
    /// a header reading "One thing from the readers you follow" above a card
    /// proposing a stranger. §13.7 wrote the honest cold-start block for exactly
    /// this state, and no account could ever reach it.
    private var isColdStart: Bool { store.follows.isEmpty }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(weekLabel).kickerStyle()

            Text("This week")
                .font(Theme.TypeScale.display())
                .foregroundStyle(Theme.Palette.ink)

            // Counts what is actually below it. The line used to read "Five
            // things from the readers you follow" unconditionally, which was
            // wrong twice over in a fresh account: there were not five, and
            // they were not from readers you follow.
            Text(subtitle)
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
        .padding(.top, Theme.Space.snug)
        .padding(.bottom, Theme.Space.tight)
    }

    /// Counts what is actually below it, and never claims a card came from
    /// somebody the reader follows while they follow nobody.
    private var subtitle: String {
        if isColdStart { return "Your edition is built from the readers you follow." }
        switch cards.count {
        case 0: return "A quiet week. Nothing from the readers you follow."
        case 1: return "One thing from the readers you follow."
        default: return "\(cards.count) things from the readers you follow."
        }
    }

    /// **What onboarding already put here.** Taste onboarding logs picks,
    /// ratings and favourites straight into the library (`OnboardingView.
    /// commitPicks`), and says so once — "Your library is yours now" — on the
    /// last onboarding screen. That screen then closes, and nothing used to
    /// carry the point onto the first screen the reader actually lands on.
    ///
    /// **This used to be gated on `isColdStart`**, which is a narrower state
    /// than "just finished onboarding": the intended path through the People
    /// step follows at least one suggested reader, which clears `isColdStart`
    /// immediately. A reader who did exactly what onboarding asked landed on a
    /// page entirely about the people they just followed, with no sign Dewey
    /// noticed the four books they rated an hour earlier — only a reader who
    /// skipped or followed nobody saw their own picks reflected back. That had
    /// it backwards. Now it renders whenever there is something to show,
    /// ahead of whichever of cold start, a quiet week, or real cards follows —
    /// `recentOwnPicks` is only ever the two most recent saves, so it keeps
    /// telling the truth as the library grows past onboarding rather than
    /// aging into a stale reference to it.
    private var recentOwnPicks: [LibraryEntry] {
        Array(store.library.sorted { $0.savedAt > $1.savedAt }.prefix(2))
    }

    @ViewBuilder
    private var yourShelf: some View {
        if !recentOwnPicks.isEmpty {
            CardShell(kicker: "Already on your shelf") {
                VStack(alignment: .leading, spacing: Theme.Space.base) {
                    ForEach(recentOwnPicks) { entry in
                        CardBookRow(book: store.book(entry.bookID), rating: store.myRating(for: entry.bookID))
                    }
                }
            }
            .pageMargin()
        }
    }

    /// **The honest cold start** (§13.7) — stated once, with something to tap.
    ///
    /// Not an error, not a spinner, and above all not a filler card. A weekly
    /// edition assembled from people you follow *cannot* have anything in it
    /// before you follow anybody, and saying so plainly is more respectful — and
    /// more accurate about how the product works — than manufacturing activity
    /// to cover the gap.
    ///
    /// It said so three times, though. The header subtitle, a display-size
    /// headline here, and the first sentence of the paragraph below all made the
    /// same point, and then the screen offered nothing to act on — on the one
    /// surface whose entire problem is that the reader has not followed anybody.
    /// The headline is gone, and the `.readerSuggestion` cards that used to
    /// *replace* this block now render underneath it: they are Dewey proposing
    /// specific people, which is the only actionable thing a cold start has.
    ///
    /// The paragraph stays whole, because the line about there being no
    /// algorithm is the one thing here a reader could not have guessed and is
    /// the actual argument for the product.
    private var coldStart: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            Text("""
                Dewey does not have an algorithm to fall back on. Everything in an \
                edition comes from a person — something they sent, something they \
                wrote, a list they keep, a book several of them turned out to be \
                reading. Follow someone and this fills up on its own.
                """)
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if !cards.isEmpty {
                Text("Start here").kickerStyle()
                    .padding(.top, Theme.Space.snug)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
    }

    /// A week in which nobody you follow did anything. Distinct from the cold
    /// start: the machinery is working and had nothing to report, which is a
    /// short edition rather than a broken screen.
    private var quietWeek: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("Nothing this week")
                .font(Theme.TypeScale.title())
                .foregroundStyle(Theme.Palette.ink)
            Text("The readers you follow were quiet. A short edition is still an edition.")
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
        .padding(.top, Theme.Space.base)
    }

    private var weekLabel: String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM"
        return f.string(from: Date())
    }
}
