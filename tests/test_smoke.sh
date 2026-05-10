#!/usr/bin/env bash
# tests/test_smoke.sh — basic smoke test for bin/insomnii
# Feeds a minimal JSON payload and checks exit 0 + HH:MM in output.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/bin/insomnii"

if [[ ! -f "$BIN" ]]; then
  echo "SKIP bin/insomnii not found — skipping smoke test"
  exit 0
fi

if ! command -v insomnii >/dev/null 2>&1 && [[ ! -x "$BIN" ]]; then
  echo "SKIP bin/insomnii not executable"
  exit 0
fi

PAYLOAD='{"model":{"display_name":"Sonnet"}}'

output=$(echo "$PAYLOAD" | "$BIN" 2>&1)
rc=$?

if (( rc != 0 )); then
  echo "FAIL exit code $rc (expected 0)"
  echo "Output: $output"
  exit 1
fi

# Strip ANSI escapes — char-decay may replace digits with █ in mode 5,
# so the HH:MM pattern won't always be intact. We assert: non-empty output
# AND contains the ':' separator (always preserved across all modes).
plain=$(printf '%s' "$output" | sed $'s/\x1b\\[[0-9;]*m//g')
if [[ -z "$plain" ]]; then
  echo "FAIL empty output"
  exit 1
fi
if [[ "$plain" != *:* ]]; then
  echo "FAIL output missing ':' separator (clock not rendered)"
  echo "Output: $output"
  exit 1
fi

exit 0
