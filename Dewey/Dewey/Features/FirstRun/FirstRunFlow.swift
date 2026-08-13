import SwiftUI

/// The whole cold start, in order (§17).
///
/// ```
/// welcome → sign in → name and handle → pick → rate → Favorite Books → people → done
/// └──────────── account ─────────────┘ └────────────── taste ──────────────────────┘
/// ```
///
/// **One sequence, two owners.** The three account screens live here; the four
/// taste steps stay in `OnboardingView`, unchanged, and are entered at `.pick`
/// because this flow has already drawn `WelcomeView` as its own first screen.
/// Keeping them apart means the taste steps can still be re-run on their own from
/// the debug menu, and means a change to how sign-in works cannot accidentally
/// alter what the app asks a reader about books.
///
/// **Where the reader is, is `SessionStore.phase` — not a step counter here.**
/// The one piece of local state is whether the welcome screen has been dismissed,
/// which is genuinely local: it is the only step with nothing behind it on the
/// server. Everything else is derived, so an app killed at any point comes back
/// to exactly the screen it left, on this device or another.
struct FirstRunFlow: View {
    @Environment(SessionStore.self) private var session
    @Environment(DeweyStore.self) private var store

    @State private var hasLeftWelcome = false

    #if DEBUG
    @State private var showingDebug = false
    #endif

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
            // **The prototype controls have to be reachable from here too.**
            // They live on the Edition and Library toolbars, which are behind
            // this cover — so while signed out there was no way to switch test
            // account, leave local test mode, or read the backend row. Which
            // made the one state where those controls matter most the one state
            // they could not be opened from.
            #if DEBUG
                .debugMenu(isPresented: $showingDebug)
            #endif
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .unconfigured:
            DeveloperConfigurationView()

        case .restoring:
            restoring

        case .signedOut:
            if hasLeftWelcome {
                SignInView()
            } else {
                FirstRunScaffold(
                    footerTitle: "Get started.",
                    footerAction: { advance { hasLeftWelcome = true } },
                    topPadding: Theme.Space.snug
                ) {
                    WelcomeView()
                }
            }

        case .needsIdentity(_, let suggestedName):
            IdentitySetupView(suggestedName: suggestedName)

        case .needsTasteOnboarding:
            // The four taste steps, exactly as they were, entered past the
            // welcome screen this flow already drew.
            OnboardingView(startingAt: .pick) {
                Task { await finishTasteOnboarding() }
            }

        case .ready:
            // `RootView` takes the cover down on this phase; drawing anything
            // here would be a frame of the wrong screen on the way out.
            Color.clear
        }
    }

    /// Reading the keychain. Deliberately almost nothing — a spinner and the
    /// wordmark. A returning reader is here for a few hundred milliseconds and
    /// should not be shown a headline they will never finish reading.
    private var restoring: some View {
        VStack(spacing: Theme.Space.base) {
            Spacer()
            DeweyMark(side: 44)
            ProgressView().controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.paper)
        .accessibilityLabel("Opening Dewey")
    }

    // MARK: - Chrome

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // Signing out is reachable from the identity screen because it is the
        // one place a reader can be stuck: authenticated as somebody, with no
        // profile, and no other way back to the sign-in screen. It is not
        // offered on welcome (nothing to sign out of) or during the taste steps
        // (`OnboardingView` has its own Skip, which finishes rather than
        // abandons).
        if case .needsIdentity = session.phase {
            ToolbarItem(placement: .cancellationAction) {
                Button("Sign out") {
                    Task { await session.signOut() }
                }
                .font(Theme.TypeScale.ui())
                .foregroundStyle(Theme.Palette.inkSoft)
            }
        }
    }

    private func advance(_ change: () -> Void) {
        withAnimation(Theme.Motion.standard, change)
    }

    // MARK: - Commit

    /// Hands the taste steps' result to the account.
    ///
    /// **`OnboardingView` has already written everything locally** by the time
    /// this runs — diary entries, ratings, the chosen four, the follows, the one
    /// provenance-stamped save. That behaviour is untouched. This reads back the
    /// two collections the account owns and pushes them, so a reinstall restores
    /// them.
    ///
    /// Ratings, diary and the provenance save are **not** pushed, and that is the
    /// deliberate limit of this stage: there is no server-side reading record
    /// yet. A second device gets your identity, your follows and your four, and
    /// an empty diary. Do not describe this as sync.
    private func finishTasteOnboarding() async {
        await session.completeTasteOnboarding(
            favoriteBooks: store.favoriteBookIDs,
            seedFollows: Array(store.follows)
        )
    }
}
