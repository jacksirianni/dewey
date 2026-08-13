import SwiftUI

// MARK: - The circled score

/// The community score as the 2023 wireframe drew it: a numeral inside a thin
/// ring (§12.5.4).
///
/// This is the number the crowd decision turns on (§12.1). The prior build put
/// the community average in a caption under a friend's rating, which was true to
/// the argument and wrong about the screen — a product that refuses to quantify
/// anything reads as inert rather than principled. Loudness here comes from the
/// numeral's size, not from colour or weight: the ring stays a hairline so the
/// mark still belongs to a page built out of rules.
///
/// **The ring means the crowd, and only the crowd.** That is the whole of
/// Dewey's rule about rating visuals, and it is stated here and on `RatingMark`
/// because for three builds it was not true: the Library drew each reader's
/// *own* rating in this component, so the one object that distinguishes "four
/// thousand strangers" from "you" meant both, one tab apart. A person's rating
/// is a bare serif numeral — `RatingMark` — everywhere in the app without
/// exception. If a second circled score is ever wanted, it needs a different
/// shape, not a different caller.
///
/// It therefore takes a raw `Double`: a community average is a mean and lands
/// wherever it lands. The `Rating` initialiser is kept because a mean that has
/// already been snapped is still a legitimate input, not because a personal
/// rating belongs in a ring.
struct ScoreCircle: View {
    enum Size {
        case small, regular, large

        var diameter: CGFloat {
            switch self {
            case .small: 34
            case .regular: 52
            case .large: 88
            }
        }

        var ring: CGFloat {
            switch self {
            case .small: 1
            case .regular: 1.25
            case .large: 1.5
            }
        }

        /// Set against the diameter rather than against Dynamic Type directly:
        /// the numeral has to stay inside its ring, so the two scale together
        /// or not at all. Same trade `BookCoverView` makes for typeset covers.
        var numeral: CGFloat {
            switch self {
            case .small: 15
            case .regular: 22
            case .large: 36
            }
        }
    }

    private let score: Double?
    private let size: Size

    init(score: Double?, size: Size = .regular) {
        self.score = score
        self.size = size
    }

    init(rating: Rating?, size: Size = .regular) {
        self.init(score: rating?.value, size: size)
    }

    /// **The ring grows with the reader's text size, up to a point.**
    ///
    /// It did not, and the comment above said so as though it were settled: the
    /// numeral was pinned to the diameter and the diameter was three literals,
    /// so at an accessibility text size the loudest number on a book page stayed
    /// exactly 88pt with a 36pt figure in it while every word around it doubled.
    /// The one element on the page a low-vision reader most needs to read was
    /// the only one that refused to answer the setting.
    ///
    /// Bounded rather than proportional, which is the part `BookCoverView`'s
    /// trade gets right: an unbounded 88pt circle reaches ~310pt at AX5 and is
    /// then wider than the phone, taking the histogram beside it off screen.
    /// A ceiling of 1.6 is enough to make the figure legibly larger and small
    /// enough that the block it lives in keeps its shape.
    @ScaledMetric(relativeTo: .title) private var typeScale: CGFloat = 1

    private static let maximumGrowth: CGFloat = 1.6

    private var scale: CGFloat { min(max(typeScale, 1), Self.maximumGrowth) }
    private var diameter: CGFloat { size.diameter * scale }
    private var numeralSize: CGFloat { size.numeral * scale }

    /// Untinted, for the same reason `RatingMark` is: a score that changes
    /// colour by whose it is reads as a claim about the book (§13.5).
    private var color: Color { Theme.Palette.ink }

    var body: some View {
        Circle()
            .stroke(color.opacity(0.25), lineWidth: size.ring)
            .frame(width: diameter, height: diameter)
            .overlay {
                Text(numeral)
                    .font(.system(size: numeralSize, weight: .semibold, design: .serif))
                    .foregroundStyle(score == nil ? Theme.Palette.inkFaint : color)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, diameter * 0.14)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
    }

    /// Whole scores drop the decimal, matching `Rating.compact`. A page of
    /// "8.0" and "7.0" reads as instrument output.
    private var numeral: String {
        guard let score else { return "—" }
        let snapped = (score * 10).rounded() / 10
        return snapped.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", snapped)
            : String(format: "%.1f", snapped)
    }

    private var label: String {
        score == nil ? "Not yet scored" : "\(numeral) out of 10"
    }
}

// MARK: - The distribution

/// Twenty thin bars, peak-normalised. Sits beside `ScoreCircle` in the Dewey
/// Score block.
///
/// **Half-point bins, not tenths** (§12.3). Input keeps 0.1 precision; ninety-nine
/// bars would be noise on any corpus this size, and the wireframe's own histogram
/// has about twelve. Twenty is the most that still reads as a shape.
///
/// The bars are deliberately quiet. This is context for the numeral next to it,
/// not a second headline — if the histogram competes, the block has two subjects
/// and a reader picks neither.
struct DistributionHistogram: View {
    /// Half a point per bin across 0.1…10.0.
    static let bucketCount = 20

    let counts: [Int]
    var height: CGFloat = 44

    /// Zero buckets keep a hairline stub so the axis reads as continuous rather
    /// than gap-toothed, and any non-empty bucket clears the stub — one rating
    /// should be visible as one rating.
    private let floorHeight: CGFloat = 1.5
    private let minimumBar: CGFloat = 3

    private var color: Color { Theme.Palette.ink }

    /// Padded or truncated rather than trusted. The seeded distributions are
    /// mid-migration from ten buckets to twenty, and a histogram that traps on
    /// the wrong length would take the whole app down with it.
    private var bars: [Int] {
        if counts.count == Self.bucketCount { return counts }
        return Array(counts.prefix(Self.bucketCount))
            + Array(repeating: 0, count: max(0, Self.bucketCount - counts.count))
    }

    private var peak: Int { bars.max() ?? 0 }
    private var total: Int { bars.reduce(0, +) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(bars.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(color.opacity(bars[i] == 0 ? 0.10 : 0.30))
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight(bars[i]))
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func barHeight(_ count: Int) -> CGFloat {
        guard peak > 0, count > 0 else { return floorHeight }
        return max(minimumBar, height * CGFloat(count) / CGFloat(peak))
    }

    /// VoiceOver gets the shape's meaning, not its shape: how many people, and
    /// where they landed. Spoken with "to" rather than a dash, which reads aloud
    /// as nothing.
    private var label: String {
        guard total > 0, let peakIndex = bars.firstIndex(of: peak) else {
            return "No ratings yet"
        }
        let span = Self.range(of: peakIndex)
        return "\(total) ratings, most often \(Self.spoken(span.lowerBound)) to \(Self.spoken(span.upperBound))"
    }

    // MARK: Binning
    //
    // Shared so the store, the histogram and anything that labels a bucket agree
    // on where the edges are. Buckets are open at the bottom and closed at the
    // top — bucket 15 is (7.5, 8.0], which is what a reader means by "eights".

    /// The bucket a rating falls in, 0…19.
    static func bucket(for value: Double) -> Int {
        min(bucketCount - 1, max(0, Int(ceil(value / 0.5)) - 1))
    }

    /// The tenths a bucket covers, inclusive of both ends as displayed:
    /// bucket 0 is 0.1…0.5, bucket 19 is 9.6…10.0.
    static func range(of index: Int) -> ClosedRange<Double> {
        // Built up from the index rather than subtracted from the top edge:
        // 0.5 − 0.4 is not 0.1 in binary floating point, and bucket 0's floor is
        // the scale's floor.
        let lower = Double(index) * 0.5 + 0.1
        return lower...(Double(index + 1) * 0.5)
    }

    /// The geometric centre of a bucket, for anything that needs to place a
    /// bucket on an axis rather than name it.
    ///
    /// **Deliberately not what `DeweyStore.communityAverage` weights by**, and
    /// this is written down because the opposite looks like the obvious fix. A
    /// bucket is named after its top edge — 7.6…8.0 is what a reader calls "the
    /// eights" — so averaging at the midpoint shifts every Dewey Score down by
    /// 0.2 and caps the scale at 9.8, meaning a book every single reader gave a
    /// 10 could never display as one. The store uses `range(of:).upperBound`.
    /// Currently unreferenced; kept because the binning statics are only useful
    /// as a complete set.
    static func midpoint(of index: Int) -> Double {
        Double(index) * 0.5 + 0.3
    }

    private static func spoken(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
