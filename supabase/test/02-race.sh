#!/usr/bin/env bash
#
# The handle race, with two genuinely concurrent sessions.
#
# `handle_available` can only ever report what was true a moment ago. Two
# readers can be told the same handle is free inside the same second, and the
# question this answers is what happens when both then commit to it. The claim
# under test is that the unique index — not the client, not the availability
# check — is what decides, and that the loser gets 23505 rather than a duplicate
# row or a deadlock.
#
# This cannot be tested from one connection: a single session would see its own
# uncommitted row. So session one opens a transaction, inserts, and *holds it
# open*; session two attempts the same handle in a different case and blocks on
# the index until session one commits.
#
# Usage: supabase/test/02-race.sh [dbname]

set -uo pipefail
DB="${1:-dewey_verify}"
export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"

A='11111111-0000-4000-8000-00000000000a'
B='22222222-0000-4000-8000-00000000000b'

psql -q -d "$DB" >/dev/null 2>&1 <<SQL
delete from public.profiles where handle_normalized = 'raceme';
delete from auth.users where id in ('$A','$B');
insert into auth.users (id, email) values ('$A','race-a@example.com'), ('$B','race-b@example.com');
SQL

# Both sessions ask first, and both are told yes. That is the premise.
avail_a=$(psql -qtA -d "$DB" -c "select public.handle_available('raceme');")
avail_b=$(psql -qtA -d "$DB" -c "select public.handle_available('RACEME');")
echo "availability before either commits — A: ${avail_a}, B: ${avail_b}"

# Session one: insert, hold the transaction open, then commit.
(
psql -q -d "$DB" >/tmp/race-a.log 2>&1 <<SQL
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$A","role":"authenticated"}';
insert into public.profiles (user_id, display_name, handle, account_setup_complete)
values ('$A', 'Racer A', 'raceme', true);
select pg_sleep(3);
commit;
SQL
echo "A_EXIT=$?" >> /tmp/race-a.log
) &

sleep 1

# Session two: the same handle in a different case. Blocks on the unique index
# until A commits, then must fail.
psql -v ON_ERROR_STOP=0 -q -d "$DB" >/tmp/race-b.log 2>&1 <<SQL
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$B","role":"authenticated"}';
insert into public.profiles (user_id, display_name, handle, account_setup_complete)
values ('$B', 'Racer B', 'RACEME', true);
commit;
SQL

wait

echo "--- session B result ---"
grep -E "ERROR|DETAIL" /tmp/race-b.log | head -3 || echo "(no error — this is a FAILURE)"

rows=$(psql -qtA -d "$DB" -c "select count(*) from public.profiles where handle_normalized='raceme';")
winner=$(psql -qtA -d "$DB" -c "select handle from public.profiles where handle_normalized='raceme';")
sqlstate=$(grep -oE "SQLSTATE[: ]*[0-9A-Z]{5}" /tmp/race-b.log | head -1)
duplicate=$(grep -c "duplicate key value violates unique constraint" /tmp/race-b.log)

echo ""
echo "rows holding that handle: ${rows}   (must be exactly 1)"
echo "winner stored as:         ${winner}"
echo "loser rejected by index:  ${duplicate} (must be 1)"

if [[ "$rows" == "1" && "$duplicate" == "1" ]]; then
    echo "RACE TEST: PASS — the unique index decided, the loser got a duplicate-key error"
    exit 0
else
    echo "RACE TEST: FAIL"
    exit 1
fi
