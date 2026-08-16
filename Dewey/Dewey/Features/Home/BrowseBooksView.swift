import SwiftUI
import UIKit

/// One browser, every discovery configuration.
///
/// **This is the architectural point of the whole slice.** Popular this week,
/// Popular · Fantasy, Popular · Horror · 1980s and Popular · Science Fiction ·
/// 1960s are not four screens and must never become four screens — they are
/// four values of `BrowseFilter` pushed into this one. Every future axis
/// arrives as a field on that struct and a control in the bar below, and every
/// future entry point (a genre chip, a decade, a shelf heading, a link from a
/// book page) arrives as a `NavigationLink` carrying a value rather than a new
/// destination.
///
/// The filter arrives as the pushed value and then becomes editable here, so
/// the reader who came in through "Horror" can add the 1980s without going
/// back — which is the difference between a browser and a category page.
struct BrowseBooksView: View {
    @Environment(DeweyStore.self) private var store

    @State var filter: BrowseFilter
    @State private var answer: BrowseAnswer?

    private var phase: BrowseAnswer.Phase {
        BrowseAnswer.phase(of: answer, for: filter.catalogQuery)
    }

    /// Covers wide enough to be covers. `.adaptive` rather than a fixed count
    /// so the grid is three across on a phone, more on a wider screen, without
    /// this file knowing which is which.
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 104), spacing: Theme.Space.base, alignment: .topLeading)]
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Rule()
            results
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
        .deweyNavigationTitle(filter.shortHeadline)
        .task(id: filter.catalogQuery) { await load() }
    }

    private func load() async {
        let asked = filter.catalogQuery
        do {
            let books = try await store.browseCatalog(asked)
            // Cancellation is cooperative and nothing checks it once the bytes
            // have landed: a task superseded while its response was in flight
            // still resumes here. The newer task owns this state.
            guard !Task.isCancelled else { return }
            answer = BrowseAnswer(query: asked, books: books)
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            answer = BrowseAnswer(query: asked, books: nil)
        }
    }

    // MARK: - The controls

    /// Three menus on one line, and a sentence under them.
    ///
    /// **Menus rather than four rows of chips.** Chips are right when the whole
    /// set is small enough to state at once — five reading statuses, eleven
    /// genres on a page built to show them. Here there are three independent
    /// axes with twenty-seven options between them, and laying them all out
    /// would be a settings screen with a shelf attached. A menu states the
    /// *current* answer, which is what a reader mid-browse needs on screen, and
    /// hides the alternatives until they are wanted. It is also the native
    /// control for exactly this, so it inherits the platform's presentation,
    /// its keyboard handling and its VoiceOver behaviour for free.
    ///
    /// They scroll horizontally rather than wrapping, because at an
    /// accessibility text size three of these are wider than any phone and a
    /// wrapped control bar starts eating the shelf it is supposed to be
    /// filtering.
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.snug) {
                    periodMenu
                    genreMenu
                    decadeMenu
                }
                .pageMargin()
                .padding(.vertical, Theme.Space.hair)
            }

            Text(filter.sourceLine)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
                .pageMargin()
        }
        .padding(.top, Theme.Space.snug)
        .padding(.bottom, Theme.Space.base)
    }

    /// The windowed options are **disabled rather than hidden** while a genre
    /// or a decade is in play, and the note says why.
    ///
    /// The catalog cannot count a subject over a rolling week — see
    /// `OpenLibraryClient.browse` — so the choice is between fabricating one,
    /// silently ignoring the reader's selection, and saying so. A greyed row
    /// with a reason above it is the version a reader can act on: clear the
    /// genre and the windows come back.
    private var periodMenu: some View {
        Menu {
            if filter.isNarrowed {
                Section(BrowseFilter.narrowedPeriodNote) { periodOptions }
            } else {
                periodOptions
            }
        } label: {
            control(label: "Popular", value: filter.period.title)
        }
    }

    private var periodOptions: some View {
        ForEach(BrowseFilter.Period.allCases) { option in
            Button {
                select { filter.period = option }
            } label: {
                Label(option.title, systemImage: filter.period == option ? "checkmark" : "")
            }
            .disabled(filter.isNarrowed && !option.survivesNarrowing)
        }
    }

    private var genreMenu: some View {
        Menu {
            Button { select { filter.apply(genre: nil) } } label: {
                Label("Every genre", systemImage: filter.genre == nil ? "checkmark" : "")
            }
            Divider()
            ForEach(BrowseFilter.Genre.all) { genre in
                Button { select { filter.apply(genre: genre) } } label: {
                    Label(genre.name, systemImage: filter.genre == genre ? "checkmark" : "")
                }
            }
        } label: {
            control(label: "Genre", value: filter.genre?.name ?? "Every genre")
        }
    }

    private var decadeMenu: some View {
        Menu {
            Button { select { filter.apply(decade: nil) } } label: {
                Label("Any decade", systemImage: filter.decade == nil ? "checkmark" : "")
            }
            Divider()
            ForEach(BrowseFilter.Decade.all) { decade in
                Button { select { filter.apply(decade: decade) } } label: {
                    Label(decade.label, systemImage: filter.decade == decade ? "checkmark" : "")
                }
            }
        } label: {
            control(label: "Decade", value: filter.decade?.label ?? "Any decade")
        }
    }

    /// One place where a filter change happens, so the haptic and the
    /// animation cannot end up on two of the three menus.
    private func select(_ change: () -> Void) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(Theme.Motion.standard) { change() }
    }

    /// A menu's face: what it filters in small caps, what it is set to in the
    /// reading face. Both on the button, because a capsule reading only
    /// "1980s" tells you the answer and not the question — and with three of
    /// these in a row, the questions are what make the row legible.
    private func control(label: String, value: String) -> some View {
        HStack(spacing: Theme.Space.tight) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).kickerStyle()
                Text(value)
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Palette.inkFaint)
        }
        .padding(.horizontal, Theme.Space.base)
        .padding(.vertical, Theme.Space.tight + 1)
        .frame(minHeight: 44)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Palette.rule, lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - The shelf

    @ViewBuilder
    private var results: some View {
        switch phase {
        case .loading:
            state("Reading the shelves…", detail: nil)
        case .failed:
            state(
                "Couldn't reach \(Vocabulary.widerCatalogue.lowercased())",
                detail: "Dewey quotes an outside catalogue for everything on this screen, and it didn't answer. Nothing here is stored on your device."
            )
        case .empty:
            state(
                "Nothing under \(filter.headline)",
                detail: "The catalogue has no books it can place in both of these at once. Widening the decade usually finds them."
            )
        case .loaded(let books):
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Space.roomy) {
                    ForEach(books) { book in
                        BrowseCover(book: book, width: 104)
                    }
                }
                .pageMargin()
                .padding(.top, Theme.Space.roomy)
                .padding(.bottom, Theme.Space.vast)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// Loading, failure and emptiness in one treatment. Prose, left-aligned,
    /// at the top of the page — not a centred spinner and not an illustration.
    /// Each says something a reader can act on, and none of them fills the
    /// space with books to hide the fact that there are none.
    private func state(_ headline: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text(headline)
                .font(Theme.TypeScale.title())
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .pageMargin()
        .padding(.top, Theme.Space.loose)
    }
}
