#!/usr/bin/env bash
# tests/run.sh — insomnii test harness
# Usage: bash tests/run.sh [--summary]
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUMMARY=0
[[ "${1:-}" == "--summary" ]] && SUMMARY=1

pass=0
fail=0
skip=0
errors=()

for test_file in "$TESTS_DIR"/test_*.sh; do
  [[ -f "$test_file" ]] || continue
  name="$(basename "$test_file" .sh)"

  output=$(bash "$test_file" 2>&1)
  rc=$?

  if echo "$output" | grep -q "^SKIP"; then
    (( ++skip ))
    (( SUMMARY )) || printf "  SKIP  %s\n" "$name"
  elif (( rc == 0 )); then
    (( ++pass ))
    (( SUMMARY )) || printf "  PASS  %s\n" "$name"
  else
    (( ++fail ))
    errors+=("$name")
    if (( SUMMARY == 0 )); then
      printf "  FAIL  %s\n" "$name"
      echo "$output" | sed 's/^/         /'
    fi
  fi
done

total=$(( pass + fail + skip ))

if (( SUMMARY )); then
  printf "Tests: %d passed, %d failed, %d skipped (of %d)\n" "$pass" "$fail" "$skip" "$total"
else
  echo ""
  printf "Results: %d passed / %d failed / %d skipped\n" "$pass" "$fail" "$skip"
  if (( ${#errors[@]} > 0 )); then
    echo "Failed:"
    for e in "${errors[@]}"; do printf "  - %s\n" "$e"; done
  fi
fi

(( fail == 0 ))
