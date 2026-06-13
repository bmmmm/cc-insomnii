#!/usr/bin/env bash
# tests/test_config.sh — regression: nested config.json toggles must be honored,
# including the `false` case. Two historical bugs lived here: the parser read
# flat dotted keys (."shame.enabled") instead of the documented nested form, and
# jq's `//` collapsed a literal `false` to empty. Both made config.json a no-op
# for shame/motivation/rainbow/breathing — only env vars worked.
#
# Strategy: pin bedtime to ~2h ago (midnight-wrap-safe) so shame WOULD render,
# then compare shame-enabled vs shame-disabled output. If the parser ignores the
# toggle, the two renders are identical — which is exactly the bug.
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

# Bedtime two hours before now, wrapped — guarantees a shame mode (delta ~120m)
# regardless of wall-clock time, including across midnight.
now_min=$(( 10#$(date +%H) * 60 + 10#$(date +%M) ))
bt_min=$(( (now_min - 120 + 1440) % 1440 ))
BT=$(printf '%02d:%02d' "$(( bt_min / 60 ))" "$(( bt_min % 60 ))")

PAYLOAD='{"model":{"display_name":"Sonnet"}}'
_strip() { LC_ALL=C sed $'s/\x1b\\[[0-9;]*m//g'; }
_run() {
  printf '%s' "$PAYLOAD" | env -u CC_INSOMNII_SHAME CC_INSOMNII_BEDTIME="$BT" \
    XDG_CONFIG_HOME="$CFG_HOME" "$BIN" 2>&1
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
