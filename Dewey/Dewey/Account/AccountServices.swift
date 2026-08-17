import Foundation
import Supabase

/// Which account system the app is talking to, and the only place that decides.
///
/// **The fallback is automatic in DEBUG, never silent, and opt-in in RELEASE.**
/// Those three clauses are the whole policy, and the middle one is what §18 was
/// actually protecting.
///
/// §18 removed an automatic debug fallback because it produced the most
/// dangerous possible failure mode: a developer running what looks like the real
/// thing, watching handles reserve and profiles save, and drawing conclusions
/// about a server they were never connected to. The fix was to make the choice
/// explicit — a configuration screen, and a button.
///
/// **The diagnosis was right and the remedy was aimed at the wrong thing.** What
/// makes the stand-in dangerous is being *mistakable* for the server, not being
/// *automatic*. A button press does nothing about that: press it once and every
/// launch afterwards is indistinguishable from a configured one. What actually
/// defends against it is the announcement — the banner on the sign-in screen,
/// the Backend row in the prototype controls, the sign-in button that reads
/// "Sign in as Test account A" rather than showing Apple's. All of that stayed,
/// and a top-of-sheet banner was added; none of it depended on the gate.
///
/// Meanwhile the gate cost a real thing: a configuration screen standing between
/// launch and the product, on every fresh checkout and every wiped simulator,
/// during a phase of work that has nothing to do with accounts.
///
/// **Release later gained its own opt-in, for the same underlying reason.** A
/// release build with no `SupabaseConfig.plist` is what a TestFlight build looks
/// like before anyone has stood up a Supabase project, and the original
/// developer-only dead end there meant nobody outside Xcode could get past
/// account setup at all. Same fix, same shape: the stand-in stays reachable only
/// through an explicit tap on a screen that says plainly what it is, never
/// automatically, and configuration still always wins.
///
/// Three modes:
///
///   * `.supabase` — `SupabaseConfig.plist` is present and parses. **Always
///     wins**, in both configurations. Adding the file is all it takes to be on
///     the real path; a configured build cannot enter local mode and is not
///     offered the choice.
///   * `.localTesting` — a debug build with no configuration, automatic; or a
///     release build with no configuration, after the reader has tapped past the
///     honest "beta, not yet connected" screen. Announced everywhere it could
///     matter. Can be left deliberately in DEBUG, which is how the
///     `.unconfigured` screen stays reachable for testing.
///   * `.unconfigured` — no configuration, and nobody has opted into the
///     stand-in yet. The app shows a screen naming that fact rather than
///     inventing an account system: a developer configuration screen in DEBUG,
///     an honest beta screen with a way in in RELEASE. **Neither build leaves
///     this state by itself** — there is no automatic code path to the
///     stand-in in RELEASE, only an explicit, remembered tap.
enum AccountBackend: String {
    case supabase
    case localTesting
    case unconfigured

    var title: String {
        switch self {
        case .supabase: "Supabase"
        case .localTesting: "Local test accounts (not Supabase)"
        case .unconfigured: "Not configured"
        }
    }

    /// Whether data written in this mode reaches a server. Read by anything
    /// tempted to describe local results as if they proved something.
    var isReal: Bool { self == .supabase }
}

enum AccountServices {
    /// **An opt-*out*, not an opt-in**, which is the whole of the default flip.
    ///
    /// It was `…localTestingMode.enabled`, defaulting false, so an unconfigured
    /// debug build sat on the configuration screen until somebody pressed a
    /// button. The key is now negative and still defaults false, so the same
    /// build goes straight to the product — and "Leave local test mode" in the
    /// prototype controls still works, because setting this is exactly what it
    /// does. The old key is deliberately not read: a checkout that had pressed
    /// the button and one that never had should now behave identically, and
    /// migrating a preference whose meaning inverted is how you get a machine
    /// that behaves differently from every other machine for reasons nobody can
    /// reconstruct.
    private static let localModeOptOutKey = "dewey.debug.localTestingMode.optedOut"

    /// The RELEASE counterpart of `localModeOptOutKey`: positive rather than
    /// negative, because the two builds default to opposite states. A debug
    /// build starts in local mode and has to be told to leave; a release build
    /// starts unconfigured and has to be told to enter — see `enterBetaLocalMode`.
    private static let betaLocalModeKey = "dewey.beta.localAccountMode.enabled"

    static var backend: AccountBackend {
        // Configuration always wins, in both build configurations. This is the
        // line that makes "switch to the real path later" a matter of adding a
        // file rather than of finding a setting.
        if AccountConfig.isConfigured { return .supabase }
        #if DEBUG
        if !UserDefaults.standard.bool(forKey: localModeOptOutKey) { return .localTesting }
        #else
        if UserDefaults.standard.bool(forKey: betaLocalModeKey) { return .localTesting }
        #endif
        return .unconfigured
    }

    /// Nil when unconfigured. Callers must handle that by showing the
    /// unconfigured state rather than by substituting anything.
    ///
    /// One `SupabaseClient` per call, shared by all three services — the same
    /// rule `SessionStore` already follows for auth and profiles, so a
    /// Library push never opens a second connection to the project.
    static func make() -> (auth: AuthService, profiles: ProfileService, library: LibraryService)? {
        switch backend {
        case .supabase:
            guard let config = AccountConfig.supabase else { return nil }
            let client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
            return (
                SupabaseAuthService(client: client),
                SupabaseProfileService(client: client),
                SupabaseLibraryService(client: client)
            )
        case .localTesting:
            return (LocalAuthService(), LocalProfileService(), LocalLibraryService())
        case .unconfigured:
            return nil
        }
    }

    #if DEBUG
    /// Leaving local mode is deliberate and persisted; entering it is the
    /// default. A configured build ignores this entirely — it is on the real
    /// path and has no stand-in to toggle.
    static func setLocalTestingMode(_ on: Bool) {
        guard !AccountConfig.isConfigured else { return }
        UserDefaults.standard.set(!on, forKey: localModeOptOutKey)
    }
    #else
    /// The RELEASE way in, from the honest beta screen. The mirror image of
    /// `setLocalTestingMode` above: entering is the deliberate act here, because
    /// an unconfigured release build must never reach the stand-in by itself —
    /// only a reader who has read what it is and tapped through it does.
    static func enterBetaLocalMode() {
        guard !AccountConfig.isConfigured else { return }
        UserDefaults.standard.set(true, forKey: betaLocalModeKey)
    }
    #endif

    /// Which of the two stand-in accounts is signing in. Two, because proving
    /// that one reader's diary cannot reach another reader's session needs two
    /// readers, and this is the only way to get them without a Supabase project.
    ///
    /// A release build never switches slots — `useTestAccount` stays a DEBUG-only
    /// tool in the prototype controls — so a beta tester's local account is
    /// always slot `a`.
    enum TestAccount: String, CaseIterable, Identifiable {
        case a, b

        var id: String { rawValue }
        var title: String { self == .a ? "Test account A" : "Test account B" }

        /// Fixed, so signing out and back in reaches the same account and the
        /// account-scoped store finds the same file.
        var userID: UUID {
            switch self {
            case .a: UUID(uuidString: "0A000000-0000-4000-8000-00000000000A")!
            case .b: UUID(uuidString: "0B000000-0000-4000-8000-00000000000B")!
            }
        }
    }

    private static let slotKey = "dewey.debug.localTestingMode.slot"

    static var testAccount: TestAccount {
        get { TestAccount(rawValue: UserDefaults.standard.string(forKey: slotKey) ?? "a") ?? .a }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: slotKey) }
    }

    /// Erases everything the stand-in has stored, for both slots, so the next
    /// launch is a genuine first launch.
    ///
    /// Not DEBUG-only: this is the other half of the RELEASE beta account's
    /// reset control (see `SessionStore.resetLocalBetaAccount`), alongside
    /// `DeweyStore.forgetActiveAccountData`.
    static func forgetAllLocalTestData() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("dewey.debug.local") {
            defaults.removeObject(forKey: key)
        }
    }
}

// MARK: - Local stand-ins

/// A local, on-device stand-in for a checkout with no Supabase project.
///
/// It exists so the first-run flow and the account-scoped local persistence of
/// §18 can be exercised before anyone has created a project — and, in RELEASE,
/// so a build with no project yet can still be handed to an external tester
/// instead of dead-ending on a developer screen. **It is testing
/// infrastructure, not a fallback**: it is constructed only when local mode has
/// been explicitly chosen — automatically in DEBUG, by a tap past the beta
/// screen in RELEASE — and a configured build never reaches it either way.
///
/// What it does not do, and what therefore cannot be concluded from it passing:
/// no cross-device uniqueness, no RLS, no real Apple identity, no multi-device
/// restore. Every one of those is a property of the server.
final class LocalAuthService: AuthService {
    private var signedInKey: String {
        "dewey.debug.local.signedIn.\(AccountServices.testAccount.rawValue)"
    }

    func restoreSession() async -> UUID? {
        guard UserDefaults.standard.bool(forKey: signedInKey) else { return nil }
        return AccountServices.testAccount.userID
    }

    func signInWithApple(_ credential: AppleCredential) async throws -> UUID {
        UserDefaults.standard.set(true, forKey: signedInKey)
        return AccountServices.testAccount.userID
    }

    func signOut() async {
        // The account survives sign-out on purpose — signing back in has to
        // reach the same account, or the sign-out/sign-in test proves nothing.
        // `AccountServices.forgetAllLocalTestData()` is what erases it.
        UserDefaults.standard.set(false, forKey: signedInKey)
    }
}

final class LocalProfileService: ProfileService {
    /// Computed rather than stored: `UserDefaults` is not `Sendable`, and this
    /// type has to be. `.standard` is the same object every time it is read.
    private var store: UserDefaults { .standard }

    private func key(_ suffix: String, _ userID: UUID) -> String {
        "dewey.debug.local.\(suffix).\(userID.uuidString)"
    }

    func profile(for userID: UUID) async throws -> AccountProfile? {
        guard let data = store.data(forKey: key("profile", userID)) else { return nil }
        return try? JSONDecoder().decode(AccountProfile.self, from: data)
    }

    func isHandleAvailable(_ candidate: String) async throws -> Bool {
        // Case-folded, matching the generated column the real index is on, so
        // the stand-in at least rejects what Postgres would reject.
        !claimedHandles().contains(Handle.normalize(candidate))
    }

    func createProfile(
        userID: UUID, displayName: String, handle: String
    ) async throws -> AccountProfile {
        guard try await isHandleAvailable(handle) else { throw AccountError.handleTaken }

        let profile = AccountProfile(
            userID: userID,
            displayName: displayName,
            handle: handle,
            accountSetupComplete: true,
            tasteOnboardingComplete: false,
            createdAt: Date()
        )
        try save(profile)
        store.set(claimedHandles() + [Handle.normalize(handle)], forKey: "dewey.debug.local.handles")
        return profile
    }

    func setTasteOnboardingComplete(userID: UUID) async throws {
        guard var profile = try await profile(for: userID) else { return }
        profile.tasteOnboardingComplete = true
        try save(profile)
    }

    func replaceFavoriteBooks(userID: UUID, bookIDs: [String]) async throws {
        store.set(Array(bookIDs.prefix(4)), forKey: key("favorites", userID))
    }

    func favoriteBooks(for userID: UUID) async throws -> [String] {
        store.stringArray(forKey: key("favorites", userID)) ?? []
    }

    func replaceSeedFollows(userID: UUID, readerIDs: [String]) async throws {
        store.set(readerIDs, forKey: key("follows", userID))
    }

    func seedFollows(for userID: UUID) async throws -> [String] {
        store.stringArray(forKey: key("follows", userID)) ?? []
    }

    private func claimedHandles() -> [String] {
        store.stringArray(forKey: "dewey.debug.local.handles") ?? []
    }

    private func save(_ profile: AccountProfile) throws {
        store.set(try JSONEncoder().encode(profile), forKey: key("profile", profile.userID))
    }
}
