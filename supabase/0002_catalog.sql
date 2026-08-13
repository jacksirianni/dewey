-- Dewey — catalog, stage one.
--
-- Run this once, whole, after `0001_identity.sql`. Like that file it is written
-- to be re-runnable: every object is created `if not exists` or replaced, so
-- pasting it a second time is a no-op rather than a pile of errors.
--
-- SCOPE. This is the *catalog* — what a book is. It contains no user data at
-- all: no score, diary, review, ranking, list, favourite or follow appears
-- here, and none ever should. Those live in the social schema and point at
-- `work.id`. See `docs/superpowers/specs/2026-08-10-catalog-schema-design.md`.
--
-- THIS MIGRATION DOES NOT IMPLEMENT INGESTION. It creates the tables, keys,
-- constraints, indexes and the handful of functions that encode rules too
-- important to leave to application code (identifier resolution, redirect
-- resolution, ISBN normalisation, provenance precedence). Loading Open Library
-- is a separate piece of work.
--
-- IDENTITY. Canonical ids are `uuid`, generated application-side as UUIDv7.
-- Postgres only gained `uuidv7()` in 18 and deployed Supabase may be older, so
-- there is deliberately NO server-side default on any canonical id column: a
-- caller must supply one. The alternative — defaulting to `gen_random_uuid()`
-- (v4) — would silently produce randomly-ordered keys and lose the index
-- locality that motivated choosing v7, which is exactly the kind of quiet
-- fallback the design forbids. `dewey.uuid_v7()` below is provided so tests and
-- backfills can mint conforming ids without waiting for PG18.
--
-- ROW LEVEL SECURITY. The catalog is public, read-only data. RLS is enabled on
-- every table with a read-only policy for the API roles; all writes belong to
-- the ingestion service, which connects as the table owner and bypasses RLS.
-- The iOS client must never write here.

create extension if not exists pg_trgm;
create extension if not exists unaccent;

create schema if not exists dewey;

-- ---------------------------------------------------------------------------
-- Enumerations
-- ---------------------------------------------------------------------------
--
-- Enums rather than text + check: they are cheap, they document themselves in
-- `\dT`, and adding a value later is one `alter type`. The values are Dewey's
-- vocabulary, not Open Library's — deliberately, since a provider swap must not
-- require re-labelling every row.

do $$
begin
    if not exists (select 1 from pg_type where typname = 'work_type') then
        create type dewey.work_type as enum (
            'book', 'collection', 'omnibus', 'study_guide', 'periodical', 'other');
    end if;

    if not exists (select 1 from pg_type where typname = 'title_kind') then
        create type dewey.title_kind as enum (
            'canonical', 'original', 'alternate', 'translated', 'subtitle');
    end if;

    if not exists (select 1 from pg_type where typname = 'name_kind') then
        create type dewey.name_kind as enum (
            'canonical', 'alias', 'romanization', 'transliteration',
            'pseudonym', 'source_variant', 'former');
    end if;

    if not exists (select 1 from pg_type where typname = 'work_role') then
        create type dewey.work_role as enum (
            'author', 'co_author', 'editor', 'illustrator');
    end if;

    -- Translator and narrator are *edition* roles and appear only here. That
    -- separation is the structural fix for the prototype's "Red Rising by
    -- Renee Joiner" bug: an audiobook's narrator is physically unable to reach
    -- work-level credit, because there is no enum value for it there.
    if not exists (select 1 from pg_type where typname = 'edition_role') then
        create type dewey.edition_role as enum (
            'translator', 'narrator', 'illustrator', 'editor', 'afterword',
            'introduction');
    end if;

    if not exists (select 1 from pg_type where typname = 'edition_format') then
        create type dewey.edition_format as enum (
            'hardcover', 'paperback', 'ebook', 'audiobook', 'other');
    end if;

    -- `dewey_legacy` is how prototype ids such as 'piranesi' keep resolving.
    -- It is an ordinary provider, deliberately: the design's rule is that no
    -- provider's identifier is ever identity, and the 2026 prototype gets no
    -- exemption from it.
    if not exists (select 1 from pg_type where typname = 'provider') then
        create type dewey.provider as enum (
            'openlibrary', 'nielsen', 'bowker', 'isbndb', 'wikidata',
            'dewey_seed', 'dewey_legacy', 'dewey_editorial');
    end if;

    if not exists (select 1 from pg_type where typname = 'entity_type') then
        create type dewey.entity_type as enum ('work', 'edition', 'author');
    end if;

    if not exists (select 1 from pg_type where typname = 'acquisition') then
        create type dewey.acquisition as enum ('dump', 'api', 'manual');
    end if;

    if not exists (select 1 from pg_type where typname = 'cover_source') then
        create type dewey.cover_source as enum (
            'openlibrary', 'licensed', 'publisher', 'dewey_typeset');
    end if;

    -- Dewey does not own third-party cover art and this column says so out
    -- loud. `unlicensed_cached` is the honest description of an Open Library
    -- cover reference: cached under the origin's own cache headers, purgeable
    -- on request, never claimed as ours.
    if not exists (select 1 from pg_type where typname = 'license_posture') then
        create type dewey.license_posture as enum (
            'unlicensed_cached', 'licensed', 'generated');
    end if;

    if not exists (select 1 from pg_type where typname = 'redirect_reason') then
        create type dewey.redirect_reason as enum (
            'duplicate', 'upstream_merge', 'editorial', 'client_collision');
    end if;

    if not exists (select 1 from pg_type where typname = 'subject_vocabulary') then
        create type dewey.subject_vocabulary as enum (
            'ol_folksonomy', 'bisac', 'thema', 'lcsh', 'dewey_curated');
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- UUIDv7, for tests and backfills until the deployed Postgres has its own.
--
-- Layout per RFC 9562: 48 bits of Unix epoch milliseconds, version nibble 7,
-- variant bits 10, and 74 bits of randomness. Time-ordered, so inserts land at
-- the btree tail instead of scattering the way v4 does across the eighteen
-- tables keyed on these ids.
create or replace function dewey.uuid_v7()
returns uuid
language plpgsql
volatile
as $$
declare
    ms    bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
    rnd   bytea  := gen_random_bytes(10);   -- 10 random bytes: octets 6-15 below
    buf   bytea  := '\x00000000000000000000000000000000'::bytea;
begin
    -- Octets 0-5: 48-bit big-endian Unix epoch milliseconds.
    buf := set_byte(buf, 0, ((ms >> 40) & 255)::int);
    buf := set_byte(buf, 1, ((ms >> 32) & 255)::int);
    buf := set_byte(buf, 2, ((ms >> 24) & 255)::int);
    buf := set_byte(buf, 3, ((ms >> 16) & 255)::int);
    buf := set_byte(buf, 4, ((ms >> 8)  & 255)::int);
    buf := set_byte(buf, 5, (ms & 255)::int);
    -- Octet 6: version nibble (0111) high, top of rand_a low.
    buf := set_byte(buf, 6, (112 | (get_byte(rnd,0) & 15)));
    -- Octet 7: rest of rand_a.
    buf := set_byte(buf, 7, get_byte(rnd,1));
    -- Octet 8: variant bits (10) high, top of rand_b low.
    buf := set_byte(buf, 8, (128 | (get_byte(rnd,2) & 63)));
    -- Octets 9-15: rest of rand_b.
    buf := set_byte(buf, 9,  get_byte(rnd,3));
    buf := set_byte(buf, 10, get_byte(rnd,4));
    buf := set_byte(buf, 11, get_byte(rnd,5));
    buf := set_byte(buf, 12, get_byte(rnd,6));
    buf := set_byte(buf, 13, get_byte(rnd,7));
    buf := set_byte(buf, 14, get_byte(rnd,8));
    buf := set_byte(buf, 15, get_byte(rnd,9));
    return encode(buf, 'hex')::uuid;
end $$;

-- Folding, identical in spirit to the client's `common.fold`, and the reason
-- the search columns are *stored* rather than computed per query: an
-- expression index over a non-IMMUTABLE function is rejected outright, which
-- the spike discovered the hard way with `array_to_string`.
create or replace function dewey.fold(s text)
returns text
language sql
immutable
strict
as $$
    select regexp_replace(
             regexp_replace(
               lower(translate(unaccent(s), '''’', '')),
               '[^[:alnum:][:space:]]', ' ', 'g'),
             '\s+', ' ', 'g')
$$;

-- Article-less comparison form. "The Hobbit" and "Hobbit" must be one title.
create or replace function dewey.title_key(s text)
returns text
language sql
immutable
strict
as $$
    select btrim(regexp_replace(
        dewey.fold(s),
        '^(the|a|an|la|le|les|el|il|der|die|das|een|de)\s+', ''))
$$;

-- ISBN normalisation -------------------------------------------------------
--
-- Everything is stored as ISBN-13. There is exactly one column to look up,
-- which is a schema-level answer to the spike's silent ISBN failure: two
-- search engines returned nothing for every ISBN query because the lookup had
-- to remember a second field, and forgot. Here there is no second field.

create or replace function dewey.isbn_digits(raw text)
returns text
language sql
immutable
strict
as $$ select upper(regexp_replace(raw, '[^0-9Xx]', '', 'g')) $$;

create or replace function dewey.isbn10_valid(raw text)
returns boolean
language plpgsql
immutable
as $$
declare d text := dewey.isbn_digits(raw); t int := 0; i int;
begin
    if d is null or length(d) <> 10 then return false; end if;
    if d ~ 'X' and d !~ '^[0-9]{9}X$' then return false; end if;
    for i in 1..9 loop
        if substr(d,i,1) !~ '[0-9]' then return false; end if;
        t := t + (11 - i) * substr(d,i,1)::int;
    end loop;
    t := t + case when substr(d,10,1) = 'X' then 10 else substr(d,10,1)::int end;
    return t % 11 = 0;
end $$;

create or replace function dewey.isbn13_valid(raw text)
returns boolean
language plpgsql
immutable
as $$
declare d text := dewey.isbn_digits(raw); t int := 0; i int;
begin
    if d is null or d !~ '^[0-9]{13}$' then return false; end if;
    for i in 1..12 loop
        t := t + (case when i % 2 = 1 then 1 else 3 end) * substr(d,i,1)::int;
    end loop;
    return (10 - (t % 10)) % 10 = substr(d,13,1)::int;
end $$;

-- Returns the ISBN-13 form of any valid ISBN-10 or ISBN-13, else NULL.
-- NULL rather than an exception: ingestion meets malformed ISBNs constantly
-- (626 of 244,511 strings in the spike corpus, 0.26%) and a single bad string
-- must not abort a batch. The caller drops nulls; the CHECK constraint on
-- `edition_isbn` then makes it impossible for one to be stored anyway.
create or replace function dewey.isbn_to_13(raw text)
returns text
language plpgsql
immutable
as $$
declare d text := dewey.isbn_digits(raw); core text; t int := 0; i int;
begin
    if d is null then return null; end if;
    if length(d) = 13 then
        return case when dewey.isbn13_valid(d) then d else null end;
    elsif length(d) = 10 then
        if not dewey.isbn10_valid(d) then return null; end if;
        core := '978' || substr(d, 1, 9);
        for i in 1..12 loop
            t := t + (case when i % 2 = 1 then 1 else 3 end) * substr(core,i,1)::int;
        end loop;
        return core || ((10 - (t % 10)) % 10)::text;
    end if;
    return null;
end $$;

-- ---------------------------------------------------------------------------
-- author, author_name
-- ---------------------------------------------------------------------------

create table if not exists dewey.author (
    id            uuid primary key,
    display_name  text not null,
    sort_name     text,
    birth_date    text,          -- free-form upstream; kept verbatim
    death_date    text,
    slug          text,
    merged_into   uuid references dewey.author (id),
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),

    constraint author_not_self_merged check (merged_into is null or merged_into <> id)
);
create unique index if not exists author_slug_key on dewey.author (slug) where slug is not null;
create index if not exists author_live_idx on dewey.author (id) where merged_into is null;

-- One row per string anyone might type or see.
--
-- POPULATING THIS FROM OPEN LIBRARY `alternate_names` IS MANDATORY IN V1.
-- The spike reported that a search for "Sayaka Murata" could not reach
-- 村田沙耶香; re-checking the raw data showed OL's own `alternate_names` for
-- that author already contains 'Sayaka Murata'. The gap was the projection
-- discarding the field, not the provider lacking it.
create table if not exists dewey.author_name (
    id         bigint generated always as identity primary key,
    author_id  uuid not null references dewey.author (id) on delete cascade,
    name       text not null,                    -- original string, never normalised in place
    kind       dewey.name_kind not null,
    script     text,                             -- ISO 15924: Latn, Jpan, Hang, Cyrl
    language   text,
    source     dewey.provider not null,
    folded     text generated always as (dewey.fold(name)) stored,
    created_at timestamptz not null default now()
);
-- Duplicate aliases are common upstream (the same string arriving from the
-- canonical name and again from alternate_names). The unique index makes the
-- ingest idempotent instead of making it the ingester's problem.
create unique index if not exists author_name_unique
    on dewey.author_name (author_id, kind, name);
create index if not exists author_name_folded_idx on dewey.author_name (folded);
create index if not exists author_name_trgm_idx
    on dewey.author_name using gin (folded gin_trgm_ops);
create index if not exists author_name_author_idx on dewey.author_name (author_id);

-- ---------------------------------------------------------------------------
-- work, work_title
-- ---------------------------------------------------------------------------

create table if not exists dewey.work (
    id                   uuid primary key,
    work_type            dewey.work_type not null default 'book',
    display_title        text not null,
    display_subtitle     text,
    first_published_year int,
    first_published_date date,
    series_name          text,
    series_position      numeric,     -- numeric: "#2.5" novellas exist
    description          text,        -- cleaned at ingest, never raw provider markup
    original_language    text,
    ddc                  text,
    slug                 text,        -- mutable, public URLs, NOT identity
    display_cover_id     uuid,        -- FK added after `cover` exists
    canonical_edition_id uuid,        -- FK added after `edition` exists
    merged_into          uuid references dewey.work (id),
    created_at           timestamptz not null default now(),
    updated_at           timestamptz not null default now(),

    constraint work_not_self_merged check (merged_into is null or merged_into <> id)
);
create unique index if not exists work_slug_key on dewey.work (slug) where slug is not null;
create index if not exists work_live_idx on dewey.work (id) where merged_into is null;
create index if not exists work_type_live_idx on dewey.work (work_type) where merged_into is null;
create index if not exists work_series_idx on dewey.work (series_name) where series_name is not null;
create index if not exists work_updated_idx on dewey.work (updated_at);

create table if not exists dewey.work_title (
    id         bigint generated always as identity primary key,
    work_id    uuid not null references dewey.work (id) on delete cascade,
    kind       dewey.title_kind not null,
    title      text not null,        -- the original string, preserved exactly
    language   text,
    source     dewey.provider not null,
    is_display boolean not null default false,
    folded     text generated always as (dewey.fold(title)) stored,
    title_key  text generated always as (dewey.title_key(title)) stored,
    created_at timestamptz not null default now()
);
create unique index if not exists work_title_unique
    on dewey.work_title (work_id, kind, title, coalesce(language, ''));
create unique index if not exists work_title_one_display
    on dewey.work_title (work_id) where is_display;
create index if not exists work_title_key_idx on dewey.work_title (title_key);
create index if not exists work_title_folded_idx on dewey.work_title (folded);
create index if not exists work_title_trgm_idx
    on dewey.work_title using gin (title_key gin_trgm_ops);
create index if not exists work_title_work_idx on dewey.work_title (work_id);

-- ---------------------------------------------------------------------------
-- edition, edition_isbn
-- ---------------------------------------------------------------------------

create table if not exists dewey.edition (
    id             uuid primary key,
    work_id        uuid not null references dewey.work (id) on delete cascade,
    title          text,
    subtitle       text,
    language       text,
    publisher      text,
    -- Kept as text *and* parsed. OL's publish_date is free-form ("1998",
    -- "March 2003", "n.d."); throwing the original away to store an int would
    -- lose information we cannot recover without re-reading the dump.
    published_date text,
    published_year int,
    page_count     int,
    format         dewey.edition_format,
    cover_id       uuid,             -- FK added after `cover` exists
    merged_into    uuid references dewey.edition (id),
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),

    constraint edition_not_self_merged check (merged_into is null or merged_into <> id),
    constraint edition_page_count_sane  check (page_count is null or page_count between 1 and 50000)
);
create index if not exists edition_work_idx on dewey.edition (work_id) where merged_into is null;
create index if not exists edition_work_lang_idx on dewey.edition (work_id, language);
create index if not exists edition_work_year_idx
    on dewey.edition (work_id, published_year desc nulls last);

-- ISBN, decided empirically. See implementation notes for the measurement.
--
-- NO GLOBAL UNIQUE CONSTRAINT ON isbn13. Measured over the 247,763 editions of
-- the spike corpus: 2.17% of valid ISBN-13s (3,287 of 151,711) appear on more
-- than one edition record, and 0.15% (220) appear on editions of *different*
-- works. A global unique index would reject thousands of legitimate rows at
-- ingest because of upstream data quality — corrupting coverage to enforce a
-- cleanliness the source does not have.
--
-- What IS enforced: the stored value is a checksum-valid ISBN-13, and an
-- edition cannot carry the same ISBN twice. Collisions are permitted, recorded,
-- and surfaced by `dewey.isbn_collision` below — where a cross-work collision
-- is not merely an error to tolerate but a genuine duplicate-work *signal*.
create table if not exists dewey.edition_isbn (
    edition_id uuid not null references dewey.edition (id) on delete cascade,
    isbn13     char(13) not null,
    isbn10     char(10),          -- retained when the source supplied one
    source     dewey.provider not null,
    created_at timestamptz not null default now(),

    primary key (edition_id, isbn13),
    constraint edition_isbn13_valid check (dewey.isbn13_valid(isbn13)),
    constraint edition_isbn10_valid check (isbn10 is null or dewey.isbn10_valid(isbn10))
);
create index if not exists edition_isbn13_idx on dewey.edition_isbn (isbn13);
create index if not exists edition_isbn10_idx on dewey.edition_isbn (isbn10) where isbn10 is not null;

-- ---------------------------------------------------------------------------
-- Contributors
-- ---------------------------------------------------------------------------

create table if not exists dewey.work_contributor (
    work_id   uuid not null references dewey.work (id) on delete cascade,
    author_id uuid not null references dewey.author (id) on delete restrict,
    role      dewey.work_role not null,
    position  int not null default 0,
    source    dewey.provider not null,

    primary key (work_id, author_id, role)
);
create index if not exists work_contributor_author_idx on dewey.work_contributor (author_id);

create table if not exists dewey.edition_contributor (
    edition_id uuid not null references dewey.edition (id) on delete cascade,
    author_id  uuid not null references dewey.author (id) on delete restrict,
    role       dewey.edition_role not null,
    position   int not null default 0,
    source     dewey.provider not null,

    primary key (edition_id, author_id, role)
);
create index if not exists edition_contributor_author_idx on dewey.edition_contributor (author_id);

-- ---------------------------------------------------------------------------
-- Subjects
-- ---------------------------------------------------------------------------

create table if not exists dewey.subject (
    id         bigint generated always as identity primary key,
    label      text not null,
    vocabulary dewey.subject_vocabulary not null,
    folded     text generated always as (dewey.fold(label)) stored
);
create unique index if not exists subject_unique on dewey.subject (vocabulary, label);
create index if not exists subject_folded_idx on dewey.subject (folded);

create table if not exists dewey.work_subject (
    work_id    uuid not null references dewey.work (id) on delete cascade,
    subject_id bigint not null references dewey.subject (id) on delete cascade,
    source     dewey.provider not null,
    primary key (work_id, subject_id)
);
create index if not exists work_subject_subject_idx on dewey.work_subject (subject_id);

-- ---------------------------------------------------------------------------
-- source_record
-- ---------------------------------------------------------------------------
--
-- What a provider handed us, and when.
--
-- DUMP PAYLOADS ARE NOT STORED. The works+editions+authors raw JSON is 60-90GB
-- uncompressed and is reproducible: Open Library publishes monthly dumps at
-- stable archived URLs, so a dump-derived record is fully addressable by
-- (source_version, provider_id). Keeping 60GB of re-downloadable JSON in the
-- primary database would be the definition of the schema bloat this design set
-- out to avoid. The CHECK below makes that policy structural rather than a
-- convention someone forgets.
--
-- API payloads ARE stored: a live force-import response is *not* reproducible
-- — the record can change or vanish before the next dump — and these are
-- low-volume by construction, being only the books a reader actually wanted.
create table if not exists dewey.source_record (
    id             bigint generated always as identity primary key,
    provider       dewey.provider not null,
    record_type    text not null,               -- 'work' | 'edition' | 'author'
    provider_id    text not null,
    acquisition    dewey.acquisition not null,
    source_version text not null,               -- dump date, or API fetch date
    imported_at    timestamptz not null default now(),
    content_hash   text,
    payload        jsonb,
    payload_ref    text,                        -- object-store key, when out-of-line

    constraint source_record_dump_has_no_payload
        check (acquisition <> 'dump' or payload is null)
);
create unique index if not exists source_record_unique
    on dewey.source_record (provider, record_type, provider_id, source_version);
create index if not exists source_record_provider_version_idx
    on dewey.source_record (provider, source_version);
create index if not exists source_record_hash_idx on dewey.source_record (content_hash);

-- ---------------------------------------------------------------------------
-- identifier
-- ---------------------------------------------------------------------------
--
-- Every external id, in one place — including prototype Dewey ids such as
-- 'piranesi', which are provider `dewey_legacy`. That uniformity is the point:
-- the design's rule is that no provider's identifier is ever identity, and
-- routing the prototype's own ids through the same table is what stops the
-- 2026 prototype from being an exception to its own rule.
--
-- Polymorphic `entity_id` is deliberate and is the one place this schema trades
-- referential purity for comprehensibility; the alternative is three
-- near-identical tables and three copies of every query over them. Integrity is
-- kept by `dewey.identifier_target_exists()` below rather than by a foreign key.
create table if not exists dewey.identifier (
    id            bigint generated always as identity primary key,
    entity_type   dewey.entity_type not null,
    entity_id     uuid not null,
    provider      dewey.provider not null,
    id_type       text not null,     -- 'ol_work','ol_edition','ol_author','local_book_id','isbn13'…
    value         text not null,
    is_primary    boolean not null default false,
    first_seen_at timestamptz not null default now(),
    last_seen_at  timestamptz not null default now()
);
-- One external id means one entity of a given type. This is the constraint that
-- makes "have we seen OL20893680W before?" a single indexed lookup during
-- ingest, and it is what keeps a re-run of the same dump idempotent.
create unique index if not exists identifier_unique
    on dewey.identifier (provider, id_type, value, entity_type);
create index if not exists identifier_entity_idx on dewey.identifier (entity_type, entity_id);
create index if not exists identifier_lookup_idx on dewey.identifier (id_type, value);
create index if not exists identifier_stale_idx on dewey.identifier (provider, last_seen_at);

-- ---------------------------------------------------------------------------
-- Redirects
-- ---------------------------------------------------------------------------
--
-- Three narrow tables rather than one polymorphic one, so each gets a real
-- foreign key to a real target and is read on the hot resolve path.
--
-- CHAINS ARE COLLAPSED AT WRITE TIME by the merge functions below: when B
-- merges into C, every row already pointing at B is rewritten to C in the same
-- transaction. Resolution is therefore always a single lookup and can never
-- loop. The `no_self` checks and the cycle guard in the merge functions are the
-- belt and braces on that guarantee.

create table if not exists dewey.work_redirect (
    old_id    uuid primary key,
    new_id    uuid not null references dewey.work (id) on delete cascade,
    reason    dewey.redirect_reason not null,
    merged_at timestamptz not null default now(),
    constraint work_redirect_no_self check (old_id <> new_id)
);
create index if not exists work_redirect_new_idx on dewey.work_redirect (new_id);

create table if not exists dewey.edition_redirect (
    old_id    uuid primary key,
    new_id    uuid not null references dewey.edition (id) on delete cascade,
    reason    dewey.redirect_reason not null,
    merged_at timestamptz not null default now(),
    constraint edition_redirect_no_self check (old_id <> new_id)
);
create index if not exists edition_redirect_new_idx on dewey.edition_redirect (new_id);

create table if not exists dewey.author_redirect (
    old_id    uuid primary key,
    new_id    uuid not null references dewey.author (id) on delete cascade,
    reason    dewey.redirect_reason not null,
    merged_at timestamptz not null default now(),
    constraint author_redirect_no_self check (old_id <> new_id)
);
create index if not exists author_redirect_new_idx on dewey.author_redirect (new_id);

-- ---------------------------------------------------------------------------
-- field_provenance
-- ---------------------------------------------------------------------------
--
-- ONE WINNING ROW PER FIELD — not a claims history. The losing values stay
-- recoverable from `source_record` (payloads for API records, re-derivable from
-- the archived dump for the rest), so storing every provider's value for every
-- field would duplicate what we already have at ~54M rows of near-identical
-- strings.
--
-- `locked` is the column that looks optional and is not: without it every
-- editorial correction is silently reverted by the next monthly dump. The
-- romanised display name for 村田沙耶香 is exactly that case.
create table if not exists dewey.field_provenance (
    entity_type      dewey.entity_type not null,
    entity_id        uuid not null,
    field            text not null,
    provider         dewey.provider not null,
    source_record_id bigint references dewey.source_record (id) on delete set null,
    set_at           timestamptz not null default now(),
    locked           boolean not null default false,

    primary key (entity_type, entity_id, field)
);
create index if not exists field_provenance_provider_idx
    on dewey.field_provenance (provider, field);
create index if not exists field_provenance_locked_idx
    on dewey.field_provenance (entity_type, entity_id) where locked;

-- Precedence. Higher wins. Editorial outranks every provider; a licensed feed
-- outranks the free one; `dewey_seed` is the floor so any real provider
-- supersedes a hand-written prototype value.
create or replace function dewey.provider_rank(p dewey.provider)
returns int
language sql
immutable
as $$
    select case p
        when 'dewey_editorial' then 100
        when 'nielsen'         then 80
        when 'bowker'          then 80
        when 'isbndb'          then 60
        when 'wikidata'        then 40
        when 'openlibrary'     then 30
        when 'dewey_seed'      then 10
        when 'dewey_legacy'    then 5
    end
$$;

-- The single gate every field write goes through.
--
-- Returns true when the caller may write this field. A locked row is
-- immovable except by another editorial write; otherwise the incoming
-- provider must rank at least as high as the incumbent. Equal rank wins so a
-- monthly refresh from the same provider can update its own value.
create or replace function dewey.claim_field(
    p_entity_type      dewey.entity_type,
    p_entity_id        uuid,
    p_field            text,
    p_provider         dewey.provider,
    p_source_record_id bigint default null,
    p_lock             boolean default false
) returns boolean
language plpgsql
as $$
declare
    cur record;
begin
    select * into cur
      from dewey.field_provenance
     where entity_type = p_entity_type and entity_id = p_entity_id and field = p_field;

    if found then
        if cur.locked and p_provider <> 'dewey_editorial' then
            return false;
        end if;
        if dewey.provider_rank(p_provider) < dewey.provider_rank(cur.provider) then
            return false;
        end if;
    end if;

    insert into dewey.field_provenance (entity_type, entity_id, field, provider,
                                        source_record_id, set_at, locked)
    values (p_entity_type, p_entity_id, p_field, p_provider,
            p_source_record_id, now(), p_lock)
    on conflict (entity_type, entity_id, field) do update
        set provider         = excluded.provider,
            source_record_id = excluded.source_record_id,
            set_at           = excluded.set_at,
            locked           = excluded.locked;
    return true;
end $$;

-- ---------------------------------------------------------------------------
-- cover
-- ---------------------------------------------------------------------------
--
-- Covers are rows referencing a book, never a column on it, because "remove one
-- cover source without deleting the book" is a hard requirement: no free
-- provider licenses cover art, because none owns it.
create table if not exists dewey.cover (
    id               uuid primary key,
    work_id          uuid references dewey.work (id) on delete cascade,
    edition_id       uuid references dewey.edition (id) on delete cascade,
    source           dewey.cover_source not null,
    source_ref       text not null,      -- OL CoverID, vendor asset id, or URL
    license_posture  dewey.license_posture not null,
    fetched_at       timestamptz,
    cached_object_key text,
    purged_at        timestamptz,
    created_at       timestamptz not null default now(),

    constraint cover_targets_one check (num_nonnulls(work_id, edition_id) = 1)
);
create index if not exists cover_work_idx on dewey.cover (work_id) where work_id is not null;
create index if not exists cover_edition_idx on dewey.cover (edition_id) where edition_id is not null;
-- "Purge every cover from source X" must be one indexed statement.
create index if not exists cover_source_purge_idx on dewey.cover (source, purged_at);
create unique index if not exists cover_source_ref_unique
    on dewey.cover (source, source_ref, coalesce(work_id, edition_id));

-- Deferred FKs, now that `cover` and `edition` exist.
do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'work_display_cover_fk') then
        alter table dewey.work add constraint work_display_cover_fk
            foreign key (display_cover_id) references dewey.cover (id) on delete set null;
    end if;
    if not exists (select 1 from pg_constraint where conname = 'work_canonical_edition_fk') then
        alter table dewey.work add constraint work_canonical_edition_fk
            foreign key (canonical_edition_id) references dewey.edition (id) on delete set null;
    end if;
    if not exists (select 1 from pg_constraint where conname = 'edition_cover_fk') then
        alter table dewey.edition add constraint edition_cover_fk
            foreign key (cover_id) references dewey.cover (id) on delete set null;
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- work_signal
-- ---------------------------------------------------------------------------
--
-- Ranking features, kept in their own table because they are recomputed on a
-- different cadence (nightly aggregates) than the catalog (monthly ingest) — so
-- a signal refresh never touches a canonical row — and so search tuning can
-- change without a catalog migration.
--
-- `edition_count` is retained but is NOT the popularity signal. It measures
-- reprint history, and the spike showed it inverts the desired order:
-- "Piranesi" ranks Giovanni Battista Piranesi's etchings (25 editions) above
-- Susanna Clarke's novel (23). `ol_readers` (41,000 vs 30) is the signal that
-- gets it right, and comes free from Open Library's monthly reading-log dump.
create table if not exists dewey.work_signal (
    work_id              uuid primary key references dewey.work (id) on delete cascade,
    edition_count        int not null default 0,
    recent_edition_count int not null default 0,
    ol_readers           int,
    ol_rating_count      int,
    ol_rating_avg        numeric(3,2),
    dewey_saves          int not null default 0,
    completeness         smallint not null default 0,
    is_derivative        boolean not null default false,
    popularity           real not null default 0,
    computed_at          timestamptz not null default now(),

    constraint work_signal_completeness_range check (completeness between 0 and 100)
);
create index if not exists work_signal_live_idx
    on dewey.work_signal (popularity desc) where not is_derivative;
create index if not exists work_signal_saves_idx on dewey.work_signal (dewey_saves desc);

-- ---------------------------------------------------------------------------
-- work_search — the materialized projection
-- ---------------------------------------------------------------------------
--
-- Holds no truth of its own; rebuildable from the catalog at any time.
--
-- `authors_folded` carrying aliases and romanizations is the single most
-- important column here: it is what lets a search for "Sayaka Murata" reach a
-- work whose upstream canonical author is 村田沙耶香, with no query-time
-- cleverness at all.
create table if not exists dewey.work_search (
    work_id         uuid primary key references dewey.work (id) on delete cascade,
    display_title   text not null,
    display_authors text,
    title_key       text,
    title_folded    text,
    alt_title_keys  text[] not null default '{}',
    authors_folded  text[] not null default '{}',
    -- Stored, not an expression index: an index over array_to_string(...) is
    -- rejected because the function is STABLE, not IMMUTABLE — found in the
    -- spike, fixed here by materialising the value.
    authors_blob    text not null default '',
    isbns           char(13)[] not null default '{}',
    year            int,
    languages       text[] not null default '{}',
    work_type       dewey.work_type not null default 'book',
    is_derivative   boolean not null default false,
    popularity      real not null default 0,
    completeness    smallint not null default 0,
    cover_ref       text,
    tsv             tsvector,
    updated_at      timestamptz not null default now()
);
create index if not exists work_search_tsv_idx on dewey.work_search using gin (tsv);
create index if not exists work_search_title_trgm_idx
    on dewey.work_search using gin (title_key gin_trgm_ops);
create index if not exists work_search_authors_trgm_idx
    on dewey.work_search using gin (authors_blob gin_trgm_ops);
create index if not exists work_search_isbn_idx on dewey.work_search using gin (isbns);
create index if not exists work_search_alt_idx on dewey.work_search using gin (alt_title_keys);
create index if not exists work_search_rank_idx
    on dewey.work_search (is_derivative, popularity desc);

-- ---------------------------------------------------------------------------
-- Resolution
-- ---------------------------------------------------------------------------

-- Follow a work redirect to the live work. Chains are collapsed at write time,
-- so this is a single lookup; the loop is a safety net that terminates rather
-- than a design that relies on iteration.
create or replace function dewey.resolve_work(p_id uuid)
returns uuid
language plpgsql
stable
as $$
declare
    cur uuid := p_id;
    nxt uuid;
    hops int := 0;
begin
    loop
        select new_id into nxt from dewey.work_redirect where old_id = cur;
        exit when nxt is null;
        cur := nxt;
        hops := hops + 1;
        if hops > 8 then
            raise exception 'work redirect chain too long or cyclic from %', p_id
                using errcode = 'data_exception';
        end if;
    end loop;
    return cur;
end $$;

create or replace function dewey.resolve_author(p_id uuid)
returns uuid
language plpgsql
stable
as $$
declare cur uuid := p_id; nxt uuid; hops int := 0;
begin
    loop
        select new_id into nxt from dewey.author_redirect where old_id = cur;
        exit when nxt is null;
        cur := nxt; hops := hops + 1;
        if hops > 8 then
            raise exception 'author redirect chain too long or cyclic from %', p_id
                using errcode = 'data_exception';
        end if;
    end loop;
    return cur;
end $$;

create or replace function dewey.resolve_edition(p_id uuid)
returns uuid
language plpgsql
stable
as $$
declare cur uuid := p_id; nxt uuid; hops int := 0;
begin
    loop
        select new_id into nxt from dewey.edition_redirect where old_id = cur;
        exit when nxt is null;
        cur := nxt; hops := hops + 1;
        if hops > 8 then
            raise exception 'edition redirect chain too long or cyclic from %', p_id
                using errcode = 'data_exception';
        end if;
    end loop;
    return cur;
end $$;

-- THE LEGACY LOOKUP PATH, explicitly.
--
--   'piranesi'  ->  identifier(dewey_legacy, local_book_id)  ->  work uuid
--                ->  resolve_work()                          ->  live work uuid
--
-- Also serves ol_work ids and any future provider, which is the whole argument
-- for routing prototype ids through `identifier` rather than the primary key.
create or replace function dewey.resolve_external_work(
    p_id_type text,
    p_value   text
) returns uuid
language sql
stable
as $$
    select dewey.resolve_work(i.entity_id)
      from dewey.identifier i
     where i.entity_type = 'work' and i.id_type = p_id_type and i.value = p_value
     limit 1
$$;

-- ISBN-shaped input gets a deterministic exact path, never a text search.
--
-- Ordering is explicit because a cross-work ISBN collision is real (0.15% of
-- ISBNs in the spike corpus): popularity first, then work id, so the same
-- query always returns the same first row rather than whatever the planner
-- happened to produce.
create or replace function dewey.resolve_isbn(p_raw text)
returns table (work_id uuid, edition_id uuid, isbn13 char(13))
language sql
stable
as $$
    select dewey.resolve_work(e.work_id), e.id, ei.isbn13
      from dewey.edition_isbn ei
      join dewey.edition e on e.id = ei.edition_id
      left join dewey.work_signal s on s.work_id = e.work_id
     where ei.isbn13 = dewey.isbn_to_13(p_raw)
       and e.merged_into is null
     order by coalesce(s.popularity, 0) desc, e.work_id, e.id
$$;

-- The cross-work ISBN collision report. Not merely an error list: an ISBN
-- appearing on two works is a genuine duplicate-work signal, and this is the
-- queue an operator works through.
create or replace view dewey.isbn_collision as
    select ei.isbn13,
           count(distinct e.work_id) as work_count,
           array_agg(distinct e.work_id) as work_ids
      from dewey.edition_isbn ei
      join dewey.edition e on e.id = ei.edition_id
     where e.merged_into is null
     group by ei.isbn13
    having count(distinct e.work_id) > 1;

-- Integrity check for the polymorphic identifier table, run periodically
-- rather than enforced by a foreign key.
create or replace view dewey.identifier_orphan as
    select i.*
      from dewey.identifier i
     where (i.entity_type = 'work'    and not exists (select 1 from dewey.work    w where w.id = i.entity_id))
        or (i.entity_type = 'edition' and not exists (select 1 from dewey.edition e where e.id = i.entity_id))
        or (i.entity_type = 'author'  and not exists (select 1 from dewey.author  a where a.id = i.entity_id));

-- ---------------------------------------------------------------------------
-- Merges
-- ---------------------------------------------------------------------------
--
-- FKs ARE PHYSICALLY REPOINTED; the redirect layer exists for references we do
-- not own — user rows, client caches, old deep links. Catalog relationships are
-- moved to the survivor so that every join in the schema reaches live data
-- without going through a resolve step. Chain collapse happens in the same
-- transaction, so resolution stays a single lookup forever.

create or replace function dewey.merge_authors(
    p_loser  uuid,
    p_winner uuid,
    p_reason dewey.redirect_reason default 'duplicate'
) returns void
language plpgsql
as $$
declare
    loser_name text;
begin
    if p_loser = p_winner then
        raise exception 'cannot merge an author into itself'
            using errcode = 'data_exception';
    end if;
    -- Refuse the merge that would create a cycle: if the winner already
    -- redirects (transitively) to the loser, this would make both unreachable.
    if dewey.resolve_author(p_winner) = p_loser then
        raise exception 'merging % into % would create a redirect cycle', p_loser, p_winner
            using errcode = 'data_exception';
    end if;

    select display_name into loser_name from dewey.author where id = p_loser;
    if not found then
        raise exception 'author % does not exist', p_loser using errcode = 'data_exception';
    end if;

    -- Losing names are retained, on the survivor. Nothing is destroyed, so a
    -- wrong merge is undoable.
    insert into dewey.author_name (author_id, name, kind, source)
    values (p_winner, loser_name, 'former', 'dewey_editorial')
    on conflict do nothing;

    insert into dewey.author_name (author_id, name, kind, script, language, source)
    select p_winner, n.name,
           case when n.kind = 'canonical' then 'source_variant' else n.kind end,
           n.script, n.language, n.source
      from dewey.author_name n
     where n.author_id = p_loser
    on conflict do nothing;

    -- Relationships move to the survivor. `on conflict do nothing` because the
    -- same work may already credit both records — which is precisely how the
    -- duplicate was noticed.
    insert into dewey.work_contributor (work_id, author_id, role, position, source)
    select work_id, p_winner, role, position, source
      from dewey.work_contributor where author_id = p_loser
    on conflict do nothing;
    delete from dewey.work_contributor where author_id = p_loser;

    insert into dewey.edition_contributor (edition_id, author_id, role, position, source)
    select edition_id, p_winner, role, position, source
      from dewey.edition_contributor where author_id = p_loser
    on conflict do nothing;
    delete from dewey.edition_contributor where author_id = p_loser;

    -- External ids follow the entity, so OL's author key still resolves.
    update dewey.identifier
       set entity_id = p_winner
     where entity_type = 'author' and entity_id = p_loser
       and not exists (
           select 1 from dewey.identifier x
            where x.entity_type = 'author' and x.entity_id = p_winner
              and x.provider = dewey.identifier.provider
              and x.id_type  = dewey.identifier.id_type
              and x.value    = dewey.identifier.value);
    delete from dewey.identifier where entity_type = 'author' and entity_id = p_loser;

    update dewey.field_provenance set entity_id = p_winner
     where entity_type = 'author' and entity_id = p_loser
       and not exists (
           select 1 from dewey.field_provenance y
            where y.entity_type = 'author' and y.entity_id = p_winner
              and y.field = dewey.field_provenance.field);
    delete from dewey.field_provenance where entity_type = 'author' and entity_id = p_loser;

    -- Collapse chains: anything already pointing at the loser now points at
    -- the winner, so `resolve_author` never needs a second hop.
    update dewey.author_redirect set new_id = p_winner where new_id = p_loser;

    insert into dewey.author_redirect (old_id, new_id, reason)
    values (p_loser, p_winner, p_reason)
    on conflict (old_id) do update set new_id = excluded.new_id;

    update dewey.author set merged_into = p_winner, updated_at = now() where id = p_loser;
end $$;

create or replace function dewey.merge_works(
    p_loser  uuid,
    p_winner uuid,
    p_reason dewey.redirect_reason default 'duplicate'
) returns void
language plpgsql
as $$
begin
    if p_loser = p_winner then
        raise exception 'cannot merge a work into itself' using errcode = 'data_exception';
    end if;
    if dewey.resolve_work(p_winner) = p_loser then
        raise exception 'merging % into % would create a redirect cycle', p_loser, p_winner
            using errcode = 'data_exception';
    end if;
    if not exists (select 1 from dewey.work where id = p_loser) then
        raise exception 'work % does not exist', p_loser using errcode = 'data_exception';
    end if;

    -- Editions move; they are the loser's manifestations of the same book.
    update dewey.edition set work_id = p_winner, updated_at = now() where work_id = p_loser;

    -- Titles survive as alternates: the loser's display title is a real string
    -- someone may search for, and discarding it would lose a match path.
    insert into dewey.work_title (work_id, kind, title, language, source, is_display)
    select p_winner,
           case when t.kind = 'canonical' then 'alternate' else t.kind end,
           t.title, t.language, t.source, false
      from dewey.work_title t
     where t.work_id = p_loser
    on conflict do nothing;

    insert into dewey.work_contributor (work_id, author_id, role, position, source)
    select p_winner, author_id, role, position, source
      from dewey.work_contributor where work_id = p_loser
    on conflict do nothing;

    insert into dewey.work_subject (work_id, subject_id, source)
    select p_winner, subject_id, source
      from dewey.work_subject where work_id = p_loser
    on conflict do nothing;

    update dewey.cover set work_id = p_winner where work_id = p_loser;

    update dewey.identifier
       set entity_id = p_winner
     where entity_type = 'work' and entity_id = p_loser
       and not exists (
           select 1 from dewey.identifier x
            where x.entity_type = 'work' and x.entity_id = p_winner
              and x.provider = dewey.identifier.provider
              and x.id_type  = dewey.identifier.id_type
              and x.value    = dewey.identifier.value);
    delete from dewey.identifier where entity_type = 'work' and entity_id = p_loser;

    update dewey.field_provenance set entity_id = p_winner
     where entity_type = 'work' and entity_id = p_loser
       and not exists (
           select 1 from dewey.field_provenance y
            where y.entity_type = 'work' and y.entity_id = p_winner
              and y.field = dewey.field_provenance.field);
    delete from dewey.field_provenance where entity_type = 'work' and entity_id = p_loser;

    update dewey.work_redirect set new_id = p_winner where new_id = p_loser;

    insert into dewey.work_redirect (old_id, new_id, reason)
    values (p_loser, p_winner, p_reason)
    on conflict (old_id) do update set new_id = excluded.new_id;

    -- The loser row is KEPT, tombstoned. Deleting it would cascade to
    -- `work_search` and take the redirect's FK target with it; more
    -- importantly a tombstone is auditable and a delete is not.
    delete from dewey.work_search where work_id = p_loser;
    delete from dewey.work_title   where work_id = p_loser;
    delete from dewey.work_subject where work_id = p_loser;
    delete from dewey.work_contributor where work_id = p_loser;
    update dewey.work set merged_into = p_winner, updated_at = now() where id = p_loser;
end $$;

create or replace function dewey.merge_editions(
    p_loser  uuid,
    p_winner uuid,
    p_reason dewey.redirect_reason default 'duplicate'
) returns void
language plpgsql
as $$
begin
    if p_loser = p_winner then
        raise exception 'cannot merge an edition into itself' using errcode = 'data_exception';
    end if;
    if dewey.resolve_edition(p_winner) = p_loser then
        raise exception 'merging % into % would create a redirect cycle', p_loser, p_winner
            using errcode = 'data_exception';
    end if;

    insert into dewey.edition_isbn (edition_id, isbn13, isbn10, source)
    select p_winner, isbn13, isbn10, source
      from dewey.edition_isbn where edition_id = p_loser
    on conflict do nothing;
    delete from dewey.edition_isbn where edition_id = p_loser;

    insert into dewey.edition_contributor (edition_id, author_id, role, position, source)
    select p_winner, author_id, role, position, source
      from dewey.edition_contributor where edition_id = p_loser
    on conflict do nothing;
    delete from dewey.edition_contributor where edition_id = p_loser;

    update dewey.cover set edition_id = p_winner where edition_id = p_loser;

    update dewey.identifier
       set entity_id = p_winner
     where entity_type = 'edition' and entity_id = p_loser
       and not exists (
           select 1 from dewey.identifier x
            where x.entity_type = 'edition' and x.entity_id = p_winner
              and x.provider = dewey.identifier.provider
              and x.id_type  = dewey.identifier.id_type
              and x.value    = dewey.identifier.value);
    delete from dewey.identifier where entity_type = 'edition' and entity_id = p_loser;

    update dewey.edition_redirect set new_id = p_winner where new_id = p_loser;
    insert into dewey.edition_redirect (old_id, new_id, reason)
    values (p_loser, p_winner, p_reason)
    on conflict (old_id) do update set new_id = excluded.new_id;

    update dewey.edition set merged_into = p_winner, updated_at = now() where id = p_loser;
end $$;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------
--
-- The catalog is public read-only reference data. Writes belong to the
-- ingestion service, which connects as the table owner and is not subject to
-- these policies. The iOS client holds the anon/authenticated key and must
-- never be able to write here — the same reasoning as `0001_identity.sql`:
-- anyone holding a key that ships inside the app binary can issue arbitrary
-- PostgREST requests.

do $$
declare t text;
begin
    foreach t in array array[
        'work','work_title','edition','edition_isbn','author','author_name',
        'work_contributor','edition_contributor','subject','work_subject',
        'cover','identifier','source_record','field_provenance','work_signal',
        'work_redirect','edition_redirect','author_redirect','work_search'
    ] loop
        execute format('alter table dewey.%I enable row level security', t);
        execute format('drop policy if exists %I on dewey.%I', t || '_read', t);
    end loop;
end $$;

do $$
declare t text;
begin
    -- Public bibliographic data: readable by both API roles.
    foreach t in array array[
        'work','work_title','edition','edition_isbn','author','author_name',
        'work_contributor','edition_contributor','subject','work_subject',
        'cover','work_signal','work_redirect','edition_redirect',
        'author_redirect','work_search'
    ] loop
        execute format(
            'create policy %I on dewey.%I for select to anon, authenticated using (true)',
            t || '_read', t);
        execute format('grant select on dewey.%I to anon, authenticated', t);
    end loop;

    -- Operational tables stay closed. `source_record` can hold retained API
    -- payloads and `identifier`/`field_provenance` describe our ingest
    -- posture; none of it is the client's business, and `identifier` in
    -- particular would let a caller enumerate provider coverage.
    foreach t in array array['identifier','source_record','field_provenance'] loop
        execute format('revoke all on dewey.%I from anon, authenticated', t);
    end loop;
end $$;

grant usage on schema dewey to anon, authenticated;

-- Resolution helpers are exposed as functions so a client can resolve a legacy
-- id or an ISBN without being granted read on `identifier` itself.
grant execute on function dewey.resolve_work(uuid)                 to anon, authenticated;
grant execute on function dewey.resolve_author(uuid)               to anon, authenticated;
grant execute on function dewey.resolve_edition(uuid)              to anon, authenticated;
grant execute on function dewey.resolve_external_work(text, text)  to anon, authenticated;
grant execute on function dewey.resolve_isbn(text)                 to anon, authenticated;
