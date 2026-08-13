import SwiftUI

// TEMPORARY — prototype scaffolding. Delete this file, DebugActions.swift, the
// two `debug*` methods on DeweyStore, and the `.debugMenu()` calls on the two
// toolbars. Nothing else depends on any of it.

/// A prototype control room.
///
/// Deliberately styled *unlike* the rest of the app — system fonts, a grouped
/// list, a plain sheet. It should never be mistaken for a Dewey surface, and it
/// should be obvious in a screenshot that this is scaffolding.
struct DebugMenuView: View {
    @Environment(DeweyStore.self) private var store
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// The comparison settings are a singleton, but they still have to be
    /// *observed* to be read from a view. A computed pass-through to
    /// `DebugSettings.shared` gives SwiftUI nothing to track, so the checkmarks
    /// below would silently never move. Holding the shared instance in `@State`
    /// is the documented `@Observable` pattern and costs nothing here —
    /// `DebugSettings.shared` is the same object every time it is read.
    @State private var settings = DebugSettings.shared

    /// The try-it slider's own value, local on purpose: comparing feels must
    /// never dirty a real book's rating. It starts unrated so the always-drawn
    /// thumb of §12.8.3 is the first thing the founder sees.
    @State private var tryRating: Rating?

    @State private var confirmingReset = false

    /// Adoption of the pre-account file (§20). `adopted` carries the outcome
    /// into the alert, because the operation can decline to run — no account, an
    /// undecodable file, a backup that could not be written — and reporting
    /// "Adopted" in those cases would be the one lie this feature must not tell.
    @State private var confirmingAdoption = false
    @State private var showingAdoptionResult = false
    @State private var adopted = false

    var body: some View {
        NavigationStack {
            List {
                backendBanner

                // Above everything, and transient — see `preAccountSection`.
                preAccountSection

                // The comparison block sits above the state and the actions
                // because it is the only reason this sheet gets opened during
                // the feel pass. The slider should be under the thumb the
                // moment the sheet lands, with no scroll in between.
                Section {
                    RatingSlider(rating: $tryRating)
                        .padding(.vertical, 4)

                    LabeledContent("Lands on", value: tryRating?.compact ?? "Not rated")
                        .accessibilityLabel("Try it, lands on")
                        .accessibilityValue(tryRating?.spoken ?? "Not rated")
                } header: {
                    Text("Try it")
                } footer: {
                    Text("Founder-evaluation controls, not user settings. They live in memory and go back to their defaults on relaunch. Drag here to feel the preset and the scale chosen below — this slider is scratch, it belongs to no book and saves nothing.")
                }

                Section {
                    ForEach(HapticPreset.allCases) { preset in
                        option(preset.title, preset.blurb, isOn: settings.haptics == preset) {
                            settings.haptics = preset
                        }
                    }
                } header: {
                    Text("Haptic feel")
                } footer: {
                    Text("Now: \(settings.haptics.title). Applies to the slider above and to every rating slider in the app.")
                }

                Section {
                    ForEach(ScaleMode.allCases) { mode in
                        option(mode.title, rungs(mode), isOn: settings.scale == mode) {
                            settings.scale = mode
                        }
                    }
                } header: {
                    Text("Rating scale")
                } footer: {
                    Text("Now: \(settings.scale.title). This changes only what the slider snaps to for new input. It converts nothing: a book already rated 8.3 is still 8.3, still renders as 8.3, and is still saved as 8.3.")
                }

                // The one control in this menu with consequences. The two above
                // live in memory and reset on relaunch; this one rewrites the
                // store and the file on disk, so it is stated as a switch of
                // worlds rather than a preference.
                Section {
                    ForEach(WorldMode.allCases) { mode in
                        option(mode.title, mode.blurb, isOn: store.world == mode) {
                            store.load(world: mode)
                        }
                    }
                } header: {
                    Text("World")
                } footer: {
                    Text("Now: \(store.world.title). Unlike the settings above, this one is destructive and persists — it replaces the library, diary, lists, rankings and follows, and survives relaunch. Switching either way resets cleanly to that world's starting state.")
                }

                Section {
                    LabeledContent("Imported books", value: "\(store.importedBooks.count)")
                    action("Refresh catalog metadata",
                           "Re-asks Open Library about every imported book now, ignoring the 7-day interval the book pages use.",
                           "arrow.triangle.2.circlepath") {
                        Task { await store.refreshAllCatalogMetadata() }
                    }
                } header: {
                    Text("Catalog")
                } footer: {
                    Text("Imported books are the ones pulled in from Open Library by saving, logging, rating, listing or ranking them. Seed books never refresh — they were never fetched.")
                }

                Section {
                    LabeledContent("Saved books", value: "\(store.library.count)")
                    LabeledContent("Waiting for you", value: "\(store.debugWaitingCount)")
                    LabeledContent("You've sent", value: "\(store.debugSentCount)")
                    // Both counts, side by side, because the two are separate
                    // and an evaluator's first question about the split is
                    // whether they can actually disagree. They can.
                    LabeledContent(Judgement.FavoriteBooksCopy.title,
                                   value: "\(store.favoriteBookIDs.count) of \(Judgement.FavoriteBooksCopy.count)")
                    LabeledContent(Judgement.FavoriteCopy.plural,
                                   value: "\(store.debugFavoriteCount)")
                } header: {
                    Text("State")
                }

                Section {
                    action("Clear \(Judgement.FavoriteBooksCopy.title)",
                           "Empties the four on your profile so the empty state and the picker are reachable. Leaves every Favorite mark alone — that is the point.",
                           "bookmark.slash") {
                        store.setFavoriteBooks([])
                    }
                } header: {
                    Text(Judgement.FavoriteBooksCopy.title)
                } footer: {
                    Text("\(Judgement.FavoriteCopy.plural) are unlimited and marked on the log sheet. \(Judgement.FavoriteBooksCopy.title) are the four you pick on your profile. Nothing derives one from the other, and this control only touches the four.")
                }

                Section {
                    action("Recommendation received",
                           "A reader sends you a book. Appears in the Edition.",
                           "tray.and.arrow.down") {
                        store.debugReceiveRecommendation()
                    }

                    action("Recommendation sent",
                           "Fabricates one you sent, so the states below have something to attach to.",
                           "paperplane") {
                        store.debugSendRecommendation()
                    }
                } header: {
                    Text("Recommendations")
                }

                Section {
                    action("Recipient started the book",
                           "Fires the closure banner now, instead of waiting the 20s the send flow uses.",
                           "book") {
                        store.debugFireClosure()
                        dismiss()
                    }

                    action("Reaction received",
                           "They mark something you sent. See it on that book's page.",
                           "hand.thumbsup") {
                        store.debugReceiveReaction()
                    }

                    action("Private reply received",
                           "They reply to something you sent. See it on that book's page.",
                           "arrowshape.turn.up.left") {
                        store.debugReceiveReply()
                    }
                } header: {
                    Text("Responses to what you sent")
                } footer: {
                    Text("These attach to your most recent sent recommendation. If you haven't sent one, use “Recommendation sent” first — then open that book from the Library.")
                }

                accountSection

                Section {
                    Button(role: .destructive) {
                        confirmingReset = true
                    } label: {
                        Label("Reset prototype", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Clears your library, every recommendation, and all saved state. Puts Priya's opening recommendation back.")
                }
            }
            // **Attached to the List, not to the section that triggers it.**
            // It was on `preAccountSection`, which removes itself the instant
            // adoption succeeds — so the modifier left the hierarchy in the same
            // update that set the flag, and the one confirmation a destructive,
            // once-only action owes the reader never appeared. Found by watching
            // it not appear; the disk said the adoption had worked perfectly.
            .alert(adopted ? "Adopted" : "Couldn't adopt", isPresented: $showingAdoptionResult) {
                Button("OK") { }
            } message: {
                Text(adopted
                     ? "Your pre-account record is now this account's. The old file has been renamed to dewey-prototype-v4.adopted.json, and whatever this account had before is beside it as state-v5.replaced.json."
                     : "Nothing was changed. The file could not be read, or this account's own file could not be set aside first.")
            }
            .navigationTitle("Prototype controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Reset the prototype?",
                                isPresented: $confirmingReset,
                                titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) {
                    store.reset()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Everything you've saved and sent will be cleared.")
            }
        }
    }

    // MARK: - Which backend

    /// **First thing in the sheet, before anything else.**
    ///
    /// Local test accounts became automatic for unconfigured debug builds, so
    /// the deliberate button press that used to prove a developer knew where
    /// they were is gone. Everything that made the mode *legible* rather than
    /// merely *chosen* had to get louder to compensate, and this is the loudest
    /// of them: the answer to "which account system am I on" is now the first
    /// thing in the prototype controls, not a `LabeledContent` row eight
    /// sections down.
    ///
    /// The Account section still carries the same fact in its Backend row, and
    /// the sign-in screen still carries the banner. Three statements of one
    /// thing is duplication everywhere else in this app and is the correct
    /// amount here — the failure being defended against is a person drawing
    /// conclusions about a server they were never connected to.
    @ViewBuilder
    private var backendBanner: some View {
        #if DEBUG
        if session.backend == .localTesting {
            Section {
                LocalTestingBanner()
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } footer: {
                Text("Automatic because no SupabaseConfig.plist is present and this is a debug build. Add the file to switch to the real account path — configuration always wins. Release builds never do this.")
            }
        }
        #endif
    }

    // MARK: - Account

    /// Where signing out lives, and where the backend is stated plainly (§18).
    ///
    /// The "Backend" row is the most important thing in this menu. The failure
    /// this whole section is built against is believing you exercised Supabase
    /// when you were on the stand-in, and the defence is that the answer is
    /// always one glance away and never inferred.
    @ViewBuilder
    private var accountSection: some View {
        Section {
            LabeledContent("Backend", value: session.backend.title)

            if let profile = session.phase.profile {
                LabeledContent("Name", value: profile.displayName)
                LabeledContent("Handle", value: Handle.display(profile.handle))
                LabeledContent("Taste onboarding",
                               value: profile.tasteOnboardingComplete ? "Complete" : "Outstanding")
                // Truncated because the whole UUID wraps to three lines and the
                // first block is enough to tell two accounts apart.
                LabeledContent("User id", value: String(profile.userID.uuidString.prefix(8)))
            } else {
                LabeledContent("Signed in", value: "No")
            }

            // Proves the §18 fix from inside the app: the id here is the account
            // whose reading data is loaded, and it must equal the signed-in user
            // or be absent. A mismatch is one reader looking at another's diary.
            LabeledContent("Local data scoped to",
                           value: store.activeAccount.map { String($0.uuidString.prefix(8)) } ?? "—")

            #if DEBUG
            action("Re-run taste onboarding",
                   "Back to Pick, Rate, Favorite Books and People. Keeps your account.",
                   "arrow.uturn.backward") {
                session.replayTasteOnboarding()
                dismiss()
            }
            .disabled(session.phase.profile == nil)
            #endif

            Button(role: .destructive) {
                Task {
                    await session.signOut()
                    dismiss()
                }
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .disabled(session.phase.profile == nil)
        } header: {
            Text("Account")
        } footer: {
            Text("\(AccountConfig.diagnostic). Signing out ends the session and returns to the first-run flow. It leaves this account's library, diary, ratings, rankings and lists on the device, filed under its own id — signing back in finds them, and a different account cannot see them. Only identity, follows and Favorite Books exist on the server; nothing else syncs, and a second device will show an empty diary.")
        }

        #if DEBUG
        localTestingSection
        #endif

    }

    /// The one-time adoption path for the pre-account file (§20).
    ///
    /// **Rendered at the top of the menu, above the evaluation controls**, and
    /// only while the file exists. It was written at the bottom, next to the
    /// other account rows, which is where it belongs by subject and exactly the
    /// wrong place by use: it is a one-time recovery offer for a reader who has
    /// just discovered their library is missing, and it sat below twelve
    /// sections of haptic presets and card fixtures. Found by trying to reach
    /// it — several screens of scrolling, on a sheet long enough that the drag
    /// keeps being read as a dismiss.
    ///
    /// It costs the top of the menu nothing, because it removes itself: adopting
    /// retires the file, and the section is gone on the next redraw.
    ///
    /// This section used to be a dead end: a sentence saying a file existed, was
    /// never read, and would not be deleted. Correct as far as it went, and it
    /// left the reader's actual prototype library sitting on disk with no way
    /// back — which is a worse answer than the leak it was avoiding, because at
    /// least the leak was visible.
    ///
    /// The reason it was a dead end was a real one: adopting the file
    /// *automatically* would hand a stranger's reading history to whoever
    /// happened to sign in first. What that argues for is a decision, not a
    /// refusal. So: shown only when the file is there, offered only to a
    /// signed-in account, stating what is in the file and which world it came
    /// from, behind a confirmation, backing up what it replaces, and retiring
    /// the source so it can only happen once.
    @ViewBuilder
    private var preAccountSection: some View {
        if let snapshot = store.preAccountSnapshot {
            Section {
                LabeledContent("Written in", value: snapshot.world.title)
                LabeledContent("Contents", value: snapshot.summary)

                Button {
                    confirmingAdoption = true
                } label: {
                    Label("Adopt into this account", systemImage: "arrow.down.doc")
                }
                .disabled(store.activeAccount == nil || snapshot.isEmpty)
                .confirmationDialog(
                    "Adopt this reading record?",
                    isPresented: $confirmingAdoption,
                    titleVisibility: .visible
                ) {
                    Button("Adopt — replaces what's here") {
                        adopted = store.adoptPreAccountData()
                        showingAdoptionResult = true
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text(adoptionWarning(snapshot))
                }
            } header: {
                Text("Pre-account save file")
            } footer: {
                Text(preAccountFooter(snapshot))
            }
        }
    }

    /// The sentence in the confirmation. Names the cost, and names the seeded
    /// world by name when that is what is about to arrive — importing the demo
    /// corpus onto a real account is the one outcome somebody would regret and
    /// not immediately understand.
    private func adoptionWarning(_ snapshot: DeweyStore.PreAccountSnapshot) -> String {
        // Not lower-cased. `summary` is already sentence-safe, and folding it
        // turned "1 of 4 Favorite Books" into "favorite books" — the same
        // mistake as the count, one layer up: it is a fixed term naming the four
        // on a profile, not an adjective and a noun.
        var text = "Brings in \(snapshot.summary). "
        if snapshot.world == .seeded {
            text += "This file was written in the Seeded world, so it contains demo content — a populated diary and ranked library that were never yours — as well as anything you added. "
        }
        text += "It replaces this account's current reading record, which is kept as a file beside it. The pre-account file is renamed afterwards, so this can only be done once."
        return text
    }

    private func preAccountFooter(_ snapshot: DeweyStore.PreAccountSnapshot) -> String {
        if store.activeAccount == nil {
            return "dewey-prototype-v4.json predates account scoping and belongs to no account. Sign in before adopting it — it has to go somewhere."
        }
        if snapshot.isEmpty {
            return "dewey-prototype-v4.json predates account scoping. There is nothing in it worth adopting, so there is nothing to do; delete it by hand if it bothers you."
        }
        return "dewey-prototype-v4.json predates account scoping, so nothing reads it. Adopting copies it into the signed-in account. Nothing is deleted either way: the source is renamed and the account's current record is kept alongside the new one."
    }

    #if DEBUG
    /// Only rendered while actually in local mode, or while it is reachable.
    /// A configured build shows nothing here at all — there is no toggle to
    /// press and therefore no way to wander into the stand-in by accident.
    @ViewBuilder
    private var localTestingSection: some View {
        if session.backend == .localTesting {
            Section {
                LocalTestingBanner()
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

                Picker("Test account", selection: Binding(
                    get: { AccountServices.testAccount },
                    set: { next in Task { await session.useTestAccount(next) } }
                )) {
                    ForEach(AccountServices.TestAccount.allCases) { account in
                        Text(account.title).tag(account)
                    }
                }
                .disabled(session.phase.profile != nil)

                action("Leave local test mode",
                       "Back to the configuration screen. Add SupabaseConfig.plist to use the real thing.",
                       "arrow.uturn.left") {
                    AccountServices.setLocalTestingMode(false)
                    Task { await session.reloadServices() }
                    dismiss()
                }

                Button(role: .destructive) {
                    session.forgetLocalAccount()
                    dismiss()
                } label: {
                    Label("Forget all local test accounts", systemImage: "trash")
                }
            } header: {
                Text("Local test accounts")
            } footer: {
                Text("Switching accounts requires signing out first, so a session can never straddle two. Each test account gets its own local reading data — switching between them is how the account-scoping fix is verified by hand.")
            }
        }
    }
    #endif

    private func action(_ title: String, _ detail: String, _ symbol: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .frame(width: 22)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Comparison controls

    /// One selectable option, laid out exactly like `action` above so the sheet
    /// stays one thing.
    ///
    /// A checkmark list rather than a `Picker`: every option here needs a line
    /// of prose under it, and an inline picker's own label would fight the
    /// section header for the same slot. It also means the active choice is
    /// legible without opening a menu, which is the whole point — the founder is
    /// comparing, so they need to see what they are currently feeling.
    private func option(_ title: String, _ detail: String, isOn: Bool, _ select: @escaping () -> Void) -> some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 12) {
                // One style, two symbols: a ternary across `.tint` and a
                // hierarchical style would need type erasure for no gain.
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .frame(width: 22)
                    .foregroundStyle(.tint)
                    .opacity(isOn ? 1 : 0.35)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    /// Spelled out from the mode's own numbers rather than a second switch in
    /// this file, so the line cannot drift from `ScaleMode`.
    ///
    /// The count is rounded before truncation: `(10.0 - 0.1) / 0.1` is
    /// 98.99999999999999 in binary floating point, and `Int()` on that would
    /// quietly report 99 rungs instead of 100. The two numerals go through
    /// `Rating.compact` so they read the way every other numeral in the app
    /// does — "1", not "1.0".
    private func rungs(_ mode: ScaleMode) -> String {
        let count = Int(((10.0 - mode.lowerBound) / mode.step).rounded()) + 1
        let step = Rating.clamping(mode.step).compact
        let floor = Rating.clamping(mode.lowerBound).compact
        return "Steps of \(step) — \(count) rungs, \(floor) to 10."
    }

}

// MARK: - Toolbar entry

extension View {
    /// Puts the prototype controls behind one toolbar button. Applied to the
    /// Edition and the Library so it is reachable from wherever you are.
    func debugMenu(isPresented: Binding<Bool>) -> some View {
        self
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented.wrappedValue = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(Theme.Palette.inkSoft)
                    }
                    .accessibilityLabel("Prototype controls")
                }
            }
            .sheet(isPresented: isPresented) { DebugMenuView() }
    }
}
