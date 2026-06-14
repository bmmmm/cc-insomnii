#!/usr/bin/env bash
# tests/test_modes.sh — mode-matrix regression.
#
# Pins the render mode for every branch of the time logic by injecting the wall
# clock through CC_INSOMNII_NOW. The dawn-override, the motivation/dawn windows
# and the midnight-wrap delta — none of which the other tests reach, because they
# depend on the absolute wall-clock hour — are asserted here deterministically.
# The synthetic epoch that CC_INSOMNII_NOW derives makes each render reproducible
# (stable glyph, colour and message), so the equality assertions below are stable.
#
# Each render is driven entirely by env vars (layer 4, highest priority) with an
# empty XDG_CONFIG_HOME, so no developer's real ~/.config/cc-insomnii leaks in.
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
  # Unset every CC_INSOMNII_* the case does not set itself, so an inherited
  # toggle (e.g. CC_INSOMNII_MOTIVATION=false in the dev's shell) can't flip the
  # rendered mode out from under the assertion. NOW/BEDTIME/DAWN/SHAME are set
  # explicitly below (layer 4, highest priority) and need no unset.
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

# Each case fixes NOW + BEDTIME (+ DAWN/SHAME) and asserts the resulting mode's
# signature: glyph for the context modes, exact elapsed suffix for the shame
# escalation. The suffix strings (+30m, +1h30m, …) never occur in the message
# catalogue, so a stray shame line can't satisfy them by accident.

# plain — well before bedtime, outside the dawn and motivation windows.
out=$(_render 18:00 23:00 04:00 true) || out="<render failed: $?>"
_contains "plain: moon glyph" "☾" "$out"
_contains "plain: clock"      "18:00" "$out"

# mode 0 — 15 min before bedtime: cyan sparkle, no elapsed suffix yet.
out=$(_render 22:45 23:00 04:00 true) || out="<render failed: $?>"
_contains "mode0: sparkle glyph" "✦" "$out"
_contains "mode0: clock"         "22:45" "$out"

# mode 1 — 30 min past bedtime.
out=$(_render 23:30 23:00 04:00 true) || out="<render failed: $?>"
_contains "mode1: +30m elapsed" "+30m" "$out"

# mode 2 — 90 min past a 23:00 bedtime, observed at 00:30. Exercises the
# midnight-wrap delta: a naive (now - bedtime) would be negative here.
out=$(_render 00:30 23:00 04:00 true) || out="<render failed: $?>"
_contains "mode2: wrap +1h30m" "+1h30m" "$out"

# mode 3 — +2h30m.
out=$(_render 01:30 23:00 04:00 true) || out="<render failed: $?>"
_contains "mode3: +2h30m" "+2h30m" "$out"

# mode 4 / mode 5 boundary — mode 5 decays the clock (digits become █), so its
# suffix cannot be asserted literally. Instead hold NOW fixed (identical epoch →
# identical glyph, message and decay seed) and move BEDTIME one minute across the
# +4h line: at delta 239 the render is an intact mode 4, at delta 240 it flips to
# mode 5. The boundary is the only variable, so the inequality isolates the jump.
mode4=$(_render 03:30 23:31 04:00 true) || mode4="<render failed A: $?>"  # delta 239m
mode5=$(_render 03:30 23:30 04:00 true) || mode5="<render failed B: $?>"  # delta 240m
_contains "mode4: intact +3h59m suffix" "+3h59m" "$mode4"
if [[ "$mode4" == "$mode5" ]]; then
  printf 'FAIL mode5: crossing +4h did not change the render (mode 5 not firing)\n'
  printf '      mode4 (+3h59m): %s\n' "$mode4"
  printf '      mode5 (+4h0m):  %s\n' "$mode5"
  fails=$(( fails + 1 ))
fi

# Dawn override — the only branch that forces mode 5 on a sub-+4h delta. Hold
# NOW and BEDTIME fixed (so epoch, delta, glyph index and message are identical)
# and move ONLY the dawn threshold across the current time. At 04:30 with a 02:00
# bedtime the delta is +2h30m (mode 3 territory); the sole difference between the
# two renders is whether 04:30 counts as "past dawn", so any inequality isolates
# the override.
no_override=$(_render 04:30 02:00 05:00 true) || no_override="<render failed A: $?>"
override=$(_render 04:30 02:00 04:00 true)    || override="<render failed B: $?>"
_contains "dawn-override: delta is +2h30m" "+2h30m" "$no_override"
if [[ "$no_override" == "$override" ]]; then
  printf 'FAIL dawn-override: crossing dawn did not change the render (override not firing)\n'
  printf '      pre-dawn : %s\n' "$no_override"
  printf '      past-dawn: %s\n' "$override"
  fails=$(( fails + 1 ))
fi

# motivation window — 10:00, bedtime long off: dim sparkle, no shame.
out=$(_render 10:00 23:00 04:00 true) || out="<render failed: $?>"
_contains "motivation: sparkle glyph" "✦" "$out"
_contains "motivation: clock"         "10:00" "$out"

# dawn window — 05:00 with shame disabled so the wrapped delta can't pre-empt it.
out=$(_render 05:00 23:00 04:00 false) || out="<render failed: $?>"
_contains "dawn: sunrise glyph" "🌅" "$out"
_contains "dawn: clock"         "05:00" "$out"

if (( fails > 0 )); then
  printf '\n%d assertion(s) failed\n' "$fails"
  exit 1
fi
exit 0
