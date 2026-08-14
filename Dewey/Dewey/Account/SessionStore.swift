import Foundation
import Observation

/// Who is signed in, and what the app should therefore be showing.
///
/// **Beside `DeweyStore`, not inside it** (§17). The two answer different
/// questions and change for different reasons: `DeweyStore` owns what a reader has
/// read and thought, this owns who the reader is. Folding identity into the store
/// would have put a network call behind `store.me` — a property read on nearly
/// every screen — and made the whole product state unavailable until an
/// authentication round trip finished.
///
/// The phase machine is the whole interface. `RootView` switches on `phase` and
/// nothing else; every method below is a transition between phases.
@MainActor
@Observable
final class SessionStore {
    private(set) var phase: AccountPhase = .restoring

    /// The last thing that went wrong, for the screen that is up. Cleared on
    /// every new attempt so a stale message never sits under a fresh spinner.
    private(set) var lastError: AccountError?

    /// True while a sign-in or a profile write is in flight, so buttons can
    /// disable themselves rather than queueing a second identical request.
    private(set) var isWorking = false

    /// Rebuilt rather than injected once, because the backend can change at
    /// runtime: opting into local test mode in the debug menu has to swap both
    /// services without relaunching.
    private var auth: AuthService?
    private var profiles: ProfileService?

    init(auth: AuthService?, profiles: ProfileService?) {
        self.auth = auth
        self.profiles = profiles
    }

    convenience init() {
        let services = AccountServices.make()
        self.init(auth: services?.auth, profiles: services?.profiles)
    }

    /// Which account system is in use. Surfaced wherever a result could be
    /// mistaken for a real one.
    var backend: AccountBackend { AccountServices.backend }

    var isAvailable: Bool { auth != nil && profiles != nil }

    /// Swaps the backend and starts over from `.restoring`. The full reset is
    /// the point: carrying a session across a backend change would mean a
    /// profile fetched from one system displayed under the other.
    ///
    /// Not DEBUG-only: the RELEASE beta screen needs this exact swap — from
    /// `.unconfigured` (nil services) to the local stand-in — the moment a
    /// tester taps through it.
    func reloadServices() async {
        let services = AccountServices.make()
        auth = services?.auth
        profiles = services?.profiles
        lastError = nil
        phase = .restoring
        await restore()
    }

    // MARK: - Restoration

    /// Runs once, at launch, before anything is drawn.
    ///
    /// **The `.restoring` phase is not cosmetic.** Without it the app would open
    /// on the signed-out state and replace it a beat later for every returning
    /// reader — the sign-in screen flashing past on every cold launch, which
    /// reads as being logged out.
    func restore() async {
        // Distinct from signed-out, and deliberately not an error on a sign-in
        // screen: there is no account system to sign into, which is a fact about
        // the build rather than about the reader (§18).
        guard let auth, let profiles else {
            phase = .unconfigured
            return
        }

        guard let userID = await auth.restoreSession() else {
            phase = .signedOut
            return
        }

        do {
            guard let profile = try await profiles.profile(for: userID) else {
                // Authenticated with no profile row: the reader closed the app
                // between Apple returning and the handle being chosen. Apple
                // will not hand back the name a second time, so there is no
                // suggestion to offer.
                phase = .needsIdentity(userID: userID, suggestedName: nil)
                return
            }
            phase = route(profile)
        } catch {
            // A valid session whose profile could not be fetched — almost
            // always the network. Signing the reader out here would be wrong:
            // the session is fine, and they would lose the app over a bad
            // connection. Hold them at identity with the error showing, which
            // is recoverable by retrying.
            phase = .needsIdentity(userID: userID, suggestedName: nil)
            lastError = error as? AccountError ?? .network
        }
    }

    /// Where a fetched profile sends the reader.
    ///
    /// **Reads `account_setup_complete` rather than inferring it from the row
    /// existing.** The two agree today — `createProfile` writes the row and the
    /// flag in one statement — but the column defaults to false exactly so that
    /// a row arriving by any other route sends the reader back through identity
    /// setup instead of into the app with a half-made account. Verified against
    /// Postgres: a `profiles` row inserted without the flag reads back
    /// incomplete, and this is what makes that mean something.
    private func route(_ profile: AccountProfile) -> AccountPhase {
        guard profile.accountSetupComplete else {
            return .needsIdentity(userID: profile.userID, suggestedName: profile.displayName)
        }
        return profile.tasteOnboardingComplete ? .ready(profile) : .needsTasteOnboarding(profile)
    }

    // MARK: - Sign in

    func signInWithApple(_ credential: AppleCredential) async {
        guard let auth, let profiles else { lastError = .notConfigured; return }

        lastError = nil
        isWorking = true
        defer { isWorking = false }

        do {
            let userID = try await auth.signInWithApple(credential)

            if let profile = try await profiles.profile(for: userID) {
                // A returning reader. Straight past the identity step — their
                // name and handle are already chosen, on this device or another.
                phase = route(profile)
            } else {
                phase = .needsIdentity(
                    userID: userID,
                    suggestedName: credential.fullName.map {
                        PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
                    }?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            }
        } catch {
            lastError = error as? AccountError ?? .server(error.localizedDescription)
        }
    }

    /// The Apple sheet failed before there was anything to send Supabase — no
    /// identity token, or an authorization that errored for a reason other than
    /// the reader cancelling. Separate from `signInWithApple` because there is no
    /// credential to attempt anything with.
    func signInFailed(_ error: AccountError) {
        lastError = error
    }

    /// Called as the reader edits a field that a message refers to. A rejection
    /// sitting under text that has since changed is worse than no message.
    func clearError() {
        lastError = nil
    }

    /// Reported to the reader while they type. Errors are swallowed to
    /// `.unknown` rather than shown: a failed availability check must not
    /// look like a rejected handle, and the insert is the real referee anyway.
    func handleAvailability(_ candidate: String) async -> HandleAvailability {
        guard let profiles else { return .unknown }
        guard case .valid(let normalized) = Handle.validate(candidate) else { return .unknown }
        do {
            return try await profiles.isHandleAvailable(normalized) ? .available : .taken
        } catch {
            return .unknown
        }
    }

    enum HandleAvailability: Equatable {
        case available, taken, unknown
    }

    // MARK: - Identity

    /// Writes the profile row. Returns whether it landed, so the view can stay
    /// put and keep the reader's typing when it did not.
    @discardableResult
    func completeIdentity(displayName: String, handle: String) async -> Bool {
        guard let profiles else { lastError = .notConfigured; return false }
        guard case .needsIdentity(let userID, _) = phase else { return false }

        guard case .valid(let normalized) = Handle.validate(handle) else {
            lastError = .handleInvalid("That handle isn't valid.")
            return false
        }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            lastError = .handleInvalid("A display name is required.")
            return false
        }

        lastError = nil
        isWorking = true
        defer { isWorking = false }

        do {
            // The handle is stored as typed so `@JackS` displays as `@JackS`;
            // `normalized` is only used to prove it validated.
            _ = normalized
            let stored = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
            let profile = try await profiles.createProfile(
                userID: userID, displayName: name, handle: stored
            )
            phase = .needsTasteOnboarding(profile)
            return true
        } catch {
            lastError = error as? AccountError ?? .server(error.localizedDescription)
            return false
        }
    }

    // MARK: - Taste onboarding

    /// Called at the end of the four taste steps, with what the reader chose.
    ///
    /// **The phase advances even when the writes fail.** A reader who has just
    /// spent four screens picking books must not be held on the last one because
    /// the network dropped — their choices are already committed locally by
    /// `DeweyStore`, which remains the authority for them. The failure is
    /// recorded in `lastError` and the server catches up the next time these are
    /// edited. What is lost in that case is multi-device restore, which this
    /// stage does not promise.
    func completeTasteOnboarding(favoriteBooks: [String], seedFollows: [String]) async {
        guard let profiles, var profile = phase.profile else { return }

        do {
            try await profiles.replaceFavoriteBooks(userID: profile.userID, bookIDs: favoriteBooks)
            try await profiles.replaceSeedFollows(userID: profile.userID, readerIDs: seedFollows)
            try await profiles.setTasteOnboardingComplete(userID: profile.userID)
        } catch {
            lastError = error as? AccountError ?? .network
        }

        profile.tasteOnboardingComplete = true
        phase = .ready(profile)
    }

    /// Pushes an edit made after onboarding — the profile four, or a follow
    /// toggled on a reader's page. Fire-and-forget by design: these are already
    /// saved locally and a failure must never block the tap.
    /// Gated on `.ready` rather than on having a profile, so the taste steps —
    /// which toggle follows and the chosen four repeatedly — do not put a
    /// request on the wire per tap. `completeTasteOnboarding` sends the settled
    /// answer once, at the end.
    func pushFavoriteBooks(_ bookIDs: [String]) {
        guard let profiles, case .ready(let profile) = phase else { return }
        Task { try? await profiles.replaceFavoriteBooks(userID: profile.userID, bookIDs: bookIDs) }
    }

    func pushSeedFollows(_ readerIDs: [String]) {
        guard let profiles, case .ready(let profile) = phase else { return }
        Task { try? await profiles.replaceSeedFollows(userID: profile.userID, readerIDs: readerIDs) }
    }

    /// What the server holds for this account, for a device that has just signed
    /// in. Nil when there is nothing to apply or the fetch failed — the caller
    /// leaves local state alone in both cases rather than clearing it.
    func remoteState() async -> (favoriteBooks: [String], seedFollows: [String])? {
        guard let profiles, let profile = phase.profile else { return nil }
        do {
            return (
                try await profiles.favoriteBooks(for: profile.userID),
                try await profiles.seedFollows(for: profile.userID)
            )
        } catch {
            return nil
        }
    }

    /// Throws away the local stand-in account so the next launch is a genuine
    /// first launch. Does nothing when a Supabase project is configured — there
    /// is no safe local equivalent of deleting a server-side account, and
    /// pretending otherwise would be the kind of affordance that quietly lies.
    ///
    /// Not DEBUG-only: this is what both the DEBUG prototype controls'
    /// "Forget all local test accounts" and Profile's RELEASE-reachable "Reset
    /// beta account" call — one function, so the two surfaces cannot drift
    /// apart on what a reset actually does. `DeweyStore.forgetActiveAccountData`
    /// is the other half; callers are expected to call both.
    func forgetLocalAccount() {
        guard AccountServices.backend == .localTesting else { return }
        AccountServices.forgetAllLocalTestData()
        lastError = nil
        phase = .signedOut
    }

    #if DEBUG
    /// Sends a signed-in reader back through the four taste steps.
    ///
    /// The debug menu's world switch used to be how onboarding got re-run: it
    /// set `DeweyStore.needsOnboarding`, which was what the cover watched. The
    /// cover now watches this phase machine, so that lever moves nothing and
    /// this is the replacement. Local only — it does not clear
    /// `taste_onboarding_complete` on the server, so the next launch comes back
    /// `.ready` unless the steps are finished again.
    func replayTasteOnboarding() {
        guard let profile = phase.profile else { return }
        phase = .needsTasteOnboarding(profile)
    }

    /// Switches which stand-in account signs in next, and drops the current
    /// session so the switch takes effect. Sign out first — this does not
    /// silently end a session that is already open.
    func useTestAccount(_ account: AccountServices.TestAccount) async {
        AccountServices.testAccount = account
        await reloadServices()
    }
    #endif

    // MARK: - Sign out

    /// Ends the session. **Local reading data is deliberately untouched** — the
    /// library, diary, ratings, rankings and lists all stay on the device. A
    /// reader who signs out to try another account and signs back in has not
    /// lost years of reading, and nothing in this stage syncs that data anywhere
    /// it could be recovered from if we deleted it. Erasing it is a separate,
    /// explicitly confirmed action; see `DebugActions.eraseEverything`.
    func signOut() async {
        await auth?.signOut()
        lastError = nil
        phase = .signedOut
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
