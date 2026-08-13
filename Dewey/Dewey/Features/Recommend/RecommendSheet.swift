import SwiftUI

/// Sending a book to one person, with a reason.
///
/// The design answer to "why not just text them?" is **specificity plus
/// persistence**: you pick one person, you say why *for them*, and the reason
/// stays attached to the book in their library for as long as they keep it. A
/// text message delivers the title and loses the reason within a day.
///
/// So: one recipient, never many. A reason is required — but the presets mean
/// requiring it costs a tap rather than a paragraph, which is how we get
/// quality without a blank page.
struct RecommendSheet: View {
    let book: Book
    @Environment(DeweyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var recipient: ReaderProfile?
    @State private var preset: Recommendation.Reason.Preset?
    @State private var written = ""
    @State private var sent = false

    private var reason: Recommendation.Reason? {
        let trimmed = written.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return .written(trimmed) }
        if let preset { return .preset(preset) }
        return nil
    }

    private var canSend: Bool { recipient != nil && reason != nil }

    var body: some View {
        NavigationStack {
            Group {
                if sent { confirmation } else { form }
            }
            .background(Theme.Palette.paper)
            .navigationTitle(sent ? "" : "Recommend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                        .foregroundStyle(Theme.Palette.inkSoft)
                }
                if !sent {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send") { send() }
                            .font(Theme.TypeScale.ui())
                            .foregroundStyle(canSend ? Theme.Palette.accent : Theme.Palette.inkFaint)
                            .disabled(!canSend)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.loose) {
                HStack(spacing: Theme.Space.base) {
                    BookCoverView(book: book, width: 56, scalesWithType: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(Theme.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(book.author)
                            .font(Theme.TypeScale.meta())
                            .foregroundStyle(Theme.Palette.inkSoft)
                    }
                    Spacer(minLength: 0)
                }
                .pageMargin()

                recipientSection
                reasonSection
            }
            .padding(.vertical, Theme.Space.base)
        }
        .scrollIndicators(.hidden)
    }

    /// One person. There is no multi-select and no "share to everyone" — a book
    /// sent to twelve people is a broadcast, and a broadcast carries none of the
    /// meaning that makes this worth doing.
    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("To").kickerStyle()

            VStack(spacing: 0) {
                ForEach(Array(store.readers.enumerated()), id: \.element.id) { index, reader in
                    Button {
                        withAnimation(Theme.Motion.standard) {
                            recipient = (recipient?.id == reader.id) ? nil : reader
                        }
                    } label: {
                        HStack(spacing: Theme.Space.snug) {
                            ReaderAvatarView(reader: reader, size: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(reader.name)
                                    .font(Theme.TypeScale.ui())
                                    .foregroundStyle(Theme.Palette.ink)
                                Text(reader.texture)
                                    .font(Theme.TypeScale.meta())
                                    .foregroundStyle(Theme.Palette.inkSoft)
                                    .lineLimit(1)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            if recipient?.id == reader.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.Palette.accent)
                            }
                        }
                        .padding(.vertical, Theme.Space.snug)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(recipient?.id == reader.id ? [.isSelected] : [])

                    if index < store.readers.count - 1 { Rule() }
                }
            }
        }
        .pageMargin()
    }

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("Why them").kickerStyle()

            Text("Required. It's the whole difference between this and sending a link.")
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkSoft)

            // Presets defeat the blank page. A product that only works for
            // people willing to write a paragraph is a product for a few.
            FlowLayout(spacing: Theme.Space.tight) {
                ForEach(Recommendation.Reason.Preset.allCases) { p in
                    Button(p.text) {
                        withAnimation(Theme.Motion.standard) {
                            preset = (preset == p) ? nil : p
                            if preset != nil { written = "" }
                        }
                    }
                    .buttonStyle(ChipStyle(selected: preset == p && written.isEmpty))
                }
            }
            .padding(.top, Theme.Space.tight)

            TextField("Or say it yourself.", text: $written, axis: .vertical)
                .font(Theme.TypeScale.prose())
                .lineLimit(2...5)
                .padding(Theme.Space.snug)
                .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.Palette.rule, lineWidth: 1))
                .onChange(of: written) { _, new in
                    if !new.isEmpty { preset = nil }
                }
                .padding(.top, Theme.Space.tight)
        }
        .pageMargin()
    }

    // MARK: - Confirmation

    /// Warm, brief, and asks for nothing further. No "send another", no share
    /// prompt, no counter.
    private var confirmation: some View {
        VStack(spacing: Theme.Space.base) {
            Spacer()

            BookCoverView(book: book, width: 96)

            VStack(spacing: Theme.Space.tight) {
                Text("On its way")
                    .font(Theme.TypeScale.title())
                    .foregroundStyle(Theme.Palette.ink)

                if let recipient {
                    Text("\(recipient.name) will see why you thought of them.")
                        .font(Theme.TypeScale.prose())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .pageMargin()
    }

    private func send() {
        guard let recipient, let reason else { return }
        store.send(bookID: book.id, to: recipient.id, reason: reason)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(Theme.Motion.gentle) { sent = true }
    }
}
