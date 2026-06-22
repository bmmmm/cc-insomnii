#!/usr/bin/env bash
# tests/test_wrap.sh — midnight-wrap generalization + config resilience.
#
# Pins the NEW wrap rule: shame wraps whenever we are before today's bedtime and
# it is the small hours (now < 06:00), not only for evening bedtimes. So an
# afternoon bedtime now escalates overnight instead of silently showing plain,
# while the default evening bedtime keeps its existing wrap delta byte-for-byte.
#
# Also pins phase-1 config robustness from the script's perspective: malformed
# JSON degrades to the no-config baseline, and a scalar `"shame": false` is still
# parsed for bedtime AND honoured as a disable.
#
# Empty XDG_CONFIG_HOME + unset toggles keep a developer's real config out; ANSI
# is stripped before matching; CC_INSOMNII_NOW is pinned for determinism.
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

EMPTY=$(mktemp -d)        # empty config home for the no-config / env-only cases
CFG_HOME=$(mktemp -d)     # populated config home for the resilience cases
trap 'rm -rf "$EMPTY" "$CFG_HOME"' EXIT
mkdir -p "$CFG_HOME/cc-insomnii"
CFG="$CFG_HOME/cc-insomnii/config.json"

PAYLOAD='{"model":{"display_name":"Sonnet"}}'
fails=0

_strip() { LC_ALL=C sed $'s/\x1b\\[[0-9;]*m//g'; }

# _render NOW BEDTIME DAWN SHAME — env-driven, empty config, deterministic.
_render() {
  printf '%s' "$PAYLOAD" | env \
    -u CC_INSOMNII_HOME -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
    -u CC_INSOMNII_MOTIVATION -u CC_INSOMNII_RAINBOW -u CC_INSOMNII_BREATHING \
    XDG_CONFIG_HOME="$EMPTY" \
    CC_INSOMNII_NOW="$1" CC_INSOMNII_BEDTIME="$2" \
    CC_INSOMNII_DAWN="$3" CC_INSOMNII_SHAME="$4" \
    "$BIN" 2>&1 | _strip
}

# _render_cfg NOW BEDTIME — config-driven (config.json present), no shame env.
_render_cfg() {
  printf '%s' "$PAYLOAD" | env \
    -u CC_INSOMNII_SHAME -u CC_INSOMNII_MESSAGES -u CC_INSOMNII_HOME \
    -u CC_INSOMNII_CONFIG -u CC_INSOMNII_DAWN -u CC_INSOMNII_BEDTIME \
    XDG_CONFIG_HOME="$CFG_HOME" CC_INSOMNII_NOW="$1" \
    ${2:+CC_INSOMNII_BEDTIME="$2"} \
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

# --- Afternoon bedtime now wraps into shame in the small hours (FIX 1) ---
# bedtime 14:00, now 02:00: old code showed plain (delta -720 not wrapped); the
# generalized rule wraps (delta < 0 && now < 06:00) → shame. Assert the elapsed
# "+" suffix, which the plain moon render never carries.
afternoon=$(_render 02:00 14:00 04:00 true) || afternoon="<render failed: $?>"
_contains "afternoon bedtime 14:00 @ 02:00 wraps to shame (+ suffix)" "+" "$afternoon"
_not_contains "afternoon bedtime 14:00 @ 02:00 is not the plain moon" "☾" "$afternoon"

# --- Default evening bedtime keeps its wrap delta (no regression) ---
# 23:00 bedtime at 00:30 → +1h30m (mode 2). The suffix is exact and never in the
# message catalogue, so it discriminates the precise wrapped delta.
evening=$(_render 00:30 23:00 04:00 true) || evening="<render failed: $?>"
_contains "evening bedtime 23:00 @ 00:30 still +1h30m" "+1h30m" "$evening"

# --- Cliff boundary: 18:00 vs 17:59 bedtime at 01:00 both wrap to shame ---
# With the generalized rule, BOTH wrap (delta < 0 && now < 06:00) — the old
# "bedtime >= 18:00" cliff is gone, so 17:59 no longer falls off into plain.
bt1800=$(_render 01:00 18:00 04:00 true) || bt1800="<render failed: $?>"
bt1759=$(_render 01:00 17:59 04:00 true) || bt1759="<render failed: $?>"
_contains "bedtime 18:00 @ 01:00 wraps to shame" "+" "$bt1800"
_not_contains "bedtime 18:00 @ 01:00 not plain moon" "☾" "$bt1800"
_contains "bedtime 17:59 @ 01:00 wraps to shame (cliff gone)" "+" "$bt1759"
_not_contains "bedtime 17:59 @ 01:00 not plain moon (cliff gone)" "☾" "$bt1759"

# --- Resilience: malformed config.json == no-config baseline ---
# A syntactically broken config must not change the render vs no config at all.
baseline=$(_render 23:30 23:00 04:00 true)               # env-driven, no config file
printf '%s' '{ this is not json' > "$CFG"
malformed=$(printf '%s' "$PAYLOAD" | env \
  -u CC_INSOMNII_HOME -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
  -u CC_INSOMNII_MOTIVATION -u CC_INSOMNII_RAINBOW -u CC_INSOMNII_BREATHING \
  XDG_CONFIG_HOME="$CFG_HOME" \
  CC_INSOMNII_NOW=23:30 CC_INSOMNII_BEDTIME=23:00 CC_INSOMNII_DAWN=04:00 \
  CC_INSOMNII_SHAME=true "$BIN" 2>&1 | _strip)
if [[ "$malformed" != "$baseline" ]]; then
  printf 'FAIL malformed config.json changed the render vs no-config baseline\n'
  printf '      baseline : %s\n' "$baseline"
  printf '      malformed: %s\n' "$malformed"
  fails=$(( fails + 1 ))
fi

# --- Resilience: scalar `"shame": false` does not shift the bedtime field (phase-1 fix) ---
# Phase-1 made the parser robust to a scalar boolean where a nested object was
# expected: `try .shame.enabled catch null` yields empty for `"shame": false`
# WITHOUT dropping a field, so the bedtime is still read from the same config and
# the US-separated split does not slide a toggle into the wrong variable. The
# scalar boolean is NOT a toggle (only the nested {"enabled":…} form is — as the
# README/man document); the discriminating proof is that bedtime 22:00 survives
# the malformed-shaped neighbour: at 23:30 the wrapped delta is exactly +1h30m.
printf '%s' '{"shame":false,"bedtime":"22:00"}' > "$CFG"
scalar=$(_render_cfg 23:30 "") || scalar="<render failed: $?>"
_contains "scalar shame:false → bedtime 22:00 still parsed (+1h30m, no field shift)" "+1h30m" "$scalar"

# The nested form IS honoured as a disable (contrast with the scalar above): with
# {"shame":{"enabled":false}} at the same time the elapsed render is suppressed,
# falling back to the plain moon. This pins the documented toggle shape.
printf '%s' '{"shame":{"enabled":false},"bedtime":"22:00"}' > "$CFG"
nested_off=$(_render_cfg 23:30 "") || nested_off="<render failed: $?>"
_contains "nested shame.enabled:false → shame suppressed (plain moon)" "☾" "$nested_off"
_not_contains "nested shame.enabled:false → no elapsed suffix" "+1h30m" "$nested_off"

if (( fails > 0 )); then
  printf '\n%d assertion(s) failed\n' "$fails"
  exit 1
fi
exit 0
