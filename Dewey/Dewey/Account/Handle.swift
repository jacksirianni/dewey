import Foundation

/// The rules a handle has to satisfy, stated once.
///
/// **This is a mirror, not the authority.** The same rules are enforced in
/// Postgres — a `CHECK` constraint on the shape and a unique index on the
/// lower-cased form (`supabase/0001_identity.sql`). This copy exists so a reader
/// finds out that a space is not allowed while they are typing it, rather than
/// after a round trip. If the two ever disagree, the database wins and the client
/// is the bug: a client-side rule can be skipped by anyone running a modified
/// build, so nothing here may be the only thing standing between a bad handle and
/// the table.
///
/// **Case is preserved for display and ignored for uniqueness.** A reader who
/// types `JackS` is shown `@JackS`; nobody else can then take `jacks`, `JACKS` or
/// `jAcKs`. That split is why `normalize` exists separately from `validate` — the
/// former produces the key, the latter judges what was typed.
enum Handle {
    static let minLength = 3
    static let maxLength = 20

    /// The uniqueness key: lower-cased, `@` stripped, surrounding space gone.
    /// Must agree exactly with the `handle_normalized` generated column.
    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("@") { value.removeFirst() }
        return value.lowercased()
    }

    /// Strips what a reader might paste without meaning to, so `validate` judges
    /// the handle they intended. Deliberately not applied on every keystroke —
    /// silently deleting a character as it is typed is worse than saying no.
    static func sanitizeForEntry(_ raw: String) -> String {
        var value = raw
        while value.hasPrefix("@") { value.removeFirst() }
        value = value.filter { !$0.isWhitespace }
        return String(value.prefix(maxLength))
    }

    enum Verdict: Equatable {
        case empty
        case valid(normalized: String)
        /// A sentence to show under the field. Written as a statement of the rule
        /// rather than an accusation — "Handles are 3 characters or more", not
        /// "Too short".
        case invalid(String)

        var isValid: Bool { if case .valid = self { return true }; return false }
    }

    private static let allowed = CharacterSet
        .alphanumerics
        .union(CharacterSet(charactersIn: "_."))

    static func validate(_ raw: String) -> Verdict {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed

        if candidate.isEmpty { return .empty }

        if candidate.count < minLength {
            return .invalid("Handles are at least \(minLength) characters.")
        }
        if candidate.count > maxLength {
            return .invalid("Handles are at most \(maxLength) characters.")
        }
        // Checked against the ASCII set on purpose. `CharacterSet.alphanumerics`
        // includes every script's letters and digits, and a handle is an address
        // people have to be able to retype from memory or read aloud.
        guard candidate.unicodeScalars.allSatisfy({ allowed.contains($0) && $0.isASCII }) else {
            return .invalid("Letters, numbers, underscores and periods only.")
        }
        guard let first = candidate.first, first.isLetter || first.isNumber else {
            return .invalid("Handles start with a letter or a number.")
        }
        guard let last = candidate.last, last != "." else {
            return .invalid("Handles don't end with a period.")
        }
        if candidate.contains("..") {
            return .invalid("Handles don't contain two periods in a row.")
        }

        return .valid(normalized: candidate.lowercased())
    }

    /// How a handle is written wherever a reader can see it. The `@` is display,
    /// never storage — it is not in the column and not in the uniqueness key.
    static func display(_ handle: String) -> String {
        handle.hasPrefix("@") ? handle : "@\(handle)"
    }

    /// A first guess seeded from the name Apple hands back, offered as a
    /// starting point rather than assigned. Returns nil when nothing usable
    /// survives — a reader called "李" should get an empty field and a free
    /// choice, not a mangled transliteration.
    static func suggestion(from displayName: String) -> String? {
        let stripped = displayName.lowercased().unicodeScalars
            .filter { allowed.contains($0) && $0.isASCII }
        var candidate = String(String.UnicodeScalarView(stripped))
        while candidate.hasSuffix(".") { candidate.removeLast() }
        candidate = String(candidate.prefix(maxLength))
        return validate(candidate).isValid ? candidate : nil
    }
}
