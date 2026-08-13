import SwiftUI

/// The Dewey mark — "3a". A stacked serif wordmark, D / E W / E Y, each letter
/// tipped a few degrees so the block leans the way books lean on a half-empty
/// shelf.
///
/// Ink on paper, consistent with the rest of the design language: flat fields
/// and hairlines, no shadows, no gradients, no page curl.
///
/// Every value is a fraction of the icon side, so `side` is the only input and
/// the mark is resolution-independent — it renders the same at 1024 as at 44
/// for a settings header.
///
/// **This is not what the app icon ships.** `Assets.xcassets` carries a
/// supplied PNG of a bolder, larger-set cut of the same mark — measured at
/// roughly cap 0.307 S against 3a's 0.2444 S, with different row offsets
/// (D −0.264 S, E W +0.082 S, E Y −0.053 S) — chosen because it holds up
/// better at 40 pt. That asset is hand-supplied, not generated from this view,
/// so the two will drift. Retune the metrics below if the in-app mark should
/// match the icon.
///
/// Two deliberate departures from `Theme`:
///
///   1. The colours are literals, not `Theme.Palette`. The palette is adaptive
///      and resolves against the current trait collection; a tile rendered off
///      screen through `ImageRenderer` must come out as the light paper version
///      regardless of the environment it renders in. The literals are the light
///      values of `paper` and `ink`.
///   2. Only SwiftUI is imported. `Theme` pulls in UIKit, and the tool that
///      renders this to PNG builds for macOS.
///
/// The mark is full-bleed and square by design — do not bake a corner radius
/// into the exported asset, iOS applies the squircle. Where it appears inside
/// the app, clip it to `Theme.Radius.card`.
struct DeweyMark: View {

    /// Side of the square tile. All geometry derives from it.
    var side: CGFloat

    /// #1C1A17 — the light value of `Theme.Palette.ink`.
    var ink: Color = Color(red: 0.110, green: 0.102, blue: 0.090)
    /// #FAF7F2 — the light value of `Theme.Palette.paper`.
    var paper: Color = Color(red: 0.980, green: 0.969, blue: 0.949)

    // MARK: - Geometry

    /// Fractions of `side`. These are the mark, not a starting point — see the
    /// note on rotation below.
    private enum Metric {
        static let cap: CGFloat = 0.2444          // font size
        static let lineHeight: CGFloat = 0.92     // × cap, not × side
        static let letterGap: CGFloat = 0.0444    // rows 2–3
        static let rowD: CGFloat = -0.2333        // x, from the tile's centre
        static let rowEW: CGFloat = 0.0333
        static let rowEY: CGFloat = -0.0778
        static let dropE: CGFloat = 0.0111        // extra y on two glyphs
        static let dropY: CGFloat = 0.0167
    }

    private var cap: CGFloat { side * Metric.cap }

    /// A single tipped letter.
    ///
    /// The height clamp is load-bearing. New York's natural line height at this
    /// size is ~1.19 × the point size, so a plain `VStack(spacing: 0)` sets the
    /// rows ~30% looser than the 0.92 line height and pushes the lockup outside
    /// the 0.80 × side safe area. Constraining each glyph's layout box is the
    /// fix; negative stack spacing is not — it would compound with the leading
    /// differently at other sizes.
    ///
    /// Rotation is applied after the clamp so each glyph turns about the centre
    /// of its own box, and `offset` after that so the nudge is vertical in the
    /// tile's space rather than along the letter's tipped axis.
    private func glyph(_ character: String, _ degrees: Double, dy: CGFloat = 0) -> some View {
        Text(character)
            .font(.system(size: cap, weight: .semibold, design: .serif))
            .foregroundStyle(ink)
            .frame(height: cap * Metric.lineHeight)
            .rotationEffect(.degrees(degrees))
            .offset(y: dy)
    }

    var body: some View {
        ZStack {
            paper
            // Fixed angles, asymmetric on purpose — symmetry reads as a tilted
            // logo rather than a leaning stack. Never randomise these.
            VStack(spacing: 0) {
                glyph("D", -7)
                    .offset(x: side * Metric.rowD)

                HStack(spacing: side * Metric.letterGap) {
                    glyph("E", 5, dy: side * Metric.dropE)
                    glyph("W", -4)
                }
                .offset(x: side * Metric.rowEW)

                HStack(spacing: side * Metric.letterGap) {
                    glyph("E", -6)
                    glyph("Y", 8, dy: side * Metric.dropY)
                }
                .offset(x: side * Metric.rowEY)
            }
        }
        .frame(width: side, height: side)
    }
}

#Preview("1024 tile") {
    DeweyMark(side: 320)
}

#Preview("Home Screen sizes") {
    HStack(alignment: .bottom, spacing: 24) {
        DeweyMark(side: 120).clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        DeweyMark(side: 60).clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        DeweyMark(side: 40).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
    .padding()
}
