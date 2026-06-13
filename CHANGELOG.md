# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `--version`/`-V` flag prints the version and exits.
- `CC_INSOMNII_CONFIG` environment variable overrides the user config file path (symmetric with `CC_INSOMNII_MESSAGES`).

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

[Unreleased]: https://github.com/bmmmm/cc-insomnii/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bmmmm/cc-insomnii/releases/tag/v0.1.0
