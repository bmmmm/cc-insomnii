#!/usr/bin/env bash
# tests/test_postmidnight.sh — after-midnight bedtime support.
#
# The centered-circle delta + 06:00 night-window cutoff make a post-midnight
# bedtime (e.g. 01:00) behave like an evening one, shifted: a mode-0 approach in
# the 30 min before, escalation through the shame modes after, and a clean
# hand-off to the dawn/motivation day modes at the morning cutoff — instead of
# the old behaviour where (now - bedtime) stayed positive all day and pinned
# mode 5 from ~05:00 until midnight.
#
# Env-driven with an empty XDG_CONFIG_HOME and a pinned CC_INSOMNII_NOW so every
# assertion is deterministic; ANSI is stripped before matching. Elapsed suffixes
# (+30m, +2h30m) never occur in the message catalogue, so they discriminate the
# exact delta rather than matching a stray shame line.
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

# _render NOW BEDTIME DAWN SHAME → stripped statusline as rendered at that time.
_render() {
  printf '%s' "$PAYLOAD" | env \
    -u CC_INSOMNII_HOME -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
    -u CC_INSOMNII_MOTIVATION -u CC_INSOMNII_RAINBOW -u CC_INSOMNII_BREATHING \
    XDG_CONFIG_HOME="$EMPTY" \
    CC_INSOMNII_NOW="$1" CC_INSOMNII_BEDTIME="$2" \
    CC_INSOMNII_DAWN="$3" CC_INSOMNII_SHAME="$4" \
    "$BIN" 2>&1 | _strip
}

_contains() { # LABEL NEEDLE HAYSTACK
  if [[ "$3" != *"$2"* ]]; then
    printf 'FAIL %s: expected to contain "%s"\n      got: %s\n' "$1" "$2" "$3"
    fails=$(( fails + 1 ))
  fi
}
_not_contains() { # LABEL NEEDLE HAYSTACK
  if [[ "$3" == *"$2"* ]]; then
    printf 'FAIL %s: did NOT expect "%s"\n      got: %s\n' "$1" "$2" "$3"
    fails=$(( fails + 1 ))
  fi
}

# Bedtime 01:00, dawn 04:00 — the full night arc for an after-midnight bedtime.

# Well before bedtime (> 30 min): plain moon, no approach yet.
out=$(_render 00:00 01:00 04:00 true) || out="<render failed: $?>"
_contains   "01:00 bedtime @ 00:00: plain moon" "☾" "$out"
_not_contains "01:00 bedtime @ 00:00: no elapsed suffix" "+" "$out"

# 15 min before bedtime: mode-0 sparkle approach (delta -15), no elapsed suffix.
out=$(_render 00:45 01:00 04:00 true) || out="<render failed: $?>"
_contains   "01:00 bedtime @ 00:45: sparkle approach" "✦" "$out"
_not_contains "01:00 bedtime @ 00:45: no elapsed suffix yet" "+" "$out"

# 30 min past bedtime: mode 1.
out=$(_render 01:30 01:00 04:00 true) || out="<render failed: $?>"
_contains "01:00 bedtime @ 01:30: +30m elapsed" "+30m" "$out"

# 2h30m past bedtime (pre-dawn, so no override): escalated, exact wrapped delta.
out=$(_render 03:30 01:00 04:00 true) || out="<render failed: $?>"
_contains "01:00 bedtime @ 03:30: +2h30m elapsed" "+2h30m" "$out"

# 05:59 — still inside the night window (and past dawn): mode 5 decay block █.
out=$(_render 05:59 01:00 04:00 true) || out="<render failed: $?>"
_contains "01:00 bedtime @ 05:59: mode-5 decay block █" "█" "$out"

# 06:00 — the night window closes: hand off to the dawn greeting, no shame.
out=$(_render 06:00 01:00 04:00 true) || out="<render failed: $?>"
_contains   "01:00 bedtime @ 06:00: dawn glyph" "🌅" "$out"
_not_contains "01:00 bedtime @ 06:00: no elapsed suffix" "+" "$out"

# 08:00 — THE FIX: the morning no longer pins mode 5. Old code kept (now-bedtime)
# positive all day → doom; now it is a calm motivation sparkle, no shame, no decay.
out=$(_render 08:00 01:00 04:00 true) || out="<render failed: $?>"
_contains   "01:00 bedtime @ 08:00: motivation sparkle (shame off)" "✦" "$out"
_not_contains "01:00 bedtime @ 08:00: no elapsed suffix (not shame)" "+" "$out"
_not_contains "01:00 bedtime @ 08:00: no mode-5 decay block" "█" "$out"

# Midnight-crossing approach: bedtime 00:15, now 23:50 (10 min before, delta -25
# via the centered remainder) → mode-0 sparkle, proving the approach wraps
# backward across midnight too.
out=$(_render 23:50 00:15 04:00 true) || out="<render failed: $?>"
_contains   "00:15 bedtime @ 23:50: approach wraps backward across midnight" "✦" "$out"
_not_contains "00:15 bedtime @ 23:50: no elapsed suffix" "+" "$out"

if (( fails > 0 )); then
  printf '\n%d assertion(s) failed\n' "$fails"
  exit 1
fi
exit 0
