#!/bin/bash
# tests/test_session.sh — payload-driven session-data coverage (Layer 2).
#
# Pins the model badge, duration tag, context redline and cost tag/tier-bump,
# and the invariant that with every session feature OFF a rich payload renders
# identically to an empty one (no field leaks into the default line).
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

# Fable model, $12.50, 3h12m (11_520_000 ms), 90% context window.
PAYLOAD='{"model":{"display_name":"Fable"},"cost":{"total_cost_usd":12.5,"total_duration_ms":11520000},"context_window":{"used_percentage":90,"context_window_size":200000},"exceeds_200k_tokens":false}'
fails=0

_strip() { LC_ALL=C sed $'s/\x1b\\[[0-9;]*m//g'; }

# _render <NOW> [extra env...] → stripped statusline.
_render() {
  local now="$1"; shift
  printf '%s' "$PAYLOAD" | env \
    -u CC_INSOMNII_HOME -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
    -u CC_INSOMNII_SHAME -u CC_INSOMNII_MOTIVATION \
    -u CC_INSOMNII_RAINBOW -u CC_INSOMNII_BREATHING -u CC_INSOMNII_DAWN \
    -u CC_INSOMNII_MODEL -u CC_INSOMNII_CONTEXT -u CC_INSOMNII_DURATION \
    -u CC_INSOMNII_COST -u CC_INSOMNII_COST_BUMP \
    XDG_CONFIG_HOME="$EMPTY" \
    CC_INSOMNII_NOW="$now" CC_INSOMNII_BEDTIME=23:00 "$@" \
    "$BIN" 2>&1 | _strip
}

_contains() { # LABEL NEEDLE HAYSTACK
  if [[ "$3" != *"$2"* ]]; then
    printf 'FAIL %s: expected to contain "%s"\n      got: %s\n' "$1" "$2" "$3"
    fails=$(( fails + 1 ))
  fi
}
_absent() { # LABEL NEEDLE HAYSTACK
  if [[ "$3" == *"$2"* ]]; then
    printf 'FAIL %s: expected NOT to contain "%s"\n      got: %s\n' "$1" "$2" "$3"
    fails=$(( fails + 1 ))
  fi
}

# --- model badge: shown in calm modes when on, absent when off ---
_contains "model plain"      "Fable" "$(_render 22:00 CC_INSOMNII_MODEL=1)"
_contains "model motivation" "Fable" "$(_render 10:00 CC_INSOMNII_MODEL=1)"
_absent   "model off"        "Fable" "$(_render 22:00)"

# A made-up future display_name must surface verbatim (no hard-coded family list).
out=$(printf '{"model":{"display_name":"Nimbus"}}' | env \
  -u CC_INSOMNII_HOME -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
  XDG_CONFIG_HOME="$EMPTY" CC_INSOMNII_NOW=22:00 CC_INSOMNII_BEDTIME=23:00 \
  CC_INSOMNII_MODEL=1 "$BIN" 2>&1 | _strip)
_contains "model unknown family" "Nimbus" "$out"

# A 0x1f (US) byte in display_name is stripped in jq, not split into the badge.
us_dn=$(printf 'Mod\037el')
us_payload=$(jq -nc --arg m "$us_dn" '{model:{display_name:$m}}')
us_out=$(printf '%s' "$us_payload" | env \
  -u CC_INSOMNII_HOME -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
  XDG_CONFIG_HOME="$EMPTY" CC_INSOMNII_NOW=22:00 CC_INSOMNII_BEDTIME=23:00 \
  CC_INSOMNII_MODEL=1 "$BIN" 2>&1 | _strip)
_contains "US-byte split-safe" "Model" "$us_out"

# --- duration tag (3h12m) appended to the clock ---
_contains "duration tag" "3h12m" "$(_render 23:30 CC_INSOMNII_DURATION=1)"
_absent   "duration off" "3h12m" "$(_render 23:30)"

# A fractional total_duration_ms is floored in jq (not dropped by the int guard).
df_out=$(printf '{"cost":{"total_duration_ms":11520000.7}}' | env \
  -u CC_INSOMNII_HOME -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
  XDG_CONFIG_HOME="$EMPTY" CC_INSOMNII_NOW=23:30 CC_INSOMNII_BEDTIME=23:00 \
  CC_INSOMNII_DURATION=1 "$BIN" 2>&1 | _strip)
_contains "duration float floored" "3h12m" "$df_out"

# --- context redline marker ---
_contains "context redline" "[!]" "$(_render 23:30 CC_INSOMNII_CONTEXT=1)"
_absent   "context off"     "[!]" "$(_render 23:30)"

# --- cost tag ---
_contains "cost tag" "\$12.50" "$(_render 23:30 CC_INSOMNII_COST=1)"
_absent   "cost off" "\$12.50" "$(_render 23:30)"

# --- no leak: every feature OFF, rich payload == empty payload ---
rich=$(_render 23:30)
lean=$(printf '{}' | env \
  -u CC_INSOMNII_HOME -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
  XDG_CONFIG_HOME="$EMPTY" CC_INSOMNII_NOW=23:30 CC_INSOMNII_BEDTIME=23:00 \
  "$BIN" 2>&1 | _strip)
if [[ "$rich" != "$lean" ]]; then
  printf 'FAIL no-leak: rich payload differs from empty with all features off\n  rich: %s\n  lean: %s\n' "$rich" "$lean"
  fails=$(( fails + 1 ))
fi

if (( fails > 0 )); then
  printf '\n%d session assertion(s) failed\n' "$fails"
  exit 1
fi
exit 0
