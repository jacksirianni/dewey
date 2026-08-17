-- Executable verification for `0004_library.sql`.
--
-- Same harness as `01-verify.sql`: every check runs a real statement as a real
-- API role with a real JWT claim, and asserts on what Postgres did. This file
-- assumes `test.check`/`test.check_count`/`test.results` already exist —
-- run `01-verify.sql` first in the same database, or paste its harness
-- section (lines 1-119) ahead of this file.
--
-- Run with:
--   psql -d dewey_verify -f supabase/test/00-supabase-stub.sql
--   psql -d dewey_verify -f supabase/0001_identity.sql
--   psql -d dewey_verify -f supabase/0004_library.sql
--   psql -d dewey_verify -f supabase/test/01-verify.sql
--   psql -d dewey_verify -f supabase/test/04-library-verify.sql
--
-- Output is one row per assertion with PASS or FAIL, and a non-zero count of
-- failures at the end.

\set ON_ERROR_STOP on
\pset pager off

truncate test.results restart identity;

-- Fixtures ===================================================================

delete from public.library_entries;
delete from public.favorite_books;
delete from public.seed_follows;
delete from public.follows;
delete from public.profiles;
delete from auth.users;

insert into auth.users (id, email) values
    ('aaaaaaaa-0000-4000-8000-000000000001', 'a@example.com'),
    ('bbbbbbbb-0000-4000-8000-000000000002', 'b@example.com'),
    ('cccccccc-0000-4000-8000-000000000003', 'c@example.com');

insert into public.profiles (user_id, display_name, handle) values
    ('aaaaaaaa-0000-4000-8000-000000000001', 'Fixture A', 'fixtureA'),
    ('bbbbbbbb-0000-4000-8000-000000000002', 'Fixture B', 'fixtureB');

\set A '''aaaaaaaa-0000-4000-8000-000000000001'''
\set B '''bbbbbbbb-0000-4000-8000-000000000002'''
\set C '''cccccccc-0000-4000-8000-000000000003'''

begin;

-- A. Structure ===============================================================

do $$
declare n int;
begin
    select count(*) into n
    from pg_tables where schemaname='public' and tablename='library_entries' and rowsecurity;
    insert into test.results (section,label,outcome,detail)
    values ('A. structure', 'RLS enabled on library_entries',
            case when n=1 then 'PASS' else 'FAIL' end,
            case when n=1 then '' else 'rowsecurity is false — table is unprotected' end);

    select count(*) into n from pg_indexes
    where schemaname='public' and indexname='library_entries_user_book_key';
    insert into test.results (section,label,outcome,detail)
    values ('A. structure','unique index on (user_id, book_ref)',
            case when n=1 then 'PASS' else 'FAIL' end, '');

    select count(*) into n from pg_indexes
    where schemaname='public' and indexname='library_entries_user_status_idx';
    insert into test.results (section,label,outcome,detail)
    values ('A. structure','index on (user_id, status)',
            case when n=1 then 'PASS' else 'FAIL' end, '');
end
$$;

-- Meta-check: confirm RLS actually filters rows under SET ROLE, before
-- trusting any "cannot" assertion below.
insert into public.library_entries (user_id, book_ref, status) values (:A, 'dewey:piranesi', 'reading');

select test.check_count('A. structure','RLS filters rows under SET ROLE (C sees none of A''s)',
    :C, 'select 1 from public.library_entries', 0);
select test.check_count('A. structure','…and A sees their own',
    :A, 'select 1 from public.library_entries', 1);

delete from public.library_entries;

-- B. status CHECK constraint =================================================

select test.check('B. status shape','known status accepted', :A,
    format('insert into public.library_entries (user_id, book_ref, status) values (%L, ''dewey:piranesi'', ''wantToRead'')', :A));
delete from public.library_entries;

select test.check('B. status shape','junk status rejected', :A,
    format('insert into public.library_entries (user_id, book_ref, status) values (%L, ''dewey:piranesi'', ''on_fire'')', :A),
    '23514');

select test.check('B. status shape','empty book_ref rejected', :A,
    format('insert into public.library_entries (user_id, book_ref, status) values (%L, '''', ''reading'')', :A),
    '23514');

-- C. uniqueness — one status per (user, book) ================================

select test.check('C. uniqueness','A sets a status', :A,
    format('insert into public.library_entries (user_id, book_ref, status) values (%L, ''olw:OL262758W'', ''wantToRead'')', :A));

select test.check('C. uniqueness','A cannot double-insert the same book', :A,
    format('insert into public.library_entries (user_id, book_ref, status) values (%L, ''olw:OL262758W'', ''reading'')', :A),
    '23505');

select test.check('C. uniqueness','…but an upsert on the pair changes status cleanly', :A,
    format('insert into public.library_entries (user_id, book_ref, status) values (%L, ''olw:OL262758W'', ''reading'')
            on conflict (user_id, book_ref) do update set status = excluded.status', :A));

select test.check_count('C. uniqueness','exactly one row for that (user, book) after the upsert',
    :A, format('select 1 from public.library_entries where user_id = %L and book_ref = ''olw:OL262758W''', :A), 1);

select test.check('C. uniqueness','B can set the same book_ref independently (scoped per user)', :B,
    format('insert into public.library_entries (user_id, book_ref, status) values (%L, ''olw:OL262758W'', ''finished'')', :B));

delete from public.library_entries;

-- D. RLS — the adversarial core ==============================================
-- This is the check that matters most: user B must never read or write user
-- A's library, in any direction, by any statement shape.

insert into public.library_entries (user_id, book_ref, status) values
    (:A, 'dewey:piranesi', 'reading'),
    (:A, 'dewey:severance', 'finished');

-- Read
select test.check_count('D. rls','B reading A''s library sees nothing',
    :B, format('select 1 from public.library_entries where user_id = %L', :A), 0);
select test.check_count('D. rls','B reading "all" library rows sees only their own (none yet)',
    :B, 'select 1 from public.library_entries', 0);
select test.check_count('D. rls','A sees their own two rows',
    :A, 'select 1 from public.library_entries', 2);

-- Forge an insert into A's library while authenticated as B
select test.check('D. rls','B cannot insert a row claiming to be A', :B,
    format('insert into public.library_entries (user_id, book_ref, status) values (%L, ''dewey:forged'', ''reading'')', :A),
    '42501');

-- Update A's row while authenticated as B (using-clause should hide the row
-- entirely: zero rows affected, not an error)
select test.check('D. rls','B''s update of A''s row is a no-op (0 rows, no error)', :B,
    format('update public.library_entries set status = ''didNotFinish'' where user_id = %L and book_ref = ''dewey:piranesi''', :A));

select test.check_count('D. rls','A''s row survived B''s update attempt',
    :A, 'select 1 from public.library_entries where book_ref = ''dewey:piranesi'' and status = ''reading''', 1);

-- Attempt to reassign one's own row onto another user via UPDATE ... SET user_id
insert into public.library_entries (user_id, book_ref, status) values (:B, 'dewey:hobbit', 'wantToRead');
select test.check('D. rls','B cannot reassign their own row to A via UPDATE user_id', :B,
    format('update public.library_entries set user_id = %L where user_id = %L and book_ref = ''dewey:hobbit''', :A, :B),
    '42501');

select test.check_count('D. rls','the row is still B''s, untouched',
    :B, format('select 1 from public.library_entries where book_ref = ''dewey:hobbit'' and user_id = %L', :B), 1);

-- Delete A's row while authenticated as B
select test.check('D. rls','B''s delete of A''s row is a no-op (0 rows, no error)', :B,
    format('delete from public.library_entries where user_id = %L and book_ref = ''dewey:severance''', :A));

select test.check_count('D. rls','A''s severance row survived B''s delete attempt',
    :A, 'select 1 from public.library_entries where book_ref = ''dewey:severance''', 1);

-- anon: no grant at all
select test.check('D. rls','anon cannot select library_entries', null,
    'select 1 from public.library_entries limit 1', '42501');
select test.check('D. rls','anon cannot insert into library_entries', null,
    format('insert into public.library_entries (user_id, book_ref, status) values (%L, ''dewey:x'', ''reading'')', :A),
    '42501');

-- A can still manage their own rows normally throughout
select test.check('D. rls','A can update their own status', :A,
    'update public.library_entries set status = ''finished'' where book_ref = ''dewey:piranesi''');
select test.check_count('D. rls','…and it took',
    :A, 'select 1 from public.library_entries where book_ref = ''dewey:piranesi'' and status = ''finished''', 1);

select test.check('D. rls','A can delete their own row', :A,
    'delete from public.library_entries where book_ref = ''dewey:severance''');
select test.check_count('D. rls','…and it is gone',
    :A, 'select 1 from public.library_entries where book_ref = ''dewey:severance''', 0);

commit;

-- E. updated_at, in its own transaction ======================================
-- Must not run inside the transaction above — see the note in `01-verify.sql`
-- section K: `now()` is transaction start time, so an insert and an update in
-- one transaction produce identical timestamps and the trigger looks dead
-- when it is working perfectly.

insert into public.library_entries (user_id, book_ref, status)
values ('aaaaaaaa-0000-4000-8000-000000000001', 'dewey:e-fixture', 'wantToRead');

update public.library_entries set status = 'reading'
where user_id = 'aaaaaaaa-0000-4000-8000-000000000001' and book_ref = 'dewey:e-fixture';

do $$
declare a timestamptz; b timestamptz;
begin
    select created_at, updated_at into a, b
    from public.library_entries
    where user_id = 'aaaaaaaa-0000-4000-8000-000000000001' and book_ref = 'dewey:e-fixture';
    insert into test.results(section,label,outcome,detail)
    values ('E. updated_at','trigger advances updated_at on a later transaction',
            case when b > a then 'PASS' else 'FAIL' end,
            case when b > a then '' else format('created %s / updated %s', a, b) end);
end $$;

-- F. Privileges ===============================================================

do $$
declare n int;
begin
    select count(*) into n from information_schema.role_table_grants
    where table_schema='public' and table_name='library_entries' and grantee='authenticated' and privilege_type='SELECT';
    insert into test.results(section,label,outcome,detail)
    values ('F. privileges', 'authenticated holds an explicit SELECT grant on library_entries',
            case when n>0 then 'PASS' else 'FAIL' end,
            case when n>0 then '' else 'no explicit grant — schema depends on ambient default privileges' end);

    select count(*) into n from information_schema.role_table_grants
    where table_schema='public' and table_name='library_entries' and grantee='anon';
    insert into test.results(section,label,outcome,detail)
    values ('F. privileges', 'anon holds no grant on library_entries',
            case when n=0 then 'PASS' else 'FAIL' end,
            case when n=0 then '' else n||' privileges still granted to anon' end);
end $$;

-- G. cascade ==================================================================

do $$
declare n int;
begin
    delete from auth.users where id = 'bbbbbbbb-0000-4000-8000-000000000002';
    select count(*) into n from public.library_entries where user_id = 'bbbbbbbb-0000-4000-8000-000000000002';
    insert into test.results(section,label,outcome,detail)
    values ('G. cascade','deleting the auth user removes their library_entries',
            case when n=0 then 'PASS' else 'FAIL' end,
            case when n=0 then '' else n||' orphaned rows' end);
end $$;

-- Report =====================================================================

\echo ''
\echo '============ LIBRARY VERIFICATION RESULTS ============'
select section, label, outcome, detail from test.results order by id;

\echo ''
select outcome, count(*) from test.results group by outcome order by outcome;

select case when count(*) = 0
            then 'ALL CHECKS PASSED'
            else count(*)||' FAILURE(S) — see above' end as summary
from test.results where outcome = 'FAIL';
