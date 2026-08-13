import Foundation
import Supabase

/// The account's server-side record: who you are, who you follow, and your four.
///
/// **This is deliberately not a sync layer** (§17). Nothing here reconciles, and
/// nothing here merges. Each method is a write the app makes at a moment the
/// reader took a durable action, and the local store remains the authority for
/// everything it already owned — library, diary, ratings, rankings, lists,
/// imported book metadata. A second device that signs in gets the reader's
/// identity, follows and chosen four, and an empty diary. That is a known,
/// deliberate limitation of this stage and not a bug to be worked around by
/// widening this protocol.
protocol ProfileService: Sendable {
    func profile(for userID: UUID) async throws -> AccountProfile?

    /// Asked while the reader types. Answered by a `SECURITY DEFINER` function
    /// rather than a `select` on `profiles` so that a taken handle can be
    /// reported without exposing the table to enumeration, and so normalisation
    /// happens in the same place uniqueness is enforced.
    func isHandleAvailable(_ candidate: String) async throws -> Bool

    /// Creates the row. The unique index is the real referee — `isHandleAvailable`
    /// can only ever report what was true a moment ago, and two readers can pick
    /// the same handle inside that window. A `23505` from Postgres is mapped to
    /// `AccountError.handleTaken` and sends the reader back to the field.
    func createProfile(userID: UUID, displayName: String, handle: String) async throws -> AccountProfile

    func setTasteOnboardingComplete(userID: UUID) async throws

    /// Replace-in-full rather than diffed. The four are a single decision about
    /// a set, `position` is meaningful, and a partial update would let a failed
    /// call leave three books on the server and four on the device.
    func replaceFavoriteBooks(userID: UUID, bookIDs: [String]) async throws
    func favoriteBooks(for userID: UUID) async throws -> [String]

    /// Follows of **seeded readers** — Priya and the rest — which is what the
    /// taste onboarding actually produces today. See `seed_follows` in the
    /// schema for why these are not rows in `follows`.
    func replaceSeedFollows(userID: UUID, readerIDs: [String]) async throws
    func seedFollows(for userID: UUID) async throws -> [String]
}

// MARK: - Supabase

struct SupabaseProfileService: ProfileService {
    let client: SupabaseClient

    // MARK: Profile

    func profile(for userID: UUID) async throws -> AccountProfile? {
        try await mapping {
            // `limit(1)` and an array decode rather than `.single()`: a missing
            // profile is the ordinary state between authenticating and finishing
            // the identity step, and `.single()` reports it as an error.
            let rows: [AccountProfile] = try await client
                .from("profiles")
                .select()
                .eq("user_id", value: userID)
                .limit(1)
                .execute()
                .value
            return rows.first
        }
    }

    func isHandleAvailable(_ candidate: String) async throws -> Bool {
        try await mapping {
            try await client
                .rpc("handle_available", params: ["candidate": Handle.normalize(candidate)])
                .execute()
                .value
        }
    }

    func createProfile(
        userID: UUID, displayName: String, handle: String
    ) async throws -> AccountProfile {
        struct NewProfile: Encodable {
            let user_id: UUID
            let display_name: String
            let handle: String
            let account_setup_complete: Bool
        }

        do {
            let rows: [AccountProfile] = try await client
                .from("profiles")
                .upsert(
                    NewProfile(
                        user_id: userID,
                        display_name: displayName,
                        handle: handle,
                        account_setup_complete: true
                    ),
                    onConflict: "user_id"
                )
                .select()
                .execute()
                .value
            guard let profile = rows.first else {
                throw AccountError.server("The profile didn't come back from the server.")
            }
            return profile
        } catch let error as PostgrestError {
            // 23505 is Postgres' unique_violation. The only unique constraint a
            // reader can collide with here is the handle index.
            if error.code == "23505" { throw AccountError.handleTaken }
            throw AccountError.server(error.message)
        } catch is URLError {
            throw AccountError.network
        } catch let error as AccountError {
            throw error
        } catch {
            throw AccountError.server(error.localizedDescription)
        }
    }

    func setTasteOnboardingComplete(userID: UUID) async throws {
        try await mapping {
            _ = try await client
                .from("profiles")
                .update(["taste_onboarding_complete": true])
                .eq("user_id", value: userID)
                .execute()
        }
    }

    // MARK: Favorite Books

    func replaceFavoriteBooks(userID: UUID, bookIDs: [String]) async throws {
        struct Row: Encodable {
            let user_id: UUID
            let book_id: String
            let position: Int
        }

        try await mapping {
            try await client.from("favorite_books")
                .delete().eq("user_id", value: userID).execute()

            guard !bookIDs.isEmpty else { return }

            // 1-based, matching the `position between 1 and 4` check. The cap is
            // applied here as well as in `DeweyStore.setFavoriteBooks` because a
            // fifth book would be rejected by the database as a constraint
            // violation, and a reader should never see that as an error.
            let rows = bookIDs.prefix(4).enumerated().map {
                Row(user_id: userID, book_id: $1, position: $0 + 1)
            }
            try await client.from("favorite_books").insert(rows).execute()
        }
    }

    func favoriteBooks(for userID: UUID) async throws -> [String] {
        struct Row: Decodable { let book_id: String }

        return try await mapping {
            let rows: [Row] = try await client
                .from("favorite_books")
                .select("book_id")
                .eq("user_id", value: userID)
                .order("position")
                .execute()
                .value
            return rows.map(\.book_id)
        }
    }

    // MARK: Follows

    func replaceSeedFollows(userID: UUID, readerIDs: [String]) async throws {
        struct Row: Encodable {
            let user_id: UUID
            let reader_slug: String
        }

        try await mapping {
            try await client.from("seed_follows")
                .delete().eq("user_id", value: userID).execute()

            guard !readerIDs.isEmpty else { return }
            try await client.from("seed_follows")
                .insert(readerIDs.map { Row(user_id: userID, reader_slug: $0) })
                .execute()
        }
    }

    func seedFollows(for userID: UUID) async throws -> [String] {
        struct Row: Decodable { let reader_slug: String }

        return try await mapping {
            let rows: [Row] = try await client
                .from("seed_follows")
                .select("reader_slug")
                .eq("user_id", value: userID)
                .execute()
                .value
            return rows.map(\.reader_slug)
        }
    }

    // MARK: - Errors

    /// One place that turns a transport or Postgres failure into something with
    /// a sentence attached. Without it every call site grows the same three
    /// `catch` blocks and they drift.
    private func mapping<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let error as PostgrestError {
            throw AccountError.server(error.message)
        } catch is URLError {
            throw AccountError.network
        } catch let error as AccountError {
            throw error
        } catch {
            throw AccountError.server(error.localizedDescription)
        }
    }
}
