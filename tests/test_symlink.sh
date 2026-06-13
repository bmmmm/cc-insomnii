#!/usr/bin/env bash
# tests/test_symlink.sh — regression: when the binary is invoked through a
# symlink (install.sh's default for system installs), CC_INSOMNII_HOME must
# resolve to the *real* binary's directory, so the shipped catalog next to it is
# found instead of falling back to the hardcoded "GO TO BED" string.
#
# We build an isolated install tree whose catalog contains a UNIQUE sentinel,
# point a launcher symlink at its binary, invoke through the symlink WITHOUT
# CC_INSOMNII_HOME/MESSAGES, and assert the sentinel reaches the output — proving
# both the symlink-chain walk and the catalog load relative to the resolved home.
# (Uses `env -u` rather than a stripped PATH so jq stays reachable wherever it
# lives — older macOS keeps it in /opt/homebrew, not /usr/bin.)
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

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
mkdir -p "$TMPD/install/bin" "$TMPD/install/config" "$TMPD/launch" "$TMPD/xdg"

# Real binary copy (so its resolved dir is the install tree, not the repo) plus a
# catalog whose only messages are the sentinel — present in every shame mode.
cp "$BIN" "$TMPD/install/bin/cc-insomnii"
chmod +x "$TMPD/install/bin/cc-insomnii"
MARKER="SENTINEL_CATALOG_VIA_SYMLINK"
cat > "$TMPD/install/config/shame-messages.json" <<EOF
{ "shame": { "1": ["$MARKER"], "2": ["$MARKER"], "3": ["$MARKER"], "4": ["$MARKER"], "5": ["$MARKER"] } }
EOF

ln -s "$TMPD/install/bin/cc-insomnii" "$TMPD/launch/cc-insomnii"

# Bedtime ~2h ago (midnight-wrap-safe) → a shame mode regardless of wall-clock.
now_min=$(( 10#$(date +%H) * 60 + 10#$(date +%M) ))
bt_min=$(( (now_min - 120 + 1440) % 1440 ))
BT="$(printf '%02d:%02d' "$(( bt_min / 60 ))" "$(( bt_min % 60 ))")"

PAYLOAD='{"model":{"display_name":"Sonnet"}}'
output="$(printf '%s' "$PAYLOAD" | env \
  -u CC_INSOMNII_HOME -u CC_INSOMNII_MESSAGES -u CC_INSOMNII_CONFIG \
  -u CC_INSOMNII_SHAME -u CC_INSOMNII_DAWN \
  CC_INSOMNII_BEDTIME="$BT" XDG_CONFIG_HOME="$TMPD/xdg" \
  "$TMPD/launch/cc-insomnii" 2>&1)"
plain="$(printf '%s' "$output" | LC_ALL=C sed $'s/\x1b\\[[0-9;]*m//g')"

if [[ "$plain" != *"$MARKER"* ]]; then
  echo "FAIL catalog not loaded through symlink — CC_INSOMNII_HOME mis-resolved (fell back to hardcoded message)"
  echo "bedtime: $BT"
  echo "Output:  $plain"
  exit 1
fi

# Sanity: the clock is always rendered.
if [[ "$plain" != *:* ]]; then
  echo "FAIL no clock rendered"
  echo "Output: $plain"
  exit 1
fi

exit 0
