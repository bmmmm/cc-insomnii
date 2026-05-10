#!/usr/bin/env bash
# install.sh — insomnii installer
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
      echo "  --prefix=DIR    Install to DIR (default: /usr/local/share/insomnii)"
      echo "  --uninstall     Remove installed files"
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# Determine install prefix
if [[ -z "$PREFIX" ]]; then
  if [[ -w /usr/local/share ]]; then
    PREFIX="/usr/local/share/insomnii"
    BIN_DIR="/usr/local/bin"
  else
    PREFIX="${HOME}/.local/share/insomnii"
    BIN_DIR="${HOME}/.local/bin"
  fi
else
  BIN_DIR="${PREFIX}/bin"
fi

BIN_LINK="${BIN_DIR}/insomnii"
BIN_SRC="${PREFIX}/bin/insomnii"

# Uninstall path
if (( UNINSTALL )); then
  echo "Uninstalling insomnii..."
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
echo "Installing insomnii to $PREFIX ..."

mkdir -p "$PREFIX"
mkdir -p "$BIN_DIR"

# Copy repo files (skip .git, tmp, test artifacts)
rsync -a --exclude='.git' --exclude='tmp/' --exclude='*.log' \
  "$SCRIPT_DIR/" "$PREFIX/" 2>/dev/null \
  || cp -R "$SCRIPT_DIR/." "$PREFIX/"

chmod +x "$PREFIX/bin/insomnii" 2>/dev/null || true

# Symlink binary
if [[ -e "$BIN_LINK" && ! -L "$BIN_LINK" ]]; then
  echo "Error: $BIN_LINK exists and is not a symlink. Remove it manually." >&2
  exit 1
fi
ln -sf "$BIN_SRC" "$BIN_LINK"
echo "  Symlinked: $BIN_LINK -> $BIN_SRC"

echo ""
echo "Installation complete."
echo ""
echo "Add the following to your ~/.claude/settings.json to enable insomnii:"
echo ""
cat <<'JSON'
{
  "statusLine": {
    "type": "command",
    "command": "insomnii"
  }
}
JSON
echo ""
echo "See examples/config.json for all configuration options."
echo "User config: \${XDG_CONFIG_HOME:-\$HOME/.config}/insomnii/config.json"
echo ""
if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
  echo "Note: $BIN_DIR is not in your PATH. Add it:"
  echo "  export PATH=\"\$PATH:$BIN_DIR\""
fi
