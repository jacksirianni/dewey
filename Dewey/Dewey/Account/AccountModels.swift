import Foundation

/// Who the signed-in reader is, as the server understands them.
///
/// **Deliberately not `ReaderProfile`.** That type is the product's idea of a
/// person — texture, accent colour, ratings, the chosen four — and most of it is
/// still local or seeded. This is the account: the handful of fields that exist
/// in Postgres, are owned by the authenticated user, and survive a reinstall.
/// `DeweyStore.me` is where the two are spliced together, and keeping them apart
/// means a change to one does not drag the other into the database.
struct AccountProfile: Codable, Hashable, Sendable, Identifiable {
    let userID: UUID
    var displayName: String
    /// Stored without the `@`, in the case the reader typed. `Handle.display`
    /// adds the `@` at every read site; `Handle.normalize` produces the key
    /// uniqueness is judged on.
    var handle: String
    /// Whether name and handle have been chosen. False for the window between
    /// the first successful Apple sign-in and the end of the identity step —
    /// a real state, because a reader can background the app inside it.
    var accountSetupComplete: Bool
    /// Whether the four taste steps have been run. **Server-side on purpose**:
    /// this is the flag that stops a second device treating a returning reader
    /// as brand new.
    var tasteOnboardingComplete: Bool
    var createdAt: Date

    var id: UUID { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case handle
        case accountSetupComplete = "account_setup_complete"
        case tasteOnboardingComplete = "taste_onboarding_complete"
        case createdAt = "created_at"
    }
}

/// What the app should be showing, as one value.
///
/// The old cold start had a single boolean (`DeweyStore.needsOnboarding`) because
/// there was only one question: has this device run onboarding. With accounts
/// there are three questions in sequence — is there a session, does it have an
/// identity, has it done the taste steps — and a boolean per question invites the
/// combination that should not exist (an identity with no session). One enum makes
/// the impossible states unrepresentable and gives `RootView` a single thing to
/// switch on.
enum AccountPhase: Equatable {
    /// No account system is available — no `SupabaseConfig.plist`, and nobody
    /// has explicitly opted into local test mode (§18). **A developer state, not
    /// a reader state.** It exists so that a missing configuration is something
    /// the app tells you rather than something it silently works around; the
    /// alternative it replaced was a stand-in that engaged on its own and let a
    /// developer believe they were exercising Supabase.
    case unconfigured
    /// Reading the keychain. The first paint of a relaunch, and the reason a
    /// signed-in reader never sees the sign-in screen flash past.
    case restoring
    case signedOut
    /// Authenticated, but no profile row yet — the name-and-handle step.
    /// `suggestedName` is what Apple handed back, which arrives **only on the
    /// very first authorization** for a given Apple ID and is empty forever
    /// after; it is a prefill, never a fallback.
    case needsIdentity(userID: UUID, suggestedName: String?)
    /// Identity chosen, taste steps outstanding.
    case needsTasteOnboarding(AccountProfile)
    case ready(AccountProfile)

    var profile: AccountProfile? {
        switch self {
        case .needsTasteOnboarding(let profile), .ready(let profile): profile
        case .unconfigured, .restoring, .signedOut, .needsIdentity: nil
        }
    }

    /// Whether the four tabs behind the cover should be interactive. Everything
    /// up to and including the taste steps is a full-screen cover.
    var isReady: Bool { if case .ready = self { return true }; return false }
}

/// What went wrong, in words a reader can act on.
///
/// Each case carries its own sentence rather than surfacing the underlying
/// error's `localizedDescription`, which for a network stack is either "The
/// operation couldn't be completed" or a paragraph about URLSession.
enum AccountError: LocalizedError, Equatable {
    case notConfigured
    case appleAuthorizationFailed
    case appleTokenMissing
    case handleTaken
    case handleInvalid(String)
    case network
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Dewey isn't connected to an account server yet."
        case .appleAuthorizationFailed:
            "Sign in with Apple didn't complete."
        case .appleTokenMissing:
            "Apple didn't return a usable token. Try again."
        case .handleTaken:
            "That handle is taken."
        case .handleInvalid(let reason):
            reason
        case .network:
            "Couldn't reach Dewey. Check your connection and try again."
        case .server(let message):
            message
        }
    }
}
