#!/bin/bash
# Phase C: after A (engines loaded, prelim bench) and B (editions extracted),
# rebuild docs WITH edition aggregates, reload all three, final benchmark,
# footprint, update mechanics.
set -euo pipefail
cd "$(dirname "$0")/data"
SP=..
echo "=== waiting for phase A and phase B ==="
until grep -q PHASE_A_DONE phase_a.log 2>/dev/null; do sleep 20; done
until grep -q PHASE_B_DONE phase_b.log 2>/dev/null; do sleep 20; done

echo "=== rebuild docs WITH editions ==="
python3 $SP/build_docs.py 2>&1 | tee build_docs.log
echo "=== reload engines ==="
python3 $SP/pg_setup.py     2>&1 | tee pg_load.log
python3 $SP/meili_setup.py  2>&1 | tee meili_load.log
python3 $SP/ts_setup.py     2>&1 | tee ts_load.log
echo "=== FINAL benchmark ==="
python3 $SP/run_bench.py postgres meilisearch typesense 2>&1 | tee bench_final.log
echo "=== footprint ==="
{ ps -o rss= -p "$(pgrep -f 'typesense-server' | head -1)" 2>/dev/null | awk '{printf "typesense_rss_mb %.0f\n", $1/1024}'
  ps -o rss= -p "$(pgrep -f 'meilisearch' | head -1)" 2>/dev/null | awk '{printf "meilisearch_rss_mb %.0f\n", $1/1024}'
  du -sm md 2>/dev/null | awk '{print "meilisearch_disk_mb "$1}'
  du -sm ts-data 2>/dev/null | awk '{print "typesense_disk_mb "$1}'
} | tee footprint.log
echo "=== update mechanics ==="
python3 $SP/update_test.py 2>&1 | tee update.log
echo "PHASE_C_DONE"
