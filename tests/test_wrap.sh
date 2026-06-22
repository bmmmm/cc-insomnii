#!/usr/bin/env bash
# tests/test_wrap.sh — midnight-wrap (evening-only) + config resilience.
#
# Pins the INTENTIONAL wrap rule: overnight shame assumes an evening/night
# bedtime (>= 18:00). The elapsed counter wraps across midnight only for such a
# bedtime; an afternoon/early-evening bedtime stays plain overnight by design
# (documented as a known limitation). The default evening bedtime keeps its exact
# wrapped delta.
#
# Also pins phase-1 config robustness from the script's perspective: malformed
# JSON degrades to the no-config baseline, a scalar `"shame": false` disables
# shame (object-type-guarded toggle parse), and a scalar leading toggle does not
# shift the bedtime field in the US-separated split.
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

# _render_cfg NOW — config.json-driven (no bedtime/shame env), deterministic.
_render_cfg() {
  printf '%s' "$PAYLOAD" | env \
    -u CC_INSOMNII_SHAME -u CC_INSOMNII_MESSAGES -u CC_INSOMNII_HOME \
    -u CC_INSOMNII_CONFIG -u CC_INSOMNII_DAWN -u CC_INSOMNII_BEDTIME \
    -u CC_INSOMNII_RAINBOW -u CC_INSOMNII_MOTIVATION -u CC_INSOMNII_BREATHING \
    XDG_CONFIG_HOME="$CFG_HOME" CC_INSOMNII_NOW="$1" \
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

# --- Default evening bedtime keeps its wrap delta (no regression) ---
# 23:00 bedtime at 00:30 → +1h30m (mode 2). The suffix is exact and never in the
# message catalogue, so it discriminates the precise wrapped delta.
evening=$(_render 00:30 23:00 04:00 true) || evening="<render failed: $?>"
_contains "evening bedtime 23:00 @ 00:30 wraps to +1h30m" "+1h30m" "$evening"

# --- Afternoon bedtime stays PLAIN overnight (evening-only wrap, by design) ---
# bedtime 14:00, now 02:00: the wrap only fires for an evening bedtime (>= 18:00),
# so an afternoon bedtime shows the plain moon — the documented known limitation.
afternoon=$(_render 02:00 14:00 04:00 true) || afternoon="<render failed: $?>"
_contains "afternoon bedtime 14:00 @ 02:00 stays plain moon" "☾" "$afternoon"
_not_contains "afternoon bedtime 14:00 @ 02:00 carries no elapsed suffix" "+" "$afternoon"

# --- Evening-threshold boundary: 18:00 wraps, 17:59 does not ---
# The wrap requires bedtime >= 18:00 (1080 min). 18:00 @ 01:00 wraps into shame;
# 17:59 @ 01:00 falls below the threshold and stays plain.
bt1800=$(_render 01:00 18:00 04:00 true) || bt1800="<render failed: $?>"
bt1759=$(_render 01:00 17:59 04:00 true) || bt1759="<render failed: $?>"
_contains "bedtime 18:00 @ 01:00 wraps to shame (+ suffix)" "+" "$bt1800"
_contains "bedtime 17:59 @ 01:00 stays plain moon" "☾" "$bt1759"

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

# --- Scalar `"shame": false` disables shame (object-type-guarded toggle, A6) ---
# The toggle parse coerces a scalar boolean: `if (.shame|type)=="object" then
# .shame.enabled else .shame end` reads the scalar `false` directly, so shame is
# disabled and the elapsed render is suppressed back to the plain moon.
printf '%s' '{"shame":false,"bedtime":"22:00"}' > "$CFG"
scalar_shame=$(_render_cfg 23:30) || scalar_shame="<render failed: $?>"
_contains "scalar shame:false → shame disabled (plain moon)" "☾" "$scalar_shame"
_not_contains "scalar shame:false → no elapsed suffix" "+1h30m" "$scalar_shame"

# --- Scalar leading toggle does not shift the bedtime field (US-split, A6) ---
# A scalar `"rainbow": false` neighbour must not slide the bedtime out of its
# slot: bedtime 22:00 is still parsed, so at 23:30 (shame on) the delta is +1h30m.
printf '%s' '{"rainbow":false,"bedtime":"22:00"}' > "$CFG"
scalar_rb=$(_render_cfg 23:30) || scalar_rb="<render failed: $?>"
_contains "scalar rainbow:false → bedtime 22:00 still parsed (+1h30m, no field shift)" "+1h30m" "$scalar_rb"

# --- Nested shame.enabled:false is honoured as a disable (documented shape) ---
printf '%s' '{"shame":{"enabled":false},"bedtime":"22:00"}' > "$CFG"
nested_off=$(_render_cfg 23:30) || nested_off="<render failed: $?>"
_contains "nested shame.enabled:false → shame suppressed (plain moon)" "☾" "$nested_off"
_not_contains "nested shame.enabled:false → no elapsed suffix" "+1h30m" "$nested_off"

if (( fails > 0 )); then
  printf '\n%d assertion(s) failed\n' "$fails"
  exit 1
fi
exit 0
