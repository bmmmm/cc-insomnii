# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-06-23

A display-overhaul release in three layers — terminal robustness, real session
data, and theming. Every new feature is opt-in and OFF by default; the default
colored render is byte-identical to 0.3.0, verified across 1440 minutes × 7
bedtimes (output hash unchanged). All new toggles honour the falsy spellings
(`false`/`0`/`no`/`off`/`disabled`).

### Added
- No-color and accessible output. cc-insomnii now honours the `NO_COLOR`
  convention (any non-empty value), `TERM=dumb`, and `CC_INSOMNII_COLOR=never`
  by dropping every ANSI escape: the rainbow chase falls back to plain text and
  the mode-5 char-decay is skipped so the clock stays legible.
  `CC_INSOMNII_COLOR=always` forces color even under `NO_COLOR`.
  `CC_INSOMNII_ACCESSIBLE` adds a screen-reader mode — no color, ASCII glyphs,
  and no blink/reverse/strobe/char-decay/glyph-swarm/matrix-drip, leaving a
  stable `time +elapsed message` line in every mode. `CC_INSOMNII_ASCII` swaps
  just the emoji glyph pools for 7-bit ASCII while keeping color.
- Session data from the statusline payload (previously read only for `--after`).
  A single batched jq pass — run only when a session feature is enabled —
  surfaces four opt-in fields: `CC_INSOMNII_MODEL` shows `model.display_name` as
  a calm-mode badge (printed verbatim, so Opus/Sonnet/Haiku/Fable and any future
  model work with no code change); `CC_INSOMNII_CONTEXT` paints a red `[!]`
  before the clock when `context_window.used_percentage` ≥ 80 (falling back to
  `exceeds_200k_tokens`); `CC_INSOMNII_DURATION` appends the session length
  (`Hh Mm`) to the clock; `CC_INSOMNII_COST` appends the dollar spend in shame
  modes and, past `CC_INSOMNII_COST_BUMP` dollars, bumps the shame message one
  tier.
- Named color themes via `CC_INSOMNII_THEME`: `vibe` (default rainbow), `mono`,
  `amber`, `matrix`, `ocean`. `CC_INSOMNII_PALETTE=escalating` gives each shame
  mode its own color region (legible from color alone); `classic` keeps the
  shared cycle. `CC_INSOMNII_QUIET=HH:MM-HH:MM` caps an active shame mode at
  mode 1 inside the window — the message and elapsed counter stay, but the
  strobe, char-decay and glyph swarm do not — for users who must stay up.
- Catalog-message sanitization: control bytes and ESC are stripped and TAB/CR/LF
  folded to spaces (byte-wise, so multibyte UTF-8 survives), so a malformed
  `messages.json` can neither break the one-line contract nor inject its own SGR.

### Changed
- All new knobs are environment-only (terminal capability, session runtime and
  theming live in the environment, not the project `config.json`); the original
  feature toggles remain config-file-settable. Documentation synced across the
  README env/mode tables and notes, `man/man1/cc-insomnii.1` (ENVIRONMENT), and
  the in-script `--help` heredoc. New regression suites: `tests/test_robustness.sh`,
  `tests/test_session.sh`, `tests/test_theme.sh`.

## [0.3.0] - 2026-06-22

### Added
- After-midnight bedtimes are now supported. A bedtime in `18:00`–`05:59` (e.g. `01:00`) shows the mode-0 approach in the 30 minutes before, escalates through the shame modes after, and hands off to the dawn/motivation day modes at the 06:00 morning cutoff — instead of the previous behaviour where `(now - bedtime)` stayed positive all day and pinned mode 5 from ~05:00 until midnight.

### Changed
- The elapsed-since-bedtime counter is now the shortest signed distance to bedtime on the 24-hour circle (centered remainder), replacing the evening-only "+1440 if before 06:00 and bedtime ≥ 18:00" wrap. A night-window gate bounds the shame/approach modes to `[bedtime-30min, 06:00)` on the 24-hour circle, so for a supported bedtime the night ends at the 06:00 cutoff. Evening/night bedtimes (`≥ 18:00`) render byte-identically to before — verified across all 1440 minutes for eleven bedtimes from 18:00 to 23:59. A daytime bedtime (`06:00`–`17:59`) is still outside the supported range and best-effort.
- `install.sh` detects an existing cc-insomnii statusLine by its launcher word, so a command that already carries arguments (e.g. `cc-insomnii --after=…`) is recognised as already-installed instead of being offered a snippet that would wrap cc-insomnii in itself. The installed copy now ships only the runtime files — the `tests/`, `scripts/`, `Makefile`, `CLAUDE.md`, `.claude/`, and `.claudeignore` dev trees are excluded.
- `make test` runs the suite under `/bin/bash` (the macOS bash 3.2 runtime the project targets) and propagates that interpreter to every test, instead of a newer PATH `bash` that could mask 3.2 incompatibilities. `make install` and `make uninstall` now honour a `PREFIX` override.

### Fixed
- Falsy toggle scalars are honoured: `CC_INSOMNII_SHAME`, `CC_INSOMNII_MOTIVATION`, `CC_INSOMNII_RAINBOW`, `CC_INSOMNII_BREATHING` (and the `config.json` equivalents) now treat `0`, `no`, `off`, and `disabled` — in any case — as off, like the documented `false`. Previously only the literal `false` disabled a feature.
- `--after` composition no longer makes `cc-insomnii` exit non-zero when the wrapped command produces no output: after rendering its own line the statusline always exits 0.
- Mode-5 char-decay no longer collapses the whole clock to `█` for ~10% of seconds. The per-character hash used a multiplicative index term that degenerated to all-decay whenever the time seed was a multiple of 10; the additive replacement decays a stable ~30% of characters for every seed (the `:` separator is always preserved).
- A custom `messages.json` whose `motivation` or `dawn` value is not an array no longer indexes into a non-array — it falls back to the built-in message, matching the guard already applied to the shame pools.
- `CC_INSOMNII_DAWN=00:00` is treated as unset (no dawn override, no dawn greeting) instead of greeting from midnight.
- Passing `--after` more than once is rejected with an error (exit 2) instead of silently keeping the last one.

### Documentation
- The README and man page document the falsy toggle spellings, that breathing also cycles the shame text colour (modes 1+), that the dawn→mode-5 override applies only for a dawn before 06:00 (the dawn greeting still shows for a dawn up to 06:59, and `00:00` disables both), that the mode-5 demo clock is shown intact for readability (it decays live), and that the default install needs both `/usr/local/share` and `/usr/local/bin` writable.

## [0.2.1] - 2026-06-22

### Fixed
- `install.sh --after` no longer mangles a multi-argument wrapped command: the command is preserved as a single quoted token instead of being re-split on whitespace.
- jq message/config handling hardened: malformed `config.json` and `messages.json` degrade to the shipped baseline instead of erroring, a scalar `"shame": false` (where a nested object was expected) is now honoured as a disable instead of being silently ignored, and a non-numeric/non-array key in a custom message catalog no longer collapses the whole shame pool.
- Mode 5 state no longer leaks decay/swarm artefacts into a subsequent lower-mode render (reset between renders).
- Test harness: `SKIP` is now gated correctly (a skipped test no longer counts as a pass), and `make bench` reports per-render time in microseconds.
- `CC_INSOMNII_BEDTIME` / `CC_INSOMNII_DAWN` (and the equivalent config keys) are validated: an out-of-range or malformed value warns on stderr and falls back to the built-in default instead of silently becoming `00:00`, keeping the statusline clean.
- Test coverage: the mode-5/dawn-override assertions now check the mode-5-exclusive decay block glyph (a mode-4 regression that merely differed could previously slip through), plus new coverage for `--version`/`-V`, `CC_INSOMNII_NOW` validation, the evening midnight-wrap (no-regression) and config resilience, and bedtime/dawn validation.

### Documentation
- Install paths in the README now match `install.sh` behaviour, the dawn greeting render mode is documented (man DESCRIPTION/MODES), and the overnight shame logic's evening-bedtime assumption is stated explicitly with its known limitation for midnight/very-early bedtimes.

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

[Unreleased]: https://github.com/bmmmm/cc-insomnii/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/bmmmm/cc-insomnii/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bmmmm/cc-insomnii/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/bmmmm/cc-insomnii/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/bmmmm/cc-insomnii/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bmmmm/cc-insomnii/releases/tag/v0.1.0
