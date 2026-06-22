#!/bin/bash
# tests/test_smoke.sh — basic smoke test for bin/cc-insomnii
# Feeds a minimal JSON payload and checks exit 0 + HH:MM in output.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/bin/cc-insomnii"

if [[ ! -f "$BIN" ]]; then
  echo "SKIP bin/cc-insomnii not found — skipping smoke test"
  exit 0
fi

if ! command -v cc-insomnii >/dev/null 2>&1 && [[ ! -x "$BIN" ]]; then
  echo "SKIP bin/cc-insomnii not executable"
  exit 0
fi
# The bin hard-requires jq; without it every render exits non-zero. Mirror the
# sibling tests and SKIP rather than report a spurious failure.
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP jq required"
  exit 0
fi

EMPTY=$(mktemp -d)
trap 'rm -rf "$EMPTY"' EXIT

PAYLOAD='{"model":{"display_name":"Sonnet"}}'

# Capture without aborting under `set -e` (a failing `$(…)` would exit here
# before `rc=$?`, hiding the real exit code we want to assert on). Isolate from
# the developer's environment (inherited CC_INSOMNII_* toggles, a real
# ~/.config/cc-insomnii) and pin the clock to 14:00 — a deterministic
# motivation-window render with no mode-5 decay, so the ':' assertion is stable.
set +e
output=$(echo "$PAYLOAD" | env \
  -u CC_INSOMNII_HOME -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
  -u CC_INSOMNII_BEDTIME -u CC_INSOMNII_DAWN -u CC_INSOMNII_SHAME \
  -u CC_INSOMNII_MOTIVATION -u CC_INSOMNII_RAINBOW -u CC_INSOMNII_BREATHING \
  XDG_CONFIG_HOME="$EMPTY" CC_INSOMNII_NOW=14:00 "$BIN" 2>&1)
rc=$?
set -e

if (( rc != 0 )); then
  echo "FAIL exit code $rc (expected 0)"
  echo "Output: $output"
  exit 1
fi

# Strip ANSI escapes and assert: non-empty output AND a ':' separator. The clock
# is pinned to the motivation window (14:00), an intact-clock render, so this is
# a structural smoke check — ':' is a mode-agnostic signal that the clock
# rendered at all. (The stronger invariant that ':' survives mode-5 char-decay is
# pinned under load by the collapse-guard in tests/test_modes.sh.)
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
