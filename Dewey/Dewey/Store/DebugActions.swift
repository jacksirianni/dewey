import SwiftUI

// TEMPORARY — prototype scaffolding.
//
// Everything in this file and in DebugMenuView.swift exists so the founder can
// trigger states that would otherwise take days of real network activity to
// reach. Delete both files and the two toolbar entries that present the menu,
// and nothing else in the app changes.
//
// Note on semantics: `Recommendation.reaction` and `.reply` always belong to
// the *recipient*. On an incoming recommendation that is you; on one you sent,
// it is them. So "reaction received" and "reply received" below simply write to
// the same fields on an outgoing recommendation.

extension DeweyStore {

    // MARK: - Incoming

    /// Drops a new recommendation into the edition, as if someone just sent it.
    /// Cycles through a few real pairings so repeated taps don't produce the
    /// same card.
    func debugReceiveRecommendation() {
        let scripts: [(reader: String, book: String, reason: String)] = [
            ("ana", "friday-black",
             "You gave Her Body and Other Parties an eight. This does the same thing to retail that Machado does to marriage."),
            ("marcus", "entangled-life",
             "You liked The Sixth Extinction and I think you'll like this more — it's the same rigour but it's actually hopeful."),
            ("tobias", "h-is-hawk",
             "Not poetry, before you close the app. It's about grief and a bird and it refuses to let either stand in for the other."),
            ("priya", "checkout-19",
             "A whole life told through what she read. You'll either finish it in two days or bounce hard off page nine."),
        ]

        let used = Set(recommendations.filter(\.isIncoming).map(\.bookID))
        guard let script = scripts.first(where: { !used.contains($0.book) }) ?? scripts.first else { return }

        let rec = Recommendation(
            id: UUID().uuidString,
            bookID: script.book,
            fromReaderID: script.reader,
            toReaderID: nil,
            reason: .written(script.reason),
            sentAt: Date(),
            status: .waiting,
            reply: nil,
            reaction: nil
        )
        withAnimation(Theme.Motion.gentle) {
            debugAppend(rec)
        }
    }

    // MARK: - Outgoing

    /// Fabricates a recommendation you sent, so the closure, reaction and reply
    /// states have something to attach to without walking the send flow first.
    func debugSendRecommendation() {
        let candidates = ["averno", "peregrine", "middlemarch", "drifts", "interpreter-maladies"]
        let used = Set(recommendations.filter { !$0.isIncoming }.map(\.bookID))
        guard let bookID = candidates.first(where: { !used.contains($0) }) else { return }

        let rec = Recommendation(
            id: UUID().uuidString,
            bookID: bookID,
            fromReaderID: nil,
            toReaderID: "priya",
            reason: .preset(.madeMeThinkOfYou),
            sentAt: Date(),
            status: .waiting,
            reply: nil,
            reaction: nil
        )
        withAnimation(Theme.Motion.gentle) {
            debugAppend(rec)
            // Also save it, so the book is reachable from the Library — in the
            // real flow you send from a book you already had open.
            save(bookID, provenance: Provenance(origin: .ownSearch, reason: nil, date: Date()))
        }
    }

    /// The signature moment, fired on demand rather than after the six-second
    /// delay the send flow uses.
    func debugFireClosure() {
        guard let target = debugLatestSent(matching: { $0.status != .startedByRecipient })
                ?? debugLatestSent(matching: { _ in true }) else { return }
        debugUpdate(target.id) { $0.status = .startedByRecipient }
        if let updated = recommendation(target.id) {
            withAnimation(Theme.Motion.gentle) { pendingClosure = updated }
        }
    }

    /// The recipient marks something you sent.
    func debugReceiveReaction() {
        guard let target = debugLatestSent(matching: { $0.reaction == nil })
                ?? debugLatestSent(matching: { _ in true }) else { return }
        withAnimation(Theme.Motion.standard) {
            debugUpdate(target.id) { $0.reaction = .exactlyRight }
        }
    }

    /// The recipient replies, privately, to something you sent.
    func debugReceiveReply() {
        guard let target = debugLatestSent(matching: { $0.reply == nil })
                ?? debugLatestSent(matching: { _ in true }) else { return }
        withAnimation(Theme.Motion.standard) {
            debugUpdate(target.id) { $0.reply = "Started it on the train. You were right about the first thirty pages." }
        }
    }

    // MARK: - Inspection helpers for the menu

    var debugSentCount: Int { recommendations.filter { !$0.isIncoming }.count }
    var debugWaitingCount: Int { incoming.count }

    /// Distinct books carrying a Favorite mark on any diary entry. Counted by
    /// book rather than by entry so a reread does not read as two Favorites —
    /// and shown next to the profile four so the two are visibly independent.
    var debugFavoriteCount: Int {
        Set(diary.filter(\.isFavorite).map(\.bookID)).count
    }

    private func debugLatestSent(matching predicate: (Recommendation) -> Bool) -> Recommendation? {
        recommendations
            .filter { !$0.isIncoming && predicate($0) }
            .max { $0.sentAt < $1.sentAt }
    }
}
