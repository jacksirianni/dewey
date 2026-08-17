-- One-shot, self-cleaning RLS verification against the REAL linked Supabase
-- project. Not part of the committed migration set — ad hoc verification
-- script, run once via `supabase db query --linked -f`.
--
-- Creates two throwaway auth.users rows, exercises library_entries RLS as
-- each of them (and as anon) via role + request.jwt.claims simulation
-- (exactly how PostgREST invokes auth.uid()/auth.role() in production), then
-- deletes everything it created. Safe to run multiple times.

create temporary table if not exists rls_check_results (seq serial, line text);
grant all on rls_check_results to anon, authenticated;
grant all on rls_check_results_seq_seq to anon, authenticated;

do $$
declare
    user_a uuid := 'aaaaaaaa-0000-4000-8000-000000000001';
    user_b uuid := 'bbbbbbbb-0000-4000-8000-000000000002';
    entry_a uuid;
    v_count int;
    v_status text;
    v_ok boolean;
    results text := '';
begin
    -- Setup: two real auth.users rows -----------------------------------
    delete from auth.users where id in (user_a, user_b);

    insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                             email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    values
        (user_a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'dewey-rls-test-a@example.com', crypt('unused', gen_salt('bf')), now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
        (user_b, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'dewey-rls-test-b@example.com', crypt('unused', gen_salt('bf')), now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

    -- ==================== USER A: full CRUD on own row ====================
    perform set_config('request.jwt.claims', json_build_object('sub', user_a, 'role', 'authenticated')::text, true);
    set local role authenticated;

    insert into public.library_entries (user_id, book_ref, status)
    values (user_a, 'olw:OL1234567W', 'wantToRead')
    returning id into entry_a;
    results := results || 'A_INSERT_OWN=ok; ';

    select count(*) into v_count from public.library_entries where id = entry_a;
    v_ok := v_count = 1;
    results := results || 'A_SELECT_OWN=' || v_ok || '; ';

    update public.library_entries set status = 'reading' where id = entry_a;
    select status into v_status from public.library_entries where id = entry_a;
    v_ok := v_status = 'reading';
    results := results || 'A_UPDATE_OWN=' || v_ok || '; ';

    reset role;
    insert into rls_check_results (line) values (results);
    results := '';

    -- ==================== USER B: adversarial checks ====================
    perform set_config('request.jwt.claims', json_build_object('sub', user_b, 'role', 'authenticated')::text, true);
    set local role authenticated;

    -- B cannot SELECT A's row
    select count(*) into v_count from public.library_entries where id = entry_a;
    v_ok := v_count = 0;
    results := results || 'B_SELECT_A_DENIED=' || v_ok || '; ';

    -- B cannot INSERT a row claiming A's user_id
    begin
        insert into public.library_entries (user_id, book_ref, status)
        values (user_a, 'olw:OL7654321W', 'wantToRead');
        results := results || 'B_INSERT_AS_A_DENIED=false(no error raised); ';
    exception when insufficient_privilege or others then
        results := results || 'B_INSERT_AS_A_DENIED=true; ';
    end;

    -- verify no row was actually created for that book_ref under A regardless of role
    reset role;
    select count(*) into v_count from public.library_entries where user_id = user_a and book_ref = 'olw:OL7654321W';
    v_ok := v_count = 0;
    results := results || 'B_INSERT_AS_A_NO_ROW=' || v_ok || '; ';

    perform set_config('request.jwt.claims', json_build_object('sub', user_b, 'role', 'authenticated')::text, true);
    set local role authenticated;

    -- B cannot UPDATE A's row (row-invisible, so update affects 0 rows)
    update public.library_entries set status = 'finished' where id = entry_a;
    get diagnostics v_count = row_count;
    v_ok := v_count = 0;
    results := results || 'B_UPDATE_A_DENIED=' || v_ok || '; ';

    -- B cannot DELETE A's row
    delete from public.library_entries where id = entry_a;
    get diagnostics v_count = row_count;
    v_ok := v_count = 0;
    results := results || 'B_DELETE_A_DENIED=' || v_ok || '; ';

    -- B creates own row, then tries to reassign it to A
    insert into public.library_entries (user_id, book_ref, status)
    values (user_b, 'olw:OL1111111W', 'wantToRead');

    begin
        update public.library_entries set user_id = user_a
        where user_id = user_b and book_ref = 'olw:OL1111111W';
        results := results || 'B_REASSIGN_TO_A_DENIED=false(no error raised); ';
    exception when insufficient_privilege or others then
        results := results || 'B_REASSIGN_TO_A_DENIED=true; ';
    end;

    reset role;
    select count(*) into v_count from public.library_entries where book_ref = 'olw:OL1111111W' and user_id = user_a;
    v_ok := v_count = 0;
    results := results || 'B_REASSIGN_NO_EFFECT=' || v_ok || '; ';

    insert into rls_check_results (line) values (results);
    results := '';

    -- ==================== ANONYMOUS: no access ====================
    perform set_config('request.jwt.claims', '', true);
    set local role anon;

    begin
        select count(*) into v_count from public.library_entries;
        v_ok := v_count = 0;
        results := results || 'ANON_SELECT_DENIED=' || v_ok || '(rows visible=' || v_count || '); ';
    exception when insufficient_privilege or others then
        results := results || 'ANON_SELECT_DENIED=true(no table grant); ';
    end;

    reset role;
    insert into rls_check_results (line) values (results);

    -- ==================== VERIFY: A can still delete own row ====================
    perform set_config('request.jwt.claims', json_build_object('sub', user_a, 'role', 'authenticated')::text, true);
    set local role authenticated;

    delete from public.library_entries where id = entry_a;
    get diagnostics v_count = row_count;
    v_ok := v_count = 1;
    insert into rls_check_results (line) values ('A_DELETE_OWN=' || v_ok);

    reset role;

    -- ==================== CLEANUP ====================
    delete from public.library_entries where user_id in (user_a, user_b);
    delete from auth.users where id in (user_a, user_b);

    insert into rls_check_results (line) values ('CLEANUP=done');
end
$$;

select line from rls_check_results order by seq;
