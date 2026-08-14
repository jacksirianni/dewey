import SwiftUI

/// What the app shows when there is no account system to sign into (§18).
///
/// **Two different audiences see this screen, and they see two different
/// things.** In DEBUG it is a developer screen, because a developer with Xcode
/// open is who could be looking at it — reached only by asking for it, via
/// "Leave local test mode" in the prototype controls, since an unconfigured
/// debug build otherwise goes straight to local test accounts. In RELEASE it is
/// what a fresh TestFlight install shows before anyone has stood up a Supabase
/// project, and whoever installed that build has never opened this repository —
/// telling them to create a `.plist` file would be telling them nothing they can
/// act on. RELEASE gets an honest beta screen instead: what's true (no account
/// server is connected yet), what that means (their reading stays on this
/// device only), and a way in.
///
/// Both branches share the same underlying defence against the stand-in being
/// *mistakable* for the real thing — see `AccountServices` — just aimed at
/// different readers of the screen.
struct DeveloperConfigurationView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        #if DEBUG
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                developerContent
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .background(Theme.Palette.paper)
        #else
        FirstRunScaffold(
            footerTitle: "Continue",
            footerAction: {
                AccountServices.enterBetaLocalMode()
                Task { await session.reloadServices() }
            }
        ) {
            betaContent
        }
        #endif
    }

    // MARK: - DEBUG: developer screen

    #if DEBUG
    /// Deliberately styled like a developer screen rather than a Dewey surface —
    /// system font, monospaced path, no serif headline. It should be obvious in
    /// a screenshot that this is not something a reader could ever reach.
    private var developerContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Accounts are not configured", systemImage: "wrench.and.screwdriver")
                .font(.title3.weight(.semibold))

            Text("Dewey has no account system to sign into. It will not invent one.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("To connect to Supabase").font(.subheadline.weight(.semibold))
                Text("Create this file and fill in both values:")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Dewey/Dewey/Account/SupabaseConfig.plist")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                Text("Copy SupabaseConfig.example.plist beside it. Full steps are in docs/SETUP-ACCOUNTS.md.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(.quinary, in: RoundedRectangle(cornerRadius: 12))

            localTestingOptIn
        }
    }

    // MARK: - Back to local
    /// The way back, since this screen is now somewhere a debug build has to be
    /// sent rather than somewhere it lands.
    ///
    /// It states what the mode is not before it offers the button, and it
    /// disappears entirely the moment real configuration exists — a configured
    /// build cannot enter local mode at all, so there is no way to end up in the
    /// fake one while believing the real one is available.
    private var localTestingOptIn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Or go back to local test accounts").font(.subheadline.weight(.semibold))
            Text("""
                 Local test accounts live in UserDefaults on this device and are \
                 the default for an unconfigured debug build — you are seeing this \
                 screen because you left them. They exercise the first-run flow and \
                 account-scoped local storage, and they prove nothing about \
                 Supabase: no shared uniqueness, no Row Level Security, no real \
                 Apple identity, no second device.
                 """)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                AccountServices.setLocalTestingMode(true)
                Task { await session.reloadServices() }
            } label: {
                Label("Use local test accounts", systemImage: "hammer")
            }
            .buttonStyle(.borderedProminent)

            Text("Debug builds only. Reversible from the prototype controls.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
    }
    #endif

    // MARK: - RELEASE: beta screen

    #if !DEBUG
    /// A Dewey surface, not a developer one — this is the first thing an
    /// external tester can see, so it reads like the rest of first run (drawn
    /// inside the same `FirstRunScaffold` as `WelcomeView` and `SignInView`)
    /// rather than like a wrench-and-screwdriver diagnostic. States plainly what
    /// is and is not true; the way in is the scaffold's own footer button, which
    /// calls `AccountServices.enterBetaLocalMode()`. No file paths, no doc
    /// references — nothing here assumes the reader has the repository open.
    private var betaContent: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("Dewey").kickerStyle()
            Text("A beta build, ahead of the account service.")
                .font(Theme.TypeScale.title())
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("""
                 This copy of Dewey isn't connected to an account service yet, \
                 so there's nothing to sign in to. You can still try everything \
                 else: your identity, your library and everything you log stay \
                 on this device. Nothing here syncs to another device, and \
                 nothing is shared with anyone else testing this beta.
                 """)
            .font(Theme.TypeScale.prose())
            .foregroundStyle(Theme.Palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
    #endif
}
