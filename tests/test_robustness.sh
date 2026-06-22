#!/bin/bash
# tests/test_robustness.sh — NO_COLOR / ASCII / accessible / sanitize coverage.
#
# Pins the Layer-1 robustness paths by rendering a known mode-5 state
# (NOW=03:30, BEDTIME=23:00) under each new toggle and asserting the
# discriminating signal: presence/absence of an ESC byte (color), the U+2588
# decay block, and a 4-byte emoji lead. The sanitize path is checked separately
# with a deliberately dirty messages.json (embedded ESC/newline/tab).
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

# _render <NOW> [extra env assignments...] → raw (un-stripped) statusline.
# Renders mode 5 (NOW 03:30, BEDTIME 23:00) by default. Isolated from the dev env.
_render() {
  local now="$1"; shift
  printf '%s' "$PAYLOAD" | env \
    -u CC_INSOMNII_HOME -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
    -u CC_INSOMNII_SHAME -u CC_INSOMNII_MOTIVATION \
    -u CC_INSOMNII_RAINBOW -u CC_INSOMNII_BREATHING -u CC_INSOMNII_DAWN \
    -u CC_INSOMNII_COLOR -u CC_INSOMNII_ASCII -u CC_INSOMNII_ACCESSIBLE -u NO_COLOR \
    XDG_CONFIG_HOME="$EMPTY" TERM=xterm-256color \
    CC_INSOMNII_NOW="$now" CC_INSOMNII_BEDTIME=23:00 "$@" \
    "$BIN" 2>&1
}

_has_esc()   { case "$1" in *$'\033'*)          return 0 ;; *) return 1 ;; esac; }
_has_block() { case "$1" in *$'\xe2\x96\x88'*)  return 0 ;; *) return 1 ;; esac; }  # U+2588 block
_has_emoji() { case "$1" in *$'\xf0\x9f'*)      return 0 ;; *) return 1 ;; esac; }  # 4-byte emoji lead

_fail() { printf 'FAIL %s\n      got: %s\n' "$1" "$2"; fails=$(( fails + 1 )); }

# --- default mode 5: colored, has emoji ---
out=$(_render 03:30)
_has_esc   "$out" || _fail "default: expected ESC (color)" "$out"
_has_emoji "$out" || _fail "default: expected an emoji glyph" "$out"

# --- NO_COLOR: no ESC, no decay block, emoji kept (only color is disabled) ---
out=$(_render 03:30 NO_COLOR=1)
! _has_esc   "$out" || _fail "NO_COLOR: expected no ESC byte" "$out"
! _has_block "$out" || _fail "NO_COLOR: expected decay skipped (no block)" "$out"
  _has_emoji "$out" || _fail "NO_COLOR: emoji should be kept (glyphs not disabled)" "$out"

# --- CC_INSOMNII_COLOR=never behaves like NO_COLOR ---
out=$(_render 03:30 CC_INSOMNII_COLOR=never)
! _has_esc "$out" || _fail "COLOR=never: expected no ESC byte" "$out"

# --- ASCII: color kept, no 4-byte emoji ---
out=$(_render 03:30 CC_INSOMNII_ASCII=1)
  _has_esc   "$out" || _fail "ASCII: color should be kept" "$out"
! _has_emoji "$out" || _fail "ASCII: expected no emoji glyphs" "$out"

# --- ACCESSIBLE: no ESC, no decay block, no emoji ---
out=$(_render 03:30 CC_INSOMNII_ACCESSIBLE=1)
! _has_esc   "$out" || _fail "ACCESSIBLE: expected no ESC byte" "$out"
! _has_block "$out" || _fail "ACCESSIBLE: expected no decay block" "$out"
! _has_emoji "$out" || _fail "ACCESSIBLE: expected ASCII glyphs (no emoji)" "$out"

# --- sanitize: a dirty catalog message cannot break the one-line contract ---
# Build a message carrying a real ESC, newline and tab at runtime, then let jq
# encode it as valid JSON; the bin's jq decodes it back to those control bytes,
# which _sanitize must neutralise. Built at runtime to keep raw control bytes
# out of this source file. Rendered under NO_COLOR, so the only ESC that could
# appear in the output would be one leaked from the (un-sanitised) message.
DIRTY="$EMPTY/messages.json"
dirty_msg=$(printf 'AAA\033[31mBBB\nCCC\tDDD')
jq -nc --arg m "$dirty_msg" '{shame:{"1":[$m]}}' > "$DIRTY"
out=$(_render 23:30 NO_COLOR=1 CC_INSOMNII_MESSAGES="$DIRTY")
lines=$(printf '%s' "$out" | wc -l | tr -d ' ')
# `$(...)` strips the bin's single trailing newline, so a clean one-line render
# yields wc -l = 0; a leaked message newline would make it >= 1.
[[ "$lines" == "0" ]] || _fail "sanitize: message newline leaked into a second line (wc -l=$lines)" "$out"
! _has_esc "$out" || _fail "sanitize: message ESC byte leaked into output" "$out"
case "$out" in
  *"AAA[31mBBB"*) : ;;  # ESC stripped, the surrounding text survives intact
  *) _fail "sanitize: expected the message text to survive sanitisation" "$out" ;;
esac

if (( fails > 0 )); then
  printf '\n%d robustness assertion(s) failed\n' "$fails"
  exit 1
fi
exit 0
