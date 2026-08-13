import SwiftUI
import UIKit

// TEMPORARY — prototype scaffolding. Delete this file alongside
// DebugMenuView.swift and DebugActions.swift. Nothing in the shipping surface
// area is allowed to depend on it; every read site should be a single
// `DebugSettings.shared.…` lookup that can be deleted in one line.

/// A founder evaluation tool. Three A/B switches for things that can only be
/// judged with a thumb on a screen.
///
/// **In memory only, and that is the whole design.** These values are never
/// written to `UserDefaults`, never enter `Persistence.State`, and never touch
/// the JSON file. Every launch starts at the defaults below. That is deliberate
/// three times over: a comparison tool that silently remembers last week's
/// setting produces a judgement about a configuration nobody can name; a
/// prototype whose persisted schema grows a settings blob acquires a migration
/// problem for a feature that will be deleted; and the defaults here are the
/// claim being tested — the app a stranger opens must be the app as built, not
/// as last fiddled with.
///
/// A singleton rather than an `@Environment` value because the read sites are
/// scattered across the mark, the slider and the book page, and threading a
/// prototype-only object through four view hierarchies is exactly the kind of
/// contamination that makes scaffolding hard to remove later. `@Observable` so
/// that flipping a switch in the debug sheet redraws the surfaces behind it
/// without any further plumbing.
@Observable final class DebugSettings {
    static let shared = DebugSettings()

    var haptics: HapticPreset = .balanced
    var scale: ScaleMode = .tenths

    /// Which world the app boots into. Unlike the two settings above this one
    /// *is* consequential — switching it rewrites the store and the file on
    /// disk — so it is applied through `DeweyStore.load(world:)` rather than
    /// read opportunistically by views.
    ///
    /// **The default is `.fresh`, and the seeded world is now debug-only** (§17).
    /// It used to be `.seeded`, which meant an ordinary launch of an ordinary
    /// build handed a stranger sixty-one followers, fourteen ranked books and
    /// somebody else's diary — a fiction that was useful for showing the product
    /// and indefensible the moment real accounts existed. A reader who signs in
    /// now gets an empty library, because that is what they have.
    ///
    /// The seeded corpus is still one tap away in this menu, and is still what
    /// previews and `SeedData` fixtures draw. `WorldMode.seeded` did not go
    /// anywhere; it just stopped being what happens by default.
    var world: WorldMode = .fresh
}

// MARK: - World

/// Seeded demo corpus, or a genuinely empty account.
///
/// The prototype has only ever booted into a rich world: fourteen ranked books,
/// sixty-one followers, a populated diary. That world is the right one for
/// showing what Dewey *is*, and it is the wrong one for answering the question
/// the app cannot otherwise answer — what a stranger sees on the first launch,
/// when "readers you follow" is nobody and the Edition has nothing to draw on.
/// For a product whose whole premise is other people's taste, that screen is
/// the one that decides whether anyone reaches the second one.
///
/// **`.fresh` fabricates nothing.** No follower count, no history, no ratings,
/// no ranked library, no lists. It is the honest floor, and the onboarding path
/// is what climbs out of it.
enum WorldMode: String, CaseIterable, Identifiable, Codable {
    case seeded
    case fresh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seeded: "Seeded world"
        case .fresh: "Fresh account"
        }
    }

    var blurb: String {
        switch self {
        case .seeded: "The demo corpus. Full diary, followed readers, ranked library."
        case .fresh: "Day one. No history, no follows, no numbers. Onboarding runs."
        }
    }
}

// MARK: - Haptics

/// Four candidate feels for the rating slider, to be compared by thumb.
///
/// §12.2.3 asks for "a subtle tick at every 0.1, a stronger one at each whole
/// number." That is a shape, not a number, and the difference between a whisper
/// and a nag is roughly 0.15 of intensity — invisible in a spec and obvious in a
/// hand. Each preset supplies both intensities, both impact styles, and its own
/// answer to *when* the engine should fire at all.
///
/// The caller decides which of the two intensities applies by asking whether the
/// value is whole; the preset only supplies the pair. So under `.minimal`, which
/// fires only at halves, an x.5 uses the tenth weight and an x.0 uses the whole
/// weight.
enum HapticPreset: String, CaseIterable, Identifiable {
    case quiet
    case balanced
    case mechanical
    case minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiet: "Quiet"
        case .balanced: "Balanced"
        case .mechanical: "Mechanical"
        case .minimal: "Minimal"
        }
    }

    /// One line, written to be read while the thumb is still on the track.
    var blurb: String {
        switch self {
        case .quiet: "Barely there."
        case .balanced: "What is built today."
        case .mechanical: "A ratchet with detents."
        case .minimal: "Ticks only at the halves."
        }
    }

    /// Weight of a tick that is not a whole number.
    var tenthIntensity: CGFloat {
        switch self {
        case .quiet: 0.15
        case .balanced: 0.30
        case .mechanical: 0.45
        case .minimal: 0.25
        }
    }

    /// Weight of a tick landing on a whole number — the orientation landmark.
    var wholeIntensity: CGFloat {
        switch self {
        case .quiet: 0.40
        case .balanced: 0.75
        case .mechanical: 1.00
        case .minimal: 0.70
        }
    }

    var tenthStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .quiet, .balanced, .minimal: .light
        case .mechanical: .rigid
        }
    }

    var wholeStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .quiet, .balanced: .light
        case .mechanical, .minimal: .medium
        }
    }

    /// Whether this preset wants a tick at `value`.
    ///
    /// Three presets tick at every tenth, which is ninety-nine events in a
    /// full-length drag; `.minimal` tests whether that is texture or noise by
    /// ticking only at x.0 and x.5.
    ///
    /// Tested against the preset's own increment with an epsilon rather than by
    /// equality. A rating arrives here after `(value * 10).rounded() / 10`, and
    /// 8.3 in binary floating point is 8.300000000000000711 — `8.3 / 0.5` is
    /// 16.599999999999998, and any comparison written as `value == steps * inc`
    /// would drop real ticks unpredictably across the track. The tolerance is far
    /// tighter than half a tenth, so it can never merge two adjacent ratings.
    func fires(at value: Double) -> Bool {
        guard value.isFinite else { return false }
        let steps = (value / tickIncrement).rounded()
        return abs(value - steps * tickIncrement) < 1e-6
    }

    /// The spacing this preset ticks on. Private: read sites ask `fires(at:)`,
    /// which is the only question they have, and keeping the grid internal means
    /// a preset could later tick on something that isn't a fixed interval.
    private var tickIncrement: Double {
        switch self {
        case .quiet, .balanced, .mechanical: 0.1
        case .minimal: 0.5
        }
    }
}

// MARK: - Scale

/// How coarse the slider is under the thumb.
///
/// §12.2.7 records the counter-argument to one decimal — that it is finer than a
/// reader can reproduce week to week — as raised and overruled. This is how that
/// gets *felt* rather than re-argued: drag at tenths, at halves and at wholes and
/// see which one produces a rating you believe.
///
/// **Scope, and this is the hard line.** This governs *only what the slider snaps
/// to for new input.* It must not alter `Rating.range`, `Rating.step`, the
/// `Codable` shape, the seed, the histogram's 0.5 bins, or any value already
/// stored. A rating recorded as 8.3 is still 8.3 after the founder switches to
/// `.wholes`; it renders as 8.3, it is written to disk as 8.3, and the only
/// consequence of the switch is that the next *new* drag lands on 8.0 or 9.0.
/// Nothing here is a step towards a configurable production rating system —
/// making the scale a real setting would mean versioning the stored shape, and
/// that is explicitly out of scope.
enum ScaleMode: String, CaseIterable, Identifiable {
    case tenths
    case halves
    case wholes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tenths: "Tenths"
        case .halves: "Halves"
        case .wholes: "Wholes"
        }
    }

    /// The gap between adjacent reachable values.
    var step: Double {
        switch self {
        case .tenths: 0.1
        case .halves: 0.5
        case .wholes: 1.0
        }
    }

    /// The lowest value this mode can reach.
    ///
    /// Equal to `step` in every case, and stated separately because it is a
    /// different claim: `Rating.range` starts at 0.1 because zero is not a
    /// rating, so a coarser grid cannot start below its own first rung without
    /// producing a value it can't return to.
    var lowerBound: Double {
        switch self {
        case .tenths: 0.1
        case .halves: 0.5
        case .wholes: 1.0
        }
    }

    /// The nearest value on this mode's grid, clamped into the rating range.
    ///
    /// Rounds to the grid, then re-rounds to a whole tenth before clamping:
    /// `(value / 0.5).rounded() * 0.5` can land on 8.500000000000002, and
    /// `Rating.init?` would take that as a third decimal. The result is always a
    /// value `Rating.clamping` will accept unchanged.
    func snap(_ value: Double) -> Double {
        guard value.isFinite else { return lowerBound }
        let onGrid = (value / step).rounded() * step
        let tidied = (onGrid * 10).rounded() / 10
        return min(max(tidied, lowerBound), Rating.range.upperBound)
    }
}

// The book-page A/B ordering variant was removed in §13.2. The page now has one
// canonical shape: a compact relationship summary above a single Log/Update
// action. The variant existed to compare two orderings of a region that also
// carried a second, competing inline editor — and once the duplicate editor
// went, the thing being compared went with it.
