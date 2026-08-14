import AuthenticationServices
import SwiftUI

/// Step two: prove who you are.
///
/// **Sign in with Apple, natively, and nothing else** (§17). `SignInWithAppleButton`
/// presents the system sheet in-process — Face ID and a confirmation, no web
/// view, no redirect, no `ASWebAuthenticationSession`. A browser-based OAuth
/// round trip would work and is what the Supabase quickstart shows; it is also a
/// worse first impression than the sheet every other iOS app uses, and it puts a
/// Safari chrome bar between a stranger and the second screen of the product.
///
/// **One provider on purpose.** Email is a second method on `AuthService` when it
/// is wanted, not a second code path through `SessionStore`; nothing here is
/// shaped around Apple specifically except the button and the nonce.
struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.colorScheme) private var colorScheme

    /// Regenerated for every attempt. Apple is handed its SHA-256 and embeds
    /// that in the token's `nonce` claim; Supabase is handed this and checks the
    /// two agree. A nonce reused across attempts would make a captured token
    /// replayable, which is the whole thing the claim is for.
    @State private var rawNonce = SignInNonce.random()

    var body: some View {
        FirstRunScaffold {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                Text("Your account").kickerStyle()
                Text("Sign in to keep it.")
                    .font(Theme.TypeScale.title())
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    """
                    Dewey is built on other people's taste, so it needs to know \
                    whose taste is yours. Your scores, your four, and the readers \
                    you follow travel with the account.
                    """
                )
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            }

            #if DEBUG
            if session.backend == .localTesting {
                localTestingMode
            } else {
                appleButton
            }
            #else
            if session.backend == .localTesting {
                betaLocalMode
            } else {
                appleButton
            }
            #endif

            if let error = session.lastError {
                Text(error.localizedDescription)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Dewey never posts anything and never reads your contacts.")
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Apple

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            // A fresh nonce per press, hashed on the way to Apple.
            let nonce = SignInNonce.random()
            rawNonce = nonce
            // `.email` is requested alongside the name so `auth.users` carries an
            // address — it costs the reader nothing extra on a sheet they are
            // already reading, and it is what makes adding email sign-in later a
            // provider change rather than an account-merge problem. Neither is
            // stored in `profiles`; the display name is a prefill and the address
            // never leaves the auth schema.
            request.requestedScopes = [.fullName, .email]
            request.nonce = SignInNonce.sha256(nonce)
        } onCompletion: { result in
            handle(result)
        }
        // The system button, in the system's two permitted colourways. Dewey's
        // palette does not get a say here: Apple's Human Interface Guidelines
        // specify the mark, the corner radius and the two fills, and a
        // restyled button is a review rejection.
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 50)
        .disabled(session.isWorking)
        .opacity(session.isWorking ? 0.5 : 1)
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                Task { await session.signInFailed(.appleTokenMissing) }
                return
            }

            let apple = AppleCredential(
                idToken: idToken,
                rawNonce: rawNonce,
                // Present only on the very first authorization for this Apple ID.
                // Nil on every subsequent one, which is correct and not an error.
                fullName: credential.fullName
            )
            Task { await session.signInWithApple(apple) }

        case .failure(let error):
            // Cancelling is not a failure and must not leave a red sentence on
            // the screen — the reader closed a sheet they opened.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            Task { await session.signInFailed(.appleAuthorizationFailed) }
        }
    }

    // MARK: - Local testing

    #if DEBUG
    /// **The Sign in with Apple button is deliberately not drawn in this mode.**
    /// Local testing does not use Apple's identity for anything — the stand-in
    /// ignores the credential entirely — so offering the real button would imply
    /// the resulting account had something to do with Apple. It does not, and
    /// the point of this mode being explicit (§18) is that nothing about it
    /// should be mistakable for the real path.
    private var localTestingMode: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            LocalTestingBanner()

            Button("Sign in as \(AccountServices.testAccount.title)") {
                Task {
                    await session.signInWithApple(
                        AppleCredential(idToken: "local-test", rawNonce: rawNonce, fullName: nil)
                    )
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(session.isWorking)

            Text("Switch accounts, or leave this mode, in the prototype controls.")
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    #else
    /// The RELEASE counterpart of `localTestingMode` above, for a tester who
    /// tapped through the beta screen: same reasoning about not showing Apple's
    /// button for an identity the stand-in ignores entirely, but in plain
    /// language rather than the developer terms (`Row Level Security`, "Test
    /// account A") DEBUG uses, and with no mention of the prototype controls —
    /// there are none reachable in this build.
    private var betaLocalMode: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            BetaLocalBanner()

            Button("Continue as a beta tester") {
                Task {
                    await session.signInWithApple(
                        AppleCredential(idToken: "local-test", rawNonce: rawNonce, fullName: nil)
                    )
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(session.isWorking)
        }
    }
    #endif
}

#if DEBUG
/// Says, wherever it is placed, that nothing on screen came from a server.
///
/// Drawn in the accent rather than a quiet grey on purpose: the failure this
/// mode exists to prevent is a developer forgetting which backend they are on,
/// and a caption that blends into the page is exactly how that happens.
struct LocalTestingBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.tight) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Local test accounts \u{2014} not Supabase")
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.ink)
                Text("Nothing here reaches a server. Handles are unique on this device only, and there is no Row Level Security to exercise.")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Space.snug)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Palette.accent, lineWidth: 1)
        )
    }
}
#else
/// The RELEASE counterpart of `LocalTestingBanner`, in plain language for a
/// beta tester rather than developer terms for a developer.
struct BetaLocalBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.tight) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Beta account \u{2014} this device only")
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.ink)
                Text("There's no account server behind this yet, so nothing you do here reaches one. Your account, your library and everything you log stay on this device.")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Space.snug)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Palette.accent, lineWidth: 1)
        )
    }
}
#endif
