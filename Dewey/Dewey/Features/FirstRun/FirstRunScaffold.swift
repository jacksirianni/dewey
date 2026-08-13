import SwiftUI

/// The page chrome the first-run screens share with the taste steps.
///
/// Lifted out of `OnboardingView` rather than reinvented, because the seam
/// between "account creation" and "onboarding" must not be visible to a reader:
/// welcome, sign in and name-and-handle are the first three screens of one
/// sequence, and a different margin or a differently-placed button on any of
/// them would announce that two teams built it.
///
/// **The action is pinned** rather than sitting under the content, for the same
/// reason it is in the taste steps — the identity screen's keyboard can push a
/// button below the fold, and a reader who has filled in both fields must never
/// have to hunt for the way forward.
struct FirstRunScaffold<Content: View>: View {
    /// Nil draws no footer at all. The sign-in screen has no footer: its action
    /// is Apple's own button, and a second primary control underneath it would
    /// be a decision the reader does not have.
    var footerTitle: String? = nil
    var footerDisabled: Bool = false
    var footerAction: () -> Void = {}

    /// The welcome step opens on a full-bleed band of covers, which wants to sit
    /// up against the navigation bar rather than a finger's width below it — the
    /// gap reads as the screen not having started yet. Every other step opens on
    /// a text head, which does want the air.
    var topPadding: CGFloat = Theme.Space.loose

    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.roomy) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, topPadding)
            .padding(.bottom, Theme.Space.vast)
            .pageMargin()
        }
        .background(Theme.Palette.paper)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            if let footerTitle {
                VStack(spacing: 0) {
                    Rule()
                    Button(footerTitle) { footerAction() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(footerDisabled)
                        // `PrimaryButtonStyle` draws no disabled state, and it
                        // is not this screen's business to add one to every
                        // primary button in the app. The taste steps get away
                        // without it because their label says what is missing
                        // ("Pick 3 more"); "Continue" cannot, so the dimming
                        // has to carry it here.
                        .opacity(footerDisabled ? 0.35 : 1)
                        .animation(Theme.Motion.standard, value: footerDisabled)
                        .pageMargin()
                        .padding(.vertical, Theme.Space.base)
                }
                .background(.regularMaterial)
            }
        }
    }
}
