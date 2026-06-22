# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- `install.sh --after` no longer mangles a multi-argument wrapped command: the command is preserved as a single quoted token instead of being re-split on whitespace.
- jq message/config handling hardened: malformed `config.json` and `messages.json` degrade to the shipped baseline instead of erroring, a scalar `"shame": false` (where a nested object was expected) is now honoured as a disable instead of being silently ignored, and a non-numeric/non-array key in a custom message catalog no longer collapses the whole shame pool.
- Mode 5 state no longer leaks decay/swarm artefacts into a subsequent lower-mode render (reset between renders).
- Test harness: `SKIP` is now gated correctly (a skipped test no longer counts as a pass), and `make bench` reports per-render time in microseconds.
- `CC_INSOMNII_BEDTIME` / `CC_INSOMNII_DAWN` (and the equivalent config keys) are validated: an out-of-range or malformed value warns on stderr and falls back to the built-in default instead of silently becoming `00:00`, keeping the statusline clean.
- Test coverage: the mode-5/dawn-override assertions now check the mode-5-exclusive decay block glyph (a mode-4 regression that merely differed could previously slip through), plus new coverage for `--version`/`-V`, `CC_INSOMNII_NOW` validation, the evening midnight-wrap (no-regression) and config resilience, and bedtime/dawn validation.

## [0.2.0] - 2026-06-14

### Added
- `--version`/`-V` flag prints the version and exits.
- `CC_INSOMNII_CONFIG` environment variable overrides the user config file path (symmetric with `CC_INSOMNII_MESSAGES`).
- `CC_INSOMNII_NOW=HH:MM` renders as if the wall clock read that time, so any mode — the approach sparkle, a shame escalation, the dawn or motivation window — can be previewed (and tested) without waiting for that time of day. The animation/message epoch is derived deterministically from the value, so a preview is reproducible; invalid values exit non-zero.
- `tests/test_modes.sh`: a deterministic mode-matrix regression that pins every render branch via `CC_INSOMNII_NOW`, including the dawn override, the motivation/dawn windows, and the midnight-wrap delta — none of which the existing tests reached. `make bench` (`tests/bench.sh`) measures render time at 16–30 ms/render, ~10× under Claude Code's ~300 ms statusline throttle, so no message-catalog caching is warranted.

### Fixed
- config.json toggles (`shame`/`motivation`/`rainbow`/`breathing` `.enabled`) were silently ignored: the parser read flat dotted keys (`."shame.enabled"`) instead of the documented nested form, and jq's `//` collapsed a literal `false` to empty. Now reads nested keys, preserves `false`, and splits on US (0x1f) so an empty bedtime/dawn can't shift a toggle into the wrong field.
- Test harness (`tests/run.sh`) aborted on the first failing test under `set -e` instead of reporting it; failures are now captured and summarized. Same guard applied to `tests/test_smoke.sh`. Added `tests/test_config.sh`; rewrote `tests/test_symlink.sh` to actually assert catalog resolution through a symlink.
- Shame message pool no longer mixes pre-bedtime (mode-0) messages into the post-bedtime modes (1-5).
- mode0: `_cfg_breathing` comparison used arithmetic context `(( ))` with string value "true"; bash treats unquoted `true` as a variable name which is unbound under `set -u`. Replaced with `[[ ]]` string comparison — no behavior change.

### Changed
- Removed dead code (`_breathing_esc`, the unused `_payload_ts` read, unused color constants) and collapsed four `date` calls into one.
- Docs corrected to match the code: mode 0 is a cyan sparkle (not yellow), rainbow and shame begin at mode 1, glyph-pool counts (26 night / 15 doom), and the 3-second color cycle. Removed the phantom `lib/` directory from CLAUDE.md and the self-reference in the man page's SEE ALSO. `make lint` now covers all scripts.

## [0.1.0] - 2026-05-10

### Added
- Extracted from claudii (originally named `insomnii`). Rebranded to `cc-insomnii`.
  Bedtime shaming with 5 escalation modes (0-5), rainbow chase animation, breathing
  pulse, motivation messages.
- Mode 0: gentle warning (30 min before bedtime, cyan sparkle with breathing pulse)
- Mode 1: bedtime passed — blinking red clock with elapsed time
- Mode 2: +1h past bedtime — rainbow clock, shame messages begin
- Mode 3: +2h — double-glyph bookends, underline, escalated messages
- Mode 4: +3h — triple-glyph storm, reverse shame, rapid blink
- Mode 5: +4h or post-dawn (04:00+) — full chaos mode, reality optional
- Configurable via `~/.config/cc-insomnii/config.json` and `CC_INSOMNII_*` env vars
- Pluggable shame messages via `config/shame-messages.json` or user override
- Morning motivation messages (07:00-15:59) when shame is not active
- `install.sh` with `--prefix` and `--uninstall` flags
- Test harness in `tests/run.sh` with `--summary` flag

[Unreleased]: https://github.com/bmmmm/cc-insomnii/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/bmmmm/cc-insomnii/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bmmmm/cc-insomnii/releases/tag/v0.1.0
