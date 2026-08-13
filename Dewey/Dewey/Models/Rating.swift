import SwiftUI
import UIKit

/// A rating on Dewey's 0.1–10.0 scale.
///
/// This is Dewey's most repeated visual motif and the thing that makes a shelf,
/// a diary, a profile and a list scannable at speed. It appears everywhere and
/// it always looks the same.
///
/// **Rating is not the same as "Favorite."** That separation is lifted
/// wholesale from Letterboxd's rating-vs-like split, which is the smartest
/// mechanic they have: a book you rate 10 is one you judge excellent; a book you
/// love may be a 6 you'd defend to the death. Collapsing them loses the more
/// interesting of the two.
///
/// **The scale moved from half-to-5 on 2026-08-04** (§12.2). One decimal is
/// finer than a reader can reproduce week to week and it adds a decision to
/// every log; that objection was raised and overruled deliberately, because the
/// expressiveness is worth the friction and a continuous slider makes the cost
/// small. Recorded here so nobody re-derives it as though it were new.
struct Rating: Hashable, Codable, Comparable {
    /// The valid range. Zero is deliberately not a rating: an unrated book is
    /// `nil`, and a scale whose floor means "I hated it" needs a floor a reader
    /// can actually land on.
    static let range: ClosedRange<Double> = 0.1...10.0

    /// One decimal, everywhere. The slider, the VoiceOver adjustable action and
    /// the haptic tick all step by this.
    static let step: Double = 0.1

    /// 0.1…10.0, always a whole tenth.
    let value: Double

    /// Fails outside the range. Anything inside it is snapped to a tenth, so a
    /// value arrived at by arithmetic — a drag fraction, an accessibility step —
    /// cannot smuggle in a third decimal.
    ///
    /// The guard runs *after* the snap on purpose: floating-point drift puts
    /// `10.000000000000002` well inside a reader's intent and well outside a
    /// literal comparison, and returning `nil` at the top of the track would be
    /// a silent failure at exactly the value people most want to give.
    init?(_ value: Double) {
        guard value.isFinite else { return nil }
        let snapped = (value * 10).rounded() / 10
        guard Rating.range.contains(snapped) else { return nil }
        self.value = snapped
    }

    /// Skips the range check for values the caller has already constrained.
    private init(unchecked value: Double) {
        self.value = value
    }

    /// The nearest valid rating to `value`. Never fails, so slider and stepper
    /// maths don't have to carry an optional through arithmetic that cannot
    /// meaningfully produce "no rating".
    static func clamping(_ value: Double) -> Rating {
        guard value.isFinite else { return Rating(unchecked: range.lowerBound) }
        let snapped = (value * 10).rounded() / 10
        return Rating(unchecked: Swift.min(Swift.max(snapped, range.lowerBound), range.upperBound))
    }

    static func < (a: Rating, b: Rating) -> Bool { a.value < b.value }

    var isWhole: Bool { value.truncatingRemainder(dividingBy: 1) == 0 }

    /// Plain text, for VoiceOver and anywhere marks won't fit.
    var spoken: String { "\(compact) out of 10" }

    /// The numeral. Whole ratings drop the decimal — "8", not "8.0" — because a
    /// trailing zero on every second rating reads as instrument output.
    var compact: String {
        isWhole ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    // MARK: Codable

    /// Decoding goes through the same snap-and-clamp as construction.
    ///
    /// Synthesised decoding writes straight to the stored property, which makes
    /// it the one door into this type that bypasses `init?(_:)`: a file carrying
    /// `8.25`, `0`, `11.0`, or a value that drifted a decimal through some
    /// earlier arithmetic, would produce a `Rating` the rest of the app believes
    /// is a whole tenth inside `range`. The mark's fill maths, the slider's
    /// fraction and `compact` all assume exactly that.
    ///
    /// Lenient rather than strict on purpose. Throwing would fail the whole
    /// enclosing container, and losing a reader's library because one rating
    /// drifted is a worse answer than reading it as the nearest rating they
    /// could have given.
    ///
    /// The encoded shape is unchanged — `encode(to:)` is still synthesised and
    /// still writes `{"value": <Double>}` — so every file already on disk loads
    /// as before. Only the reading changed.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = Rating.clamping(try container.decode(Double.self, forKey: .value))
    }

    /// Stated rather than inferred, so the on-disk shape is legible from the
    /// type. Synthesis still uses it for `encode(to:)`.
    private enum CodingKeys: String, CodingKey { case value }
}

// MARK: - The mark

/// Dewey's rating figure: **a serif numeral, one size, everywhere a person's
/// rating appears in a row.**
///
/// It used to be a row of ten filled rules, and about two hundred lines of this
/// file argued for them: they read as typesetting rather than arcade scoring,
/// they sat naturally beside serif type, and they were unmistakably not
/// Letterboxd's green stars. The argument was good and the shape lost anyway,
/// one call site at a time, for a reason §12.8.2 measured on device — ten rules
/// in the ~44pt an inline row can spare leaves each rule barely longer than it
/// is thick, so the mark renders as ten identical dots and 6.0 is
/// indistinguishable from 10.0 at a glance. A mark that cannot carry its value
/// is decoration.
///
/// By this pass **all thirteen call sites passed `.tiny`** — the numeral — so
/// the rules were drawn nowhere in the app while this file went on calling them
/// "Dewey's most repeated visual motif". The metrics, the proportional fill, the
/// partial-rule floor and ceiling and the two larger sizes are deleted rather
/// than kept warm: they were unreachable code under a comment that described a
/// product that did not exist.
///
/// **The size parameter went with them**, so no surface can ask for a rendering
/// there isn't one of. Every personal rating in the app is now the same figure
/// at the same size, which is the property §12.5.6 wanted a fixed column for in
/// the first place.
///
/// Serif, via its own token. `meta()` carries an explicit `.default` design and
/// an explicit design beats `.fontDesign(.serif)` on the environment, so the
/// modifier silently did nothing — hence `metaNumeral()`, the same size with the
/// design baked in. Do not add `.monospacedDigit()`: on a *text-style* serif
/// system font it drops back to the default design, verified on device, and this
/// numeral is always inline in a row rather than in a column, so there is
/// nothing for fixed-width digits to align to.
///
/// **No tint, and it cannot be given one** (§13.5). It used to take one, and the
/// Edition passed each reader's accent colour in, so Priya's 9.2 drew in clay
/// and Ana's 10 in plum. On a card printing two ratings side by side that reads
/// as a *quality* signal — one score warm, one cool, as though the colour said
/// something about the books — and it takes a moment to work out that it is only
/// saying who is speaking. Reader identity still colours the avatar, the
/// provenance accent and the name; those are the places colour answers "who",
/// which it can do without being mistaken for "how good".
///
/// **Its counterpart is `ScoreCircle`, and the split between them is the rule
/// this app had been breaking: a circled numeral is the crowd's verdict, a bare
/// numeral is a person's.** Nothing else tells them apart, so nothing else may.
/// A library row drawing its own owner's rating in a circle — which is what
/// shipped — put the reader's opinion in the component that means "four thousand
/// strangers".
struct RatingMark: View {
    let rating: Rating?

    /// What an unrated book looks like here. Defaults to the historic
    /// behaviour — nothing at all — so no existing row changes shape.
    var unrated: Unrated = .blank

    /// How much room the figure is asking for. **Two roles, not a size scale.**
    ///
    /// The `size` parameter was removed from this type because it offered
    /// renderings that did not exist. This is not that parameter coming back:
    /// there are exactly two jobs a personal score does in Dewey, and they are
    /// jobs rather than dimensions.
    ///
    /// `.inline` is a figure sitting in a sentence or beside a title — a diary
    /// row, a card byline, a cover slot, a search result. `.column` is the
    /// Library's trailing gutter, the one surface built for *scanning your own
    /// verdicts down a page*, where the figure is the thing the eye travels on
    /// and every row's numeral lands at the same x.
    ///
    /// The Library used to hand-set that gutter — `.title3`, serif, semibold,
    /// written into `LibraryRow` — which meant the one value the app promises
    /// means the same thing everywhere was specified in two places and drawn in
    /// two typographic treatments. Same component now; only the role differs.
    var prominence: Prominence = .inline

    enum Prominence {
        /// Beside prose. Caption-sized, matching the metadata it sits among.
        case inline
        /// A gutter of its own, scanned down a page. The Library only.
        case column

        var font: Font {
            switch self {
            case .inline: Theme.TypeScale.metaNumeral()
            case .column: .system(.title3, design: .serif, weight: .semibold)
            }
        }
    }

    /// How a missing rating presents itself.
    ///
    /// Drawing nothing is right exactly where the surrounding row already
    /// accounts for the absence — a Want to Read rail, a browse grid, a search
    /// result for a book you have never opened — and wrong wherever the mark
    /// sits in a column beside rated siblings. There the row says nothing at
    /// all, and VoiceOver steps straight over it: "Piranesi, Susanna Clarke"
    /// reads identically whether the reader gave it a 9 or has never rated it.
    ///
    /// `.stated` is one faint dash. It is the typographic convention for "no
    /// entry in this column", it sits where the numeral it stands in for would
    /// sit, and it holds the column width so a pair of stacked ratings stays
    /// aligned when only one of them exists.
    enum Unrated {
        /// Draws nothing and speaks nothing.
        case blank
        /// Draws a faint dash, and speaks "Not rated".
        case stated
    }

    var body: some View {
        if let rating {
            Text(rating.compact)
                .font(prominence.font)
                .foregroundStyle(Theme.Palette.ink)
                .accessibilityLabel(rating.spoken)
        } else {
            switch unrated {
            case .blank:
                EmptyView()
            case .stated:
                Text(verbatim: "\u{2014}")
                    .font(prominence.font)
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .accessibilityLabel("Not scored")
            }
        }
    }
}

// MARK: - Input

/// The app's feedback generators.
///
/// SwiftUI re-initialises a `View` struct on every state change, so a stored
/// `let` generator on `RatingSlider` would allocate a fresh one at each of the
/// ninety-nine steps in a full-length drag — and a generator that has just been
/// created has not been prepared, which is exactly when the Taptic Engine is
/// slowest to answer. Process-wide instances are correct here because only one
/// rating slider is ever on screen.
///
/// **Three of them, because a style is fixed at construction.** `HapticPreset`
/// can ask for one `FeedbackStyle` at the tenths and a different one at the
/// wholes — `.mechanical` is rigid then medium — so a single generator cannot
/// serve a drag. Three objects that live for the process is still the answer
/// over allocating one per tick; only the styles the presets actually name are
/// held.
private enum RatingHaptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)

    private static func generator(
        for style: UIImpactFeedbackGenerator.FeedbackStyle
    ) -> UIImpactFeedbackGenerator {
        switch style {
        case .medium: return medium
        case .rigid: return rigid
        // `.light` plus anything a later preset names. Falling back to the
        // lightest tap is the safe direction to be wrong in on a control that
        // can fire ninety-nine times in a second and a half.
        default: return light
        }
    }

    /// Called on drag start. Preparing warms the engine for a few seconds, which
    /// covers a rating gesture with room to spare.
    ///
    /// Both of the active preset's generators are warmed, because one drag can
    /// use either and the first whole number is usually reached within a few
    /// tenths of the first touch — far too soon to warm one lazily.
    static func prepare() {
        let preset = DebugSettings.shared.haptics
        generator(for: preset.tenthStyle).prepare()
        generator(for: preset.wholeStyle).prepare()
    }

    /// A tenth is a whisper; a whole number is a landmark you can feel without
    /// looking. `UISelectionFeedbackGenerator` was the obvious first choice and
    /// is far too heavy to fire ninety-nine times across one drag — it turns a
    /// considered rating into a ratchet.
    ///
    /// **Which of the two applies stays this file's decision.** The preset
    /// supplies a pair of weights and a pair of styles; `crossesWhole` owns the
    /// question "is this a landmark", exactly as it did before presets existed.
    /// Under `.minimal`, which ticks only at x.0 and x.5, that means the halves
    /// speak in the tenth voice and the wholes in the whole voice — which is the
    /// contrast the preset exists to test.
    static func emit(from old: Rating?, to new: Rating) {
        let preset = DebugSettings.shared.haptics
        // Not every landed value ticks: a preset may tick on a coarser grid than
        // the slider moves on, and silence is the setting.
        guard preset.fires(at: new.value) else { return }
        let landmark = crossesWhole(from: old, to: new)
        generator(for: landmark ? preset.wholeStyle : preset.tenthStyle)
            .impactOccurred(intensity: landmark ? preset.wholeIntensity : preset.tenthIntensity)
    }

    /// Clearing gets its own weight: heavier than a tenth so it registers as an
    /// event, lighter than a whole number so it doesn't read as a value. Stated
    /// as the midpoint of the active preset's two intensities so that rule holds
    /// under every preset instead of only under the one it was tuned against —
    /// under `.balanced` the midpoint is 0.525, which is the 0.5 this used to
    /// hardcode.
    ///
    /// Deliberately *not* gated on `fires(at:)`. Clearing is not a value on the
    /// scale, so a preset that ticks only at the halves still owes the reader an
    /// answer when their rating disappears.
    static func clearTick() {
        let preset = DebugSettings.shared.haptics
        generator(for: preset.wholeStyle)
            .impactOccurred(intensity: (preset.tenthIntensity + preset.wholeIntensity) / 2)
    }

    private static func crossesWhole(from old: Rating?, to new: Rating) -> Bool {
        if new.isWhole { return true }
        // Leaving a whole number is not a second crossing — descending 8.1 → 8.0
        // → 7.9 should be one landmark, not two.
        guard let old, !old.isWhole else { return false }
        // A fast drag can skip straight past a whole number without landing on
        // it. The landmark should still register.
        return Int(old.value) != Int(new.value)
    }
}

/// Drag anywhere on the track to rate, in tenths (§12.2.2).
///
/// The old picker was five tap segments and cleared by tapping the current value
/// again. Neither survives a continuous track: 0.1 granularity is finer than a
/// tap can aim, and "tap the same value" has no meaning when every pixel is a
/// different value. Hence a real slider and an explicit Clear (§12.2.5).
///
/// **The floating readout is gone (§12.9).** A numeral used to appear above the
/// thumb while dragging, and its row was kept in the layout at rest so the
/// control would not jump on first touch — which cost ~30pt of reserved blank
/// space above the track on every screen that hosts the slider, permanently, to
/// serve something visible only mid-drag. Both host screens already print the
/// value in their own header ("YOUR RATING   7.7"), so the readout was a second
/// numeral changing in lockstep with the first, which reads as a bug. Removing
/// it takes the reservation with it and reintroduces no jump, because nothing
/// appears on touch any more: the control is the same height before, during and
/// after a drag.
struct RatingSlider: View {
    @Binding var rating: Rating?

    @State private var isDragging = false

    /// Intrinsic geometry, not layout spacing — the same category of constant as
    /// `RatingMark.Size` and `BookCoverView.width`.
    private enum Metrics {
        static let track: CGFloat = 6
        static let thumb: CGFloat = 26
        /// Touch band around the track, and — since the readout row went — the
        /// entire height of the control above its legend.
        ///
        /// It was 34pt, which was fine while the 30pt readout row sat above it
        /// and took the same gesture: 64pt of target. Removing that row without
        /// touching this number would have left a 34pt target, under the 44pt
        /// minimum, on the one control in the app that is *only* usable by
        /// touch. 44pt restores the target and still gives back 20pt of the 30
        /// the readout was holding. The extra height is not dead space in the
        /// §12.9 sense — it is symmetric around the thumb and it is the thing
        /// your finger lands on.
        static let band: CGFloat = 44
    }

    var body: some View {
        // `snug` rather than `tight`: see the Clear button below, which used
        // to sit six points under a live drag surface.
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            GeometryReader { geo in
                let usable = max(geo.size.width - Metrics.thumb, 1)
                let centre = usable * fraction + Metrics.thumb / 2

                track(centre: centre)
                    .frame(width: geo.size.width, height: Metrics.band)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    RatingHaptics.prepare()
                                }
                                set(x: value.location.x, usable: usable)
                            }
                            .onEnded { _ in isDragging = false }
                    )
            }
            .frame(height: Metrics.band)
            .accessibilityElement()
            .accessibilityLabel(Judgement.ScoreCopy.title)
            .accessibilityValue(rating?.spoken ?? "Not rated")
            .accessibilityAdjustableAction { direction in
                // Steps by whatever the thumb is currently snapping to, so a
                // VoiceOver reader and a dragging reader are on the same grid.
                // Stepping by a tenth under Wholes would produce values the
                // slider itself cannot return to.
                let mode = DebugSettings.shared.scale
                switch direction {
                case .increment:
                    // From unrated, one increment lands on the mode's first rung
                    // rather than a step above it.
                    let base = rating?.value ?? (mode.lowerBound - mode.step)
                    rating = Rating.clamping(mode.snap(base + mode.step))
                case .decrement:
                    // Stepping below the floor holds there rather than clearing.
                    // Clear is an explicit control and is reachable as its own
                    // VoiceOver element, so an under-run should not silently
                    // discard a rating.
                    guard let current = rating else { return }
                    rating = Rating.clamping(mode.snap(current.value - mode.step))
                @unknown default:
                    break
                }
            }

            footer
        }
    }

    // MARK: Parts

    private func track(centre: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Theme.Palette.ink.opacity(0.12))
                .frame(height: Metrics.track)

            if rating != nil {
                Capsule()
                    .fill(Theme.Palette.ink)
                    .frame(width: centre, height: Metrics.track)
            }

            // The thumb is drawn whether or not there is a rating. Hiding it
            // when unrated left a bare capsule that reads as a divider, not a
            // control — on a page of hairline rules nothing said this one could
            // be dragged. Unrated it sits at the floor and is drawn faintly, so
            // it offers itself without claiming a value of 0.1.
            Circle()
                .fill(Theme.Palette.paper)
                .overlay(
                    Circle().stroke(
                        Theme.Palette.ink.opacity(rating == nil ? 0.3 : 1),
                        lineWidth: 2
                    )
                )
                .frame(width: Metrics.thumb, height: Metrics.thumb)
                .offset(x: centre - Metrics.thumb / 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.band)
    }

    /// The legend is the only thing that tells a first-time reader what the ends
    /// of a continuous track mean; a slider with no anchors is a guess.
    private var footer: some View {
        HStack(spacing: Theme.Space.snug) {
            Text("0.1 – 10")
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            if rating != nil {
                // **The most dangerous small target in the app**, and it was
                // the smallest. `.plain` hit-tests the glyphs, so this was
                // roughly 30x15pt — and it sat `tight` (6pt) below a track whose
                // `contentShape` fills the full 44pt band and carries a
                // `DragGesture(minimumDistance: 0)`. A tap a few points high did
                // not miss harmlessly: it registered as a drag and rewrote the
                // score to whatever value happened to sit under that x. Clearing
                // is the one action here a reader cannot undo by dragging back,
                // because once it is gone they no longer know what the number
                // was.
                //
                // Padded inside the label so the target grows rather than a
                // transparent box floating over a smaller one, and the footer's
                // spacing was opened up so a high tap lands on neither control
                // instead of on the track.
                Button {
                    RatingHaptics.clearTick()
                    rating = nil
                } label: {
                    Text("Clear")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .padding(.vertical, Theme.Space.snug)
                        .padding(.leading, Theme.Space.base)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear \(Judgement.ScoreCopy.title)")
            }
        }
    }

    // MARK: Maths

    /// 0.1 sits at the left edge and 10.0 at the right, so both ends of the
    /// scale are reachable without fighting the thumb's own width.
    private var fraction: CGFloat {
        guard let rating else { return 0 }
        return CGFloat((rating.value - Rating.range.lowerBound) / span)
    }

    private var span: Double { Rating.range.upperBound - Rating.range.lowerBound }

    private func set(x: CGFloat, usable: CGFloat) {
        let f = Double(min(max((x - Metrics.thumb / 2) / usable, 0), 1))
        // The grid under the thumb is a prototype setting. §12.2.7 records the
        // objection to one decimal — finer than a reader can reproduce week to
        // week — as raised and overruled; this is how it gets *felt* on device
        // rather than re-argued on paper.
        //
        // It governs new input and nothing else: `Rating.range`, `Rating.step`,
        // the encoded shape and every seeded and stored value are untouched, so
        // switching modes never rewrites a rating that already exists. The
        // track still spans 0.1–10.0; a coarser mode simply cannot land between
        // its rungs, and its own floor is its first rung.
        let mode = DebugSettings.shared.scale
        let next = Rating.clamping(mode.snap(Rating.range.lowerBound + f * span))
        // Only on a real change — a drag reports continuously, and firing per
        // event rather than per tenth is what makes a slider feel like sandpaper.
        guard next.value != rating?.value else { return }
        RatingHaptics.emit(from: rating, to: next)
        rating = next
    }
}

/// **Favorite** — the claim that is not a score.
///
/// This mark is about the book on screen and nothing else. It never means "on
/// their profile"; the four a reader features live in
/// `ReaderProfile.favoriteBookIDs` and are chosen separately.
struct FavoriteMark: View {
    var filled: Bool
    var size: CGFloat = 14

    /// **It grows with the reader's text size.**
    ///
    /// `.font(.system(size:))` is an absolute point size and answers no setting,
    /// so this glyph stayed 12–14pt beside numerals and titles that doubled. It
    /// sits next to a rating on nearly every row in the app — the diary, the
    /// library, list rows, review bylines, comparison cards — and it is the only
    /// object in those rows carrying a whole concept on its own, with no word
    /// beside it to fall back on.
    ///
    /// Capped like the cover and the score ring: unbounded, a 22pt mark on the
    /// log sheet reaches ~77pt at AX5 and starts pushing the label it belongs to
    /// off the row.
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    private var drawnSize: CGFloat { size * min(max(typeScale, 1), 1.8) }

    var body: some View {
        Image(systemName: filled ? "bookmark.circle.fill" : "bookmark.circle")
            .font(.system(size: drawnSize))
            .foregroundStyle(filled ? Theme.Palette.accent : Theme.Palette.inkFaint)
            .accessibilityLabel(filled ? Judgement.FavoriteCopy.title : "Not a favorite")
    }
}
