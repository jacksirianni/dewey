import Foundation
import Supabase

/// The reader's reading status per book, on the server — the second slice of
/// account data to leave the device, after identity and the profile four
/// (§Phase2 Library).
///
/// **Also not a sync layer**, in the sense `ProfileService` means it: nothing
/// here decides *when* to call these methods or how to reconcile what comes
/// back — that is `DeweyStore.reconcileLibrary(withRemote:)`. This protocol is
/// the three verbs Postgres actually needs: read every row for a reader,
/// upsert one status, delete one row. `book_ref` is the provider-prefixed
/// string `supabase/0004_library.sql` and `DeweyStore.cloudLibraryRef(for:)`
/// agree on — never a local Dewey book id, which is not guaranteed stable
/// across devices (see that function's doc comment for why).
protocol LibraryService: Sendable {
    func fetchEntries(userID: UUID) async throws -> [RemoteLibraryEntry]

    /// One row per `(userID, bookRef)`, idempotent by design — the caller
    /// never needs to know whether a row already exists, only what it should
    /// say now.
    func upsertStatus(userID: UUID, bookRef: String, status: ReadingStatus) async throws

    func deleteEntry(userID: UUID, bookRef: String) async throws
}

/// One reader's status on one book, as the server holds it.
///
/// `createdAt` and `updatedAt` are both carried because they answer different
/// questions during reconciliation: `createdAt` is the closest honest analog
/// to `LibraryEntry.savedAt` for a book hydrated from the cloud, and
/// `updatedAt` is the only trustworthy "did this change since I last looked"
/// signal in this slice — the local model has no equivalent (see
/// `DeweyStore.reconcileLibrary(withRemote:)`).
struct RemoteLibraryEntry: Sendable, Equatable {
    let bookRef: String
    let status: ReadingStatus
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Supabase

struct SupabaseLibraryService: LibraryService {
    let client: SupabaseClient

    func fetchEntries(userID: UUID) async throws -> [RemoteLibraryEntry] {
        struct Row: Decodable {
            let book_ref: String
            let status: ReadingStatus
            let created_at: Date
            let updated_at: Date
        }

        return try await mapping {
            let rows: [Row] = try await client
                .from("library_entries")
                .select()
                .eq("user_id", value: userID)
                .execute()
                .value
            return rows.map {
                RemoteLibraryEntry(
                    bookRef: $0.book_ref, status: $0.status,
                    createdAt: $0.created_at, updatedAt: $0.updated_at
                )
            }
        }
    }

    func upsertStatus(userID: UUID, bookRef: String, status: ReadingStatus) async throws {
        struct Row: Encodable {
            let user_id: UUID
            let book_ref: String
            let status: ReadingStatus
        }

        try await mapping {
            _ = try await client
                .from("library_entries")
                .upsert(
                    Row(user_id: userID, book_ref: bookRef, status: status),
                    onConflict: "user_id,book_ref"
                )
                .execute()
        }
    }

    func deleteEntry(userID: UUID, bookRef: String) async throws {
        try await mapping {
            _ = try await client
                .from("library_entries")
                .delete()
                .eq("user_id", value: userID)
                .eq("book_ref", value: bookRef)
                .execute()
        }
    }

    // MARK: - Errors

    /// The same translation `SupabaseProfileService` uses. No `23505` mapping
    /// here — unlike a handle, a `book_ref` collision is never a rejection to
    /// show the reader: `upsertStatus` always upserts, so a unique-key hit is
    /// success, not an error path that could reach this function at all.
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

// MARK: - Local stand-in

/// The `LocalAuthService` / `LocalProfileService` stand-in, for the same
/// reason: `AccountServices.make()` returns one triple per backend, and
/// `.localTesting` has no Supabase client to build a real one from. Keyed by
/// user so the two local test-account slots never see each other's library.
///
/// **An actor, not a class.** `DeweyStore.reconcileLibrary`'s bootstrap step
/// can fire several `upsertStatus` calls back to back for one reader's
/// library, each spawned as its own `Task` by `SessionStore.pushLibraryStatus`
/// — concurrent read-modify-write against the same `UserDefaults` key would
/// race, and the losing write's entry silently vanishes. Real Postgres has no
/// equivalent hazard: each upsert is one atomic statement on the server, not
/// a client-side read-then-write. Serializing access here is what makes the
/// stand-in behave like the thing it is standing in for.
actor LocalLibraryService: LibraryService {
    private struct StoredEntry: Codable {
        let bookRef: String
        var status: ReadingStatus
        let createdAt: Date
        var updatedAt: Date
    }

    private var store: UserDefaults { .standard }
    private func key(_ userID: UUID) -> String { "dewey.debug.local.library.\(userID.uuidString)" }

    private func load(_ userID: UUID) -> [StoredEntry] {
        guard let data = store.data(forKey: key(userID)) else { return [] }
        return (try? JSONDecoder().decode([StoredEntry].self, from: data)) ?? []
    }

    private func save(_ entries: [StoredEntry], for userID: UUID) {
        store.set(try? JSONEncoder().encode(entries), forKey: key(userID))
    }

    func fetchEntries(userID: UUID) async throws -> [RemoteLibraryEntry] {
        load(userID).map {
            RemoteLibraryEntry(
                bookRef: $0.bookRef, status: $0.status,
                createdAt: $0.createdAt, updatedAt: $0.updatedAt
            )
        }
    }

    func upsertStatus(userID: UUID, bookRef: String, status: ReadingStatus) async throws {
        var entries = load(userID)
        if let i = entries.firstIndex(where: { $0.bookRef == bookRef }) {
            entries[i].status = status
            entries[i].updatedAt = Date()
        } else {
            entries.append(StoredEntry(bookRef: bookRef, status: status, createdAt: Date(), updatedAt: Date()))
        }
        save(entries, for: userID)
    }

    func deleteEntry(userID: UUID, bookRef: String) async throws {
        save(load(userID).filter { $0.bookRef != bookRef }, for: userID)
    }
}
