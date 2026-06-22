#!/bin/bash
# tests/test_install_safety.sh — verify install.sh detects an existing
# Claude Code statusLine and adapts its advice instead of blindly telling
# the user to overwrite it. We never want to be the reason someone loses
# their richer claudii / framework statusline.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$REPO_ROOT/install.sh"

if [[ ! -f "$INSTALL" ]]; then
  echo "SKIP install.sh not present"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP jq required for install.sh detection logic"
  exit 0
fi

# Build a fake $HOME with each statusLine variant, then dry-run install.sh
# into a tmp prefix and capture stdout. We don't actually install anywhere
# permanent — --prefix isolates everything inside the fake home.
_run_with_fake_home() {
  local cmd="$1"           # statusLine.command value (or "" for no setting)
  local fake_home; fake_home=$(mktemp -d)
  mkdir -p "$fake_home/.claude"
  if [[ -n "$cmd" ]]; then
    printf '{"statusLine":{"type":"command","command":"%s"}}' "$cmd" \
      > "$fake_home/.claude/settings.json"
  fi
  local out
  out=$(HOME="$fake_home" bash "$INSTALL" --prefix="$fake_home/cc-insomnii-prefix" 2>&1)
  rm -rf "$fake_home"
  printf '%s' "$out"
}

# 1. No existing statusLine → must print the JSON snippet
out=$(_run_with_fake_home "")
if [[ "$out" != *'"command": "cc-insomnii"'* ]]; then
  echo "FAIL no-statusLine case did not print snippet"
  echo "Output: $out"; exit 1
fi

# 2. Existing claudii-cc-statusline → must NOT print snippet, must say "no settings.json change needed"
out=$(_run_with_fake_home "claudii-cc-statusline")
if [[ "$out" == *'"command": "cc-insomnii"'* ]]; then
  echo "FAIL claudii detection still printed the overwrite snippet"
  echo "Output: $out"; exit 1
fi
if [[ "$out" != *"No settings.json change needed"* ]]; then
  echo "FAIL claudii detection did not produce the expected guidance"
  echo "Output: $out"; exit 1
fi

# 3. Existing custom statusLine → must offer --after composition as RECOMMENDED
out=$(_run_with_fake_home "my-custom-bar")
if [[ "$out" != *"my-custom-bar"* ]]; then
  echo "FAIL custom-statusLine case did not mention existing command"
  echo "Output: $out"; exit 1
fi
if [[ "$out" != *'"command": "cc-insomnii --after=my-custom-bar"'* ]]; then
  echo "FAIL did not offer --after composition snippet"
  echo "Output: $out"; exit 1
fi
if [[ "$out" != *"RECOMMENDED"* ]]; then
  echo "FAIL did not flag --after as the recommended path"
  echo "Output: $out"; exit 1
fi
# The plain-overwrite snippet must still be present as the alternative
if [[ "$out" != *"Alternative"* ]]; then
  echo "FAIL did not present the explicit-replace fallback"
  echo "Output: $out"; exit 1
fi

# 4. Already cc-insomnii → must say "already runs cc-insomnii"
out=$(_run_with_fake_home "cc-insomnii")
if [[ "$out" != *"already runs cc-insomnii"* ]]; then
  echo "FAIL already-cc-insomnii case did not detect itself"
  echo "Output: $out"; exit 1
fi
if [[ "$out" == *'"command": "cc-insomnii"'* ]]; then
  echo "FAIL already-cc-insomnii still printed redundant snippet"
  echo "Output: $out"; exit 1
fi

exit 0
