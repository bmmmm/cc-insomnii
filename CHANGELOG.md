# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-10

### Added
- Extracted from claudii (originally named `insomnii`). Rebranded to `cc-insomnii`.
  Bedtime shaming with 5 escalation modes (0-5), rainbow chase animation, breathing
  pulse, motivation messages.
- Mode 0: gentle warning (30 min before bedtime, clock turns yellow)
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
