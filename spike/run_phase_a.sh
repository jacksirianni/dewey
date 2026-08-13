#!/bin/bash
# Phase A: works + authors -> corpus -> docs (no editions yet) -> 3 engines -> benchmark.
# Produces preliminary numbers so the whole pipeline is proven before the
# 11.7GB editions dump lands.
set -euo pipefail
cd "$(dirname "$0")/data"
SP=..

echo "=== waiting for works.gz + authors.gz ==="
until [ -f works.gz ] && [ -f authors.gz ] \
      && [ "$(stat -f%z works.gz)" -ge 4026000000 ] \
      && [ "$(stat -f%z authors.gz)" -ge 770000000 ]; do sleep 20; done
ls -la works.gz authors.gz | awk '{printf "%-14s %8.1f MB\n", $9, $5/1048576}'

echo "=== extract works + authors ==="
python3 $SP/extract.py authors authors.jsonl 2> authors.log &
python3 $SP/extract.py works works.jsonl 2> works.log
wait
tail -1 works.log authors.log

echo "=== select corpus ==="
NOISE_MOD=${NOISE_MOD:-40} PER_SEED_CAP=${PER_SEED_CAP:-40000} \
  python3 $SP/select_corpus.py 2>&1 | tee select.log

echo "=== build docs (no editions) ==="
NO_EDITIONS=1 python3 $SP/build_docs.py 2>&1 | tee build_docs_noed.log

echo "=== load postgres ==="
python3 $SP/pg_setup.py 2>&1 | tee pg_load.log
echo "=== load meilisearch ==="
python3 $SP/meili_setup.py 2>&1 | tee meili_load.log
echo "=== load typesense ==="
python3 $SP/ts_setup.py 2>&1 | tee ts_load.log

echo "=== benchmark (preliminary, no edition data) ==="
python3 $SP/run_bench.py postgres meilisearch typesense 2>&1 | tee bench_prelim.log
for f in bench_postgres.json bench_meilisearch.json bench_typesense.json bench_summary.json; do
  [ -f "$f" ] && cp "$f" "prelim_$f"
done
echo "PHASE_A_DONE"
