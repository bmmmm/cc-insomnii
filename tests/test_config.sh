#!/bin/bash
# tests/test_config.sh — regression: nested config.json toggles must be honored,
# including the `false` case. Two historical bugs lived here: the parser read
# flat dotted keys (."shame.enabled") instead of the documented nested form, and
# jq's `//` collapsed a literal `false` to empty. Both made config.json a no-op
# for shame/motivation/rainbow/breathing — only env vars worked.
#
# Strategy: pin a fixed night time (CC_INSOMNII_NOW) and an evening bedtime 2h
# earlier so a shame mode WOULD render, then compare shame-enabled vs disabled
# output. If the parser ignores the toggle, the two renders are identical — which
# is exactly the bug. Pinning NOW (rather than deriving bedtime from the real
# wall clock) keeps the test deterministic: a 2h-ago bedtime only escalates while
# now is inside the night window, so a wall-clock run in the morning would
# otherwise land past the 06:00 cutoff and see no shame.
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

CFG_HOME=$(mktemp -d)
trap 'rm -rf "$CFG_HOME"' EXIT
mkdir -p "$CFG_HOME/cc-insomnii"
CFG="$CFG_HOME/cc-insomnii/config.json"

# Fixed night time with an evening bedtime two hours earlier — a +2h shame mode
# (delta 120m) inside the night window, deterministic regardless of when the
# suite runs.
NOW="01:00"
BT="23:00"

PAYLOAD='{"model":{"display_name":"Sonnet"}}'
_strip() { LC_ALL=C sed $'s/\x1b\\[[0-9;]*m//g'; }
_run() {
  printf '%s' "$PAYLOAD" | env \
    -u CC_INSOMNII_SHAME -u CC_INSOMNII_MESSAGES -u CC_INSOMNII_HOME \
    -u CC_INSOMNII_CONFIG -u CC_INSOMNII_DAWN \
    -u CC_INSOMNII_MOTIVATION -u CC_INSOMNII_RAINBOW -u CC_INSOMNII_BREATHING \
    CC_INSOMNII_NOW="$NOW" CC_INSOMNII_BEDTIME="$BT" XDG_CONFIG_HOME="$CFG_HOME" "$BIN" 2>&1
}

# Shame enabled (nested) → must actually render a shame mode (elapsed suffix "+").
printf '%s' '{"shame":{"enabled":true}}' > "$CFG"
shame_on=$(_run)
on_plain=$(printf '%s' "$shame_on" | _strip)
if [[ "$on_plain" != *"+"* ]]; then
  echo "FAIL expected a shame mode (elapsed '+suffix') with shame enabled at bedtime $BT"
  echo "Output: $on_plain"
  exit 1
fi

# Shame disabled (nested false) → must differ. Identical output means the toggle
# was ignored (nested-path bug or `//`-swallows-false bug).
printf '%s' '{"shame":{"enabled":false}}' > "$CFG"
shame_off=$(_run)

if [[ "$shame_on" == "$shame_off" ]]; then
  echo "FAIL nested config toggle had no effect — config.json is being ignored"
  echo "bedtime: $BT"
  echo "enabled:  $(printf '%s' "$shame_on"  | _strip)"
  echo "disabled: $(printf '%s' "$shame_off" | _strip)"
  exit 1
fi

exit 0
