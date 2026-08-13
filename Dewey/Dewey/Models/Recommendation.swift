import Foundation

/// A book handed from one person to one person, with a reason.
///
/// The reason is required. A book arriving with no reason is a link, and links
/// are what Dewey is trying to beat — "why not just text them?" is answered by
/// specificity, so a recommendation without it has no claim on anyone's time.
struct Recommendation: Identifiable, Hashable, Codable {
    let id: String
    let bookID: String
    let fromReaderID: String?   // nil means it came from you
    let toReaderID: String?     // nil means it came to you
    let reason: Reason
    let sentAt: Date
    var status: Status
    /// One private line back to the sender. Not a comment thread — two people,
    /// inside the context of one book.
    var reply: String?
    var reaction: Reaction?

    var isIncoming: Bool { fromReaderID != nil }

    enum Status: String, Codable, Hashable {
        case waiting
        case saved
        case declined
        /// The closure moment: they picked it up.
        case startedByRecipient
    }

    /// Tap-to-choose, or write your own. The presets exist to defeat the blank
    /// page — most people will not write a paragraph, and a product that only
    /// works for people who will is a product for a narrow few.
    enum Reason: Hashable, Codable {
        case preset(Preset)
        case written(String)

        var text: String {
            switch self {
            case .preset(let p): p.text
            case .written(let s): s
            }
        }

        enum Preset: String, Codable, Hashable, CaseIterable, Identifiable {
            case becauseYouLoved
            case forTheProse
            case forTheIdeas
            case madeMeThinkOfYou

            var id: String { rawValue }

            var text: String {
                switch self {
                // Was "Because you loved—", an em-dashed fragment waiting for a
                // book title the sheet never asks for. Sent as-is it arrived on
                // the recipient's card as the whole of the reason, in the slot
                // the product treats as the payload — a sender's actual words —
                // reading as a message that had been cut off.
                case .becauseYouLoved: "Because of what you already love"
                case .forTheProse: "For the prose"
                case .forTheIdeas: "For the ideas"
                case .madeMeThinkOfYou: "This made me think of you"
                }
            }
        }
    }

    /// One reaction, not a count. The quiet reader's entire vocabulary — someone
    /// who will never write a review will absolutely tap once to say "yes, this
    /// one." Displayed as a mark, never totalled, never ranked.
    enum Reaction: String, Codable, Hashable, CaseIterable, Identifiable {
        case noted
        case alreadyLoved
        case exactlyRight

        var id: String { rawValue }

        var label: String {
            switch self {
            case .noted: "Noted"
            case .alreadyLoved: "Already loved it"
            case .exactlyRight: "Exactly right"
            }
        }

        var symbol: String {
            switch self {
            case .noted: "bookmark"
            case .alreadyLoved: "heart"
            case .exactlyRight: "hand.thumbsup"
            }
        }
    }
}
