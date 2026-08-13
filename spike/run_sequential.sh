#!/bin/bash
# Run all three engines STRICTLY SEQUENTIALLY: only one of {meilisearch,
# typesense} is ever running at a time. Postgres is the one persistent
# service (it's disk-backed, not RAM-resident like the other two, and every
# real architecture keeps it running) so it is loaded once and left up, but
# its own load+benchmark+update phase still runs in isolation before either
# of the other two starts.
#
# Before/after each engine: record free memory and swap so a bad run is
# visible in the log, not just in a stalled machine.
set -euo pipefail
cd "$(dirname "$0")/data"
SP=..
MEILI_PID=""
TS_PID=""

mem() {
  echo "  mem: $(sysctl -n vm.swapusage) | $(vm_stat | awk '/Pages free/{f=$3} /page size/{s=$8} END{}')"
  vm_stat | awk -v ts="$1" '/page size of/{s=$8} /Pages free/{f=$3} /Pages active/{a=$3} /Pages inactive/{i=$3} /Pages wired/{w=$3} END{printf "  [%s] free=%.0fMB active=%.0fMB inactive=%.0fMB wired=%.0fMB\n", ts, f*4096/1048576, a*4096/1048576, i*4096/1048576, w*4096/1048576}'
  echo "  [$1] swap: $(sysctl -n vm.swapusage)"
}

stop_meili() { [ -n "$MEILI_PID" ] && kill "$MEILI_PID" 2>/dev/null; pkill -f "meilisearch --db-path" 2>/dev/null || true; MEILI_PID=""; }
stop_ts()    { [ -n "$TS_PID" ] && kill "$TS_PID" 2>/dev/null; pkill -f "typesense-server" 2>/dev/null || true; TS_PID=""; }

echo "===================================================================="
echo "POSTGRES  (persistent service, loaded once)"
echo "===================================================================="
mem "pg-before"
python3 $SP/pg_setup.py 2>&1 | tee pg_load.log
mem "pg-after-load"
python3 $SP/run_bench.py postgres 2>&1 | tee bench_postgres.log
python3 $SP/update_test_one.py postgres 2>&1 | tee update_postgres.log
{ ps -o rss= -p "$(pgrep -f 'postgres -D' | head -1)" 2>/dev/null | awk '{printf "postgres_rss_mb %.0f\n", $1/1024}'
  echo "postgres_disk: $(/opt/homebrew/opt/postgresql@15/bin/psql -d dewey_spike -tAc "select pg_size_pretty(pg_total_relation_size('doc'))")"
} | tee footprint_postgres.log
mem "pg-final"

echo "===================================================================="
echo "MEILISEARCH  (starts now, stops before typesense starts)"
echo "===================================================================="
stop_ts; sleep 3
mem "meili-before-start"
rm -rf md && mkdir -p md
nohup meilisearch --db-path ./md --http-addr 127.0.0.1:7700 --no-analytics \
  --master-key deweyspikemasterkey1234 > meili.log 2>&1 &
MEILI_PID=$!
until curl -s -m 2 http://127.0.0.1:7700/health 2>/dev/null | grep -q available; do sleep 1; done
mem "meili-after-start"
python3 $SP/meili_setup.py 2>&1 | tee meili_load.log
mem "meili-after-index"
python3 $SP/run_bench.py meilisearch 2>&1 | tee bench_meilisearch.log
python3 $SP/update_test_one.py meilisearch 2>&1 | tee update_meilisearch.log
{ ps -o rss= -p "$MEILI_PID" 2>/dev/null | awk '{printf "meilisearch_rss_mb %.0f\n", $1/1024}'
  du -sm md 2>/dev/null | awk '{print "meilisearch_disk_mb "$1}'
} | tee footprint_meilisearch.log
stop_meili
sleep 5
mem "meili-after-stop"

echo "===================================================================="
echo "TYPESENSE  (starts now, meilisearch already stopped)"
echo "===================================================================="
mem "ts-before-start"
rm -rf ts-data && mkdir -p ts-data
nohup $SP/bin/typesense-server --data-dir=$(pwd)/ts-data --api-key=deweyspike \
  --listen-port=8108 > ts.log 2>&1 &
TS_PID=$!
until curl -s -m 2 -H "X-TYPESENSE-API-KEY: deweyspike" http://127.0.0.1:8108/health 2>/dev/null | grep -q '"ok":true'; do sleep 1; done
mem "ts-after-start"
python3 $SP/ts_setup.py 2>&1 | tee ts_load.log
mem "ts-after-index"
python3 $SP/run_bench.py typesense 2>&1 | tee bench_typesense.log
python3 $SP/update_test_one.py typesense 2>&1 | tee update_typesense.log
{ ps -o rss= -p "$TS_PID" 2>/dev/null | awk '{printf "typesense_rss_mb %.0f\n", $1/1024}'
  du -sm ts-data 2>/dev/null | awk '{print "typesense_disk_mb "$1}'
} | tee footprint_typesense.log
stop_ts
sleep 5
mem "ts-after-stop"

echo "SEQUENTIAL_DONE"
