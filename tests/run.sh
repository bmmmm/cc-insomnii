#!/bin/bash
# tests/run.sh — cc-insomnii test harness
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

  # Run each test with the SAME interpreter running this harness ($BASH), not a
  # bare `bash` from PATH. The 3.2 guarantee lives in the Makefile: `make test`
  # invokes `/bin/bash tests/run.sh`, so $BASH is macOS bash 3.2 and every test
  # runs under it — the runtime the project targets. (Invoking `bash tests/run.sh`
  # directly with a newer PATH bash instead runs the tests under that bash; the
  # pin is the Makefile's hardcoded /bin/bash, not this line.)
  # Capture without aborting: under `set -e` a failing `var=$(cmd)` exits the
  # script before `rc=$?` runs, which would swallow the failure entirely.
  set +e
  output=$("$BASH" "$test_file" 2>&1)
  rc=$?
  set -e

  if (( rc == 0 )) && echo "$output" | grep -q "^SKIP"; then
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
      while IFS= read -r line; do printf '         %s\n' "$line"; done <<< "$output"
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
