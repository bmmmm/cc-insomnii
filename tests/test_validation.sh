#!/bin/bash
# tests/test_validation.sh — input validation and --version.
#
# Covers three contracts:
#   1. --version / -V print "cc-insomnii <semver>" and exit 0.
#   2. CC_INSOMNII_NOW rejects out-of-range / malformed values (exit 2 + stderr),
#      accepts a 1-digit hour, and treats empty as "use the real clock".
#   3. A garbage CC_INSOMNII_BEDTIME / CC_INSOMNII_DAWN warns to stderr and falls
#      back to the built-in default instead of silently corrupting the render.
#
# Every render runs with an empty XDG_CONFIG_HOME and the CC_INSOMNII_* toggles
# unset so a developer's real config can't leak in. ANSI is stripped before any
# string match, and CC_INSOMNII_NOW is pinned so renders are deterministic.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/bin/cc-insomnii"

if [[ ! -x "$BIN" ]]; then
  echo "SKIP bin/cc-insomnii not executable"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP jq required"
  exit 0
fi

EMPTY=$(mktemp -d)
trap 'rm -rf "$EMPTY"' EXIT

PAYLOAD='{"model":{"display_name":"Sonnet"}}'
fails=0

_strip() { LC_ALL=C sed $'s/\x1b\\[[0-9;]*m//g'; }

# Run BIN with a clean env; extra args after the env block become CLI args/vars.
# Usage: _run [VAR=VAL ...] -- [cli args]   → prints "stdout\x1fstderr\x1frc".
# Simpler: dedicated helpers below capture exactly what each case needs.

_contains() { # LABEL NEEDLE HAYSTACK
  if [[ "$3" != *"$2"* ]]; then
    printf 'FAIL %s: expected to contain "%s"\n      got: %s\n' "$1" "$2" "$3"
    fails=$(( fails + 1 ))
  fi
}
_equals() { # LABEL EXPECTED ACTUAL
  if [[ "$3" != "$2" ]]; then
    printf 'FAIL %s: expected "%s" got "%s"\n' "$1" "$2" "$3"
    fails=$(( fails + 1 ))
  fi
}

# --- 1. --version / -V ---
for flag in --version -V; do
  out=$("$BIN" "$flag" 2>&1); rc=$?
  _equals "version $flag: exit 0" "0" "$rc"
  if [[ ! "$out" =~ ^cc-insomnii\ [0-9] ]]; then
    printf 'FAIL version %s: output %q does not match ^cc-insomnii [0-9]\n' "$flag" "$out"
    fails=$(( fails + 1 ))
  fi
done

# --- 2. CC_INSOMNII_NOW validation ---
# Invalid values must exit 2 with an actionable stderr message and render nothing.
for bad in 99:99 25:00 12:60 notatime 24:00; do
  set +e
  out=$(printf '%s' "$PAYLOAD" | env -u CC_INSOMNII_BEDTIME -u CC_INSOMNII_DAWN \
    XDG_CONFIG_HOME="$EMPTY" CC_INSOMNII_NOW="$bad" "$BIN" 2>&1)
  rc=$?
  set -e
  _equals "NOW $bad: exit 2" "2" "$rc"
  _contains "NOW $bad: stderr names the var" "invalid CC_INSOMNII_NOW" "$out"
done

# A single-digit hour is valid and renders zero-padded.
set +e
out=$(printf '%s' "$PAYLOAD" | env -u CC_INSOMNII_DAWN XDG_CONFIG_HOME="$EMPTY" \
  CC_INSOMNII_NOW=1:30 CC_INSOMNII_BEDTIME=23:00 "$BIN" 2>&1)
rc=$?
set -e
_equals "NOW 1:30: exit 0" "0" "$rc"
_contains "NOW 1:30: zero-padded clock" "01:30" "$(printf '%s' "$out" | _strip)"

# Empty NOW falls through to the real clock — must NOT be treated as invalid.
set +e
out=$(printf '%s' "$PAYLOAD" | env XDG_CONFIG_HOME="$EMPTY" \
  CC_INSOMNII_NOW='' CC_INSOMNII_BEDTIME=23:00 "$BIN" 2>&1)
rc=$?
set -e
_equals "NOW empty: exit 0 (uses real clock)" "0" "$rc"

# --- 3. bedtime / dawn validation → warn + fall back to default ---
# Garbage bedtime: stderr warns, exit stays 0 (clean statusline), and the render
# uses the 23:00 default — at 23:30 that is exactly +30m (mode 1). The "+30m"
# suffix never appears in the message catalogue, so it is a discriminating signal
# that the fallback bedtime (not the garbage) drove the delta.
set +e
out=$(printf '%s' "$PAYLOAD" | env -u CC_INSOMNII_DAWN XDG_CONFIG_HOME="$EMPTY" \
  CC_INSOMNII_NOW=23:30 CC_INSOMNII_BEDTIME=garbage "$BIN" 2>/dev/null)
err=$(printf '%s' "$PAYLOAD" | env -u CC_INSOMNII_DAWN XDG_CONFIG_HOME="$EMPTY" \
  CC_INSOMNII_NOW=23:30 CC_INSOMNII_BEDTIME=garbage "$BIN" 2>&1 >/dev/null)
rc=$?
set -e
_equals "bad bedtime: exit 0 (statusline stays clean)" "0" "$rc"
_contains "bad bedtime: stderr warns" "invalid bedtime" "$err"
_contains "bad bedtime: fell back to 23:00 default (+30m at 23:30)" "+30m" "$(printf '%s' "$out" | _strip)"

# Out-of-range bedtime (25:99 matches HH:MM shape but exceeds 23:59) also falls back.
set +e
err=$(printf '%s' "$PAYLOAD" | env -u CC_INSOMNII_DAWN XDG_CONFIG_HOME="$EMPTY" \
  CC_INSOMNII_NOW=23:30 CC_INSOMNII_BEDTIME=25:99 "$BIN" 2>&1 >/dev/null)
set -e
_contains "out-of-range bedtime: stderr warns" "invalid bedtime 25:99" "$err"

# Garbage dawn warns and falls back to 04:00; shame off so the dawn window can show.
set +e
err=$(printf '%s' "$PAYLOAD" | env XDG_CONFIG_HOME="$EMPTY" \
  CC_INSOMNII_NOW=05:00 CC_INSOMNII_BEDTIME=23:00 CC_INSOMNII_DAWN=99:99 \
  CC_INSOMNII_SHAME=false "$BIN" 2>&1 >/dev/null)
set -e
_contains "bad dawn: stderr warns + names default" "invalid dawn 99:99" "$err"

# 00:00 is a LEGITIMATE bedtime — it must NOT warn.
set +e
err=$(printf '%s' "$PAYLOAD" | env -u CC_INSOMNII_DAWN XDG_CONFIG_HOME="$EMPTY" \
  CC_INSOMNII_NOW=12:00 CC_INSOMNII_BEDTIME=00:00 "$BIN" 2>&1 >/dev/null)
set -e
_equals "valid 00:00 bedtime: no warning" "" "$err"

if (( fails > 0 )); then
  printf '\n%d assertion(s) failed\n' "$fails"
  exit 1
fi
exit 0
