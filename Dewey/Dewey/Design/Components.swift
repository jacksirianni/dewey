import SwiftUI

// MARK: - Book cover

/// A typeset cover.
///
/// Real jacket art needs a network, a cache, and a licence, and a prototype
/// with three of those and none of the others looks worse than one with a
/// consistent house style. Typesetting each cover also makes the library read
/// as *Dewey's* shelf rather than a scrape of someone else's.
struct BookCoverView: View {
    /// Height as a multiple of width. Exposed so callers that have to reserve
    /// space for a cover — a clipped band, a placeholder slot — can compute it
    /// from the same constant the cover draws with, rather than hardcoding 1.5
    /// in a second place and drifting.
    static let aspectRatio: CGFloat = 1.5

    let book: Book
    var width: CGFloat = 92

    /// Whether this cover grows with the reader's text size.
    ///
    /// **Off by default, and on wherever a cover sits beside prose.** A cover is
    /// fixed geometry — its title and author are sized off its own width, which
    /// is the trade this type makes so a typeset jacket reads as a jacket rather
    /// than as a text box. That trade is right in a rail or a grid, where the
    /// covers are the content and scaling them would break the column count and
    /// leave one and a half books on a line.
    ///
    /// It is wrong in a *row*. At an accessibility text size a library row put a
    /// 58pt cover next to two-inch letters, an edition card put a 76pt one next
    /// to a title hyphenating across three lines, and the cover — the row's one
    /// visual anchor — was the only element on screen that had not answered the
    /// reader's setting.
    ///
    /// Capped at 1.6, for the same reason `ScoreCircle` is: unbounded, a 76pt
    /// cover reaches ~270pt at AX5 and takes the entire measure, leaving the
    /// title it is supposed to be introducing a column two words wide.
    var scalesWithType: Bool = false

    @ScaledMetric(relativeTo: .title3) private var typeScale: CGFloat = 1

    private static let maximumGrowth: CGFloat = 1.6

    private var drawnWidth: CGFloat {
        scalesWithType ? width * min(max(typeScale, 1), Self.maximumGrowth) : width
    }

    private var height: CGFloat { drawnWidth * Self.aspectRatio }

    var body: some View {
        ZStack(alignment: .topLeading) {
            book.coverPalette.base.color

            // A single hairline inset frame. Enough to read as a designed
            // object, quiet enough not to compete with the title.
            Rectangle()
                .stroke(book.coverPalette.ink.color.opacity(0.28), lineWidth: 0.5)
                .padding(drawnWidth * 0.06)

            VStack(alignment: .leading, spacing: drawnWidth * 0.06) {
                Text(book.title)
                    .font(.system(size: drawnWidth * 0.135, weight: .semibold, design: .serif))
                    .foregroundStyle(book.coverPalette.ink.color)
                    .lineSpacing(-drawnWidth * 0.01)
                    .minimumScaleFactor(0.7)
                    .lineLimit(5)

                Text(book.author)
                    .font(.system(size: drawnWidth * 0.075, weight: .regular, design: .serif))
                    .foregroundStyle(book.coverPalette.ink.color.opacity(0.75))
                    .lineLimit(2)
            }
            .multilineTextAlignment(.leading)
            .padding(drawnWidth * 0.13)

            // The catalog's jacket, when there is one (§16). Layered over the
            // typeset cover rather than replacing it: the palette is the
            // loading state, and it stays the cover outright for imported
            // books the catalog has no image for. Seed books never carry a
            // cover reference, so this branch costs them nothing.
            if let url = book.remoteCoverURL(width: drawnWidth) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: drawnWidth, height: height)
                        .clipped()
                } placeholder: {
                    // The typeset cover underneath *is* the placeholder.
                    Color.clear
                }
            }
        }
        .frame(width: drawnWidth, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cover, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.cover, style: .continuous)
                .stroke(Theme.Palette.ink.opacity(0.10), lineWidth: 0.5)
        )
        // The cover carries the book's identity, so VoiceOver reads it as one
        // object rather than two stray text nodes.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.title), by \(book.author)")
    }
}

// MARK: - Reader avatar

/// Initials on the reader's accent. No photographs: the readers are seeded, and
/// a stock headshot would make them read as personas rather than people.
///
/// **The initials are ink, not the accent**, and that is a legibility fix rather
/// than a taste one. Drawing the letters in the same colour as the 16%-opacity
/// fill beneath them meant the contrast depended entirely on which token a
/// reader happened to be seeded with, and most of them failed badly. Measured
/// against the composited fill:
///
///     bone   1.29:1 in light      ink    1.37:1 in dark
///     ochre  2.02:1 in light      plum   2.32:1 in dark
///
/// At those ratios the letters are not "low contrast", they are gone — a reader
/// with the `ink` accent showed an empty circle in dark mode, and `bone` showed
/// one in light. Seven of the ten tokens sat under the 4.5:1 floor in at least
/// one theme, so this was not an edge case; it was most of the cast.
///
/// The cause is that `CoverPalette.ColorToken` is a set of **cover** colours,
/// chosen to sit under jacket type at full saturation. Nothing about them was
/// ever chosen to work as text on a wash of themselves.
///
/// Ink on the tint clears 11:1 on every token in both themes, and identity is
/// unaffected: the wash and the ring still carry the reader's colour, which is
/// where colour was answering "who" all along. The letters just have to be
/// readable.
struct ReaderAvatarView: View {
    let reader: ReaderProfile
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(reader.accent.color.opacity(0.16))
            .overlay(
                Text(reader.initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.Palette.ink)
            )
            .overlay(Circle().stroke(reader.accent.color.opacity(0.35), lineWidth: 0.5))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Structure

/// Hairline rule. Depth in Dewey comes from type and space, so separators are
/// as light as the display can render.
struct Rule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Palette.rule)
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}

/// The card container used throughout the edition.
///
/// **The kicker is optional**, because a card is not always under a heading that
/// needs restating. The Lists index proved it: its "Yours" section drew a stack
/// of cards each kickered "Yours", so the word appeared once as the section head
/// and again on every card beneath it. A kicker earns its line when it says
/// something the surrounding page does not — who kept this list, what kind of
/// edition card this is — and is noise when it repeats the heading directly
/// above.
struct CardShell<Content: View>: View {
    let kicker: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            if let kicker {
                Text(kicker).kickerStyle()
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.base)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Palette.rule, lineWidth: 0.5)
        )
    }
}

// MARK: - Provenance

/// The line that answers "how did this reach me?".
///
/// This is the sentence the whole product is built around, so it gets a
/// consistent treatment everywhere it appears and is never abbreviated to an
/// icon — an avatar alone tells you *who* but not *why*, and the why is the part
/// that survives six months in a want-to-read list.
struct ProvenanceLine: View {
    let text: String
    var reader: ReaderProfile?
    var emphasis: Bool = false

    /// Top-aligned, not centred.
    ///
    /// Centring is invisible while the line fits on one row and wrong the moment
    /// it does not: at an accessibility text size "From Marcus Lindqvist's
    /// review" wraps to four lines and the avatar floated halfway down the
    /// paragraph, beside the third word, reading as a stray mark rather than as
    /// the person the sentence is about. Aligned to the top it sits against the
    /// first line, where a byline belongs, at every width.
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.tight) {
            Group {
                if let reader {
                    ReaderAvatarView(reader: reader, size: 22)
                } else {
                    Image(systemName: "bookmark")
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .accessibilityHidden(true)
                }
            }
            // Nudged down so a 22pt circle reads as sitting *on* the first line
            // rather than above it — the optical centre of a cap-height line.
            .padding(.top, 1)

            Text(text)
                .font(Theme.TypeScale.support())
                .foregroundStyle(emphasis ? Theme.Palette.ink : Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Flow layout

/// Lays children left to right, wrapping to a new line when the current one runs
/// out of room. Every chip row in Dewey uses it.
///
/// **There were two of these, and the one with more callers was the broken
/// one.** `FlowLayout` measured each child with `sizeThatFits(.unspecified)`,
/// which asks "how wide would you like to be" — so a `Text` answered with its
/// full single-line width, was placed at that width, and ran past the page
/// margin to be clipped by the enclosing scroll view. Because the layout also
/// *reported* a size that fit, nothing upstream could tell. At accessibility
/// text sizes that cut "Literary Fiction" on the book page hero, "Did Not
/// Finish" in the log sheet's status row — the one control in that sheet a
/// reader cannot skip — and every reason chip in the Recommend sheet, mid-word,
/// at the screen edge.
///
/// `ChipFlowLayout` was written to fix exactly that, correctly, and was wired to
/// two rows out of eight. Its own documentation said "Unifying the two is a call
/// for whoever owns `FlowLayout`". This is that unification: one layout, the
/// correct algorithm, all eight callers.
///
/// **The fix is the proposal.** Each child is offered the container's width, so
/// a label too long for a line wraps *inside its own capsule* rather than
/// overflowing it. A chip can therefore never be wider than the space it was
/// given, at any device width and any Dynamic Type size — which is the property
/// the old version could not provide at any spacing.
///
/// Measuring and placing share one `solve`, so the two can never disagree about
/// where a line broke.
struct FlowLayout: Layout {
    /// Between items on a line.
    var spacing: CGFloat = 8

    /// Between lines. Defaults to `spacing`; chip rows pass something tighter so
    /// a wrapped set still reads as one row of controls rather than two rows.
    var lineSpacing: CGFloat?

    private var betweenLines: CGFloat { lineSpacing ?? spacing }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // An unspecified width means "how wide would you like to be" — answer
        // with the single-line width and let the parent decide.
        solve(subviews, maxWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placements = solve(subviews, maxWidth: bounds.width).placements
        for (view, placement) in zip(subviews, placements) {
            view.place(
                at: CGPoint(x: bounds.minX + placement.origin.x, y: bounds.minY + placement.origin.y),
                proposal: ProposedViewSize(placement.size)
            )
        }
    }

    private func solve(_ subviews: Subviews, maxWidth: CGFloat) -> (size: CGSize, placements: [CGRect]) {
        var placements: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0

        for view in subviews {
            // The clamp that makes the guarantee: proposing `maxWidth` means a
            // child reports the size it will actually draw at, wrapping its
            // label if it must, instead of the size it would prefer.
            let size = view.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            // `x > 0` keeps the first item on the line it starts — one that
            // fills the whole width still gets a line to itself rather than an
            // empty one above it.
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + betweenLines
                lineHeight = 0
            }
            placements.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            widest = max(widest, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }

        return (CGSize(width: widest, height: y + lineHeight), placements)
    }
}

// MARK: - Fact tables

/// A label and its value, as every table in Dewey draws one.
///
/// **Three private copies of this collapsed into it.** The book page had
/// `factRow` on a 92pt label column, `detailRow` on a 108pt one, and `personRow`
/// on another 92pt one — three tables on a single screen, three hand-written
/// implementations, three chances to disagree about baseline alignment, value
/// font and label colour. They already did: two of them combined their children
/// for VoiceOver and one did not.
///
/// **All three broke at accessibility text sizes, in the same way.** A label
/// column stated in points does not grow with the type, so at AX3 and up
/// "First published" and "Dewey Decimal" wrapped inside 108pt — and a table
/// whose labels wrap has stopped being a table — while the value beside them was
/// squeezed into whatever was left of a 390pt phone. Two fixes, and it needs
/// both: the column *scales* with the type until the type gets large enough that
/// no side-by-side arrangement works, and past that point the row **stacks**,
/// label above value, full measure for each. `isAccessibilitySize` is the
/// platform's own line for "this reader has asked for a layout, not just a font
/// size", which is precisely the question being asked here.
///
/// Generic over the value so the Favorite row can hand it a mark instead of a
/// string; `FactRow(_:_:)` is the string case, which is all but one call site.
struct FactRow<Value: View>: View {
    let label: String
    let value: Value

    /// Unlabelled first argument, so a row reads as the thing it draws:
    /// `FactRow("Rating") { RatingMark(...) }`. The synthesised memberwise
    /// initialiser would demand `label:`, which is noise on a type whose whole
    /// job is two fields.
    init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    /// The label column at default type. Both of the widths this replaced —
    /// 92 and 108 — are now this one number, because two tables a screen apart
    /// aligning to different gutters is the sort of thing that reads as
    /// carelessness without ever being noticed as a decision.
    private static var baseColumn: CGFloat { 104 }

    /// 1 at default type and proportional above it, so the column tracks the
    /// text rather than a guess about it. Multiplying a stored base is the only
    /// way to scale a width that varies per instance — `@ScaledMetric` on the
    /// width itself would fix it at construction.
    @ScaledMetric(relativeTo: .caption) private var typeScale: CGFloat = 1

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Space.hair) {
                    labelText
                    wrappingValue
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
                    labelText
                        .frame(width: Self.baseColumn * typeScale, alignment: .leading)
                    wrappingValue
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, Theme.Space.snug)
        .accessibilityElement(children: .combine)
    }

    private var labelText: some View {
        Text(label)
            .font(Theme.TypeScale.meta())
            .foregroundStyle(Theme.Palette.inkFaint)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Applied here rather than by each caller. Without it a long value —
    /// a cast list, a run of themes, a Setting line — is truncated to one line
    /// inside an `HStack` that has room to wrap it, which is how a table row
    /// silently loses the half of its content that was worth reading.
    private var wrappingValue: some View {
        value.fixedSize(horizontal: false, vertical: true)
    }
}

extension FactRow where Value == Text {
    /// The ordinary case: a label and a string. Serif, because a value in a
    /// catalogue record is a thing's name rather than chrome.
    init(_ label: String, _ value: String) {
        self.label = label
        self.value = Text(value)
            .font(.system(.subheadline, design: .serif))
            .foregroundStyle(Theme.Palette.ink)
    }
}

// MARK: - Navigation title

extension View {
    /// The one navigation-bar title treatment, so the four tabs cannot drift.
    ///
    /// They had. The Edition carried a serif principal reading "Dewey" and the
    /// Library one reading "Your library" — a name the tab underneath it called
    /// "Library" — while Search and Profile carried **no title at all** and
    /// pushed their own display-size heading into the content instead. So two
    /// tabs had a bar with something in it, two had an empty strip, one screen
    /// disagreed with its own tab about its name, and Search called itself
    /// "Find" in the only place it named itself.
    ///
    /// A title in every bar is also what makes the bar's material legible. See
    /// `RootView.tabs`: a translucent bar over a scrolling page needs something
    /// *in* it, or a reader reads it as a grey band that failed to load.
    ///
    /// Serif and semibold, matching the app's rule that anything a person wrote
    /// or a thing is called is serif and only chrome is sans. A navigation title
    /// is the name of a place, which puts it on the serif side.
    func deweyNavigationTitle(_ text: String) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(text)
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}

// MARK: - Buttons

/// The one filled button. Used for the single most important action on a
/// screen, and never twice on the same screen.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.TypeScale.ui())
            .foregroundStyle(Theme.Palette.paper)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(Theme.Palette.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(Theme.Motion.standard, value: configuration.isPressed)
    }
}

/// Everything else. Outlined, quiet, equal weight to its siblings — used for
/// "Not for me", which must never feel like the discouraged choice.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.TypeScale.ui())
            .foregroundStyle(Theme.Palette.ink)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.Palette.rule, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(Theme.Motion.standard, value: configuration.isPressed)
    }
}

/// Small selectable chip. Used for recommendation reasons and reactions.
struct ChipStyle: ButtonStyle {
    var selected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.TypeScale.support())
            .foregroundStyle(selected ? Theme.Palette.paper : Theme.Palette.ink)
            .padding(.horizontal, Theme.Space.base)
            .padding(.vertical, Theme.Space.snug)
            .background {
                if selected {
                    Capsule().fill(Theme.Palette.ink)
                } else {
                    Capsule().stroke(Theme.Palette.rule, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(Theme.Motion.standard, value: selected)
    }
}

// MARK: - End of edition

/// Reaching the end is a designed moment, not an empty state. The edition is
/// finite on purpose; if the bottom of it felt like running out, the constraint
/// would read as a limitation rather than a promise kept.
///
/// **The second line was doing the opposite of that** (§13.8). It read: "A new
/// edition arrives Sunday. Until then, your library is where the interesting
/// things are." Every clause of it is true and the sentence as a whole is an
/// advertisement for six days of nothing — it names the wait, then offers the
/// reader somewhere else to go. An ending should close, not apologise.
///
/// Candidates written for this, and why each was or was not taken:
///
/// - *"That's the week. The books are yours now."* — **taken.** It closes on
///   the reader's ownership rather than on the calendar, and "yours now" is a
///   handover, which is what the edition has actually just done.
/// - *"That's the week. Nothing more until Sunday."* — states the gap outright.
///   Honest, and still an announcement about absence.
/// - *"That's the week. Five things, and no more scrolling."* — makes the
///   restraint the boast. Too pleased with itself; the reader did not ask to be
///   congratulated on the product's discipline.
/// - *"That's the week. Go and read something."* — the right sentiment, wrong
///   register: it instructs, and Dewey does not tell people what to do with
///   their evening.
/// - *"That's the week. The rest is up to you."* — close, but it puts the
///   burden on the reader rather than handing them something.
///
/// No date, deliberately. The old line's "Sunday" invited the reader to compute
/// how long they were being asked to wait.
struct EditionEndView: View {
    let readerCount: Int

    var body: some View {
        VStack(spacing: Theme.Space.snug) {
            Rule().frame(width: 40)
            Text("That's the week")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.ink)
            Text("The books are yours now.")
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.loose)
        .pageMargin()
    }
}
