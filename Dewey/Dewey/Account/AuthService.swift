import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

/// What the Apple button hands back, reduced to the three things Supabase needs.
///
/// `fullName` is here because Apple returns it **only on the first authorization
/// for a given Apple ID** and never again — not on the second sign-in, not after
/// a reinstall. It is a prefill for the name field and nothing more; anything that
/// treated it as the source of truth would show a blank name to every returning
/// reader. The authority for a display name is the `profiles` row.
struct AppleCredential {
    let idToken: String
    /// The **raw** nonce. Apple is sent its SHA-256; Supabase is sent this, and
    /// checks that hashing it reproduces the `nonce` claim inside the token. Send
    /// the hash to both and every sign-in fails with a nonce mismatch.
    let rawNonce: String
    let fullName: PersonNameComponents?
}

/// Authentication, narrowed to what Dewey does.
///
/// **A protocol with one real implementation, on purpose.** Two reasons, both
/// present today rather than anticipated: an unconfigured debug build needs a
/// local stand-in so the first-run flow can be walked without a Supabase project
/// (see `AccountServices.live()`), and email — which is explicitly out of scope
/// now — arrives as a second method here rather than as a second code path
/// through `SessionStore`. It is not a database abstraction and should not grow
/// into one.
protocol AuthService: Sendable {
    /// The user id of a session restored from the keychain, or nil when signed
    /// out. Never throws: a relaunch with a dead network, an expired refresh
    /// token or a revoked Apple credential all mean the same thing to the app —
    /// show the sign-in screen — and distinguishing them would only give
    /// `SessionStore` a decision it has no better answer to.
    func restoreSession() async -> UUID?

    func signInWithApple(_ credential: AppleCredential) async throws -> UUID

    func signOut() async
}

// MARK: - Nonce

/// The replay protection Apple's flow requires.
///
/// The button is handed `sha256(raw)`; Apple embeds that in the identity token's
/// `nonce` claim; Supabase is handed `raw` and verifies the two agree. Generating
/// it per attempt is the point — a fixed nonce would make a captured token
/// reusable, which is the exact attack the claim exists to prevent.
enum SignInNonce {
    static func random(length: Int = 32) -> String {
        // Rejection-free: index into the alphabet rather than filtering random
        // bytes, so the loop always terminates and the distribution is uniform
        // over an alphabet whose size divides evenly into the drawn range.
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        guard status == errSecSuccess else {
            // SecRandom failing is not a condition an app can meaningfully
            // continue through, and silently substituting a weaker source would
            // defeat the nonce entirely.
            fatalError("Dewey: secure random unavailable (OSStatus \(status))")
        }
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Supabase

/// The real one.
///
/// Session persistence and refresh are the SDK's, not ours: `SupabaseClient`
/// defaults to keychain-backed storage on Apple platforms and refreshes access
/// tokens in the background. That is why `restoreSession` is a read rather than a
/// flow, and why nothing here writes a token anywhere.
struct SupabaseAuthService: AuthService {
    let client: SupabaseClient

    func restoreSession() async -> UUID? {
        do {
            // Asking for `session` rather than `currentSession` on purpose: this
            // refreshes an expired access token if the refresh token is still
            // good, which is the ordinary case for an app reopened days later.
            // `currentSession` would hand back the stale one.
            let session = try await client.auth.session
            return session.user.id
        } catch {
            // Includes `AuthError.sessionMissing` (never signed in, or signed
            // out) and a refresh token the server has revoked. Both are
            // "signed out" as far as the app is concerned.
            return nil
        }
    }

    func signInWithApple(_ credential: AppleCredential) async throws -> UUID {
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: credential.idToken,
                    nonce: credential.rawNonce
                )
            )
            return session.user.id
        } catch is URLError {
            throw AccountError.network
        } catch {
            throw AccountError.server(error.localizedDescription)
        }
    }

    func signOut() async {
        // Failure here is not worth surfacing or blocking on. `signOut` clears
        // the local session before it calls the server, so a reader on a dead
        // network is still signed out on this device — which is what they asked
        // for. Refusing to sign them out because a network call failed would be
        // the worse behaviour.
        try? await client.auth.signOut()
    }
}
