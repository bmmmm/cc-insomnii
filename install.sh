#!/usr/bin/env bash
# install.sh — cc-insomnii installer
# Usage: bash install.sh [--prefix=DIR] [--uninstall]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX=""
UNINSTALL=0

for arg in "$@"; do
  case "$arg" in
    --prefix=*) PREFIX="${arg#--prefix=}" ;;
    --uninstall) UNINSTALL=1 ;;
    --help|-h)
      echo "Usage: bash install.sh [--prefix=DIR] [--uninstall]"
      echo ""
      echo "Options:"
      echo "  --prefix=DIR    Install to DIR (default: /usr/local/share/cc-insomnii)"
      echo "  --uninstall     Remove installed files"
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# Determine install prefix
if [[ -z "$PREFIX" ]]; then
  if [[ -w /usr/local/share ]]; then
    PREFIX="/usr/local/share/cc-insomnii"
    BIN_DIR="/usr/local/bin"
  else
    PREFIX="${HOME}/.local/share/cc-insomnii"
    BIN_DIR="${HOME}/.local/bin"
  fi
else
  BIN_DIR="${PREFIX}/bin"
fi

BIN_LINK="${BIN_DIR}/cc-insomnii"
BIN_SRC="${PREFIX}/bin/cc-insomnii"

# Self-contained install: when --prefix puts the launcher dir inside the prefix
# (BIN_LINK == BIN_SRC), there is no separate symlink to create — the binary
# already lives at its launch path. The user just adds $PREFIX/bin to PATH.
SELF_CONTAINED=0
[[ "$BIN_LINK" == "$BIN_SRC" ]] && SELF_CONTAINED=1

# Uninstall path
if (( UNINSTALL )); then
  echo "Uninstalling cc-insomnii..."
  if [[ -L "$BIN_LINK" ]]; then
    rm -f "$BIN_LINK"
    echo "  Removed symlink: $BIN_LINK"
  fi
  if [[ -d "$PREFIX" ]]; then
    rm -rf "$PREFIX"
    echo "  Removed install dir: $PREFIX"
  fi
  echo "Done. Remove the statusLine entry from ~/.claude/settings.json manually."
  exit 0
fi

# Install
echo "Installing cc-insomnii to $PREFIX ..."

mkdir -p "$PREFIX"
mkdir -p "$BIN_DIR"

# Copy repo files (skip .git, tmp, test artifacts)
rsync -a --exclude='.git' --exclude='tmp/' --exclude='*.log' \
  "$SCRIPT_DIR/" "$PREFIX/" 2>/dev/null \
  || cp -R "$SCRIPT_DIR/." "$PREFIX/"

chmod +x "$PREFIX/bin/cc-insomnii" 2>/dev/null || true

# Symlink binary — skipped for self-contained installs (BIN_LINK == BIN_SRC).
if (( SELF_CONTAINED )); then
  echo "  Self-contained install: binary at $BIN_SRC (no symlink needed)"
else
  if [[ -e "$BIN_LINK" && ! -L "$BIN_LINK" ]]; then
    echo "Error: $BIN_LINK exists and is not a symlink. Remove it manually." >&2
    exit 1
  fi
  ln -sf "$BIN_SRC" "$BIN_LINK"
  echo "  Symlinked: $BIN_LINK -> $BIN_SRC"
fi

echo ""
echo "Installation complete."
echo ""

# Inspect existing Claude Code statusLine and tailor the next-step advice. We
# never auto-edit settings.json — only print the right snippet for the user's
# situation, and explicitly NOT recommend overwriting an existing configured
# statusLine without acknowledgement.
SETTINGS="$HOME/.claude/settings.json"
EXISTING_CMD=""
if [[ -f "$SETTINGS" ]] && command -v jq >/dev/null 2>&1; then
  EXISTING_CMD=$(jq -r '.statusLine.command // ""' "$SETTINGS" 2>/dev/null)
fi

case "$EXISTING_CMD" in
  cc-insomnii|*/cc-insomnii)
    echo "Detected: ~/.claude/settings.json already runs cc-insomnii. No changes needed."
    ;;
  claudii-cc-statusline|*/claudii-cc-statusline)
    echo "Detected: claudii is your Claude Code statusLine."
    echo ""
    echo "  → No settings.json change needed. claudii will auto-delegate the"
    echo "    clock segment to cc-insomnii (see 'claudii doctor')."
    echo ""
    echo "  → Add 'clock' to your claudii layout if it isn't already, e.g.:"
    echo "      claudii config statusline.lines '[[\"model\",\"clock\"], ...]'"
    echo ""
    echo "  → To disable the delegation explicitly:"
    echo "      claudii config statusline.cc-insomnii off"
    ;;
  "")
    echo "Add the following to your ~/.claude/settings.json to enable cc-insomnii:"
    echo ""
    cat <<'JSON'
{
  "statusLine": {
    "type": "command",
    "command": "cc-insomnii"
  }
}
JSON
    ;;
  *)
    echo "Detected: ~/.claude/settings.json already has a statusLine command:"
    echo "    $EXISTING_CMD"
    echo ""
    echo "RECOMMENDED — keep your current statusLine and put cc-insomnii ON TOP."
    echo "cc-insomnii's line renders FIRST (top), your existing output below it."
    echo "No overwrite, no reorder of your existing tool — just one line above:"
    echo ""
    cat <<JSON
{
  "statusLine": {
    "type": "command",
    "command": "cc-insomnii --after=$EXISTING_CMD"
  }
}
JSON
    echo ""
    echo "Alternative — replace your statusLine entirely (you LOSE everything"
    echo "that '$EXISTING_CMD' renders — only do this if you understand that):"
    echo ""
    cat <<'JSON'
{
  "statusLine": {
    "type": "command",
    "command": "cc-insomnii"
  }
}
JSON
    ;;
esac

echo ""
echo "See examples/config.json for all configuration options."
echo "User config: \${XDG_CONFIG_HOME:-\$HOME/.config}/cc-insomnii/config.json"
echo ""
if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
  echo "Note: $BIN_DIR is not in your PATH. Add it:"
  echo "  export PATH=\"\$PATH:$BIN_DIR\""
fi
