-- A local stand-in for the parts of a Supabase project that `0001_identity.sql`
-- depends on, so the migration and its policies can be executed and exercised
-- against a real Postgres before they are run against the real project.
--
-- **This file is test scaffolding and must never be run against Supabase.** It
-- creates roles and an `auth` schema that a real project already has, and its
-- `auth.users` is a stub with only the columns the migration references.
--
-- What it reproduces, and why each piece matters:
--
--   * The four roles PostgREST authenticates as. `anon` and `authenticated` are
--     the two the policies name, and getting their grants wrong is the most
--     likely way for a migration to pass review and fail in production.
--   * `auth.uid()`, read from `request.jwt.claims` exactly as Supabase defines
--     it — this is what every policy in the migration is written against, so a
--     stub that read the claim differently would test nothing.
--   * Supabase's default privileges on `public`, which silently grant table
--     access to the three API roles. The migration relies on these, and the
--     point of reproducing them is to find out whether that reliance is safe.

-- Roles ----------------------------------------------------------------------
do $$
begin
    if not exists (select 1 from pg_roles where rolname = 'anon') then
        create role anon nologin noinherit;
    end if;
    if not exists (select 1 from pg_roles where rolname = 'authenticated') then
        create role authenticated nologin noinherit;
    end if;
    if not exists (select 1 from pg_roles where rolname = 'service_role') then
        create role service_role nologin noinherit bypassrls;
    end if;
end
$$;

grant usage on schema public to anon, authenticated, service_role;

-- Supabase configures these on a new project. Reproduced here because the
-- migration inherits them rather than issuing its own grants — which is
-- precisely the assumption under test.
alter default privileges in schema public
    grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
    grant all on sequences to anon, authenticated, service_role;

-- auth schema ----------------------------------------------------------------
create schema if not exists auth;
grant usage on schema auth to anon, authenticated, service_role;

create table if not exists auth.users (
    id                 uuid primary key default gen_random_uuid(),
    email              text,
    raw_user_meta_data jsonb default '{}'::jsonb,
    created_at         timestamptz not null default now()
);

-- Matches Supabase's own definition. `true` in `current_setting` means "return
-- null rather than error when unset", which is what makes an unauthenticated
-- request evaluate policies as `auth.uid() = null` — never equal to anything,
-- so every ownership policy denies. That behaviour is load-bearing.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
    select coalesce(
        nullif(current_setting('request.jwt.claim.sub', true), ''),
        (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
    )::uuid
$$;

create or replace function auth.role()
returns text
language sql
stable
as $$
    select coalesce(
        nullif(current_setting('request.jwt.claim.role', true), ''),
        (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
    )::text
$$;

grant execute on function auth.uid() to anon, authenticated, service_role;
grant execute on function auth.role() to anon, authenticated, service_role;
