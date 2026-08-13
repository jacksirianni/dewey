import SwiftUI

/// Step three: choose what everyone else will call you.
///
/// Two fields, and they are not the same kind of thing. The **display name** is
/// yours and nobody else's business — it collides with anyone, it changes freely,
/// and it can be any script. The **handle** is an address: unique, case-folded,
/// ASCII, and the thing another reader retypes from memory or reads aloud. Asking
/// for both on one screen is what keeps the second from having to serve the first.
///
/// Avatar and bio are deliberately absent. Neither is needed to make a profile
/// legible — the four books do that — and a first run that asks for a photo
/// before it has shown what the app is for is asking for work in exchange for
/// nothing.
struct IdentitySetupView: View {
    let suggestedName: String?

    @Environment(SessionStore.self) private var session

    @State private var displayName = ""
    @State private var handle = ""
    @State private var availability: SessionStore.HandleAvailability = .unknown
    @State private var isChecking = false
    /// Set once, so a reader who clears the name field does not get Apple's
    /// suggestion typed back in underneath them.
    @State private var didPrefill = false

    var body: some View {
        FirstRunScaffold(
            footerTitle: session.isWorking ? "Saving…" : "Continue",
            footerDisabled: !canSubmit,
            footerAction: { Task { await submit() } }
        ) {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                // Not a counter. The taste steps that follow number themselves
                // "One of four" through "Four of four", and a second, shorter
                // count running alongside them would read as a progress bar
                // that resets.
                Text("Your profile").kickerStyle()
                Text("Who are you here?")
                    .font(Theme.TypeScale.title())
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Your name is what readers see. Your handle is how they find you.")
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            nameField
            handleField

            if let error = session.lastError {
                Text(error.localizedDescription)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            guard !didPrefill else { return }
            didPrefill = true
            // Apple's name is a starting point for both fields and an authority
            // for neither. It arrives only on a first authorization, so most
            // readers see two empty fields, which is a fine screen.
            if let suggestedName, displayName.isEmpty {
                displayName = suggestedName
                if handle.isEmpty, let guess = Handle.suggestion(from: suggestedName) {
                    handle = guess
                }
            }
        }
    }

    // MARK: - Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text("Display name").kickerStyle()
            TextField("Your name", text: $displayName)
                .font(Theme.TypeScale.ui())
                .foregroundStyle(Theme.Palette.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .padding(.vertical, Theme.Space.snug)
            Rule()
        }
    }

    // MARK: - Handle

    private var handleField: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text("Handle").kickerStyle()

            HStack(spacing: 0) {
                // Drawn rather than typed. The `@` is display everywhere in
                // Dewey and storage nowhere — it is not in the column and not
                // in the key uniqueness is judged on — so putting it in the
                // field's text would make it the one character a reader could
                // delete and break their own handle with.
                Text("@")
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .accessibilityHidden(true)

                TextField("handle", text: $handle)
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .accessibilityLabel("Handle")
                    .onChange(of: handle) { _, new in
                        let cleaned = Handle.sanitizeForEntry(new)
                        if cleaned != new { handle = cleaned }
                        availability = .unknown
                        session.clearError()
                    }

                Spacer(minLength: Theme.Space.snug)

                if isChecking {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.vertical, Theme.Space.snug)

            Rule()
            handleStatus
        }
        // Debounced by re-running whenever the text changes: a new keystroke
        // cancels the pending task, so the network sees one request per pause
        // rather than one per character.
        .task(id: handle) {
            availability = .unknown
            guard case .valid = Handle.validate(handle) else { return }

            isChecking = true
            defer { isChecking = false }

            do {
                try await Task.sleep(for: .milliseconds(400))
            } catch {
                return  // Superseded by the next keystroke.
            }
            availability = await session.handleAvailability(handle)
        }
    }

    /// One line under the field, and never more than one. Which sentence wins is
    /// the order a reader discovers the problem in: shape first (they can see
    /// what they typed), then availability (they cannot).
    @ViewBuilder
    private var handleStatus: some View {
        switch Handle.validate(handle) {
        case .empty:
            statusLine(
                "Letters, numbers, underscores and periods. \(Handle.minLength)–\(Handle.maxLength) characters.",
                tone: .quiet
            )
        case .invalid(let reason):
            statusLine(reason, tone: .problem)
        case .valid:
            switch availability {
            case .taken:
                statusLine("\(Handle.display(handle)) is taken. Try another.", tone: .problem)
            case .available:
                statusLine("\(Handle.display(handle)) is yours.", tone: .good)
            case .unknown:
                statusLine(isChecking ? "Checking…" : " ", tone: .quiet)
            }
        }
    }

    private enum Tone {
        case quiet, problem, good

        var color: Color {
            switch self {
            case .quiet: Theme.Palette.inkFaint
            case .problem: Theme.Palette.accent
            case .good: Theme.Palette.inkSoft
            }
        }
    }

    private func statusLine(_ text: String, tone: Tone) -> some View {
        Text(text)
            .font(Theme.TypeScale.meta())
            .foregroundStyle(tone.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Commit

    /// What the pinned footer needs to know. Availability being `.unknown` does
    /// **not** block: a failed check must not lock a reader out of their own
    /// account, and the unique index is the real referee — a collision comes
    /// back from the insert and returns them to this screen with the field
    /// intact.
    private var canSubmit: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Handle.validate(handle).isValid
            && availability != .taken
            && !session.isWorking
    }

    private func submit() async {
        await session.completeIdentity(displayName: displayName, handle: handle)
    }
}
