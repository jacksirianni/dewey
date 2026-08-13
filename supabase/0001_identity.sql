-- Dewey — identity, stage one.
--
-- Run this once, whole, in the Supabase SQL editor. It is written to be
-- re-runnable: every object is created `if not exists` or replaced, and every
-- policy is dropped before it is created, so pasting it a second time is a
-- no-op rather than a pile of "already exists" errors.
--
-- SCOPE. This is the account, and nothing else. The library, diary, ratings,
-- rankings, lists and imported book metadata all remain on the device in this
-- stage, deliberately — see the header of ProfileService.swift. Do not add
-- tables for them here without deciding the migration story first.
--
-- ROW LEVEL SECURITY IS ON FOR EVERY TABLE, FROM THE FIRST MIGRATION. The iOS
-- client is not trusted to enforce ownership. Anyone holding the anon key —
-- which ships inside the app binary and is readable by anyone who cares to look
-- — can issue arbitrary PostgREST requests, so every rule that matters is a
-- policy below rather than a check in Swift.

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
--
-- One row per authenticated user. `user_id` is both the primary key and the
-- foreign key to `auth.users`, which is what lets every policy in this file be
-- written as `auth.uid() = user_id` with no join.
--
-- `handle` stores what the reader typed, case intact, so `@JackS` displays as
-- `@JackS`. `handle_normalized` is the generated lower-cased form, and the
-- unique index is on *that* — which is how uniqueness ends up case-insensitive
-- without the display losing its capitals. A generated column rather than a
-- trigger because it cannot drift: there is no code path that writes `handle`
-- without also producing the key it is judged on.

create table if not exists public.profiles (
    user_id                   uuid primary key references auth.users (id) on delete cascade,
    display_name              text not null,
    handle                    text not null,
    handle_normalized         text generated always as (lower(handle)) stored,

    -- Name and handle chosen. False for the window between Apple returning and
    -- the identity step finishing — a real state, because a reader can close
    -- the app inside it.
    account_setup_complete    boolean not null default false,

    -- The four taste steps. THIS IS THE COLUMN THAT MAKES A SECOND DEVICE
    -- BEHAVE. Without it, a reinstall would run a returning reader through
    -- onboarding again as though they were new.
    taste_onboarding_complete boolean not null default false,

    created_at                timestamptz not null default now(),
    updated_at                timestamptz not null default now(),

    -- Mirrors Handle.validate in Swift, and outranks it. 3–20 characters;
    -- starts with a letter or digit; letters, digits, underscores and periods
    -- only; never ends in a period; no two periods in a row.
    constraint profiles_display_name_length check (
        char_length(trim(display_name)) between 1 and 50
    ),
    constraint profiles_handle_shape check (
        handle ~ '^[A-Za-z0-9][A-Za-z0-9_.]{1,18}[A-Za-z0-9_]$'
        and handle !~ '\.\.'
    )
);

create unique index if not exists profiles_handle_normalized_key
    on public.profiles (handle_normalized);

-- ---------------------------------------------------------------------------
-- follows — reader to reader, both real accounts
-- ---------------------------------------------------------------------------
--
-- Created now and expected to be empty for a while, which is worth stating
-- plainly rather than discovering later. Every reader the taste onboarding can
-- currently offer to follow — Priya and the rest — is a seeded fixture in
-- SeedData.swift, not a row in auth.users, so those follows cannot live here
-- without a fake user per fixture. They go in `seed_follows` below instead.
--
-- This table is the one that starts carrying rows the moment two real people
-- are signed in, and its shape is settled now so that day needs no migration.

create table if not exists public.follows (
    follower_user_id uuid not null references auth.users (id) on delete cascade,
    followed_user_id uuid not null references auth.users (id) on delete cascade,
    created_at       timestamptz not null default now(),

    primary key (follower_user_id, followed_user_id),
    constraint follows_no_self check (follower_user_id <> followed_user_id)
);

create index if not exists follows_followed_idx on public.follows (followed_user_id);

-- ---------------------------------------------------------------------------
-- seed_follows — the demo readers, which are fixtures rather than accounts
-- ---------------------------------------------------------------------------
--
-- `reader_slug` is a SeedData id: 'priya', 'marcus'. Kept apart from `follows`
-- rather than modelled as a nullable column on it, because the two have
-- genuinely different referential integrity — one is a foreign key the database
-- enforces, the other is a string only the app can resolve. Collapsing them
-- would mean `follows` could no longer declare `followed_user_id not null`,
-- and the constraint that matters most on the real table would be gone to
-- accommodate the temporary one.
--
-- Expected to be dropped whole when the seeded readers stop existing.

create table if not exists public.seed_follows (
    user_id     uuid not null references auth.users (id) on delete cascade,
    reader_slug text not null,
    created_at  timestamptz not null default now(),

    primary key (user_id, reader_slug),
    constraint seed_follows_slug_shape check (char_length(reader_slug) between 1 and 64)
);

-- ---------------------------------------------------------------------------
-- favorite_books — the four on your profile
-- ---------------------------------------------------------------------------
--
-- `book_id` is a Dewey book id (a seed slug like 'severance', or an id minted
-- by the catalog import), and is deliberately a plain text column with no
-- foreign key: there is no books table on the server in this stage, and
-- inventing one would be the "giant backend migration" this work is scoped
-- against.
--
-- `position` carries the reader's chosen order, which is meaningful — these are
-- ranked by intent, not by score. The unique index on (user_id, position) is
-- what stops two books claiming the same slot.

create table if not exists public.favorite_books (
    user_id    uuid not null references auth.users (id) on delete cascade,
    book_id    text not null,
    position   integer not null,
    created_at timestamptz not null default now(),

    primary key (user_id, book_id),
    constraint favorite_books_position_range check (position between 1 and 4)
);

create unique index if not exists favorite_books_user_position_key
    on public.favorite_books (user_id, position);

-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
    before update on public.profiles
    for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- handle_available
-- ---------------------------------------------------------------------------
--
-- Answers the question the identity screen asks while the reader types.
--
-- SECURITY DEFINER for two reasons. It normalises the candidate in the same
-- place uniqueness is enforced, so the client cannot get the answer wrong by
-- normalising differently; and it answers one yes/no question about one handle
-- rather than requiring a `select` on `profiles`, so availability can be
-- checked without handing out a way to enumerate the table.
--
-- `set search_path` is not optional on a SECURITY DEFINER function — without it
-- a caller can shadow `public` and have the body resolve to their own tables.
--
-- This is a convenience, not a guarantee. Two readers can be told the same
-- handle is free within the same second; the unique index is what actually
-- decides, and the client maps its 23505 to "that handle is taken".

create or replace function public.handle_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
    select not exists (
        select 1
        from public.profiles
        where handle_normalized = lower(trim(leading '@' from trim(candidate)))
    );
$$;

revoke all on function public.handle_available(text) from public;
grant execute on function public.handle_available(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles       enable row level security;
alter table public.follows        enable row level security;
alter table public.seed_follows   enable row level security;
alter table public.favorite_books enable row level security;

-- Privileges ----------------------------------------------------------------
--
-- **Stated explicitly rather than inherited, and this is not belt-and-braces —
-- the migration is broken without it on any project whose default privileges
-- differ from the stock ones.** Verified: with Supabase's
-- `alter default privileges … grant all on tables to anon, authenticated,
-- service_role` in place, the migration works with no grants of its own; with
-- those defaults absent, every request fails with *permission denied for table
-- profiles*. Relying on the ambient configuration means the schema is only
-- correct in a project someone else set up a particular way.
--
-- GRANT and RLS are independent layers and both are required: GRANT decides
-- whether a role may touch the table at all, RLS decides which rows. Granting
-- exactly the verbs each table's policies allow means the two cannot drift into
-- disagreeing — there is no table here where a role holds a privilege no policy
-- would ever let it use.
--
-- `anon` is revoked outright. It has no policy on any of these tables, so RLS
-- already denies it everything; removing the grant as well means a policy added
-- carelessly later cannot silently open the table to unauthenticated callers.
--
-- **`authenticated` is revoked first and then granted back**, rather than
-- granted on top of whatever it already holds. On a stock project the ambient
-- defaults hand it every verb including DELETE and TRUNCATE, so without the
-- revoke it would keep a DELETE privilege on `profiles` that no policy will
-- ever permit — blocked by RLS instead of by grant. That is the two layers
-- disagreeing, which is the thing this block exists to prevent, and it also
-- makes the same statement behave differently on two projects: 42501 where the
-- grant is absent, silently-zero-rows where it is present.

revoke all on public.profiles, public.follows,
              public.seed_follows, public.favorite_books
    from anon, authenticated;

grant select, insert, update              on public.profiles       to authenticated;
grant select, insert, delete              on public.follows        to authenticated;
grant select, insert, update, delete      on public.seed_follows   to authenticated;
grant select, insert, update, delete      on public.favorite_books to authenticated;

-- profiles ------------------------------------------------------------------
-- Readable by any signed-in reader: Dewey is a product about other people's
-- taste, and a profile you cannot read is not a profile. Writable only by its
-- owner. `anon` is deliberately not granted read — there is no signed-out
-- surface in the app today, and opening the table to the anon key would make
-- every handle and display name scrapable by anyone with the app binary.

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
    for select to authenticated
    using (true);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
    for insert to authenticated
    with check (auth.uid() = user_id);

-- Both `using` and `with check`. `using` decides which rows you may attempt to
-- update; `with check` decides what the row is allowed to look like afterwards.
-- With only the first, a reader could reassign `user_id` and hand their profile
-- to somebody else.
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
    for update to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- follows -------------------------------------------------------------------
-- Public among signed-in readers (a follower list is a social object); writable
-- only from your own account, in either direction of the pair.

drop policy if exists follows_select on public.follows;
create policy follows_select on public.follows
    for select to authenticated
    using (true);

drop policy if exists follows_insert_own on public.follows;
create policy follows_insert_own on public.follows
    for insert to authenticated
    with check (auth.uid() = follower_user_id);

drop policy if exists follows_delete_own on public.follows;
create policy follows_delete_own on public.follows
    for delete to authenticated
    using (auth.uid() = follower_user_id);

-- seed_follows --------------------------------------------------------------
-- Own rows only, including reads. Which fixtures a reader follows is not a
-- social object — the fixtures are not people — so there is nothing to gain
-- from publishing it.

drop policy if exists seed_follows_all_own on public.seed_follows;
create policy seed_follows_all_own on public.seed_follows
    for all to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- favorite_books ------------------------------------------------------------
-- Readable by any signed-in reader: the four are the most public thing on a
-- profile and the whole point of the constraint. Writable only by their owner.

drop policy if exists favorite_books_select on public.favorite_books;
create policy favorite_books_select on public.favorite_books
    for select to authenticated
    using (true);

drop policy if exists favorite_books_write_own on public.favorite_books;
create policy favorite_books_write_own on public.favorite_books
    for all to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
