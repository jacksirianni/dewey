#!/bin/bash
# Phase B: editions extraction ONLY. Must not touch docs.jsonl or the engines
# while phase A is still loading them.
set -euo pipefail
cd "$(dirname "$0")/data"
echo "=== waiting for editions.gz ==="
until [ -f editions.gz ] && [ "$(stat -f%z editions.gz)" -ge 12530000000 ]; do sleep 30; done
echo "=== waiting for phase A to publish kept_works.json ==="
until [ -f kept_works.json ]; do sleep 20; done
python3 ../extract_editions_filtered.py 2>&1 | tee editions.log
echo "PHASE_B_DONE"
