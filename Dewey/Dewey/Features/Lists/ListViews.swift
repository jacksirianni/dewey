import SwiftUI
import UIKit

// MARK: - List detail

/// A list, read as an argument rather than a folder.
///
/// The premise sits directly under the title in prose, because the premise is
/// the reason the list exists. Ordered lists get a numbered gutter — a position is a
/// claim, and a claim deserves to be legible from across the room.
struct ListDetailView: View {
    let list: BookList

    @Environment(DeweyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    @State private var showAddBooks = false

    /// The store is the authority — the pushed value goes stale the moment the
    /// editor saves.
    private var live: BookList {
        store.list(list.id) ?? list
    }

    private var owner: ReaderProfile? {
        live.ownerID == "me" ? store.me : store.reader(live.ownerID)
    }

    private var isMine: Bool { live.ownerID == "me" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.roomy) {
                header
                coverFan
                Rule().pageMargin()
                bookSection
            }
            .padding(.top, Theme.Space.snug)
            .padding(.bottom, Theme.Space.vast)
        }
        .background(Theme.Palette.paper)
        .navigationTitle(live.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showEditor) {
            ListEditorSheet(list: live, onDeleted: { dismiss() })
        }
        .sheet(isPresented: $showAddBooks) {
            AddBooksSheet(listID: live.id)
        }
    }

    /// **Two controls, not one, for the owner** (§21). "Edit" alone meant the
    /// fast path to adding books was the editor's own footer — "Add them from
    /// a book page" — which sent the reader who wanted to add three books to
    /// a list on a trip through Search three separate times. Add is the verb a
    /// reader reaches for on nearly every visit; Edit is for the rarer
    /// business of renaming, reordering and removing. Splitting them puts the
    /// common case one tap away instead of behind the rare one.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isMine {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditor = true }
                    .font(Theme.TypeScale.ui())
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddBooks = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add books")
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text(live.isOrdered ? Vocabulary.orderedList : Vocabulary.list)
                .kickerStyle()

            Text(live.title)
                .font(Theme.TypeScale.display())
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !live.premise.isEmpty {
                Text(live.premise)
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Theme.Space.hair)
            }

            ProvenanceLine(text: ownerLine, reader: owner)
                .padding(.top, Theme.Space.tight)

            Text(live.subtitle)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
    }

    private var ownerLine: String {
        if isMine { return "Yours" }
        guard let owner else { return "A list on Dewey" }
        return "Kept by \(owner.name)"
    }

    // MARK: Cover fan

    private var fanBooks: [Book] {
        live.bookIDs.prefix(5).map { store.book($0) }
    }

    @ViewBuilder
    private var coverFan: some View {
        if !fanBooks.isEmpty {
            HStack(spacing: -Theme.Space.roomy) {
                ForEach(Array(fanBooks.enumerated()), id: \.element.id) { index, book in
                    BookCoverView(book: book, width: 82)
                        .rotationEffect(.degrees(Double(index) * 1.4 - 2.8))
                        .zIndex(Double(fanBooks.count - index))
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, Theme.Space.margin)
            .padding(.vertical, Theme.Space.tight)
            .accessibilityHidden(true)
        }
    }

    // MARK: Books

    @ViewBuilder
    private var bookSection: some View {
        if live.items.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                if let attribution = ratingAttribution {
                    Text(attribution)
                        .kickerStyle()
                        .pageMargin()
                }
                ForEach(Array(live.items.enumerated()), id: \.element.id) { index, item in
                    row(for: item, position: index + 1)
                    if item.id != live.items.last?.id {
                        Rule().pageMargin()
                    }
                }
            }
        }
    }

    private var ratingAttribution: String? {
        guard let owner, !isMine else { return nil }
        let anyRated = live.bookIDs.contains { owner.ratings[$0] != nil }
        guard anyRated else { return nil }
        let first = owner.name.split(separator: " ").first.map(String.init) ?? owner.name
        return "Marks are \(first)'s"
    }

    private func row(for item: BookList.Item, position: Int) -> some View {
        let book: Book = store.book(item.bookID)
        return NavigationLink(value: book) {
            ListBookRow(
                book: book,
                position: live.isOrdered ? position : nil,
                rating: rating(for: item.bookID),
                note: item.note,
                isFavorite: isMine && store.isFavorite(item.bookID)
            )
        }
        .buttonStyle(.plain)
    }

    private func rating(for bookID: String) -> Rating? {
        if isMine { return store.myRating(for: bookID) }
        guard let value = owner?.ratings[bookID] else { return nil }
        return Rating(value)
    }

    /// **A real affordance, not a pointer to one** (§21). It read "Open any
    /// book and choose Add to list" — accurate, and the one route it named
    /// was three taps and a full-screen departure from the list the reader
    /// was just looking at. Search/add now happens in a sheet over this
    /// screen, so the empty state can offer the actual button instead of
    /// directions to a different one.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text("Nothing in it yet")
                .font(Theme.TypeScale.cardTitle())
                .foregroundStyle(Theme.Palette.ink)
            Text(isMine
                 ? "A list needs books before it can argue anything."
                 : "The premise is here; the books are still coming.")
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if isMine {
                Button {
                    showAddBooks = true
                } label: {
                    Label("Add books", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 220, alignment: .leading)
                .padding(.top, Theme.Space.snug)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
    }
}

// MARK: - One book in a list

private struct ListBookRow: View {
    let book: Book
    let position: Int?
    let rating: Rating?
    let note: String?
    let isFavorite: Bool

    /// The ordered list's numbered gutter, scaled. At a fixed 32pt a `.title`
    /// serif numeral clipped from around position 10 at accessibility sizes, on
    /// the one column whose entire job is to state the claim the list is making.
    /// `minimumScaleFactor` is the second half: a three-digit position in a
    /// long ordered list stays inside the gutter instead of pushing the cover.
    @ScaledMetric(relativeTo: .title) private var positionColumn: CGFloat = 32

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.base) {
            if let position {
                Text("\(position)")
                    .font(Theme.TypeScale.title().monospacedDigit())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: positionColumn, alignment: .leading)
                    .accessibilityLabel("Number \(position)")
            }

            BookCoverView(book: book, width: 58, scalesWithType: true)

            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(book.title)
                    .font(Theme.TypeScale.cardTitle())
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.subtitleLine)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .lineLimit(2)

                markLine

                if let note, !note.isEmpty {
                    Text(note)
                        .font(Theme.TypeScale.prose())
                        .italic()
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Theme.Space.hair)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .pageMargin()
    }

    /// The numeral alone. An ordered list row can already carry a 32pt position
    /// numeral in the left column, so the rules plus a second figure gave one
    /// row three numeric objects fighting over a single 58pt cover and an
    /// italic note. The rating stays — a list *is* a comparison, and the kicker
    /// overhead tells you whose marks these are — but 66pt of rules that cannot
    /// resolve a tenth is the part that was not earning its width.
    ///
    /// Dropping the rules also fixes a VoiceOver double-read: the mark spoke
    /// `rating.spoken` and the loose numeral beside it spoke again. One element
    /// now, carrying the full "8.3 out of 10".
    @ViewBuilder
    private var markLine: some View {
        if rating != nil || isFavorite {
            HStack(spacing: Theme.Space.tight) {
                if let rating {
                    RatingMark(rating: rating)
                }
                if isFavorite {
                    FavoriteMark(filled: true, size: 13)
                }
            }
            .padding(.top, Theme.Space.hair)
        }
    }
}

// MARK: - Editor

/// Editing a list is editing an argument: the premise gets as much room as the
/// title, and the per-book note is a first-class field rather than a hidden
/// detail.
struct ListEditorSheet: View {
    let list: BookList
    var onDeleted: (() -> Void)? = nil

    @Environment(DeweyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: BookList
    @State private var editMode: EditMode = .inactive
    @State private var confirmingDelete = false

    init(list: BookList, onDeleted: (() -> Void)? = nil) {
        self.list = list
        self.onDeleted = onDeleted
        _draft = State(initialValue: list)
    }

    var body: some View {
        NavigationStack {
            List {
                premiseSection
                shapeSection
                itemsSection
                deleteSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.paper)
            .environment(\.editMode, $editMode)
            .navigationTitle("Edit list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { editorToolbar }
            .confirmationDialog(
                "Delete this list?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete list", role: .destructive) { deleteList() }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("The books stay in your library. The argument goes.")
            }
        }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .font(Theme.TypeScale.ui())
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }
                .font(Theme.TypeScale.ui())
                .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: Fields

    private var premiseSection: some View {
        Section {
            TextField("Title", text: $draft.title, axis: .vertical)
                .font(Theme.TypeScale.cardTitle())
                .foregroundStyle(Theme.Palette.ink)

            TextField("What is this list arguing?", text: $draft.premise, axis: .vertical)
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(2...6)
        } header: {
            Text("The list").kickerStyle()
        } footer: {
            Text("A premise turns a pile of books into a list worth arguing with.")
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
        }
        .listRowBackground(Theme.Palette.card)
    }

    private var shapeSection: some View {
        Section {
            Toggle(isOn: $draft.isOrdered) {
                VStack(alignment: .leading, spacing: Theme.Space.hair) {
                    Text("Ordered")
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.ink)
                    Text("Order becomes a claim.")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                }
            }

            Toggle(isOn: $draft.isPublic) {
                VStack(alignment: .leading, spacing: Theme.Space.hair) {
                    Text("Visible to others")
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.ink)
                    Text(draft.isPublic ? "Readers who follow you can find it." : "Only you.")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                }
            }
        } header: {
            Text("How it reads").kickerStyle()
        }
        .listRowBackground(Theme.Palette.card)
    }

    // MARK: Items

    private var itemsSection: some View {
        Section {
            if draft.items.isEmpty {
                Text("No books yet. Add them from a book page.")
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.inkSoft)
            } else {
                ForEach(draft.items) { item in
                    itemRow(item)
                        .moveDisabled(!draft.isOrdered)
                }
                .onMove { from, to in
                    draft.items.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    draft.items.remove(atOffsets: offsets)
                }
            }
        } header: {
            HStack {
                Text("Books").kickerStyle()
                Spacer()
                if !draft.items.isEmpty {
                    Button {
                        withAnimation(Theme.Motion.standard) {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    } label: {
                        // Kicker-sized text in a section header: ~16pt tall.
                        Text(editMode == .active ? "Done" : "Reorder")
                            .font(Theme.TypeScale.kicker())
                            .textCase(nil)
                            .foregroundStyle(Theme.Palette.accent)
                            .padding(.vertical, Theme.Space.snug)
                            .padding(.leading, Theme.Space.base)
                            .frame(minHeight: 44, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!draft.isOrdered)
                }
            }
        } footer: {
            Text(draft.isOrdered
                 ? "Drag to change the order. Swipe a row to remove it."
                 : "Swipe a row to remove it.")
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
        }
        .listRowBackground(Theme.Palette.card)
    }

    /// No rating on an editor row. The reader here is arranging an argument —
    /// dragging order, typing "Why this one?" into a live field on every line —
    /// and a valuation is not an input to that. It was also the third thing
    /// competing for one 34pt row alongside the author and an open text field.
    private func itemRow(_ item: BookList.Item) -> some View {
        let book: Book = store.book(item.bookID)
        return HStack(alignment: .top, spacing: Theme.Space.snug) {
            if draft.isOrdered, let index = index(of: item.id) {
                Text("\(index + 1)")
                    .font(Theme.TypeScale.cardTitle().monospacedDigit())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .frame(width: 22, alignment: .leading)
            }

            BookCoverView(book: book, width: 34)

            VStack(alignment: .leading, spacing: Theme.Space.hair) {
                Text(book.title)
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)

                Text(book.author)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .lineLimit(1)

                TextField("Why this one?", text: noteBinding(itemID: item.id), axis: .vertical)
                    .font(Theme.TypeScale.prose())
                    .italic()
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .lineLimit(1...4)
            }
        }
        .padding(.vertical, Theme.Space.hair)
    }

    private func index(of itemID: String) -> Int? {
        draft.items.firstIndex { $0.id == itemID }
    }

    private func noteBinding(itemID: String) -> Binding<String> {
        Binding(
            get: { draft.items.first { $0.id == itemID }?.note ?? "" },
            set: { newValue in
                guard let i = draft.items.firstIndex(where: { $0.id == itemID }) else { return }
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                draft.items[i].note = trimmed.isEmpty ? nil : newValue
            }
        )
    }

    // MARK: Destructive

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Text("Delete list")
                    .font(Theme.TypeScale.ui())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .listRowBackground(Theme.Palette.card)
    }

    // MARK: Actions

    private func save() {
        var updated: BookList = draft
        updated.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.premise = draft.premise.trimmingCharacters(in: .whitespacesAndNewlines)
        store.updateList(updated)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func deleteList() {
        store.deleteList(draft.id)
        dismiss()
        onDeleted?()
    }
}

// MARK: - Add books to a list

/// **The other half of "Add to list"** (§21).
///
/// `AddToListSheet` answers "which lists does this one book belong to?",
/// reached from a book page. This answers the opposite question — "which
/// books belong in this list?" — reached from the list itself, and it is the
/// one Dewey never offered: building a list of five meant opening Search five
/// times, each trip ending on a different book page's "Add to list" sheet.
///
/// Search-as-you-type over `store.listCandidates`, which puts the reader's
/// own library first — the ordinary case, since a list is usually assembled
/// out of books already read or shelved — and everything else behind it. A
/// tap adds or removes immediately; there is no separate "Done" step for the
/// add itself; the toolbar button is only there to close the sheet.
struct AddBooksSheet: View {
    let listID: String

    @Environment(DeweyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var live: BookList? { store.list(listID) }

    private var results: [Book] {
        store.listCandidates(excluding: live?.bookIDs ?? [], query: query)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let live, !live.items.isEmpty {
                        addedStrip(live)
                    }
                    resultsList
                }
                .padding(.vertical, Theme.Space.base)
            }
            .background(Theme.Palette.paper)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Title, author, series")
            .navigationTitle("Add books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.TypeScale.ui())
                }
            }
        }
    }

    /// What is already in, as a confirmation rail — a reader adding a fifth
    /// book wants to see the four that landed, not just trust that they did.
    private func addedStrip(_ live: BookList) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("Already in \(live.title)").kickerStyle()
                .pageMargin()
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Space.tight) {
                    ForEach(live.bookIDs, id: \.self) { id in
                        BookCoverView(book: store.book(id), width: 46, scalesWithType: true)
                    }
                }
                .padding(.horizontal, Theme.Space.margin)
            }
            .scrollIndicators(.hidden)
            Rule().pageMargin().padding(.top, Theme.Space.snug)
        }
        .padding(.bottom, Theme.Space.base)
    }

    @ViewBuilder
    private var resultsList: some View {
        if results.isEmpty {
            Text(query.isEmpty
                 ? "Nothing left to add — every book Dewey knows is already on this list."
                 : "No matches for “\(query)”.")
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .pageMargin()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if query.isEmpty {
                    Text("Your books first").kickerStyle()
                        .pageMargin()
                        .padding(.bottom, Theme.Space.snug)
                }
                ForEach(results) { book in
                    candidateRow(book)
                    if book.id != results.last?.id { Rule().pageMargin() }
                }
            }
        }
    }

    private func candidateRow(_ book: Book) -> some View {
        Button {
            add(book)
        } label: {
            HStack(spacing: Theme.Space.snug) {
                BookCoverView(book: book, width: 40)
                VStack(alignment: .leading, spacing: Theme.Space.hair) {
                    Text(book.title)
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(2)
                    Text(book.subtitleLine)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus.circle")
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.accent)
            }
            .padding(.vertical, Theme.Space.snug)
            .pageMargin()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(book.title) by \(book.author)")
    }

    private func add(_ book: Book) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(Theme.Motion.standard) {
            store.addToList(listID, bookID: book.id)
        }
    }
}

// MARK: - Add to list

/// Putting a book somewhere is a small act of curation, so the sheet leads with
/// making a *new* list rather than burying it under the existing ones.
struct AddToListSheet: View {
    let book: Book

    @Environment(DeweyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var composing = false
    @State private var newTitle = ""
    @State private var newPremise = ""
    @State private var newIsOrdered = false
    @State private var newIsPublic = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.base) {
                    bookLine
                    Rule()
                    newListBlock
                    Rule()
                    listsBlock
                }
                .pageMargin()
                .padding(.vertical, Theme.Space.base)
            }
            .background(Theme.Palette.paper)
            .navigationTitle("Add to a list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.TypeScale.ui())
                }
            }
        }
    }

    /// One book, confirming which one. No rating: nothing on this line is being
    /// compared with anything, so the number can only answer a question the
    /// reader did not ask on the way to picking a list.
    private var bookLine: some View {
        HStack(alignment: .center, spacing: Theme.Space.base) {
            BookCoverView(book: book, width: 46, scalesWithType: true)
            VStack(alignment: .leading, spacing: Theme.Space.hair) {
                Text(book.title)
                    .font(Theme.TypeScale.cardTitle())
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(book.author)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: New list

    @ViewBuilder
    private var newListBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Button {
                withAnimation(Theme.Motion.standard) { composing.toggle() }
            } label: {
                HStack(spacing: Theme.Space.snug) {
                    Image(systemName: composing ? "minus" : "plus")
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.accent)
                        .frame(width: 20)
                    Text("New list")
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.ink)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if composing { composerFields }
        }
    }

    private var composerFields: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            TextField("Title", text: $newTitle, axis: .vertical)
                .font(Theme.TypeScale.cardTitle())
                .foregroundStyle(Theme.Palette.ink)

            TextField("What is it arguing?", text: $newPremise, axis: .vertical)
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(1...4)

            Rule()

            Toggle("Ordered", isOn: $newIsOrdered)
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.ink)

            Toggle("Visible to others", isOn: $newIsPublic)
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.ink)

            Button("Create and add") { createList() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.top, Theme.Space.tight)
        }
        .padding(Theme.Space.base)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Palette.rule, lineWidth: 0.5)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: Existing lists

    @ViewBuilder
    private var listsBlock: some View {
        if store.myLists.isEmpty {
            Text("You have no lists yet. The first one is the hardest.")
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your lists").kickerStyle()
                    .padding(.bottom, Theme.Space.snug)

                ForEach(store.myLists) { list in
                    toggleRow(for: list)
                    if list.id != store.myLists.last?.id {
                        Rule()
                    }
                }
            }
        }
    }

    private func toggleRow(for list: BookList) -> some View {
        let contains: Bool = list.bookIDs.contains(book.id)
        return Button {
            toggle(list, contains: contains)
        } label: {
            HStack(alignment: .top, spacing: Theme.Space.snug) {
                Image(systemName: contains ? "checkmark.circle.fill" : "circle")
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(contains ? Theme.Palette.accent : Theme.Palette.inkFaint)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: Theme.Space.hair) {
                    Text(list.title)
                        .font(Theme.TypeScale.cardTitle())
                        .foregroundStyle(Theme.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if !list.premise.isEmpty {
                        Text(list.premise)
                            .font(Theme.TypeScale.prose())
                            .foregroundStyle(Theme.Palette.inkSoft)
                            .lineLimit(2)
                    }
                    Text(list.subtitle)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkFaint)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, Theme.Space.snug)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(contains ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Actions

    private func toggle(_ list: BookList, contains: Bool) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(Theme.Motion.standard) {
            if contains {
                store.removeFromList(list.id, bookID: book.id)
            } else {
                store.addToList(list.id, bookID: book.id)
            }
        }
    }

    private func createList() {
        let title: String = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let premise: String = newPremise.trimmingCharacters(in: .whitespacesAndNewlines)
        let created: BookList = store.createList(
            title: title, premise: premise,
            isOrdered: newIsOrdered, isPublic: newIsPublic
        )
        store.addToList(created.id, bookID: book.id)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        newTitle = ""
        newPremise = ""
        newIsOrdered = false
        newIsPublic = true
        withAnimation(Theme.Motion.standard) { composing = false }
    }
}

// MARK: - Index

/// Every list in one place. Covers first — a list is judged by its spines long
/// before anyone reads the premise.
struct ListsIndexView: View {
    @Environment(DeweyStore.self) private var store
    @State private var composing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.loose) {
                masthead
                mineSection
                communitySection
            }
            .padding(.top, Theme.Space.snug)
            .padding(.bottom, Theme.Space.vast)
        }
        .background(Theme.Palette.paper)
        .deweyNavigationTitle(Vocabulary.lists)
        .sheet(isPresented: $composing) { NewListSheet() }
    }

    /// **The name is in the navigation bar; this is the argument.**
    ///
    /// A display-size "Lists" sat here, forty points under an inline navigation
    /// title reading "Lists" — the same duplication the Search tab had with
    /// "Find", and the reason `deweyNavigationTitle` exists. The kicker is the
    /// half worth keeping: it says what a list is *for*, which the title cannot,
    /// and it is the only editorial line on the screen.
    private var masthead: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text("Arguments, not folders")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageMargin()
    }

    // MARK: Mine

    private var mineSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            HStack(alignment: .firstTextBaseline) {
                Text("Yours").kickerStyle()
                Spacer()
                Button {
                    composing = true
                } label: {
                    Label("New list", systemImage: "plus")
                        .font(Theme.TypeScale.kicker())
                        .textCase(nil)
                        .foregroundStyle(Theme.Palette.accent)
                        // The only way to create a list from this screen, drawn
                        // at kicker size on the heading line. Padded inside the
                        // label so the capsule of tappable area clears 44pt
                        // while the text stays on the baseline beside "Yours".
                        .padding(.vertical, Theme.Space.snug)
                        .padding(.leading, Theme.Space.base)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .pageMargin()

            if store.myLists.isEmpty {
                Text("Nothing yet. A list needs a premise before it needs books.")
                    .font(Theme.TypeScale.support())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .pageMargin()
            } else {
                // No kicker. It used to pass "Yours", under a section head that
                // already reads "Yours" — the word twice on screen, once per
                // card, saying nothing the heading had not.
                cards(for: store.myLists, kicker: nil)
            }
        }
    }

    // MARK: Community

    /// **Filtered to the readers you actually follow** (§13.7).
    ///
    /// It rendered `store.communityLists` whole under a heading reading "From
    /// readers you follow", which in a fresh account is the same straightforward
    /// lie the Edition was fixed for: every seeded list, from four strangers,
    /// under a claim that they are people you chose. `DeweyStore.edition` filters
    /// its cards against the follow set for exactly this reason, and a second
    /// surface asserting the same relationship has to answer to the same test.
    ///
    /// Withheld entirely rather than shown with a different heading. A list from
    /// somebody you do not follow has no claim on this screen, and "Lists from
    /// people you have never heard of" is not a section anyone wanted.
    private var followedLists: [BookList] {
        store.communityLists.filter { store.isFollowing($0.ownerID) }
    }

    @ViewBuilder
    private var communitySection: some View {
        if !followedLists.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                Text("From readers you follow")
                    .kickerStyle()
                    .pageMargin()
                cards(for: followedLists, kicker: nil, attributed: true)
            }
        }
    }

    /// `kicker` nil means "this section's heading already says whose these are".
    /// The community section passes nothing and gets the owner's name per card,
    /// which is the one thing that genuinely varies row to row there.
    private func cards(for lists: [BookList], kicker: String?, attributed: Bool = false) -> some View {
        VStack(spacing: Theme.Space.base) {
            ForEach(lists) { list in
                NavigationLink(value: list) {
                    ListIndexCard(
                        list: list,
                        kicker: attributed ? ownerName(for: list) : kicker
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .pageMargin()
    }

    private func ownerName(for list: BookList) -> String {
        store.reader(list.ownerID)?.name ?? "On Dewey"
    }
}

// MARK: - Index card

private struct ListIndexCard: View {
    let list: BookList
    let kicker: String?

    @Environment(DeweyStore.self) private var store

    private var covers: [Book] {
        list.bookIDs.prefix(5).map { store.book($0) }
    }

    var body: some View {
        CardShell(kicker: kicker) {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                coverRow
                Text(list.title)
                    .font(Theme.TypeScale.cardTitle())
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !list.premise.isEmpty {
                    Text(list.premise)
                        .font(Theme.TypeScale.prose())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
                footer
            }
        }
    }

    /// Covers only. Five loose numerals used to sit under this row, directly
    /// above the list's title and premise — and the premise is what sells a
    /// list, as the FromListCard doc says outright. Nobody compares five books
    /// they have not opened yet; they read the title.
    ///
    /// It was also the worst-broken slot in the app: a `.frame(height: 4)` sized
    /// for the old 4pt rule, holding a ~14pt caption glyph that grows with
    /// Dynamic Type. SwiftUI does not clip, so the numerals drew straight
    /// through the gap and the card reported the wrong height.
    @ViewBuilder
    private var coverRow: some View {
        if !covers.isEmpty {
            HStack(alignment: .top, spacing: Theme.Space.tight) {
                ForEach(covers) { book in
                    BookCoverView(book: book, width: 46, scalesWithType: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, Theme.Space.hair)
        }
    }

    /// **`BookList.subtitle` already says all of this.**
    ///
    /// It renders "4 books · ordered · private", and this row printed that string
    /// and then repeated two thirds of it as a lock glyph and a numbered-list
    /// glyph at the other end of the same line. One fact, twice, eight points
    /// apart — and the icons were the less legible half, since "ordered" is a
    /// word and `list.number` is a picture a reader has to decode.
    ///
    /// The words win because they are also what every other surface uses:
    /// `subtitle` is on the profile rails, the search rows and the list header.
    /// The icons existed only here.
    private var footer: some View {
        HStack(spacing: Theme.Space.tight) {
            Text(list.subtitle)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - New list sheet

private struct NewListSheet: View {
    @Environment(DeweyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var premise = ""
    @State private var isOrdered = false
    @State private var isPublic = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.base) {
                    Text("A list earns its place by having a premise.")
                        .font(Theme.TypeScale.prose())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    Rule()

                    TextField("Title", text: $title, axis: .vertical)
                        .font(Theme.TypeScale.title())
                        .foregroundStyle(Theme.Palette.ink)

                    TextField("What is this list arguing?", text: $premise, axis: .vertical)
                        .font(Theme.TypeScale.prose())
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(2...6)

                    Rule()

                    Toggle("Ordered", isOn: $isOrdered)
                        .font(Theme.TypeScale.support())
                        .foregroundStyle(Theme.Palette.ink)

                    Toggle("Visible to others", isOn: $isPublic)
                        .font(Theme.TypeScale.support())
                        .foregroundStyle(Theme.Palette.ink)

                    Button("Create list") { create() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.top, Theme.Space.snug)
                }
                .pageMargin()
                .padding(.vertical, Theme.Space.base)
            }
            .background(Theme.Palette.paper)
            .navigationTitle("New list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.TypeScale.ui())
                }
            }
        }
    }

    private func create() {
        let cleanTitle: String = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        store.createList(
            title: cleanTitle,
            premise: premise.trimmingCharacters(in: .whitespacesAndNewlines),
            isOrdered: isOrdered,
            isPublic: isPublic
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
