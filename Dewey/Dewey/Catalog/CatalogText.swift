import Foundation

/// Cleaning up after an open catalog (§16).
///
/// Open Library descriptions are written by whoever last edited the record, in
/// no particular format, and they arrive carrying things Dewey must not print:
/// Markdown emphasis, HTML, footnote plumbing, and — routinely, on popular
/// novels — pirate-PDF link spam appended to the end of the blurb. The live
/// record for *Tomorrow, and Tomorrow, and Tomorrow* ends its otherwise decent
/// synopsis with a bolded link to a "pdf" site, and the first build of this
/// integration set that on the page verbatim.
///
/// So the rule is the same one the rest of the app follows: print what is
/// genuinely the book's, and drop what isn't. A description is prose. Anything
/// that is markup, a citation, or an advertisement is removed rather than
/// rendered, and if that leaves nothing, the About section does not appear.
///
/// **Everything here is line-scoped, and that is a correctness requirement
/// rather than tidiness.** The first version's link pattern let its character
/// classes cross newlines, so a single unmatched `[` in the prose — and these
/// records carry `[sic]`, `[1930s]`, truncated `Contents: [Part 1` — paired
/// with the next real link anywhere further down and deleted every paragraph
/// in between. A description is not a document to be parsed; it is a stack of
/// lines to be cleaned one at a time.
enum CatalogText {

    /// Descriptions longer than this are not blurbs, and the patterns below
    /// are O(n²) on adversarial bracket runs — 32,000 unmatched brackets took
    /// twenty seconds to chew through. The field is wiki-editable, so it gets
    /// a ceiling.
    private static let maxLength = 6_000

    /// Prose, or `nil` if there was none left once the markup came out.
    static func cleanedDescription(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        var text = raw.replacingOccurrences(of: "\r\n", with: "\n")
        if text.count > maxLength { text = String(text.prefix(maxLength)) }

        // Entities first, tags second. The other order turns HTML-escaped
        // markup into live-looking markup: `&lt;i&gt;Hamlet&lt;/i&gt;` would
        // decode to `<i>Hamlet</i>` *after* the tag strip had already run, and
        // reach the page as the very thing this function exists to remove.
        text = decodingEntities(text)

        text = replacing(#"<br\s*/?>|</p>"#, in: text, with: "\n")
        // A tag must *start* like a tag — `<` then a letter or a slash. An
        // earlier pattern accepted `<` anything `>`, which ate the middle of
        // "readers who like x < 5 and y > 3" and left "x 3". Descriptions
        // discussing ranges, code, or arithmetic are commoner than HTML ones.
        text = replacing(#"</?[a-zA-Z][^>\n]{0,40}>"#, in: text, with: "")

        // Inline Markdown links go entirely — text and target both. In these
        // records a link is almost never load-bearing prose: it is a citation,
        // a "read more", or spam, and keeping the anchor text is how
        // "…you have read before. Tomorrow and Tomorrow and Tomorrow pdf"
        // ends up on a book page. Both classes stop at a newline.
        text = replacing(#"\[[^\]\n]*\]\([^)\n]*\)"#, in: text, with: "")

        // Reference-style links keep their words: `[Wikipedia][1]` is a
        // sentence's own noun. The `[1]: http…` definition line is structure,
        // not prose, and goes whole.
        text = replacing(#"\[([^\]\n]+)\]\[[^\]\n]*\]"#, in: text, with: "$1")
        text = replacing(#"(?m)^[ \t]*\[[^\]\n]+\]:[ \t]*\S+.*$"#, in: text, with: "")

        // Remaining bare URLs are removed *from* their line rather than taking
        // the line with them. Dropping whole lines was the first approach and
        // it is unsafe in one very common shape: a description written as a
        // single paragraph that cites a link mid-sentence would lose every
        // word of itself, and About would vanish for a book whose blurb was
        // perfectly good.
        text = replacing(#"(?i)(?:https?://|www\.)\S+"#, in: text, with: "")

        // Emphasis, matched as *pairs* so the words between the markers
        // survive, and only where there is a word in there to emphasise. The
        // letter requirement is what keeps "the grid is 3 * 4 * 5 units" from
        // losing its operators: two asterisks around a number are arithmetic,
        // not italics.
        //
        // **Italics before bold, because these records nest them.** Piranesi's
        // live blurb is `**From the *New York Times* author of *Jonathan
        // Strange*…**` — an outer bold wrapping inner italics — and a bold
        // pattern whose inner class cannot cross a `*` never matches it. Taking
        // the inner pair out first leaves the outer one matchable.
        text = replacing(#"(?<![\w*])\*([^*\n]*[a-zA-Z][^*\n]*)\*(?![\w*])"#, in: text, with: "$1")
        text = replacing(#"(?<![\w_])_([^_\n]*[a-zA-Z][^_\n]*)_(?![\w_])"#, in: text, with: "$1")
        text = replacing(#"\*\*([^*\n]*[a-zA-Z][^*\n]*)\*\*"#, in: text, with: "$1")
        text = replacing(#"(?<![\w_])__([^_\n]*[a-zA-Z][^_\n]*)__(?![\w_])"#, in: text, with: "$1")

        // Any `**` still standing is unpaired Markdown residue — two
        // asterisks together are never prose. `__` is deliberately left alone:
        // it survives in identifiers a description might legitimately quote.
        text = text.replacingOccurrences(of: "**", with: "")

        // Footnote markers whose targets were just removed. "A great book.[1]"
        // is not what the sentence says.
        text = replacing(#"\[\d{1,3}\]"#, in: text, with: "")

        // Open Library's own separators between a blurb and its provenance
        // note, and punctuation left holding nothing once a link inside it is
        // gone.
        text = replacing(#"(?m)^[ \t]*[-=*_]{3,}[ \t]*$"#, in: text, with: "")
        text = replacing(#"\(\s*\)|\[\s*\]|\{\s*\}"#, in: text, with: "")

        // Collapse the holes left behind.
        text = replacing(#"[ \t]{2,}"#, in: text, with: " ")
        text = replacing(#" +([.,;:!?])"#, in: text, with: "$1")
        text = replacing(#"(?m)^[ \t]+$"#, in: text, with: "")
        text = replacing(#"\n{3,}"#, in: text, with: "\n\n")

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Not merely non-empty — a description that was pure link spam leaves
        // its brackets and full stop behind, and "()" is not a blurb. The
        // contract this file states is that nothing left means no About
        // section, so it has to mean *nothing readable*.
        guard trimmed.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }
        return trimmed
    }

    // MARK: - Entities

    /// Named and numeric character references, decoded in one pass.
    ///
    /// `&amp;` is handled last so this cannot cascade: a double-encoded
    /// `&amp;lt;` resolves to the `&lt;` its author meant to display, rather
    /// than being decoded twice into a bare `<` that reads as markup.
    ///
    /// The numeric forms are not an afterthought — `&#8217;` (a right single
    /// quote) is one of the commonest artefacts in text pasted into these
    /// records, and it reaches the page as seven literal characters in the
    /// middle of a word.
    private static func decodingEntities(_ input: String) -> String {
        var text = input
        for (entity, character) in [
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "),
            ("&mdash;", "—"), ("&ndash;", "–"), ("&hellip;", "…"),
            ("&rsquo;", "’"), ("&lsquo;", "‘"), ("&rdquo;", "”"), ("&ldquo;", "“"),
        ] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        text = decodingNumericReferences(text)
        return text.replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func decodingNumericReferences(_ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"&#(x?)([0-9a-fA-F]{1,6});"#) else { return input }
        var output = input
        // Back to front, so each replacement leaves the earlier ranges valid.
        let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: output),
                  let hexRange = Range(match.range(at: 1), in: input),
                  let digitsRange = Range(match.range(at: 2), in: input) else { continue }
            let digits = String(input[digitsRange])
            let radix = input[hexRange].isEmpty ? 10 : 16
            guard let value = UInt32(digits, radix: radix), let scalar = Unicode.Scalar(value) else { continue }
            output.replaceSubrange(range, with: String(Character(scalar)))
        }
        return output
    }

    /// `NSRegularExpression` rather than a `Regex` literal: this target builds
    /// in Swift 5 language mode, and one bridging helper is cheaper than
    /// finding out which literals it will accept.
    private static func replacing(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }
}
