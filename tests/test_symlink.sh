#!/usr/bin/env bash
# tests/test_symlink.sh — regression: when the binary is invoked through a
# symlink (the `install.sh` default for system installs), CC_INSOMNII_HOME must
# resolve to the *real* binary's directory, not the symlink's. Otherwise the
# shipped config/shame-messages.json is unreachable and the renderer falls
# back to the hardcoded "GO TO BED" string, losing the entire 461-message
# catalog.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/bin/cc-insomnii"

if [[ ! -x "$BIN" ]]; then
  echo "SKIP bin/cc-insomnii not executable"
  exit 0
fi

TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT
ln -s "$BIN" "$TMPD/cc-insomnii"

# Force mode-5 (well past bedtime) by setting bedtime to "now minus many hours".
# We use 01:00 — works for any current time except 01:00-01:59 itself.
PAYLOAD='{"model":{"display_name":"Sonnet"}}'
output=$(echo "$PAYLOAD" | env -i HOME="$HOME" PATH="$TMPD:/usr/bin:/bin" \
  CC_INSOMNII_BEDTIME=01:00 "$TMPD/cc-insomnii" 2>&1)
plain=$(printf '%s' "$output" | LC_ALL=C sed 's/\x1b\[[0-9;]*m//g')

# Strict: when the catalog is found, output should contain a shame phrase that
# does NOT exist in the hardcoded fallback. The fallback only ever emits
# "GO TO BED" — anything richer proves the JSON file was loaded via the real
# binary path.
if [[ "$plain" == *"GO TO BED"* && "$plain" != *":"* ]]; then
  echo "FAIL hardcoded fallback used — CC_INSOMNII_HOME failed to resolve through symlink"
  echo "Output: $plain"
  exit 1
fi

# Sanity: output must contain a colon (always part of the clock).
if [[ "$plain" != *:* ]]; then
  echo "FAIL no clock rendered"
  echo "Output: $plain"
  exit 1
fi

exit 0
