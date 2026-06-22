#!/bin/bash
# tests/test_theme.sh — named themes, per-mode palette, quiet-hours (Layer 3).
#
# Themes swap the palette set; CC_INSOMNII_PALETTE=escalating shifts the colour
# region per mode; CC_INSOMNII_QUIET caps an active shame mode at mode 1 inside
# its window. All render byte-identically by default (proven by the sweep); this
# file pins that each knob, when set, changes the line in the intended way. The
# clock is pinned with CC_INSOMNII_NOW so every selection is deterministic.
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

# _render <NOW> [extra env...] → raw (un-stripped) statusline.
_render() {
  local now="$1"; shift
  printf '%s' "$PAYLOAD" | env \
    -u CC_INSOMNII_HOME -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
    -u CC_INSOMNII_SHAME -u CC_INSOMNII_MOTIVATION \
    -u CC_INSOMNII_RAINBOW -u CC_INSOMNII_BREATHING -u CC_INSOMNII_DAWN \
    -u CC_INSOMNII_THEME -u CC_INSOMNII_PALETTE -u CC_INSOMNII_QUIET \
    XDG_CONFIG_HOME="$EMPTY" TERM=xterm-256color \
    CC_INSOMNII_NOW="$now" CC_INSOMNII_BEDTIME=23:00 "$@" \
    "$BIN" 2>&1
}

_contains() { [[ "$3" == *"$2"* ]] || { printf 'FAIL %s: expected "%s"\n      got: %s\n' "$1" "$2" "$3"; fails=$(( fails + 1 )); }; }
_absent()   { [[ "$3" != *"$2"* ]] || { printf 'FAIL %s: did not expect "%s"\n      got: %s\n' "$1" "$2" "$3"; fails=$(( fails + 1 )); }; }
_strip()    { LC_ALL=C sed $'s/\x1b\\[[0-9;]*m//g'; }

# --- themes swap the palette (mode 1 at 23:30) ---
_contains "vibe pink"      "38;5;219" "$(_render 23:30)"
_absent   "matrix no pink" "38;5;219" "$(_render 23:30 CC_INSOMNII_THEME=matrix)"
_contains "matrix green"   "38;5;46"  "$(_render 23:30 CC_INSOMNII_THEME=matrix)"
_contains "amber tone"     "38;5;214" "$(_render 23:30 CC_INSOMNII_THEME=amber)"

# --- per-mode palette: escalating differs from classic at mode 3 (01:30) ---
if [[ "$(_render 01:30)" == "$(_render 01:30 CC_INSOMNII_PALETTE=escalating)" ]]; then
  printf 'FAIL palette: escalating did not change the mode-3 render\n'
  fails=$(( fails + 1 ))
fi

# --- quiet-hours clamp: mode 5 (03:30) is softened to mode 1 inside the window ---
# At NOW=03:30 the selection is deterministic: non-quiet is mode 5 (lead glyph
# the doom skull), quiet collapses to mode 1 (a night glyph, no swarm), but the
# real elapsed delta is preserved.
q_off=$(_render 03:30)
q_on=$(_render 03:30 CC_INSOMNII_QUIET=00:00-06:00)
# The wave wraps each clock char in its own SGR, so check the delta on the
# stripped line; the doom glyph is a single token and is checked on the raw line.
_contains "quiet keeps delta"   "+4h30m" "$(printf '%s' "$q_on" | _strip)"
_contains "non-quiet is mode 5" "💀"     "$q_off"
_absent   "quiet drops doom"    "💀"     "$q_on"
if [[ "$q_off" == "$q_on" ]]; then
  printf 'FAIL quiet: clamp did not change the render\n'
  fails=$(( fails + 1 ))
fi

# --- a malformed quiet window warns on stderr but still renders cleanly ---
# _render folds stderr into stdout, so call the bin directly to split the streams.
_raw() {
  printf '%s' "$PAYLOAD" | env \
    -u CC_INSOMNII_HOME -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
    XDG_CONFIG_HOME="$EMPTY" TERM=xterm-256color \
    CC_INSOMNII_NOW=03:30 CC_INSOMNII_BEDTIME=23:00 CC_INSOMNII_QUIET=garbage "$BIN"
}
set +e
err=$(_raw 2>&1 >/dev/null)
out=$(_raw 2>/dev/null)
set -e
_contains "invalid quiet warns" "invalid CC_INSOMNII_QUIET" "$err"
_contains "invalid quiet still renders" ":" "$out"

if (( fails > 0 )); then
  printf '\n%d theme assertion(s) failed\n' "$fails"
  exit 1
fi
exit 0
