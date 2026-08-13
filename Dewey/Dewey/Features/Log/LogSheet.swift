import SwiftUI
import UIKit

// MARK: - Shared date formatting

/// One place for the diary's dates. Formatters are expensive to build and these
/// are rebuilt on every row otherwise.
private enum LogDate {
    static let day: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()

    static let weekday: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("EEE"); return f
    }()

    static let medium: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
}

/// Whether an existing entry carries anything that lives under "Add more". If it
/// does, the disclosure opens on load — hiding a person's own paragraph behind a
/// chevron they didn't close is the kind of small betrayal that stops people
/// writing.
private func logEntryHasDetail(_ entry: DiaryEntry) -> Bool {
    if entry.startedOn != nil || entry.finishedOn != nil { return true }
    if entry.isReread || entry.format != nil { return true }
    if !entry.tags.isEmpty { return true }
    if let text = entry.review, !text.isEmpty { return true }
    return entry.visibility != .onlyMe
}

private extension View {
    /// The bordered box used for every free-text field in the sheet.
    func logFieldChrome() -> some View {
        self
            .padding(Theme.Space.snug)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.Palette.rule, lineWidth: 1)
            )
    }
}

// MARK: - Log sheet

/// Logging a reading.
///
/// The entire design is progressive disclosure. Above the fold there are five
/// decisions, all of them optional except the status, and Save is always one
/// tap away in the toolbar, whatever is expanded below it — that is the
/// five-second log, and it stays reachable even now that a new entry opens
/// with the disclosure already open (see `showMore`'s init). Everything else
/// lives under one disclosure, because a form that asks fourteen questions
/// gets answered once and then avoided.
///
/// Nothing is required. A finish with no rating, no dates and no words is a
/// complete, honest record, and the sheet never implies otherwise.
struct LogSheet: View {
    let book: Book
    let existing: DiaryEntry?

    /// Handed the saved entry the instant it is persisted, just before this
    /// sheet dismisses itself. The presenter owns everything that happens
    /// after — see `logFlow(book:isPresented:existing:)`.
    var onSaved: (DiaryEntry) -> Void = { _ in }

    /// Whether a *new* log of this book should arrive with "A reread" already
    /// on. The presenter decides, because it knows the book's current status
    /// and this initialiser cannot reach the store.
    var defaultsToReread: Bool = false

    @Environment(DeweyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    // Above the fold
    @State private var status: ReadingStatus
    @State private var date: Date
    @State private var rating: Rating?
    @State private var isFavorite: Bool

    // Under "Add more"
    @State private var showMore: Bool
    @State private var hasStarted: Bool
    @State private var startedOn: Date
    @State private var hasFinished: Bool
    @State private var finishedOn: Date
    @State private var isReread: Bool
    @State private var format: ReadingFormat?
    @State private var tagsText: String
    @State private var review: String
    @State private var isSpoiler: Bool
    @State private var isDraft: Bool
    @State private var visibility: Visibility

    init(
        book: Book,
        existing: DiaryEntry? = nil,
        defaultsToReread: Bool = false,
        onSaved: @escaping (DiaryEntry) -> Void = { _ in }
    ) {
        self.book = book
        self.existing = existing
        self.defaultsToReread = defaultsToReread
        self.onSaved = onSaved

        let today = Date()
        // A log sheet is opened to record a finish far more often than anything
        // else, so that is the default. It stays one tap from every other state.
        _status = State(initialValue: existing?.status ?? .finished)
        _date = State(initialValue: existing?.loggedOn ?? today)
        _rating = State(initialValue: existing?.rating)
        _isFavorite = State(initialValue: existing?.isFavorite ?? false)

        // **A new entry opens with "Add more" already open** — the one
        // deliberate exception to this sheet's five-second-log design.
        //
        // A brand-new log defaults to `.finished` (above), because recording
        // a finish is what this sheet is for far more often than anything
        // else. But the fields "Add more" was hiding are the review and who
        // can see it — the write-up and the share decision, the two things
        // "Crystallize meaning" and "Share intentionally" actually depend
        // on. Collapsed by default, a reader who took the fast path (which
        // the app's own copy calls "the only path most people will ever
        // take") saved a finish and never saw either control: the resurfaced
        // Moments prompt just above already invites a reflection, and the
        // box to write one was a chevron tap nobody had a reason to make.
        //
        // Nothing becomes required by opening it. Save still works with the
        // review empty and the status left wherever it lands — this only
        // makes the field visible at the one moment it matters, instead of
        // filed next to Tags and Format under a generic disclosure. Editing
        // an existing entry is unaffected: it still opens on `logEntryHasDetail`,
        // exactly as before.
        _showMore = State(initialValue: existing.map(logEntryHasDetail) ?? true)
        _hasStarted = State(initialValue: existing?.startedOn != nil)
        _startedOn = State(initialValue: existing?.startedOn ?? today)
        _hasFinished = State(initialValue: existing?.finishedOn != nil)
        _finishedOn = State(initialValue: existing?.finishedOn ?? today)
        // Editing keeps whatever the entry says. A new log defaults to what
        // the app already knows: opening this sheet on a book you have already
        // finished is, by definition, recording a second reading, and making
        // the reader say so again asks them to confirm a fact the app supplied
        // the screen with. Still a toggle — a first read logged late is a real
        // case, and it is one tap away.
        _isReread = State(initialValue: existing?.isReread ?? defaultsToReread)
        _format = State(initialValue: existing?.format)
        _tagsText = State(initialValue: (existing?.tags ?? []).joined(separator: ", "))
        _review = State(initialValue: existing?.review ?? "")
        _isSpoiler = State(initialValue: existing?.reviewIsSpoiler ?? false)
        _isDraft = State(initialValue: existing?.reviewIsDraft ?? false)
        // A new entry starts private, same as the model default — the reader
        // has to choose "People who follow me" or "Everyone" for anything to
        // leave this device.
        _visibility = State(initialValue: existing?.visibility ?? .onlyMe)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            scroller
                .background(Theme.Palette.paper)
                .navigationTitle(existing == nil ? "Log" : "Edit entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .presentationDragIndicator(.visible)
    }

    /// Sections are separated by `base` rather than the `roomy` this app uses
    /// between blocks elsewhere.
    ///
    /// The 0.1–10.0 slider is roughly fifty points taller than the five tap
    /// segments it replaced (§12.2.2), and the whole claim of this sheet is that
    /// status, date, rating, Favorite and "Add more" are all reachable without
    /// a scroll on the smallest phone. That height was paid for out of the gaps
    /// between sections, not out of anything a person needs to see — the tighter
    /// rhythm is the cost of the finer scale, and it is the right thing to spend.
    private var scroller: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.base) {
                header
                momentsPrompt
                statusSection
                dateRow
                ratingSection
                favoriteRow
                moreDisclosure
            }
            .pageMargin()
            .padding(.top, Theme.Space.base)
            .padding(.bottom, Theme.Space.loose)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
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
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Space.base) {
            BookCoverView(book: book, width: 58, scalesWithType: true)

            VStack(alignment: .leading, spacing: Theme.Space.hair) {
                Text(book.title)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.subtitleLine)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                if let existing {
                    Text("Logged \(LogDate.medium.string(from: existing.loggedOn))")
                        .kickerStyle()
                        .padding(.top, Theme.Space.tight)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: Moments

    /// A light prompt, not a review of the reviews: what was caught while the
    /// book was open, oldest first — the order they happened in, so reading
    /// down this list retraces the book rather than working backward from the
    /// last page. Read-only here; capturing and deleting stay on the book page.
    ///
    /// Present only when there is something to show. A book with no Moments
    /// gets no empty state — "you didn't capture anything" is not a fact this
    /// sheet exists to state, and the whole point of the five-second log is
    /// that it stays that short for the reader who never uses Moments at all.
    ///
    /// Set below the header and above every reflection control, and set
    /// quieter than all of them — `support()` and `inkSoft` against the
    /// review field's `prose()` and `ink` — because this is raw material for
    /// what the reader is about to write, not a second thing being written.
    @ViewBuilder
    private var momentsPrompt: some View {
        let moments = Array(store.moments(forBook: book.id).reversed())
        if !moments.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                Text("From your Moments").kickerStyle()
                VStack(alignment: .leading, spacing: Theme.Space.base) {
                    ForEach(moments) { moment in
                        momentRow(moment)
                    }
                }
            }
        }
    }

    private func momentRow(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.hair) {
            Text(moment.text)
                .font(Theme.TypeScale.support())
                .foregroundStyle(Theme.Palette.inkSoft)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
            if let page = moment.pageNumber {
                Text("Page \(page)")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
            }
        }
        .padding(.leading, Theme.Space.snug)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Theme.Palette.rule)
                .frame(width: 2)
        }
    }

    // MARK: Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("This reading").kickerStyle()

            FlowLayout(spacing: Theme.Space.tight) {
                ForEach(ReadingStatus.allCases) { option in
                    Button(option.title) { choose(option) }
                        .buttonStyle(ChipStyle(selected: status == option))
                        .accessibilityAddTraits(status == option ? [.isSelected] : [])
                }
            }
        }
    }

    private func choose(_ option: ReadingStatus) {
        guard status != option else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(Theme.Motion.standard) { status = option }
    }

    // MARK: Date

    /// **A control that stopped mattering used to keep accepting input.**
    ///
    /// `buildEntry` files the entry under `hasFinished ? finishedOn : date`, so
    /// the moment "Finished on" is switched on under Add more, this picker
    /// governs nothing. It stayed fully live: a reader could open it, spin
    /// through months, watch the value change, tap Save — and the entry filed
    /// under a different day, with the caption "Files under the finish date"
    /// sitting beside it as the only clue, phrased as a note rather than as the
    /// reason the thing they were touching was inert.
    ///
    /// It now shows the date it will actually file under, and says which field
    /// owns it. Nothing is hidden — the reader still sees the day — but the
    /// picker is not offered when it cannot be obeyed, which is the only honest
    /// state for a control that has been overruled.
    private var dateRow: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("Date").kickerStyle()

            HStack(spacing: Theme.Space.snug) {
                if hasFinished {
                    Text(LogDate.medium.string(from: finishedOn))
                        .font(Theme.TypeScale.support())
                        .foregroundStyle(Theme.Palette.ink)
                } else {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Theme.Palette.accent)
                }

                Spacer(minLength: 0)

                Text(hasFinished
                     ? "Taken from Finished on, under Add more."
                     : "Files under this date")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(Theme.Motion.standard, value: hasFinished)
    }

    // MARK: Rating

    /// A continuous track, 0.1 to 10.0 (§12.2.2).
    ///
    /// The caption that used to sit under the control is gone. It said "Tap the
    /// first mark again to clear it", which stopped being true the moment the
    /// segments became a track — there is no first mark, and every pixel is a
    /// different value. The slider carries its own scale legend and its own
    /// explicit Clear (§12.2.5), so the caption was a wrong sentence occupying
    /// the height the slider needed.
    ///
    /// "Optional" moved into the kicker row in its place. It is the one fact the
    /// control cannot state about itself, and this sheet's whole posture is that
    /// a finish with no rating is a complete record.
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack(alignment: .firstTextBaseline) {
                Text(Judgement.ScoreCopy.title).kickerStyle()
                Spacer(minLength: 0)

                // One text style across both states so the row cannot change
                // height the instant a rating first appears — the track would
                // slide out from under the finger that just set it. Monospaced
                // because these digits change ninety-nine times in one drag, and
                // a numeral that reflows while you aim reads as a glitch.
                //
                // Hidden from VoiceOver: the slider announces "Rating, 8.3 out
                // of 10" as its own label and value, and a loose "8.3" sitting
                // beside it is the same fact twice.
                Text(rating?.compact ?? "Optional")
                    .font(.system(.subheadline, design: .serif,
                                  weight: rating == nil ? .regular : .semibold))
                    .foregroundStyle(rating == nil ? Theme.Palette.inkFaint : Theme.Palette.ink)
                    .monospacedDigit()
                    .accessibilityHidden(true)
            }

            RatingSlider(rating: $rating)

            // States the rating's job at the point it is asked for (§13.1).
            // Without it, this control and the Favorite toggle directly below
            // look like two ways of saying the same thing, which is exactly the
            // confusion this pass exists to remove.
            Text(Judgement.ScoreCopy.explainer)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        // Keyed to *whether* there is a rating, never to its value. Keyed to the
        // value, every tenth of a drag would spring the thumb toward the finger
        // instead of sitting under it, and a slider that lags its own gesture
        // feels broken however pretty the curve is.
        .animation(Theme.Motion.standard, value: rating == nil)
    }

    // MARK: Favorite

    /// A separate claim from the rating, and the sheet says so out loud — the
    /// distinction is the most interesting thing in the model and it dies the
    /// moment people read this as a second, softer score.
    ///
    /// **This toggle does not touch your profile** (§14). It marks the book,
    /// nothing more, and there is no cap on how many books may carry it. The
    /// four on your profile are `Judgement.FavoriteBooksCopy` and are chosen
    /// deliberately from the profile itself. The copy below says "mark as many
    /// as you like" for exactly that reason: a reader who thinks this control is
    /// rationed will use it as a ranking.
    private var favoriteRow: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(Theme.Motion.standard) { isFavorite.toggle() }
        } label: {
            HStack(spacing: Theme.Space.snug) {
                FavoriteMark(filled: isFavorite, size: 22)

                // The full definition, not the short form (§13.1). This is
                // where a reader meets the concept for the first time and the
                // only place they are asked to *apply* it, so it is stated
                // outright rather than gestured at — and stated from the shared
                // constant, so every other surface that shows a Favorite cannot
                // drift into a second wording.
                VStack(alignment: .leading, spacing: 1) {
                    Text(Judgement.FavoriteCopy.title)
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.ink)
                    Text(Judgement.FavoriteCopy.definition)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(Theme.Space.snug)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isFavorite ? Theme.Palette.accent.opacity(0.08) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFavorite ? Theme.Palette.accent.opacity(0.4) : Theme.Palette.rule, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        // Spoken as one control rather than a heading plus a paragraph, and the
        // hint carries the thing a screen-reader user cannot see: that this is
        // unlimited, and that it is not the profile four.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Judgement.FavoriteCopy.title)
        .accessibilityValue(isFavorite ? "Marked" : "Not marked")
        .accessibilityHint(Judgement.FavoriteCopy.definition)
        .accessibilityAddTraits(isFavorite ? [.isSelected] : [])
    }

    // MARK: Add more

    private var moreDisclosure: some View {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            Button {
                withAnimation(Theme.Motion.standard) { showMore.toggle() }
            } label: {
                HStack(spacing: Theme.Space.tight) {
                    Text(showMore ? "Less" : "Add more")
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.accent)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.Palette.accent)
                        .rotationEffect(.degrees(showMore ? 180 : 0))
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Theme.Space.tight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showMore ? "Hide extra fields" : "Add more detail")

            if showMore {
                datesBlock
                formatBlock
                tagsBlock
                reviewBlock
                visibilityBlock
            }
        }
        .overlay(alignment: .top) { Rule().offset(y: -Theme.Space.snug) }
    }

    private var datesBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.base) {
            Text("Dates").kickerStyle()

            optionalDate("Started on", isOn: $hasStarted, value: $startedOn)
            optionalDate("Finished on", isOn: $hasFinished, value: $finishedOn)

            Toggle(isOn: $isReread) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("A reread")
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.ink)
                    Text("Kept as its own entry. The first time stays where it was.")
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .multilineTextAlignment(.leading)
                }
            }
            .tint(Theme.Palette.accent)
        }
    }

    private func optionalDate(_ label: String, isOn: Binding<Bool>, value: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Toggle(isOn: isOn.animation(Theme.Motion.standard)) {
                Text(label)
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.ink)
            }
            .tint(Theme.Palette.accent)

            if isOn.wrappedValue {
                DatePicker(label, selection: value, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Theme.Palette.accent)
            }
        }
    }

    private var formatBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("How you read it").kickerStyle()

            FlowLayout(spacing: Theme.Space.tight) {
                ForEach(ReadingFormat.allCases) { option in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(Theme.Motion.standard) {
                            format = (format == option) ? nil : option
                        }
                    } label: {
                        Label(option.title, systemImage: option.symbol)
                    }
                    .buttonStyle(ChipStyle(selected: format == option))
                    .accessibilityAddTraits(format == option ? [.isSelected] : [])
                }
            }
        }
    }

    private var tagsBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("Tags").kickerStyle()

            TextField("winter, on a train, unfinished business", text: $tagsText)
                .font(Theme.TypeScale.support())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .logFieldChrome()

            if parsedTags.isEmpty {
                Text("Separate them with commas.")
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
            } else {
                Text(parsedTags.joined(separator: " · "))
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// **The object is named plainly and the question is asked expressively.**
    ///
    /// That split is the whole of the Reflection → Review rename (§`ReviewCopy`).
    /// The kicker says what a reader is making — a Review, the word they already
    /// have for it — and the field still asks "What did it do to you?", which is
    /// the register the old name was trying and failing to carry on its own.
    /// Renaming the object *and* flattening the prompt to "Write your review"
    /// would have traded one problem for a worse one.
    private var reviewBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text(Judgement.ReviewCopy.title).kickerStyle()

            TextField(Judgement.ReviewCopy.question, text: $review, axis: .vertical)
                .font(Theme.TypeScale.prose())
                .lineLimit(4...12)
                .logFieldChrome()
                .accessibilityLabel(Judgement.ReviewCopy.write)
                .accessibilityHint(Judgement.ReviewCopy.question)

            // Stated once, under the field, because "as long as you like" is the
            // thing a reader most needs to hear before writing anything — a
            // one-line review is a review, and the box is four lines tall.
            Text(Judgement.ReviewCopy.explainer)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: $isSpoiler) {
                Text(Judgement.ReviewCopy.spoilerToggle)
                    .font(Theme.TypeScale.ui())
                    .foregroundStyle(Theme.Palette.ink)
            }
            .tint(Theme.Palette.accent)
            .disabled(trimmedReview.isEmpty)

            Toggle(isOn: $isDraft) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Judgement.ReviewCopy.draftToggle)
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.ink)
                    Text(Judgement.ReviewCopy.draftBlurb)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .multilineTextAlignment(.leading)
                }
            }
            .tint(Theme.Palette.accent)
            .disabled(trimmedReview.isEmpty)
        }
    }

    private var visibilityBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Text("Who can see it").kickerStyle()

            Picker(selection: $visibility) {
                ForEach(Visibility.allCases) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                }
            } label: {
                Text("Who can see it")
            }
            .pickerStyle(.menu)
            .tint(Theme.Palette.accent)

            Text("\(Judgement.ScoreCopy.title) and dates follow this too. Private notes never leave.")
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Derived

    private var trimmedReview: String {
        review.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: Saving

    private func buildEntry() -> DiaryEntry {
        let text = trimmedReview
        return DiaryEntry(
            id: existing?.id ?? UUID().uuidString,
            bookID: book.id,
            status: status,
            startedOn: hasStarted ? startedOn : nil,
            finishedOn: hasFinished ? finishedOn : nil,
            loggedOn: hasFinished ? finishedOn : date,
            isReread: isReread,
            rating: rating,
            isFavorite: isFavorite,
            review: text.isEmpty ? nil : text,
            reviewIsSpoiler: isSpoiler,
            reviewIsDraft: isDraft,
            visibility: visibility,
            privateNote: existing?.privateNote,
            tags: parsedTags,
            format: format
        )
    }

    /// Saves, reports, and **closes** (§13.4).
    ///
    /// It used to save and then stay open: the finished form remained on screen
    /// and apparently editable, "Cancel" silently became "Done", and a "Place it
    /// in your rankings?" panel rose from the bottom *inside the same sheet*. A
    /// reader could not tell whether they had finished, whether the form was
    /// still live, or whether the thing now being asked was part of saving.
    ///
    /// Saving is now a completed act with a visible end. What happens next —
    /// the confirmation, and the entirely optional ranking offer — belongs to
    /// whoever presented this sheet; see `logFlow(book:isPresented:existing:)`.
    private func save() {
        let entry: DiaryEntry = buildEntry()
        // `log` refuses when Dewey can no longer answer for the book — a
        // transient evicted by a debug world switch while this sheet's page
        // stayed open (§16). Nothing was written, so nothing is reported: the
        // sheet closes without a confirmation rather than showing a receipt
        // for a log that does not exist.
        guard store.log(entry) != nil else {
            dismiss()
            return
        }
        onSaved(entry)
        dismiss()
    }
}

// MARK: - Diary

/// The reading diary, in order, forever.
///
/// A record and not a scoreboard: there are no totals, no counts, no streaks and
/// no "books this year". The moment a diary starts keeping score it stops being
/// a place you write honestly — you log the short book because it moves the
/// number, and you don't log the abandoned one at all.
struct DiaryView: View {
    @Environment(DeweyStore.self) private var store

    @State private var editing: DiaryEntry?

    /// The book a swipe asked to open. See `row(_:)`.
    @State private var opening: Book?

    var body: some View {
        Group {
            if store.diary.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Theme.Palette.paper)
        .navigationTitle("Diary")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { entry in
            LogSheet(book: store.book(entry.bookID), existing: entry)
        }
        // A row's own tap opens the editor, which is the right default — the
        // diary is a thing you keep, not a thing you browse. But it left the
        // book itself unreachable from here: every other list in Dewey pushes a
        // `Book`, and the one surface built entirely out of books you have
        // actually read was the one you could not get out of. A swipe action
        // cannot push a value on its own, so it sets this and the stack does the
        // push. `deweyDestinations` still owns what a book page looks like.
        .navigationDestination(item: $opening) { book in
            BookDetailView(book: book)
        }
    }

    private var list: some View {
        List {
            ForEach(store.diaryByMonth, id: \.label) { group in
                Section {
                    ForEach(group.entries) { entry in
                        row(entry)
                    }
                } header: {
                    monthHeader(group.label)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }

    private func monthHeader(_ label: String) -> some View {
        Text(label)
            .font(.system(.title3, design: .serif, weight: .semibold))
            .foregroundStyle(Theme.Palette.ink)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Space.tight)
            .background(Theme.Palette.paper)
            .listRowInsets(EdgeInsets(
                top: Theme.Space.tight, leading: Theme.Space.margin,
                bottom: Theme.Space.tight, trailing: Theme.Space.margin
            ))
    }

    private func row(_ entry: DiaryEntry) -> some View {
        Button {
            editing = entry
        } label: {
            DiaryRow(entry: entry, book: store.book(entry.bookID))
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.Palette.paper)
        .listRowSeparatorTint(Theme.Palette.rule)
        .listRowInsets(EdgeInsets(
            top: Theme.Space.base, leading: Theme.Space.margin,
            bottom: Theme.Space.base, trailing: Theme.Space.margin
        ))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                withAnimation(Theme.Motion.standard) { store.deleteEntry(entry.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                opening = store.book(entry.bookID)
            } label: {
                Label("Open book", systemImage: "book")
            }
            .tint(Theme.Palette.accent)
        }
    }

    /// An invitation, not an error. Nothing has gone wrong here.
    private var emptyState: some View {
        VStack(spacing: Theme.Space.snug) {
            Spacer(minLength: 0)

            Text("The first page is blank")
                .font(Theme.TypeScale.title())
                .foregroundStyle(Theme.Palette.ink)
                .multilineTextAlignment(.center)

            Text("Log a book and it lands here, dated. Read it again in ten years and that gets its own line too.")
                .font(Theme.TypeScale.prose())
                .foregroundStyle(Theme.Palette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageMargin()
    }
}

// MARK: - Diary row

/// One dated act of reading. Cover, date, rating — the three things you scan
/// for — carry the row; everything else is quieter than they are.
private struct DiaryRow: View {
    let entry: DiaryEntry
    let book: Book

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.snug) {
            dateColumn
            BookCoverView(book: book, width: 44, scalesWithType: true)
            details
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// The gutter grows with the type rather than holding at 34pt.
    ///
    /// A `.title2` serif "31" over a three-letter weekday does not fit 34
    /// points once a reader turns text up: the day clipped and the weekday
    /// wrapped to two lines, in the column the row is scanned by. `@ScaledMetric`
    /// keeps the alignment — every row still shares one gutter — while letting
    /// that gutter answer the setting.
    @ScaledMetric(relativeTo: .title2) private var dateColumnWidth: CGFloat = 34

    private var dateColumn: some View {
        VStack(spacing: 0) {
            Text(LogDate.day.string(from: entry.loggedOn))
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.ink)
            Text(LogDate.weekday.string(from: entry.loggedOn))
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: dateColumnWidth, alignment: .center)
        .padding(.top, 2)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            Text(book.title)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            Text(book.author)
                .font(Theme.TypeScale.meta())
                .foregroundStyle(Theme.Palette.inkSoft)

            // Only drawn when there is something in it. An always-present
            // `HStack` still spends its stack spacing and top padding, which on
            // a diary of unscored finishes is a ragged gap under every author
            // line.
            if hasMarks { marks }

            // **Three lines, not one** (§13.6).
            //
            // A one-line clamp cut every review in the diary mid-word:
            // "Read it in one sitting on a Sun…", "Marcus was right and I
            // resent i…", "The episode guide story is doi…". That text is the
            // entire reason to keep a diary rather than a list of dates, and it
            // was the one thing on the row that could not be read. Three lines
            // carries a normal review whole and still keeps the row
            // scannable.
            //
            // A longer one still truncates mid-word — `Text` clips at the
            // character, and there is no word-boundary truncation mode to ask
            // for. This comment used to claim `.byWordWrapping` was doing that
            // job; no such modifier was ever on the view. Left as is rather
            // than hand-trimming the string, which would need the rendered line
            // width and would break the moment a reader changed their type
            // size.
            if let line = reviewPreview {
                Text(line)
                    .font(Theme.TypeScale.prose())
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !entry.tags.isEmpty {
                Text(entry.tags.joined(separator: " · "))
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .lineLimit(1)
            }
        }
    }

    /// The rating is a numeral here, and this is a correction of something that
    /// was visibly broken on screen.
    ///
    /// The row previously drew a `.regular` mark: ten capsules, 66pt wide, no
    /// numeral, crammed in ahead of the Favorite glyph, the reread label, a
    /// format symbol and a status word. Three consecutive entries rated 9.3, 9.7
    /// and 7.8 rendered as three identical dashes, because at `.regular` the
    /// partial capsule is shorter than it is thick below .36 of a unit and a 0.9
    /// fill differs from a full rule by half a point. The diary is exactly where
    /// that fails hardest: a diary is read *across* — the same book on a reread
    /// two years later, a month's entries compared against each other — so the
    /// number has to be the number, not an impression of one.
    ///
    /// It leads the row for the same reason the struct comment names it one of
    /// the three things you scan for, and it stays in `ink` while everything
    /// beside it stays `inkFaint`, so it reads as the value on a line of
    /// annotations. It is also a quarter the width of what it replaced, which is
    /// what made room for the other four marks to stop colliding.
    private var hasMarks: Bool {
        entry.rating != nil || entry.isFavorite || entry.isReread
            || entry.format != nil || entry.status != .finished
    }

    private var marks: some View {
        HStack(spacing: Theme.Space.snug) {
            if entry.rating != nil {
                RatingMark(rating: entry.rating)
            }

            if entry.isFavorite {
                FavoriteMark(filled: true, size: 14)
            }

            if entry.isReread {
                Label("Reread", systemImage: "arrow.counterclockwise")
                    .labelStyle(.titleAndIcon)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
            }

            if let format = entry.format {
                Image(systemName: format.symbol)
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .accessibilityLabel(format.title)
            }

            if entry.status != .finished {
                Text(entry.status.title)
                    .font(Theme.TypeScale.meta())
                    .foregroundStyle(Theme.Palette.inkFaint)
            }
        }
        .padding(.top, Theme.Space.hair)
    }

    /// **Your own spoilers are not hidden from you.**
    ///
    /// This returned a "hidden — spoilers" placeholder whenever the entry carried
    /// the spoiler flag, which is nonsense on this surface: the diary is yours
    /// alone, you wrote the sentence, and you set the flag. The flag is a
    /// *publishing* instruction — it tells the book page to blur your paragraph
    /// for readers who have not finished the book, which `reviewBody` does —
    /// and applying it to the author was the app protecting a reader from a plot
    /// they already know, at the cost of the one line on the row worth reading.
    ///
    /// Three consecutive spoiler-flagged entries rendered as three identical
    /// grey sentences, so a month of the diary said nothing at all.
    private var reviewPreview: String? {
        guard let text = entry.review?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }
}

// MARK: - The log flow

/// Presenting a log sheet, and everything that follows a save (§13.4).
///
/// The sequence is fixed and each step is a separate object on screen:
///
/// 1. **Save** the log.
/// 2. The form **dismisses**. Saving is over, visibly.
/// 3. A lightweight **confirmation** says so.
/// 4. If the reading can be ranked, a **distinct** offer appears.
/// 5. The reader ranks, or dismisses. Either way the log is already saved.
///
/// What this replaces: the sheet stayed open after Save, the completed form
/// remained on screen and apparently editable, "Cancel" quietly relabelled
/// itself "Done", and the ranking question rose from the bottom of the *same*
/// sheet. Three different things — a form, a receipt, and a new question — were
/// stacked in one container with no boundary between them.
///
/// Bundled as one modifier rather than reimplemented per call site, because the
/// ordering *is* the fix: a second presenter that showed the offer without
/// dismissing first would quietly reintroduce the bug.
extension View {
    func logFlow(
        book: Book,
        isPresented: Binding<Bool>,
        existing: DiaryEntry? = nil
    ) -> some View {
        modifier(LogFlowModifier(book: book, isPresented: isPresented, existing: existing))
    }
}

private struct LogFlowModifier: ViewModifier {
    let book: Book
    @Binding var isPresented: Bool
    let existing: DiaryEntry?

    @Environment(DeweyStore.self) private var store

    /// Set the moment the log is persisted; drives the confirmation and decides
    /// whether ranking is even offered.
    @State private var saved: DiaryEntry?
    @State private var showConfirmation = false
    @State private var offeringRanking = false
    @State private var showRanking = false

    /// Ranking compares one *finished* reading against others. Offering it
    /// after "Want to Read" would be asking the reader to place a book they
    /// have not read.
    ///
    /// **A score is no longer required** (§19). This read
    /// `saved.status == .finished && saved.rating != nil`, which made Your
    /// Score a precondition for Your Ranking — so a reader who finished a book
    /// and did not want to put a number on it was never offered the one
    /// judgement that does not need a number, and the app quietly taught that
    /// ranking is something you do to books you have already scored. They are
    /// independent, and the flow that introduces them both has to be the first
    /// thing that says so.
    private var canRank: Bool {
        saved?.status == .finished
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                LogSheet(
                    book: book,
                    existing: existing,
                    defaultsToReread: existing == nil && store.status(of: book.id) == .finished
                ) { entry in
                    saved = entry
                }
            }
            // Fires after the sheet is fully gone, so the confirmation is never
            // animating in behind a form that is still animating out.
            .onChange(of: isPresented) { _, presented in
                guard !presented, saved != nil else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(Theme.Motion.gentle) { showConfirmation = true }
            }
            .sheet(isPresented: $showRanking, onDismiss: { saved = nil }) {
                RankingSheet(book: book)
            }
            .overlay(alignment: .bottom) { confirmationBanner }
    }

    /// A receipt, not a dialog. It states what happened, offers the one optional
    /// next step, and gets out of the way on its own if the reader ignores it.
    @ViewBuilder
    private var confirmationBanner: some View {
        if showConfirmation {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                HStack(spacing: Theme.Space.snug) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Palette.accent)
                    Text(confirmationLine)
                        .font(Theme.TypeScale.ui())
                        .foregroundStyle(Theme.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }

                if offeringRanking {
                    // Singular. There is one ranking (§19), and "rankings"
                    // implied the reader was choosing which of several to put
                    // the book in — a choice that used to exist and should
                    // never have.
                    Text("Place it in \(Judgement.RankingCopy.title.lowercased())?")
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)

                    Text(Judgement.RankingCopy.explainer)
                        .font(Theme.TypeScale.meta())
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: Theme.Space.snug) {
                        Button("Not now") { close() }
                            .buttonStyle(QuietButtonStyle())
                        Button("Place it") {
                            withAnimation(Theme.Motion.standard) {
                                showConfirmation = false
                                offeringRanking = false
                            }
                            showRanking = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.top, Theme.Space.hair)
                }
            }
            .pageMargin()
            .padding(.vertical, Theme.Space.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .overlay(alignment: .top) { Rule() }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task {
                // A log that cannot be ranked needs no decision from anyone, so
                // the receipt simply expires. One that can waits, because
                // dismissing an offer out from under a reader mid-read is worse
                // than leaving it there.
                guard canRank else {
                    try? await Task.sleep(for: .seconds(2))
                    close()
                    return
                }
                withAnimation(Theme.Motion.gentle) { offeringRanking = true }
            }
        }
    }

    private var confirmationLine: String {
        guard let saved else { return "Saved" }
        return existing == nil ? "\(saved.status.title) — logged" : "Entry updated"
    }

    private func close() {
        withAnimation(Theme.Motion.gentle) {
            showConfirmation = false
            offeringRanking = false
        }
        saved = nil
    }
}
