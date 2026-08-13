import SwiftUI
import UIKit

/// The prototype's design language. Not a brand system — a practical set of
/// decisions consistent enough that new screens inherit the feel rather than
/// re-inventing it.
///
/// Three commitments:
///   1. Editorial, not dashboard. Serif for anything a person wrote or a book
///      is called; sans only for chrome. This is the single strongest signal
///      that Dewey is not a tracker.
///   2. Paper, not surface. Warm off-white in light, warm near-black in dark.
///      Pure #FFF and #000 both read as "web page".
///   3. Hairlines, not shadows. Depth comes from type and space.
enum Theme {

    // MARK: - Colour

    enum Palette {
        /// Page background. Warm — a cool grey reads clinical.
        static let paper = adaptive(light: (0.98, 0.97, 0.95), dark: (0.07, 0.07, 0.075))
        /// Raised surfaces: cards, sheets.
        static let card = adaptive(light: (1.0, 0.996, 0.988), dark: (0.11, 0.11, 0.118))
        /// Primary text.
        static let ink = adaptive(light: (0.11, 0.10, 0.09), dark: (0.95, 0.94, 0.91))
        /// Secondary text. Used heavily — most of Dewey's copy is supporting.
        ///
        /// Darkened from `(0.42, 0.40, 0.38)` — 5.32:1 — as part of the ladder
        /// below. It already passed AA; it moved so that `inkFaint` could reach
        /// AA without the two tiers collapsing into each other.
        static let inkSoft = adaptive(light: (0.34, 0.32, 0.30), dark: (0.63, 0.61, 0.58))

        /// Tertiary: kickers, metadata, dates, counts, every author line in the
        /// Library.
        ///
        /// **It failed WCAG AA in both themes and it carries the most small text
        /// in the app.** Measured against `paper`: 3.02:1 in light and 4.25:1 in
        /// dark, against a 4.5:1 floor for text under 18pt — and `meta()` is
        /// caption, around 12pt, so nothing here qualifies for the large-text
        /// exemption. That is not a marginal miss in light mode; 3:1 is the
        /// floor for *non-text* like icons and borders.
        ///
        /// The whole ladder moved rather than this one value, because darkening
        /// only the faint tier would have parked it at 4.59:1 next to a soft
        /// tier at 5.32:1 — two greys a reader could not tell apart, which
        /// destroys the three-level hierarchy the palette exists to provide.
        ///
        ///     ink       16.3:1    unchanged
        ///     inkSoft    7.3:1    was 5.3:1
        ///     inkFaint   4.6:1    was 3.0:1
        ///
        /// Better separated in ratio terms than what it replaces, and every tier
        /// now passes. Dark mode needed only a nudge — 4.25:1 to 4.56:1 — since
        /// its soft tier was already at 6.8:1.
        static let inkFaint = adaptive(light: (0.46, 0.44, 0.41), dark: (0.50, 0.49, 0.47))
        /// Hairline rules.
        static let rule = adaptive(light: (0.87, 0.85, 0.82), dark: (0.22, 0.22, 0.23))
        /// The one accent. Ink blue — close enough to black to stay quiet,
        /// blue enough to read as deliberate.
        static let accent = adaptive(light: (0.16, 0.30, 0.52), dark: (0.56, 0.70, 0.94))

        /// Declares a light/dark pair inline, so the prototype stays a
        /// pure-code project with no asset catalog to keep in sync.
        private static func adaptive(
            light: (CGFloat, CGFloat, CGFloat),
            dark: (CGFloat, CGFloat, CGFloat)
        ) -> Color {
            Color(UIColor { traits in
                let c = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
            })
        }
    }

    // MARK: - Type

    /// Everything scales with Dynamic Type. `relativeTo` is doing the work —
    /// fixed point sizes would break at accessibility sizes, and the wedge
    /// reader is disproportionately likely to use them.
    enum TypeScale {
        /// Screen titles. Editorial weight.
        static func display() -> Font { .system(.largeTitle, design: .serif, weight: .semibold) }
        /// Book titles in detail views.
        static func title() -> Font { .system(.title, design: .serif, weight: .semibold) }
        /// Book titles on cards.
        static func cardTitle() -> Font { .system(.title3, design: .serif, weight: .semibold) }
        /// Anything a person wrote. Serif, because it is prose.
        static func prose() -> Font { .system(.body, design: .serif) }
        /// Pull-quoted reviews.
        static func proseLarge() -> Font { .system(.title3, design: .serif) }
        /// UI chrome, labels, buttons.
        static func ui() -> Font { .system(.subheadline, weight: .medium) }
        /// Supporting copy.
        static func support() -> Font { .system(.subheadline) }
        /// Kickers and metadata. Small caps via tracking, not a caps lock key.
        static func kicker() -> Font { .system(.caption, weight: .semibold) }
        static func meta() -> Font { .system(.caption) }

        /// A rating figure set inline — the diary row, cover slots, card rows.
        ///
        /// `meta()` at the same size but serif, because since §12.8.2 made the
        /// numeral the whole of the mark at `.tiny` this is the most repeated
        /// rating figure in the app, and it sits beside serif titles and under
        /// serif score circles. Sans there is the one visibly foreign numeral
        /// in a serif app.
        ///
        /// It has to be its own token rather than `.fontDesign(.serif)` on top
        /// of `meta()`: `.system(.caption)` carries an explicit `.default`
        /// design, and an explicit design wins over the environment, so the
        /// modifier silently did nothing. `meta()` itself stays sans — dates,
        /// counts and captions share it and are correctly sans.
        static func metaNumeral() -> Font { .system(.caption, design: .serif) }
    }

    // MARK: - Space

    /// A 4pt-derived scale. Named by intent so screens stay consistent when
    /// someone (me, later) is moving fast.
    enum Space {
        static let hair: CGFloat = 2
        static let tight: CGFloat = 6
        static let snug: CGFloat = 10
        static let base: CGFloat = 16
        static let roomy: CGFloat = 24
        static let loose: CGFloat = 36
        static let vast: CGFloat = 56

        /// Horizontal page margin. Generous — breathing room is the brief.
        static let margin: CGFloat = 20
    }

    enum Radius {
        static let cover: CGFloat = 4     // books have square-ish corners
        static let card: CGFloat = 16
        static let pill: CGFloat = 999
    }

    enum Motion {
        /// One spring, used everywhere. Multiple easing curves in a small app
        /// read as inconsistency rather than craft.
        static let standard: Animation = .spring(response: 0.38, dampingFraction: 0.82)
        static let gentle: Animation = .spring(response: 0.5, dampingFraction: 0.9)
    }
}

// MARK: - Kicker treatment

extension View {
    /// Uppercase tracked kicker. Used above cards and section heads.
    func kickerStyle(_ color: Color = Theme.Palette.inkFaint) -> some View {
        self.font(Theme.TypeScale.kicker())
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(color)
    }

    /// Standard page horizontal inset.
    func pageMargin() -> some View {
        self.padding(.horizontal, Theme.Space.margin)
    }
}
