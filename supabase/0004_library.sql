-- Dewey — library, stage one: reading status only.
--
-- Run this once, whole, after `0001_identity.sql`. Like that file it is
-- written to be re-runnable: every object is created `if not exists` or
-- replaced, and every policy is dropped before it is created, so pasting it a
-- second time is a no-op rather than a pile of "already exists" errors.
--
-- SCOPE. This is one fact: which reading status a reader has set for one book
-- — Want to Read, Reading, Finished, Paused, Did Not Finish. Notes, tags,
-- diary entries, ratings, reflections, Moments, lists and rankings all remain
-- on the device in this stage, deliberately. Do not add columns or tables for
-- them here without deciding the migration story first.
--
-- BOOK IDENTITY. There is no books/catalog table on the server in this stage,
-- on purpose — the same call `favorite_books.book_id` already made in
-- `0001_identity.sql`: "there is no books table on the server in this stage,
-- and inventing one would be the giant backend migration this work is scoped
-- against." `dewey.work` in `0002_catalog.sql` is a real canonical-identity
-- schema, but it is empty: that migration explicitly does not implement
-- ingestion, no Swift code references it, and its RLS forbids the iOS client
-- from writing to it at all — only the ingestion service, connecting as table
-- owner, may insert a `dewey.work` row. Requiring one to exist before a reader
-- can set a status on a book they just found in Open Library search would
-- make this migration depend on building ingestion, which is exactly the
-- scope creep this stage is scoped against.
--
-- `book_ref` is therefore a plain text column with no foreign key, carrying a
-- provider-prefixed external reference chosen by the client with this
-- precedence: `olw:<open library work id>` when the book has one, else
-- `isbn:<isbn13>` when it has an ISBN, else `dewey:<book id>` as the fallback
-- for seed books and freshly-imported books lacking any external id. This is
-- forward-compatible with a future catalog phase: once `0002_catalog.sql`
-- gains an ingestion pipeline, `dewey.resolve_external_work('ol_work', …)`
-- already exists to map an `olw:` reference to a live `dewey.work.id`, so a
-- later migration can backfill a real foreign key without this table's shape
-- changing today.
--
-- ROW LEVEL SECURITY IS ON FROM THE FIRST STATEMENT THAT CREATES THIS TABLE.
-- Unlike `profiles`/`follows`/`favorite_books`, a reading status is not a
-- social object — nobody else has any reason to read it — so every policy
-- here is owner-only, in both directions.

-- ---------------------------------------------------------------------------
-- library_entries
-- ---------------------------------------------------------------------------

create table if not exists public.library_entries (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references auth.users (id) on delete cascade,
    book_ref   text not null,
    status     text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint library_entries_status_valid check (
        status in ('wantToRead', 'reading', 'finished', 'paused', 'didNotFinish')
    ),
    constraint library_entries_book_ref_shape check (
        char_length(book_ref) between 1 and 512
    )
);

-- One status per book per reader. This is what makes a write idempotent: the
-- client always upserts on this pair rather than needing to know whether a
-- row already exists.
create unique index if not exists library_entries_user_book_key
    on public.library_entries (user_id, book_ref);

-- The only other query shape the app needs: "this reader's Want to Read /
-- Reading / Finished shelf."
create index if not exists library_entries_user_status_idx
    on public.library_entries (user_id, status);

drop trigger if exists library_entries_touch_updated_at on public.library_entries;
create trigger library_entries_touch_updated_at
    before update on public.library_entries
    for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.library_entries enable row level security;

-- See the note on this pattern in `0001_identity.sql`: GRANT and RLS are
-- independent layers, and revoking `authenticated`'s ambient default
-- privileges before granting back exactly the verbs its policies allow is
-- what stops the two layers from disagreeing.
revoke all on public.library_entries from anon, authenticated;

grant select, insert, update, delete on public.library_entries to authenticated;

-- Owner-only, full stop. No reader's status on any book is any other
-- reader's business — this is the one place in the schema so far with no
-- "social read" policy at all.

drop policy if exists library_entries_select_own on public.library_entries;
create policy library_entries_select_own on public.library_entries
    for select to authenticated
    using (auth.uid() = user_id);

drop policy if exists library_entries_insert_own on public.library_entries;
create policy library_entries_insert_own on public.library_entries
    for insert to authenticated
    with check (auth.uid() = user_id);

-- Both `using` and `with check`, for the same reason as `profiles_update_own`
-- in `0001_identity.sql`: `using` decides which rows you may attempt to
-- update, `with check` decides what the row may look like afterwards. Without
-- the second, a reader could reassign `user_id` and hand their row to
-- somebody else.
drop policy if exists library_entries_update_own on public.library_entries;
create policy library_entries_update_own on public.library_entries
    for update to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

drop policy if exists library_entries_delete_own on public.library_entries;
create policy library_entries_delete_own on public.library_entries
    for delete to authenticated
    using (auth.uid() = user_id);
