import SwiftUI

/// Responding to a recommendation someone sent you.
///
/// Two choices at equal visual weight. "Not for me" is outlined rather than
/// buried in a menu, because a recommendation you can only accept is a demand,
/// and the whole design premise is that this interaction creates no debt.
///
/// After responding, the restrained social surface appears: one reaction and
/// one private reply. Not a comment thread — two people, inside one book.
struct RecommendationResponseRow: View {
    let recommendation: Recommendation
    @Environment(DeweyStore.self) private var store

    @State private var showingReply = false
    @State private var replyDraft = ""

    private var live: Recommendation {
        store.recommendation(recommendation.id) ?? recommendation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            switch live.status {
            case .waiting:
                HStack(spacing: Theme.Space.snug) {
                    Button("Save it") { accept() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Not for me") { store.respond(to: live.id, accept: false) }
                        .buttonStyle(QuietButtonStyle())
                }

            case .saved:
                statusLine(icon: "checkmark", text: "Saved to your library.")
                socialRow

            case .declined:
                // No apology, no "are you sure", no notification to the sender.
                // Declining is a normal outcome and is treated as one.
                statusLine(icon: "xmark", text: "Passed on this one.")

            case .startedByRecipient:
                statusLine(icon: "book", text: "You started it.")
                socialRow
            }

            if showingReply { replyField }
        }
    }

    // MARK: - Pieces

    private func statusLine(icon: String, text: String) -> some View {
        HStack(spacing: Theme.Space.tight) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.Palette.inkFaint)
            Text(text)
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }

    /// One reaction and one reply. Deliberately the smallest possible social
    /// vocabulary — but not zero, because a reader who will never write a review
    /// will still tap once to say "yes, this one", and banning that removes the
    /// quiet reader's only voice.
    private var socialRow: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            // Wraps. Three chips reading "Noted", "Already loved it" and
            // "Exactly right" do not fit one line inside a card that already
            // carries the page margin plus its own padding — on any iPhone, at
            // default type — so the row overflowed and the labels were cut. A
            // reaction whose name is truncated is not a reaction anyone can pick
            // with confidence.
            FlowLayout(spacing: Theme.Space.tight) {
                ForEach(Recommendation.Reaction.allCases) { reaction in
                    Button {
                        store.react(reaction, to: live.id)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: live.reaction == reaction
                                  ? "\(reaction.symbol).fill" : reaction.symbol)
                                .font(.caption)
                            Text(reaction.label)
                        }
                    }
                    .buttonStyle(ChipStyle(selected: live.reaction == reaction))
                    .accessibilityLabel(reaction.label)
                    .accessibilityAddTraits(live.reaction == reaction ? [.isSelected] : [])
                }
            }
            .font(Theme.TypeScale.meta())

            if let reply = live.reply {
                HStack(alignment: .top, spacing: Theme.Space.tight) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.caption2)
                        .foregroundStyle(Theme.Palette.inkFaint)
                    Text(reply)
                        .font(Theme.TypeScale.prose())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            } else if !showingReply {
                Button {
                    withAnimation(Theme.Motion.standard) { showingReply = true }
                } label: {
                    Text("Reply privately")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.accent)
                        // The one written response the product offers, at
                        // caption size: ~90x15pt of target before this.
                        .padding(.vertical, Theme.Space.snug)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var replyField: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            TextField("Just to them.", text: $replyDraft, axis: .vertical)
                .font(Theme.TypeScale.prose())
                .lineLimit(1...4)
                .padding(Theme.Space.snug)
                .background(Theme.Palette.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.Palette.rule, lineWidth: 1)
                )

            HStack {
                Button("Cancel") {
                    withAnimation(Theme.Motion.standard) { showingReply = false; replyDraft = "" }
                }
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkSoft)

                Spacer()

                Button("Send") {
                    store.reply(replyDraft, to: live.id)
                    withAnimation(Theme.Motion.standard) { showingReply = false; replyDraft = "" }
                }
                .font(Theme.TypeScale.ui())
                .foregroundStyle(replyDraft.isEmpty ? Theme.Palette.inkFaint : Theme.Palette.accent)
                .disabled(replyDraft.isEmpty)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func accept() {
        guard let sender = store.reader(live.fromReaderID) else { return }
        store.save(
            live.bookID,
            provenance: Provenance(
                origin: .person(readerID: sender.id, via: .directRecommendation),
                reason: live.reason.text,
                date: Date()
            )
        )
        store.respond(to: live.id, accept: true)
    }
}

// MARK: - Closure

/// "Someone started the book you recommended."
///
/// Dewey's signature social moment, and the direction matters: closure travels
/// to the *giver*, never the receiver. Told to the giver it is a gift — you were
/// useful to someone. Told to the receiver ("you started Elena's book, tell
/// her?") it would be a debt. Dewey never sends the second one.
///
/// It asks for nothing. There is no reply field, no reciprocal prompt, no
/// suggestion to send another. Dismissing it is the only action.
struct ClosureBanner: View {
    let recommendation: Recommendation
    @Environment(DeweyStore.self) private var store

    private var book: Book { store.book(recommendation.bookID) }
    private var recipient: ReaderProfile? { store.reader(recommendation.toReaderID) }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.snug) {
            if let recipient {
                ReaderAvatarView(reader: recipient, size: 36)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(recipient?.name.split(separator: " ").first.map(String.init) ?? "They") started it")
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)

                Text("\(book.title) — because you sent it.")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                store.dismissClosure()
            } label: {
                // The banner's only control, at ~23x23pt with `tight` padding.
                // An arriving gift the reader cannot reliably close is worse
                // than no banner.
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(-Theme.Space.snug)
            .accessibilityLabel("Dismiss")
        }
        .padding(Theme.Space.base)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Palette.rule, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 18, y: 6)
        .pageMargin()
        // Clears the navigation bar. Sitting flush to the safe area covered the
        // back button, so an arriving gift blocked you from leaving the screen.
        .padding(.top, 48)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
