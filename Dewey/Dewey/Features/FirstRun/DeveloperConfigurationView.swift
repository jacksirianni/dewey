import SwiftUI

/// What the app shows when there is no account system to sign into (§18).
///
/// **In a release build this is the end of the road, and that is the point.** A
/// release binary with no `SupabaseConfig.plist` stops here: there is no code
/// path to a stand-in, and `LocalAuthService` does not compile into it at all.
/// Missing production configuration stays an explicit state the app shows you.
///
/// **In a debug build this screen is now reached only by asking for it** —
/// "Leave local test mode" in the prototype controls. Unconfigured debug builds
/// go straight to local test accounts, because what makes the stand-in dangerous
/// is being mistakable for the server, not being automatic, and the defences
/// against *that* are the announcements: the banner under the sign-in headline,
/// the banner at the top of the prototype controls, the Backend row, and a
/// sign-in button reading "Test account A" instead of showing Apple's. A
/// configuration screen between launch and the product bought none of that and
/// cost a step on every fresh checkout and every wiped simulator.
///
/// Deliberately styled like a developer screen rather than a Dewey surface —
/// system font, monospaced path, no serif headline. It should be obvious in a
/// screenshot that this is not something a reader could ever reach.
struct DeveloperConfigurationView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        ScrollView {
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

                #if DEBUG
                localTestingOptIn
                #endif

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .background(Theme.Palette.paper)
    }

    // MARK: - Back to local

    #if DEBUG
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
}
