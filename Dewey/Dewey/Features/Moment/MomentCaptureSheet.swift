import SwiftUI

/// Capturing a line while the book is still open.
///
/// One field, above the fold, and it is the only thing this sheet asks for.
/// The page number sits under it as a single optional tap-to-add row, not a
/// stepper demanding a number nobody has to hand — a reader mid-chapter on an
/// audiobook has no page at all, and the sheet has to be just as fast for them.
struct MomentCaptureSheet: View {
    let book: Book

    @Environment(DeweyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var textFocused: Bool

    @State private var text: String = ""
    @State private var hasPage = false
    @State private var page: Int = 1

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                header
                textField
                pageRow
                Spacer(minLength: 0)
            }
            .pageMargin()
            .padding(.top, Theme.Space.base)
            .background(Theme.Palette.paper)
            .navigationTitle("Capture a Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .presentationDragIndicator(.visible)
        .onAppear { textFocused = true }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Space.base) {
            BookCoverView(book: book, width: 44, scalesWithType: true)
            VStack(alignment: .leading, spacing: Theme.Space.hair) {
                Text(book.title)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A quote, or a thought — kept dated, exactly as it happened.")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var textField: some View {
        TextField("What caught you?", text: $text, axis: .vertical)
            .font(Theme.TypeScale.prose())
            .lineLimit(4...10)
            .focused($textFocused)
            .padding(Theme.Space.snug)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.Palette.rule, lineWidth: 1)
            )
    }

    private var pageRow: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Toggle(isOn: $hasPage.animation(Theme.Motion.standard)) {
                Text("Page number")
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.ink)
            }
            .tint(Theme.Palette.accent)

            if hasPage {
                Stepper(value: $page, in: 1...9999) {
                    Text("Page \(page)")
                        .font(Theme.TypeScale.support())
                        .foregroundStyle(Theme.Palette.ink)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .foregroundStyle(Theme.Palette.inkSoft)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }
                .font(Theme.TypeScale.ui())
                .foregroundStyle(Theme.Palette.accent)
                .disabled(trimmed.isEmpty)
        }
    }

    private func save() {
        store.captureMoment(bookID: book.id, text: text, pageNumber: hasPage ? page : nil)
        dismiss()
    }
}
