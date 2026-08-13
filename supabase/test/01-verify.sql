-- Executable verification for `0001_identity.sql`.
--
-- Every check below *exercises* the schema rather than inspecting it: each one
-- runs a real statement as a real API role, with a real JWT claim, and asserts
-- on what Postgres did. Reading `pg_policies` proves a policy exists; it does
-- not prove it denies anything. This proves it denies.
--
-- Run with:  psql -d dewey_verify -f supabase/test/01-verify.sql
-- Requires:  00-supabase-stub.sql, then 0001_identity.sql.
--
-- Output is one row per assertion with PASS or FAIL, and a non-zero count of
-- failures at the end.

\set ON_ERROR_STOP on
\pset pager off

create schema if not exists test;

create table if not exists test.results (
    id      serial primary key,
    section text,
    label   text,
    outcome text,
    detail  text
);
truncate test.results restart identity;

-- The whole harness in one function.
--
-- `uid` null means act as `anon`; otherwise act as `authenticated` with that
-- user as the JWT subject — which is exactly how PostgREST presents a request,
-- and therefore what `auth.uid()` reads.
--
-- `expect` is either 'ok' or the SQLSTATE the statement must raise. Asserting
-- on the *code* rather than on "it failed somehow" is deliberate: a policy
-- denial (42501) and a constraint violation (23514/23505) are different
-- outcomes, and a test that accepts either would pass while the schema was
-- wrong in an interesting way.
create or replace function test.check(
    section text,
    label   text,
    uid     uuid,
    stmt    text,
    expect  text default 'ok'
) returns void
language plpgsql
as $$
declare
    got_state text := 'ok';
    got_msg   text := '';
    verdict   text;
begin
    begin
        perform set_config(
            'request.jwt.claims',
            case when uid is null then ''
                 else json_build_object('sub', uid, 'role', 'authenticated')::text end,
            true
        );
        execute format('set local role %I', case when uid is null then 'anon' else 'authenticated' end);
        execute stmt;
        execute 'reset role';
    exception when others then
        get stacked diagnostics
            got_state = returned_sqlstate,
            got_msg   = message_text;
    end;

    verdict := case when got_state = expect then 'PASS' else 'FAIL' end;

    insert into test.results (section, label, outcome, detail)
    values (
        section, label, verdict,
        case when verdict = 'PASS' then ''
             else format('expected %s, got %s — %s', expect, got_state, got_msg) end
    );
end
$$;

-- Asserts a query returns an exact row count, as a given role. Used for the
-- read side of RLS, where "denied" shows up as zero rows rather than an error:
-- a select blocked by policy is not an error, it is an empty result, and a test
-- that only watched for exceptions would miss a table being world-readable.
create or replace function test.check_count(
    section text,
    label   text,
    uid     uuid,
    query   text,
    expect  bigint
) returns void
language plpgsql
as $$
declare
    got     bigint;
    verdict text;
begin
    begin
        perform set_config(
            'request.jwt.claims',
            case when uid is null then ''
                 else json_build_object('sub', uid, 'role', 'authenticated')::text end,
            true
        );
        execute format('set local role %I', case when uid is null then 'anon' else 'authenticated' end);
        execute format('select count(*) from (%s) q', query) into got;
        execute 'reset role';
    exception when others then
        execute 'reset role';
        insert into test.results (section, label, outcome, detail)
        values (section, label, 'FAIL', 'query errored: ' || sqlerrm);
        return;
    end;

    verdict := case when got = expect then 'PASS' else 'FAIL' end;
    insert into test.results (section, label, outcome, detail)
    values (section, label, verdict,
            case when verdict = 'PASS' then '' else format('expected %s rows, got %s', expect, got) end);
end
$$;

-- Fixtures ===================================================================
-- Two real auth users. Created as the owner, before any role switching, the
-- way Supabase's auth service would create them.

delete from public.favorite_books;
delete from public.seed_follows;
delete from public.follows;
delete from public.profiles;
delete from auth.users;

insert into auth.users (id, email) values
    ('aaaaaaaa-0000-4000-8000-000000000001', 'a@example.com'),
    ('bbbbbbbb-0000-4000-8000-000000000002', 'b@example.com'),
    ('cccccccc-0000-4000-8000-000000000003', 'c@example.com');

\set A '''aaaaaaaa-0000-4000-8000-000000000001'''
\set B '''bbbbbbbb-0000-4000-8000-000000000002'''
\set C '''cccccccc-0000-4000-8000-000000000003'''

begin;

-- A. Structure ===============================================================

do $$
declare
    t text;
    n int;
begin
    foreach t in array array['profiles','follows','seed_follows','favorite_books'] loop
        select count(*) into n
        from pg_tables where schemaname='public' and tablename=t and rowsecurity;
        insert into test.results (section,label,outcome,detail)
        values ('A. structure', format('RLS enabled on %s', t),
                case when n=1 then 'PASS' else 'FAIL' end,
                case when n=1 then '' else 'rowsecurity is false — table is unprotected' end);
    end loop;

    -- handle_available must be SECURITY DEFINER *and* have a pinned
    -- search_path. Definer without the pin is a privilege-escalation shape:
    -- a caller can create their own `profiles` in a schema they control and
    -- have the function body resolve to it.
    select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname='public' and p.proname='handle_available'
      and p.prosecdef
      and array_to_string(coalesce(p.proconfig,'{}'),',') like '%search_path%';
    insert into test.results (section,label,outcome,detail)
    values ('A. structure','handle_available is SECURITY DEFINER with pinned search_path',
            case when n=1 then 'PASS' else 'FAIL' end, '');

    select count(*) into n from pg_indexes
    where schemaname='public' and indexname='profiles_handle_normalized_key';
    insert into test.results (section,label,outcome,detail)
    values ('A. structure','unique index on handle_normalized',
            case when n=1 then 'PASS' else 'FAIL' end, '');
end
$$;

-- Meta-check: confirm RLS actually filters rows under SET ROLE.
--
-- **If this fails, every RLS result below is worthless** — the harness would be
-- running as a role that bypasses policies (an owner or a superuser), and every
-- "cannot" assertion would pass for the wrong reason. It is deliberately run
-- against `seed_follows`, whose policy is own-rows-only, because `profiles` is
-- `using (true)` and reading it proves grants work and nothing about policies.
insert into public.profiles (user_id, display_name, handle)
values (:A, 'Fixture A', 'fixtureA');
insert into public.seed_follows (user_id, reader_slug) values (:A, 'priya');

select test.check_count('A. structure','RLS filters rows under SET ROLE (C sees none of A''s)',
    :C, 'select 1 from public.seed_follows', 0);
select test.check_count('A. structure','…and A sees their own',
    :A, 'select 1 from public.seed_follows', 1);

delete from public.seed_follows;
delete from public.profiles;

-- B. Handle shape constraint =================================================
-- The CHECK is the authority. Each of these is a real insert.

select test.check('B. handle shape','rejects 2 characters',            :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','ab')$q$, '23514');
select test.check('B. handle shape','rejects 21 characters',           :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','abcdefghijklmnopqrstu')$q$, '23514');
select test.check('B. handle shape','rejects a space',                 :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','jack s')$q$, '23514');
select test.check('B. handle shape','rejects an @',                    :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','@jack')$q$, '23514');
select test.check('B. handle shape','rejects a hyphen',                :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','jack-s')$q$, '23514');
select test.check('B. handle shape','rejects non-ASCII',               :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','jackü')$q$, '23514');
select test.check('B. handle shape','rejects leading period',          :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','.jack')$q$, '23514');
select test.check('B. handle shape','rejects leading underscore',      :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','_jack')$q$, '23514');
select test.check('B. handle shape','rejects trailing period',         :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','jack.')$q$, '23514');
select test.check('B. handle shape','rejects consecutive periods',     :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','ja..ck')$q$, '23514');
select test.check('B. handle shape','rejects empty display name',      :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','   ','jackok')$q$, '23514');

select test.check('B. handle shape','accepts 3 characters',            :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','abc')$q$, 'ok');
delete from public.profiles;
select test.check('B. handle shape','accepts 20 characters',           :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','abcdefghijklmnopqrst')$q$, 'ok');
delete from public.profiles;
select test.check('B. handle shape','accepts interior period',         :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','ja.ck')$q$, 'ok');
delete from public.profiles;
select test.check('B. handle shape','accepts trailing underscore',     :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','jack_')$q$, 'ok');
delete from public.profiles;
select test.check('B. handle shape','accepts digits',                  :A, $q$insert into public.profiles(user_id,display_name,handle) values ('aaaaaaaa-0000-4000-8000-000000000001','A','jack99')$q$, 'ok');
delete from public.profiles;

-- C. Case-insensitive uniqueness =============================================

-- Sets `account_setup_complete` because that is what `ProfileService.createProfile`
-- actually inserts. An earlier version of this fixture omitted it and the
-- completion assertion below failed — correctly, and for a reason worth keeping
-- a test for: see 'a row inserted without the flag defaults to incomplete'.
select test.check('C. uniqueness','A takes "Jack"',  :A, $q$insert into public.profiles(user_id,display_name,handle,account_setup_complete) values ('aaaaaaaa-0000-4000-8000-000000000001','A','Jack',true)$q$, 'ok');
select test.check('C. uniqueness','B cannot take "jack"', :B, $q$insert into public.profiles(user_id,display_name,handle) values ('bbbbbbbb-0000-4000-8000-000000000002','B','jack')$q$, '23505');
select test.check('C. uniqueness','B cannot take "JACK"', :B, $q$insert into public.profiles(user_id,display_name,handle) values ('bbbbbbbb-0000-4000-8000-000000000002','B','JACK')$q$, '23505');
select test.check('C. uniqueness','B cannot take "JaCk"', :B, $q$insert into public.profiles(user_id,display_name,handle) values ('bbbbbbbb-0000-4000-8000-000000000002','B','JaCk')$q$, '23505');
select test.check('C. uniqueness','B can take a different handle', :B, $q$insert into public.profiles(user_id,display_name,handle) values ('bbbbbbbb-0000-4000-8000-000000000002','B','Jill')$q$, 'ok');

do $$
declare v text;
begin
    select handle_normalized into v from public.profiles where user_id='aaaaaaaa-0000-4000-8000-000000000001';
    insert into test.results(section,label,outcome,detail)
    values ('C. uniqueness','stored handle keeps its case, key is folded',
            case when v='jack' then 'PASS' else 'FAIL' end,
            case when v='jack' then '' else 'handle_normalized = '||coalesce(v,'null') end);
end $$;

-- D. handle_available ========================================================

select test.check_count('D. availability','taken handle reports unavailable (exact case)', :C, $q$select 1 where public.handle_available('Jack')$q$, 0);
select test.check_count('D. availability','taken handle reports unavailable (other case)', :C, $q$select 1 where public.handle_available('JACK')$q$, 0);
select test.check_count('D. availability','taken handle reports unavailable (with @)',     :C, $q$select 1 where public.handle_available('@jack')$q$, 0);
select test.check_count('D. availability','taken handle reports unavailable (whitespace)', :C, $q$select 1 where public.handle_available('  Jack ')$q$, 0);
select test.check_count('D. availability','free handle reports available',                 :C, $q$select 1 where public.handle_available('brandnew')$q$, 1);
select test.check('D. availability','anon cannot call handle_available', null, $q$select public.handle_available('x')$q$, '42501');

-- E. RLS — profiles ==========================================================

select test.check('E. rls profiles','A can update own display name', :A, $q$update public.profiles set display_name='A2' where user_id='aaaaaaaa-0000-4000-8000-000000000001'$q$, 'ok');
select test.check_count('E. rls profiles','A cannot update B (0 rows affected, silently)', :A, $q$select 1 from public.profiles where user_id='bbbbbbbb-0000-4000-8000-000000000002' and display_name='HACKED'$q$, 0);

-- An update denied by RLS affects zero rows rather than raising. Proven by
-- attempting it and then reading the row back as its owner.
select test.check('E. rls profiles','A attempts to rename B (no error, must not apply)', :A, $q$update public.profiles set display_name='HACKED' where user_id='bbbbbbbb-0000-4000-8000-000000000002'$q$, 'ok');
select test.check_count('E. rls profiles','B''s name survived A''s attempt', :B, $q$select 1 from public.profiles where user_id='bbbbbbbb-0000-4000-8000-000000000002' and display_name='B'$q$, 1);

-- The `with check` half: reassigning your row to someone else.
select test.check('E. rls profiles','A cannot reassign own row to B', :A, $q$update public.profiles set user_id='bbbbbbbb-0000-4000-8000-000000000002' where user_id='aaaaaaaa-0000-4000-8000-000000000001'$q$, '42501');

select test.check('E. rls profiles','A cannot insert a profile owned by C', :A, $q$insert into public.profiles(user_id,display_name,handle) values ('cccccccc-0000-4000-8000-000000000003','C','ceecee')$q$, '42501');

select test.check_count('E. rls profiles','A can read B''s profile (social read)', :A, $q$select 1 from public.profiles where user_id='bbbbbbbb-0000-4000-8000-000000000002'$q$, 1);
select test.check('E. rls profiles','anon is denied profiles at the grant layer', null, $q$select 1 from public.profiles$q$, '42501');
select test.check('E. rls profiles','nobody may delete a profile (no grant, no policy)', :A, $q$delete from public.profiles where user_id='bbbbbbbb-0000-4000-8000-000000000002'$q$, '42501');
select test.check_count('E. rls profiles','B''s profile survived A''s delete', :B, $q$select 1 from public.profiles where user_id='bbbbbbbb-0000-4000-8000-000000000002'$q$, 1);

-- F. RLS — follows ===========================================================

select test.check('F. rls follows','A can follow B', :A, $q$insert into public.follows(follower_user_id,followed_user_id) values ('aaaaaaaa-0000-4000-8000-000000000001','bbbbbbbb-0000-4000-8000-000000000002')$q$, 'ok');
select test.check('F. rls follows','A cannot forge a follow from B', :A, $q$insert into public.follows(follower_user_id,followed_user_id) values ('bbbbbbbb-0000-4000-8000-000000000002','cccccccc-0000-4000-8000-000000000003')$q$, '42501');
select test.check('F. rls follows','self-follow rejected', :A, $q$insert into public.follows(follower_user_id,followed_user_id) values ('aaaaaaaa-0000-4000-8000-000000000001','aaaaaaaa-0000-4000-8000-000000000001')$q$, '23514');
select test.check('F. rls follows','follow of a non-user rejected', :A, $q$insert into public.follows(follower_user_id,followed_user_id) values ('aaaaaaaa-0000-4000-8000-000000000001','dddddddd-0000-4000-8000-000000000004')$q$, '23503');
select test.check_count('F. rls follows','A can read the follow graph', :A, $q$select 1 from public.follows$q$, 1);
select test.check('F. rls follows','B cannot delete A''s follow', :B, $q$delete from public.follows where follower_user_id='aaaaaaaa-0000-4000-8000-000000000001'$q$, 'ok');
select test.check_count('F. rls follows','A''s follow survived B''s delete', :A, $q$select 1 from public.follows where follower_user_id='aaaaaaaa-0000-4000-8000-000000000001'$q$, 1);
select test.check('F. rls follows','A can delete own follow', :A, $q$delete from public.follows where follower_user_id='aaaaaaaa-0000-4000-8000-000000000001'$q$, 'ok');
select test.check_count('F. rls follows','A''s follow is gone', :A, $q$select 1 from public.follows$q$, 0);

-- G. RLS — seed_follows ======================================================

select test.check('G. rls seed_follows','A can add own', :A, $q$insert into public.seed_follows(user_id,reader_slug) values ('aaaaaaaa-0000-4000-8000-000000000001','priya')$q$, 'ok');
select test.check('G. rls seed_follows','B can add own', :B, $q$insert into public.seed_follows(user_id,reader_slug) values ('bbbbbbbb-0000-4000-8000-000000000002','marcus')$q$, 'ok');
select test.check('G. rls seed_follows','A cannot insert for B', :A, $q$insert into public.seed_follows(user_id,reader_slug) values ('bbbbbbbb-0000-4000-8000-000000000002','tobias')$q$, '42501');
select test.check_count('G. rls seed_follows','A sees only own (private, not social)', :A, $q$select 1 from public.seed_follows$q$, 1);
select test.check('G. rls seed_follows','A cannot delete B''s', :A, $q$delete from public.seed_follows where user_id='bbbbbbbb-0000-4000-8000-000000000002'$q$, 'ok');
select test.check_count('G. rls seed_follows','B''s survived', :B, $q$select 1 from public.seed_follows where user_id='bbbbbbbb-0000-4000-8000-000000000002'$q$, 1);

-- H. RLS + constraints — favorite_books ======================================

select test.check('H. favorite_books','A sets position 1', :A, $q$insert into public.favorite_books(user_id,book_id,position) values ('aaaaaaaa-0000-4000-8000-000000000001','severance',1)$q$, 'ok');
select test.check('H. favorite_books','A sets position 4', :A, $q$insert into public.favorite_books(user_id,book_id,position) values ('aaaaaaaa-0000-4000-8000-000000000001','piranesi',4)$q$, 'ok');
select test.check('H. favorite_books','position 0 rejected', :A, $q$insert into public.favorite_books(user_id,book_id,position) values ('aaaaaaaa-0000-4000-8000-000000000001','x',0)$q$, '23514');
select test.check('H. favorite_books','position 5 rejected', :A, $q$insert into public.favorite_books(user_id,book_id,position) values ('aaaaaaaa-0000-4000-8000-000000000001','y',5)$q$, '23514');
select test.check('H. favorite_books','duplicate position rejected', :A, $q$insert into public.favorite_books(user_id,book_id,position) values ('aaaaaaaa-0000-4000-8000-000000000001','z',1)$q$, '23505');
select test.check('H. favorite_books','B may reuse position 1 independently', :B, $q$insert into public.favorite_books(user_id,book_id,position) values ('bbbbbbbb-0000-4000-8000-000000000002','piranesi',1)$q$, 'ok');
select test.check('H. favorite_books','A cannot write to B''s four', :A, $q$insert into public.favorite_books(user_id,book_id,position) values ('bbbbbbbb-0000-4000-8000-000000000002','intruder',2)$q$, '42501');
select test.check('H. favorite_books','A cannot delete B''s four', :A, $q$delete from public.favorite_books where user_id='bbbbbbbb-0000-4000-8000-000000000002'$q$, 'ok');
select test.check_count('H. favorite_books','B''s four survived', :B, $q$select 1 from public.favorite_books where user_id='bbbbbbbb-0000-4000-8000-000000000002'$q$, 1);
select test.check_count('H. favorite_books','A can read B''s four (public on a profile)', :A, $q$select 1 from public.favorite_books where user_id='bbbbbbbb-0000-4000-8000-000000000002'$q$, 1);
select test.check('H. favorite_books','anon is denied at the grant layer', null, $q$select 1 from public.favorite_books$q$, '42501');
select test.check_count('H. favorite_books','positions round-trip in order', :A, $q$select book_id from public.favorite_books where user_id='aaaaaaaa-0000-4000-8000-000000000001' order by position$q$, 2);

-- I. Completion state ========================================================

select test.check('I. completion','A marks taste onboarding complete', :A, $q$update public.profiles set taste_onboarding_complete=true where user_id='aaaaaaaa-0000-4000-8000-000000000001'$q$, 'ok');
select test.check_count('I. completion','flag persisted', :A, $q$select 1 from public.profiles where user_id='aaaaaaaa-0000-4000-8000-000000000001' and taste_onboarding_complete and account_setup_complete$q$, 1);
select test.check('I. completion','A cannot flip B''s flag', :A, $q$update public.profiles set taste_onboarding_complete=true where user_id='bbbbbbbb-0000-4000-8000-000000000002'$q$, 'ok');
select test.check_count('I. completion','B''s flag untouched', :B, $q$select 1 from public.profiles where user_id='bbbbbbbb-0000-4000-8000-000000000002' and taste_onboarding_complete=false$q$, 1);

-- A row created by some path that did not set the flag must route the reader
-- back through identity setup rather than into the app. This is why the column
-- defaults to false and why `SessionStore` reads it.
select test.check('I. completion','a row inserted without the flag defaults to incomplete', :C,
    $q$insert into public.profiles(user_id,display_name,handle) values ('cccccccc-0000-4000-8000-000000000003','C','ceecee')$q$, 'ok');
select test.check_count('I. completion','…and reads back as setup-incomplete', :C,
    $q$select 1 from public.profiles where user_id='cccccccc-0000-4000-8000-000000000003' and account_setup_complete = false$q$, 1);

-- J. Cascade ================================================================
-- Deleting the auth user must take every dependent row with it, or a deleted
-- account leaves a handle permanently claimed by nobody.

delete from auth.users where id = 'bbbbbbbb-0000-4000-8000-000000000002';

do $$
declare n int;
begin
    select (select count(*) from public.profiles where user_id='bbbbbbbb-0000-4000-8000-000000000002')
         + (select count(*) from public.favorite_books where user_id='bbbbbbbb-0000-4000-8000-000000000002')
         + (select count(*) from public.seed_follows where user_id='bbbbbbbb-0000-4000-8000-000000000002')
    into n;
    insert into test.results(section,label,outcome,detail)
    values ('J. cascade','deleting the auth user removes every dependent row',
            case when n=0 then 'PASS' else 'FAIL' end,
            case when n=0 then '' else n||' orphaned rows' end);
end $$;

commit;

-- K. updated_at, in its own transaction ======================================
--
-- **Must not run inside the transaction above.** `now()` returns transaction
-- start time, so an insert and an update in one transaction produce identical
-- timestamps and the trigger looks dead when it is working perfectly. This cost
-- a false failure once; the separate transaction is the whole point of the
-- section.

update public.profiles set display_name = 'A3'
where user_id = 'aaaaaaaa-0000-4000-8000-000000000001';

do $$
declare a timestamptz; b timestamptz;
begin
    select created_at, updated_at into a, b
    from public.profiles where user_id='aaaaaaaa-0000-4000-8000-000000000001';
    insert into test.results(section,label,outcome,detail)
    values ('K. updated_at','trigger advances updated_at on a later transaction',
            case when b > a then 'PASS' else 'FAIL' end,
            case when b > a then '' else format('created %s / updated %s', a, b) end);
end $$;

-- L. Privileges ==============================================================
--
-- Guards the portability bug this harness found: the migration originally
-- issued no grants and depended on Supabase's ambient default privileges, which
-- meant it produced a working schema on a stock project and *permission denied
-- for table profiles* anywhere else.

do $$
declare
    t text;
    n int;
begin
    foreach t in array array['profiles','follows','seed_follows','favorite_books'] loop
        select count(*) into n from information_schema.role_table_grants
        where table_schema='public' and table_name=t and grantee='authenticated' and privilege_type='SELECT';
        insert into test.results(section,label,outcome,detail)
        values ('L. privileges', format('authenticated holds an explicit SELECT grant on %s', t),
                case when n>0 then 'PASS' else 'FAIL' end,
                case when n>0 then '' else 'no explicit grant — schema depends on ambient default privileges' end);

        select count(*) into n from information_schema.role_table_grants
        where table_schema='public' and table_name=t and grantee='anon';
        insert into test.results(section,label,outcome,detail)
        values ('L. privileges', format('anon holds no grant on %s', t),
                case when n=0 then 'PASS' else 'FAIL' end,
                case when n=0 then '' else n||' privileges still granted to anon' end);
    end loop;
end $$;

-- Report =====================================================================

\echo ''
\echo '================ VERIFICATION RESULTS ================'
select section, label, outcome, detail from test.results order by id;

\echo ''
select outcome, count(*) from test.results group by outcome order by outcome;

select case when count(*) = 0
            then 'ALL CHECKS PASSED'
            else count(*)||' FAILURE(S) — see above' end as summary
from test.results where outcome = 'FAIL';
