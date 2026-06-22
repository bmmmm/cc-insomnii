#!/bin/bash
# tests/test_compose.sh — verify --after=CMD composes cleanly:
# 1. CMD's output is printed verbatim
# 2. cc-insomnii's own line is appended below (with newline normalization)
# 3. CMD failure does not suppress cc-insomnii (graceful degradation)
# 4. Same JSON is fed to both (no double-read truncation)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/bin/cc-insomnii"
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

# Isolate from the developer's environment: an inherited CC_INSOMNII_* toggle or
# a real ~/.config/cc-insomnii must not perturb the composed output we assert on.
# TMPD has no cc-insomnii/ subdir, so no user config is picked up; the clock is
# pinned so the cc-insomnii line is deterministic (':' always present).
export XDG_CONFIG_HOME="$TMPD"
export CC_INSOMNII_NOW="14:00"
unset CC_INSOMNII_HOME CC_INSOMNII_CONFIG CC_INSOMNII_MESSAGES \
      CC_INSOMNII_BEDTIME CC_INSOMNII_DAWN CC_INSOMNII_SHAME \
      CC_INSOMNII_MOTIVATION CC_INSOMNII_RAINBOW CC_INSOMNII_BREATHING

# Fake "other statusline tool" — echoes a recognizable marker plus the JSON
# it received. Lets us assert (a) it ran, (b) it got the same JSON.
cat > "$TMPD/fake-bar" <<'EOF'
#!/usr/bin/env bash
read -r line
printf '## OTHER_BAR_OUTPUT [%s]\n' "$line"
EOF
chmod +x "$TMPD/fake-bar"

PAYLOAD='{"model":{"display_name":"Sonnet"}}'

# 1. Compose mode renders BOTH lines, with cc-insomnii ALWAYS at the top.
output=$(echo "$PAYLOAD" | "$BIN" "--after=$TMPD/fake-bar" 2>&1)
plain=$(printf '%s' "$output" | LC_ALL=C sed 's/\x1b\[[0-9;]*m//g')

if [[ "$plain" != *"OTHER_BAR_OUTPUT"* ]]; then
  echo "FAIL wrapped command output not present"
  echo "Output: $plain"; exit 1
fi
if [[ "$plain" != *"$PAYLOAD"* ]]; then
  echo "FAIL wrapped command did not receive the original JSON"
  echo "Output: $plain"; exit 1
fi

# Output must be exactly 2 lines (insomnii + wrapped), not 1, not 3+
nlines=$(printf '%s' "$plain" | grep -c '^' || true)
if (( nlines != 2 )); then
  echo "FAIL expected 2 lines, got $nlines"
  echo "Output: $plain"; exit 1
fi

# CRITICAL: cc-insomnii line is ALWAYS the FIRST line (top), wrapped output below.
first_line=$(printf '%s\n' "$plain" | head -1)
last_line=$(printf '%s\n' "$plain" | tail -1)

# cc-insomnii's line always contains ':' from the HH:MM clock; the fake bar's
# marker says "OTHER_BAR_OUTPUT" — distinct, easy to assert ordering on.
if [[ "$first_line" != *:* ]]; then
  echo "FAIL cc-insomnii line is not on top (first line missing clock ':')"
  echo "First line: $first_line"; echo "Full: $plain"; exit 1
fi
if [[ "$first_line" == *"OTHER_BAR_OUTPUT"* ]]; then
  echo "FAIL wrapped command output appeared on top — cc-insomnii must be first"
  echo "First line: $first_line"; echo "Full: $plain"; exit 1
fi
if [[ "$last_line" != *"OTHER_BAR_OUTPUT"* ]]; then
  echo "FAIL wrapped command output is not on the bottom"
  echo "Last line: $last_line"; echo "Full: $plain"; exit 1
fi

# 2. CMD failure must not suppress cc-insomnii line — and cc-insomnii itself must
# still exit 0. A wrapped CMD that fails (or yields no output) must not leak a
# non-zero status out of the statusline: capture rc explicitly so a regression
# here reports clearly instead of tripping the harness's `set -e` silently.
set +e
output=$(echo "$PAYLOAD" | "$BIN" "--after=/nonexistent/cmd" 2>&1)
rc=$?
set -e
if (( rc != 0 )); then
  echo "FAIL compose with a failing CMD exited $rc (expected 0)"
  echo "Output: $output"; exit 1
fi
plain=$(printf '%s' "$output" | LC_ALL=C sed 's/\x1b\[[0-9;]*m//g')
if [[ "$plain" != *:* ]]; then
  echo "FAIL cc-insomnii line missing when wrapped CMD does not exist"
  echo "Output: $plain"; exit 1
fi

# 3. Unknown arg → exit 2 with helpful message.
set +e
output=$(echo "$PAYLOAD" | "$BIN" "--bogus" 2>&1)
rc=$?
set -e
if (( rc != 2 )); then
  echo "FAIL unknown arg exit code: got $rc, expected 2"
  echo "Output: $output"; exit 1
fi
if [[ "$output" != *"unknown argument"* ]]; then
  echo "FAIL unknown arg did not print error"
  echo "Output: $output"; exit 1
fi

# 3b. Passing --after more than once is rejected with exit 2 and a clear message
# (a regression that silently kept the last one would otherwise go unnoticed).
set +e
output=$(echo "$PAYLOAD" | "$BIN" "--after=echo a" "--after=echo b" 2>&1)
rc=$?
set -e
if (( rc != 2 )); then
  echo "FAIL duplicate --after exit code: got $rc, expected 2"
  echo "Output: $output"; exit 1
fi
if [[ "$output" != *"more than once"* ]]; then
  echo "FAIL duplicate --after did not print the expected error"
  echo "Output: $output"; exit 1
fi

# 4. --help must exit 0 and print USAGE
output=$("$BIN" --help 2>&1)
if [[ "$output" != *"USAGE"* ]]; then
  echo "FAIL --help did not show USAGE"
  echo "Output: $output"; exit 1
fi

exit 0
