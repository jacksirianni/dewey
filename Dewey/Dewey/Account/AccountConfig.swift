import Foundation

/// Where the Supabase project lives, and whether we know about it at all.
///
/// **Read from a plist in the app bundle rather than compiled into the source.**
/// `SupabaseConfig.plist` sits next to this file, is listed in `.gitignore`, and
/// is picked up automatically by the target's file-system-synchronised group —
/// so there is no Xcode step to remember and nothing to add to the build phases.
/// `SupabaseConfig.example.plist` is the committed copy that documents the shape.
///
/// **The anon key is not a secret and is not treated as one.** It is a public
/// identifier that says "this request is coming from an unauthenticated client of
/// project X"; every real access decision is made by Row Level Security on the
/// server, against the JWT of the signed-in user. Keeping the file out of version
/// control is about not publishing which project a given checkout points at — not
/// about protecting the key, which ships inside the app binary regardless and can
/// be read out of it by anyone who cares to. If this key alone were enough to read
/// another reader's rows, the policies would be wrong, and no amount of hiding it
/// would fix that.
enum AccountConfig {
    struct Supabase {
        let url: URL
        let anonKey: String
    }

    /// Nil when no config file is present. Callers must handle that rather than
    /// force-unwrapping: an unconfigured **debug** build falls back to a local
    /// account store automatically so the flow can be walked end to end, and an
    /// unconfigured **release** build shows an honest beta screen offering the
    /// same local store as an explicit, remembered opt-in. See `AccountServices`.
    static let supabase: Supabase? = load()

    static var isConfigured: Bool { supabase != nil }

    private static func load() -> Supabase? {
        guard
            let url = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
        else { return nil }

        // Accepts either a bare host ("abcd.supabase.co") or a full URL, because
        // both are things a person reasonably copies out of the dashboard and
        // being wrong about which one you pasted is a miserable thing to debug.
        let rawURL = (plist["SupabaseURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let key = (plist["SupabaseAnonKey"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !rawURL.isEmpty, !key.isEmpty else { return nil }
        // The example file ships with placeholders; a checkout that copied it
        // without editing is unconfigured, not misconfigured.
        guard !rawURL.contains("YOUR-PROJECT"), !key.hasPrefix("YOUR-") else { return nil }

        let normalised = rawURL.contains("://") ? rawURL : "https://\(rawURL)"
        guard let parsed = URL(string: normalised), parsed.host != nil else { return nil }

        return Supabase(url: parsed, anonKey: key)
    }

    /// One line for the debug menu, so "why am I not signed in" is answerable
    /// without a breakpoint.
    static var diagnostic: String {
        guard let supabase else {
            return "Supabase: not configured (add SupabaseConfig.plist)"
        }
        return "Supabase: \(supabase.url.host ?? supabase.url.absoluteString)"
    }
}
