# cc-insomnii

Standalone bedtime-shame statusline plugin for Claude Code.
Extracted from claudii — no claudii dependency. Replaces the default Claude Code statusline
with a time-aware display that escalates through passive-aggressive clock imagery as bedtime recedes.

## Identity

This repo follows the Claude push convention. Commits authored as
`Claude (cc-insomnii) <claude@local>`, pushed to Forgejo via HTTPS-with-token.
See `~/ops/runbooks/identity-setup.md`.

## Conventions

- Cross-repo notes, runbooks, audits: `~/ops/`
- Per-repo intent (current focus, blockers, next): `~/ops/projects/cc-insomnii.md`

## Install / Uninstall

```bash
bash install.sh           # install to ~/.local/share/cc-insomnii
bash install.sh --uninstall
# or via Make:
make install
make uninstall
```

## Testing

```bash
make test                 # bash tests/run.sh
make lint                 # shellcheck bin/ + install.sh + tests/ + scripts/
```

## Architecture

```
bin/cc-insomnii           # Main script — reads stdin JSON (CC statusline payload), outputs one line
config/                   # Default config (bedtime, shame messages)
man/                      # Man page
examples/                 # Example configs
tests/                    # Test suite
install.sh                # Installer
```

## Key constraints

- **No runtime deps beyond bash 3.2 + jq** — zero dependency on claudii or other tools.
- Reads Claude Code statusline JSON from stdin, writes one styled line to stdout.
- Shame messages and bedtime are configurable; the feature itself is not optional.
- Compatible with macOS `/bin/bash` 3.2 — no `declare -A`, no `(( var++ ))` on counters.
- **`bin/cc-insomnii` is the source of truth; docs mirror it.** Any change to env-var
  names, defaults, mode boundaries, timings, or glyph pools must be synced across all
  four doc surfaces: README (env + mode tables, demo, install steps), `man/man1/cc-insomnii.1`
  (ENVIRONMENT / MODES / FILES), the in-script `--help` heredoc, and `examples/`. Version
  lives in three places — `_VERSION`, the man `.TH`, and `CHANGELOG.md`. Lint the man page
  with `mandoc -T lint` (groff is absent on macOS).
