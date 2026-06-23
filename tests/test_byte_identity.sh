#!/bin/bash
# tests/test_byte_identity.sh — encode the hard byte-identity invariant as a gate.
#
# With every optional feature OFF (no NO_COLOR, every CC_INSOMNII_* toggle unset,
# THEME=vibe, PALETTE=classic) the rendered line must be byte-for-byte identical
# to the 0.3.0 baseline across every minute of the day. This test sweeps
# CC_INSOMNII_NOW over all 1440 minutes for a set of representative bedtimes,
# hashes the concatenated output, and compares it to a committed baseline. Any
# drift in the DEFAULT render — even one byte at one minute — fails it.
#
# It is OPT-IN so it never slows `make test`: it SKIPs unless CC_INSOMNII_SWEEP is
# set. `make sweep` runs the full 7-bedtime release gate. The render is provably
# payload-independent (the bin reads stdin JSON only for --after), so an empty
# payload is sufficient. Each render runs in a pinned, isolated env (env -i with a
# real TERM so the no-color path can't fire and no user config can leak in).
#
#   CC_INSOMNII_SWEEP=1       bash tests/test_byte_identity.sh   # 3-bedtime subset gate
#   CC_INSOMNII_SWEEP=full    bash tests/test_byte_identity.sh   # 7-bedtime release gate
#   CC_INSOMNII_SWEEP_PRINT=1 CC_INSOMNII_SWEEP=1 ...            # print the hash, do not compare
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/bin/cc-insomnii"

[[ -x "$BIN" ]] || { echo "SKIP bin/cc-insomnii not executable"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "SKIP jq required"; exit 0; }
if [[ -z "${CC_INSOMNII_SWEEP:-}" ]]; then
  echo "SKIP set CC_INSOMNII_SWEEP=1 (subset) or =full to run the byte-identity sweep"
  exit 0
fi

# Pick a hasher: shasum (macOS) or sha1sum (GNU coreutils).
if command -v shasum >/dev/null 2>&1; then
  _hash() { shasum | awk '{print $1}'; }
elif command -v sha1sum >/dev/null 2>&1; then
  _hash() { sha1sum | awk '{print $1}'; }
else
  echo "SKIP no shasum/sha1sum on PATH"
  exit 0
fi

# Representative bedtimes: evening, exactly-at-bedtime, and post-midnight together
# exercise every mode plus the absolute 06:00 night-window cap.
SUBSET=(22:00 23:00 01:00)
FULL=(18:00 20:00 22:00 23:00 23:30 23:59 01:00)

# Baselines captured from the 0.4.0 build, which is byte-identical to 0.3.0. If the
# DEFAULT render ever changes on purpose, re-verify against the 0.3.0 release and
# update the matching constant here.
BASE_SUBSET="f96737cca5520125438580bceac61b1deaa2c300"
BASE_FULL="ca52fa1759afbbd2c279bfe726d4a42e21afb659"

case "$CC_INSOMNII_SWEEP" in
  full) BEDTIMES=("${FULL[@]}");   EXPECTED="$BASE_FULL";   MODE="full (7 bedtimes)";   CONST="BASE_FULL" ;;
  *)    BEDTIMES=("${SUBSET[@]}"); EXPECTED="$BASE_SUBSET"; MODE="subset (3 bedtimes)"; CONST="BASE_SUBSET" ;;
esac

TH="$(mktemp -d)"
trap 'rm -rf "$TH"' EXIT
mkdir -p "$TH/.config"

_sweep() {
  local bt m now
  for bt in "${BEDTIMES[@]}"; do
    for (( m = 0; m < 1440; m++ )); do
      now="$(printf '%02d:%02d' $(( m / 60 )) $(( m % 60 )))"
      printf '{}' | env -i \
        PATH="$PATH" HOME="$TH" XDG_CONFIG_HOME="$TH/.config" TERM=xterm-256color \
        CC_INSOMNII_NOW="$now" CC_INSOMNII_BEDTIME="$bt" \
        "$BIN"
    done
  done
}

got="$(_sweep | _hash)"

if [[ -n "${CC_INSOMNII_SWEEP_PRINT:-}" ]]; then
  printf '%s  %s\n' "$got" "$MODE"
  exit 0
fi

if [[ "$got" != "$EXPECTED" ]]; then
  printf 'FAIL byte-identity: %s sweep hash drifted\n' "$MODE"
  printf '  expected: %s\n' "$EXPECTED"
  printf '  got:      %s\n' "$got"
  printf '  The DEFAULT render changed. If intentional, re-verify against the 0.3.0\n'
  printf '  release and update %s in tests/test_byte_identity.sh.\n' "$CONST"
  exit 1
fi

printf 'OK byte-identity: %s sweep matches baseline (%s)\n' "$MODE" "$got"
exit 0
