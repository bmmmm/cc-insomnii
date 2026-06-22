#!/usr/bin/env bash
# tests/bench.sh — render-time benchmark for bin/cc-insomnii.
#
# Not a pass/fail test (run.sh only globs test_*.sh, so this is excluded); it is
# a reproducible measurement, run via `make bench`. Claude Code throttles the
# statusline command to roughly one call every ~300 ms, so that is the budget a
# single render must stay well under.
#
# The hot-path cost is dominated by jq process spawns, which scale with the
# scenario: plain with no config file spawns none, a shame render spawns one (the
# message pick), and a shame render with a user config.json spawns two (config
# parse + message pick). Time is injected via CC_INSOMNII_NOW so each scenario is
# deterministic regardless of the wall clock; production additionally spends one
# `date` call (~1-2 ms) that the injected path skips.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/bin/cc-insomnii"
N="${1:-200}"

if ! [[ "$N" =~ ^[0-9]+$ ]] || (( N < 1 )); then
  echo "cc-insomnii bench: iteration count must be a positive integer (got: $N)" >&2
  exit 2
fi

if [[ ! -x "$BIN" ]]; then
  echo "SKIP bin/cc-insomnii not executable"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP jq required"
  exit 0
fi

# Portable millisecond clock — date +%N is GNU-only (absent on macOS/BSD).
if command -v perl >/dev/null 2>&1; then
  _now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time()*1000'; }
elif command -v python3 >/dev/null 2>&1; then
  _now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }
else
  echo "SKIP no perl or python3 available for sub-second timing"
  exit 0
fi

PAYLOAD='{"model":{"display_name":"Sonnet"}}'
EMPTY=$(mktemp -d)
CFG=$(mktemp -d)
trap 'rm -rf "$EMPTY" "$CFG"' EXIT
mkdir -p "$CFG/cc-insomnii"
printf '%s' '{"bedtime":"23:00","shame":{"enabled":true}}' > "$CFG/cc-insomnii/config.json"

# Scenarios — each renders one line and discards it.
run_plain() { # 0 jq: no config file, plain mode picks no message
  printf '%s' "$PAYLOAD" | env -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
    XDG_CONFIG_HOME="$EMPTY" CC_INSOMNII_NOW=18:00 CC_INSOMNII_BEDTIME=23:00 \
    CC_INSOMNII_DAWN=04:00 "$BIN" >/dev/null 2>&1
}
run_shame() { # 1 jq: no config file, shame mode picks a message
  printf '%s' "$PAYLOAD" | env -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
    XDG_CONFIG_HOME="$EMPTY" CC_INSOMNII_NOW=01:00 CC_INSOMNII_BEDTIME=23:00 \
    CC_INSOMNII_DAWN=04:00 "$BIN" >/dev/null 2>&1
}
run_shame_cfg() { # 2 jq: user config.json parse + message pick
  printf '%s' "$PAYLOAD" | env -u CC_INSOMNII_CONFIG -u CC_INSOMNII_MESSAGES \
    XDG_CONFIG_HOME="$CFG" CC_INSOMNII_NOW=01:00 "$BIN" >/dev/null 2>&1
}

bench() { # LABEL FN
  local label="$1" fn="$2" i start end total
  start=$(_now_ms)
  for (( i = 0; i < N; i++ )); do "$fn"; done
  end=$(_now_ms)
  total=$(( end - start ))
  printf '  %-34s %6d ms / %4d = %5d us/render\n' "$label" "$total" "$N" "$(( total * 1000 / N ))"
}

echo "cc-insomnii render benchmark ($N iterations each)"
echo "budget: << ~300 ms/render (Claude Code statusline throttle)"
echo
bench "plain        (0 jq)" run_plain
bench "shame        (1 jq)" run_shame
bench "shame+config (2 jq)" run_shame_cfg
