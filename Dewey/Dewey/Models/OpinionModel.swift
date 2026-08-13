import Foundation

/// Dewey's judgements, and the words the app is allowed to use for them.
///
/// **Four separate concepts, and they are separate all the way down** (§19):
///
/// - **Your Score** — how good *this* book was, on its own. `ScoreCopy`.
/// - **Favorite** — a book you love. Unlimited. `FavoriteCopy`.
/// - **Favorite Books** — the four you feature on your profile. `FavoriteBooksCopy`.
/// - **Your Ranking** — which of your books you prefer, in order. `RankingCopy`.
///
/// A fifth number lives next to them and belongs to nobody in this file: the
/// **Dewey Score**, the crowd's average, `DeweyStore.communityAverage`. It is
/// not a judgement of the reader's, which is why it has no copy here.
///
/// The prototype walkthrough on 2026-08-05 found the product's most important
/// contradiction: Dewey asked for **one opinion in three incompatible
/// currencies**. Logging a single book requested a 0.1–10.0 score, a Favorite
/// mark, and a pairwise ranking — then displayed a score of 8 beside a rank of
/// No. 1 out of 14, above a book scored 10, with nothing anywhere on screen
/// acknowledging that those two numbers were answering different questions.
/// A reader could not tell which one the app believed, which one their followers
/// saw, or which one drove recommendations.
///
/// **§19 finished the job the naming had left half-done.** Score and Ranking had
/// one meaning each in this file and several on screen: the score was "Rating"
/// in the log sheet and "Your rating" in the Library; ranking was one concept in
/// the copy and five orderings in the store; and `BookList` badged a curated
/// list "ranked", one tab from "Your Ranking". A concept that is defined once
/// and named three ways is not defined.
///
/// The fix is **not** to collapse the three into one, and it is not to make one
/// derive from another. All three are worth having; they were never in conflict
/// as *ideas*. They were in conflict because the app never said what each was
/// for. So each one gets exactly one job, stated here, in the app's own words,
/// once — and every surface reads its copy from this file rather than inventing
/// a local phrasing.
///
/// The scale itself is unchanged (§12.2). 0.1–10.0 was reconsidered during this
/// pass and deliberately kept: the contradiction was never the granularity, it
/// was the absence of an explanation, and rescaling would have changed the
/// currency without resolving the confusion between currencies.
enum Judgement {

    // MARK: - Your Score

    /// **How good was this book to you?**
    ///
    /// A judgement of the work. Optional, public, and independent of identity
    /// and of ranking. A score is the one of the three that is *about the
    /// book* rather than about the reader's relationship to it: it is arrived
    /// at by looking at one book, and it does not move when another book is
    /// scored.
    ///
    /// **It is called "Your Score", and the crowd's number is the "Dewey
    /// Score"** — `DeweyStore.communityAverage`, drawn in `ScoreCircle` at the
    /// top of a book page. Two numbers on the same 0.1–10.0 scale sit within an
    /// inch of each other there, so the possessive is doing all the work and it
    /// is never dropped: a bare "Score" on either of them makes the page
    /// unreadable. The visual split is the older half of the rule and still
    /// holds — a circled numeral is four thousand strangers, a bare serif
    /// numeral is you (`RatingMark`).
    ///
    /// The type behind it is still `Rating`, and the on-disk key is still
    /// `rating`. Renaming a persisted shape to match a label would cost every
    /// reader their history to settle a question about words.
    enum ScoreCopy {
        static let title = "Your Score"
        static let question = "How good was this book to you?"
        static let short = "Your evaluation of the book."
        /// Shown under the score control the first time it can be reached.
        ///
        /// Deliberately says nothing about Ranking. The score-versus-ranking
        /// distinction is carried by `RankingCopy.explainer`, which appears at
        /// the moment ranking is *offered* — which is where the confusion
        /// actually happens, and where a reader has the two things side by side
        /// to compare. Saying it here as well would put two disclaimers on a
        /// control whose whole design goal is a five-second log.
        static let explainer = "How good you thought it was. Optional, and separate from marking it a Favorite."

        /// **The onboarding variant, which says the name out loud** (§19.2).
        ///
        /// A fresh-account walkthrough found the gap: onboarding's second step
        /// asks "What did you think?", hands the reader a 0.1–10.0 slider, and
        /// never once calls the result anything. Minutes later — on the first
        /// log — the app says "**Your Score** says how good you thought a book
        /// was. Your Ranking says which of your books you prefer", explaining a
        /// new concept in terms of one the reader was never taught the name of.
        ///
        /// It also drops `explainer`'s "separate from marking it a Favorite",
        /// which is right in the log sheet — the Favorite toggle is directly
        /// underneath it there — and a forward reference here: the Favorite
        /// *mark* appears nowhere in onboarding, and the step that follows this
        /// one is about Favorite **Books**, which is a third thing again. One
        /// unlearned word is enough.
        static let onboardingExplainer =
            "This is Your Score — how good you thought the book was, on its own. Optional, and you can change it later."
    }

    // MARK: - Favorite

    /// **Do you love this book?**
    ///
    /// Independent of quality, and emphatically not a super-like or a synonym
    /// for a top score. A Favorite may be a 6 you would defend to the death; a
    /// flawless 10 may be a book you admire and do not love.
    ///
    /// **Unlimited, and private to no one.** A reader may mark as many Favorites
    /// as they like, whenever they like, from the log sheet or the book page.
    /// Nothing about this mark is scarce, and nothing about it is a ranking.
    ///
    /// **Not the same thing as `FavoriteBooksCopy`** (§14). Favorite is the
    /// mark on a book; Favorite Books are the four a reader deliberately chooses
    /// to feature on their profile. The two were briefly one concept and one
    /// field, which meant the profile silently re-published every mark a reader
    /// made and a reader who loved thirty books had four of them chosen for
    /// them. They are two fields and two decisions again — see
    /// `ReaderProfile.favoriteBookIDs`.
    enum FavoriteCopy {
        static let title = "Favorite"
        static let plural = "Favorites"
        static let question = "Do you love this book?"
        /// The one-line definition. Stated once, in full, wherever the concept
        /// is first offered — the log sheet and the book page.
        static let definition = "A book you love. Mark as many as you like."
        /// The shorter form, for rows too tight for the full definition.
        static let short = "Not a score. A book you love."
    }

    // MARK: - Favorite Books

    /// **Which four books do you want on your profile?**
    ///
    /// A separate decision from marking a book a Favorite, and separate again
    /// from rating or ranking it. These four are chosen by hand, one at a time,
    /// and they are the only books a stranger sees at the top of a profile.
    ///
    /// **Nothing computes this list.** It is not the four highest-rated books,
    /// not the top four of a ranking, and not the four most recently marked
    /// Favorite. A reader picks them, and the picking is the point: four forces
    /// a real choice and reads as identity, lifted from Letterboxd's four
    /// favourites, which is the best-designed scarcity in that product.
    ///
    /// **Exactly four** — the profile shows four slots whether or not they are
    /// full, because three covers and a gap says "unfinished" where three covers
    /// alone says "this is the list".
    enum FavoriteBooksCopy {
        static let title = "Favorite Books"
        static let count = 4
        static let question = "Which four books do you want on your profile?"
        /// Shown on your own profile and in the picker.
        static let definition = "The four books you feature on your profile. You choose them, one at a time."
        /// Shown on someone else's profile.
        static let profileBlurb = "Four books they chose to show — not their highest-rated, not their top-ranked."
        /// The empty slot's label, and the picker's invitation.
        static let choose = "Choose"
        static let edit = "Edit"

        /// The honest-empty line for your own profile.
        static let emptyMine = "You haven't chosen your four yet. It is meant to be hard."

        static func emptyTheirs(_ firstName: String) -> String {
            "\(firstName) hasn't chosen their four yet."
        }

        /// Spoken label for a filled slot on someone else's profile.
        static func spokenSlot(_ firstName: String) -> String {
            "One of \(firstName)'s Favorite Books"
        }
    }

    // MARK: - Review

    /// **What did it do to you?**
    ///
    /// The long-form half of an opinion — the paragraph, as against the number.
    /// It is not a fourth judgement: a review carries a rating rather than
    /// competing with one, and a reader who writes nothing has still recorded a
    /// complete reading.
    ///
    /// **This was called a Reflection until 2026-08-09.** The name was chosen to
    /// signal a register — what a book did to you, not a verdict for an audience
    /// — and it could not do that job, because a word cannot carry a tone that
    /// its readers do not already associate with it. Nobody calls the thing they
    /// write under a book a reflection, so the name made a reader decode the ask
    /// before answering it.
    ///
    /// **The register moved into the prompt, which is where it belongs.** The
    /// object is a Review; the question is still `question` below, and it is
    /// deliberately not "Write your review of this book". Naming the object
    /// plainly and asking for it expressively is the whole of the fix — the
    /// alternative, a generic object *and* a generic prompt, is the school-like
    /// register this product exists to avoid.
    ///
    /// **Not a private note.** `DiaryEntry.privateNote` is a separate object
    /// with a separate audience — one line for yourself, never published, never
    /// prompted for — and nothing here applies to it.
    enum ReviewCopy {
        static let title = "Review"
        static let plural = "Reviews"
        /// The action, wherever writing is offered.
        static let write = "Write a review"
        /// The composer's prompt. Expressive on purpose; see above.
        static let question = "What did it do to you?"
        /// Shown under the field the first time it can be reached.
        static let explainer = "As long or as short as you like. Published to whoever you choose below."
        static let spoilerToggle = "Contains spoilers"
        static let draftToggle = "Keep as a draft"
        static let draftBlurb = "Saved with the entry, published by nobody."
        /// Book page, when nobody has written anything yet.
        static let emptyOnBook = "Nothing written here yet."
    }

    // MARK: - Ranking

    /// **Which of your books do you prefer?**
    ///
    /// A personal ordering, first-class and independent of score. Built from
    /// pairwise comparisons, always optional, and abandonable at any point.
    ///
    /// **There is exactly one of it.** Not one per year, per genre, per author
    /// or per list — `PersonalRanking` is a single ordered claim, and every
    /// "Sci-Fi ranking" or "2026 ranking" a reader sees is that one list with
    /// rows hidden. Dewey shipped five independent orderings behind a
    /// `RankingContext.Kind` enum and a chip switcher, which meant a book could
    /// hold two incompatible positions at once and neither was the answer to
    /// "which do you prefer".
    enum RankingCopy {
        static let title = "Your Ranking"
        static let question = "Where does this book sit among your books?"

        /// **The one comparison question**, used for every pair in every round.
        ///
        /// The flow used to rotate between "Which stayed with you more?",
        /// "Which would you recommend first?" and "Which would you rather
        /// reread?" — which reads as variety and is not. Those are three
        /// genuinely different questions: the book that stayed with you is
        /// often not the one you would recommend first. Collapsing their
        /// answers into a single ordering silently corrupts it. If Dewey ever
        /// wants those orderings, they are separate rankings, not alternating
        /// prompts feeding one list.
        ///
        /// **It also stopped being "Which belongs higher in your personal
        /// library?"**, which was one question but the wrong one: "belongs" is
        /// a claim about merit, and a reader answering it honestly answers with
        /// their score a second time. Preference is the thing ranking is for
        /// and the thing a score cannot say, so the prompt asks for it in the
        /// plainest words available.
        static let comparison = "Which book do you prefer?"

        /// Sits under the question, in every round.
        ///
        /// Preference is the vaguest of the three judgements on purpose, and a
        /// reader given no steer will substitute the precise question they
        /// already know — "which is better?" — which is their score. This line
        /// names the two things preference is actually made of without turning
        /// either into a separate prompt.
        static let comparisonSupport = "Think about which you like more, or which means more to you."

        /// Shown **before** the first comparison, every time ranking is offered.
        /// This sentence is the actual resolution of the contradiction: it is
        /// what makes an 8.8 at No. 2 legible instead of broken.
        static let explainer = """
            \(ScoreCopy.title) says how good you thought a book was. \(title) says \
            which of your books you prefer. They do not have to agree.
            """

        /// The same fact in one line, for rows with no room for the pair of
        /// sentences above.
        static let contrast = "Score what you thought of it. Rank where it sits among your books."

        static let optional = "Ranking is optional. Your log is already saved."

        // The escape hatches. They are the most considerate thing in the flow.
        static let equal = "About equal"
        static let incomparable = "Too different to compare"

        /// **"Done for now", not "Stop here".**
        ///
        /// Both leave, and only one of them says the ranking is still open.
        /// "Stop" reads as an abort on a job with a finish line; there is no
        /// finish line — a reader who answers one comparison and leaves has a
        /// real ranking, and Dewey uses what they gave it.
        static let stop = "Done for now"

        // MARK: The boundary question

        /// **The one extra comparison, offered only at the top** (§19.1).
        ///
        /// A capped session on a large ranking can end with the candidate's
        /// position still open across the first few places — every answer said
        /// "I prefer the new one" and the result still read No. 3, because the
        /// reader was never shown their own No. 1. That is honest and it reads
        /// as the app disagreeing with them.
        ///
        /// This is not a seventh round and must never be described as one. It
        /// is one question, against one named book, asked only when the answer
        /// could move the book into the top few — see
        /// `RankingInsertion.offersBoundaryQuestion`. Mid-list it is not
        /// offered at all, because two positions in the middle of three hundred
        /// is not worth a tap.
        ///
        /// **The prompt itself does not change.** "Which book do you prefer?"
        /// is still the question and the support line is still the support
        /// line; these two strings only frame *why there is one more*. Changing
        /// the question here would be the rotating-prompts bug returning
        /// through the one door left open.
        static let boundaryKicker = "One last choice"

        /// Sits under the support line. Says what is at stake, in the reader's
        /// terms, without claiming the placement so far was wrong.
        static func boundaryNote(position: Int) -> String {
            position == 1
                ? "This looks like it could be your new No. 1."
                : "This looks like one of your very top books."
        }
    }

    // MARK: - Tuning

    /// **Revisiting a ranking that has drifted.**
    ///
    /// Every string here is careful not to say the current order is wrong. It
    /// is not wrong; it is the honest result of the comparisons the reader
    /// actually made, and a product that tells people their taste needs
    /// correcting is a product they stop being honest with.
    ///
    /// What tuning is *for* is the places the ranking is thin: a book placed on
    /// one comparison sits where a single tap put it, and the reader never said
    /// anything about the twenty books around it. That is a gap in the
    /// evidence, not an error in the taste.
    ///
    /// Triggered by uncertainty in the data and by nothing else — see
    /// `DeweyStore.tuningCandidates`. No schedule, no notification, no streak.
    enum TuningCopy {
        static let title = "Tune your ranking"
        static let action = "Tune"

        /// Head of the tuning sheet.
        static let question = "A few more comparisons?"

        /// Says what tuning does without implying the list is broken.
        static let explainer = """
            These books were placed on very few comparisons, so Dewey is not \
            confident about where they sit. Nothing here is wrong — there is \
            just less behind it.
            """

        /// The quiet row that offers it, when there is something to offer.
        static func invitation(_ count: Int) -> String {
            count == 1
                ? "1 book is loosely placed."
                : "\(count) books are loosely placed."
        }

        /// Shown when the ranking is as well-supported as it can be.
        static let settled = "Every book has been compared more than once. Nothing to tune."

        /// The reassurance under a tuning comparison.
        ///
        /// Not `RankingCopy.optional`, which promises that "your log is already
        /// saved" — true after a log and meaningless here, where nothing was
        /// logged and the ranking already exists. What a tuning reader needs
        /// reassuring about is that leaving does not undo anything.
        static let optional = "Leave whenever you like. Everything you have answered is kept."

        /// End of a tuning session.
        static let finished = "Updated with what you told us."
    }

    // MARK: - Visibility

    /// **Your Ranking is on your profile, and it can be taken off.**
    ///
    /// On by default and deliberately quiet to turn off: a ranking is a taste
    /// artifact of the same order as Favorite Books, Reviews, Lists and the
    /// Diary, and a product that asks permission before showing one is telling
    /// the reader it is embarrassing. The control exists because some people
    /// will want it, and it lives in an overflow menu because nobody needs to
    /// meet it on the way in.
    enum RankingPrivacyCopy {
        static let hide = "Hide from your profile"
        static let show = "Show on your profile"
        /// Shown on your own profile once hidden, so the state is never a
        /// mystery — a section that has silently vanished reads as a bug.
        static let hidden = "Hidden from your profile. Only you can see this."
    }
}

// MARK: - Collection vocabulary

/// The words for *where books live*, fixed so that one concept never wears two
/// names and one name never covers two concepts.
///
/// The walkthrough found "Shelves" meaning reading status in the Library tab
/// and "Bookshelves" meaning curated collections on the profile — the same word
/// for two different things, one tab apart. And a Library filter called "Set
/// Down" that silently contained Paused and Did Not Finish, a phrase used
/// nowhere else in the app, so marking a book Paused made it unfindable.
///
/// **"Shelf" had come back, in a third meaning.** That claim was written down
/// once and then not enforced, so by this pass the word was live in nine
/// user-visible strings and had acquired a *new* referent nobody had decided
/// on: Search called the external catalog "the wider shelf", called the local
/// corpus "the whole shelf", and a provenance line read "From Priya's shelf" —
/// which is her library, the one thing `library` above is supposed to name.
/// Three meanings, none of them the two that were banned. The constants below
/// now cover every place the word was reached for, and `Provenance` and
/// `SearchView` read from them, so there is nowhere left for a tenth string to
/// invent a fourth sense of it.
///
/// Four words, four meanings, no overlap:
enum Vocabulary {
    /// Everything the reader has saved, in any state. The tab is called this,
    /// and so is *another* reader's collection — "From Priya's library".
    static let library = "Library"

    /// One of the five `ReadingStatus` values. Never "shelf".
    static let status = "Status"
    static let readingStatus = "Reading Status"

    /// Named, curated, ordered collections the reader makes. Never "shelves"
    /// and never "bookshelves".
    ///
    /// **And never "ranked", either** (§19). A list whose order is a claim is an
    /// *ordered* list — `BookList.isOrdered`. It is hand-arranged by dragging,
    /// scoped to its own premise, and there can be any number of them.
    /// `Judgement.RankingCopy.title` is one app-wide ordering built from
    /// comparisons. Two things called "ranked" one tab apart is the exact shape
    /// of the bug the rest of this enum exists to prevent.
    static let lists = "Lists"
    static let list = "List"
    static let orderedList = "Ordered list"

    /// Books Dewey can reach but does not hold an opinion about — the external
    /// provider behind `BookCatalogProvider`.
    ///
    /// Deliberately not the provider's name (§16): the reader has no
    /// relationship with Open Library and cannot act on it, and naming it dates
    /// every string here to whichever supplier sits behind the seam today.
    /// "Catalogue" is the word a reader already has for *books an institution
    /// can find you*, and it is the sense the app is named after.
    static let widerCatalogue = "The wider catalogue"

    /// Everything Dewey itself holds — the browse surface's resting state.
    static let everything = "All books"
}

// MARK: - Following

/// The words for **following a reader**, and the one sentence saying what
/// following actually does.
///
/// Following is not a judgement — it makes no claim about a book — and it is not
/// a place books live, so it sits beside `Judgement` and `Vocabulary` rather
/// than inside either. It is written down here for the same reason they are:
/// the control now exists on two surfaces (onboarding's suggestion rows, and a
/// reader's profile) and two screens inventing their own word for one two-state
/// action is exactly how "Follow" becomes "Followed" one tab over.
///
/// **The strings here are the visible text, and that is load-bearing.** Voice
/// Control matches a spoken command against what a control *announces*, so a
/// button reading "Follow" that announces anything else is a button a Voice
/// Control user cannot reach at all (WCAG 2.5.3, Label in Name). Every spoken
/// string below is built from the same two words the button draws, by the same
/// function, so the two cannot drift apart — the lesson `editVerb` already
/// learned on the Favorite Books head.
enum FollowCopy {
    /// Not following yet: the action.
    static let follow = "Follow"

    /// Already following: the state, shown as the label.
    ///
    /// Deliberately not "Unfollow". A button that reads "Unfollow" states the
    /// destruction rather than the fact, so the page answers "do you want to
    /// stop?" — a question the reader did not ask — where "Following" answers
    /// "what is true right now?", which is the one they came with.
    static let following = "Following"

    /// The single source for the word. Both the drawn label and the spoken one
    /// come through here.
    static func verb(isFollowing: Bool) -> String { isFollowing ? following : follow }

    /// Spoken state, for `accessibilityValue`. The label changes with state and
    /// the value says it outright, because a control whose *name* is its state
    /// is ambiguous the moment you cannot see whether the chip is filled.
    static func state(isFollowing: Bool) -> String {
        isFollowing ? "Following" : "Not following"
    }

    /// Spoken name. Carries the reader, and *contains* the visible word, which
    /// is what keeps "tap Follow" working.
    static func spokenLabel(_ firstName: String, isFollowing: Bool) -> String {
        "\(verb(isFollowing: isFollowing)) \(firstName)"
    }

    /// What the tap does. Non-obvious enough to need saying: nothing about a
    /// filled capsule tells a reader it changes what arrives on Sunday.
    static func hint(isFollowing: Bool) -> String {
        isFollowing
            ? "Stops their books reaching your weekly edition."
            : "Lets their books reach your weekly edition."
    }

    /// The mechanic, stated once, above the control at the end of the argument.
    ///
    /// Phrased as how the edition is *built* rather than as what the reader will
    /// receive. "Follow them and their books join your edition" would be a
    /// promise about next Sunday that the follow set alone cannot keep — a
    /// followed reader with nothing in this week's run adds nothing, and an app
    /// that quietly overstates its own output is the thing §13.7 exists to stop.
    static let mechanic = "Dewey's weekly edition is built from the readers you follow."
}
