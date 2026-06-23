# cc-insomnii

A Claude Code statusline that watches the clock and judges you for it.

---

## What it is

**cc-insomnii** is a standalone statusline plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).
It replaces the default statusline with a time-aware display that escalates
through six modes of passive-aggressive clock imagery as your bedtime recedes
into the past.

At its most benign it shows a moon glyph and the current time. At its least
benign — four hours past your configured bedtime, or after dawn — it produces
a blinking rainbow character-chase animation accompanied by rotating shame
messages. The shame messages are configurable. The existence of the feature is
not.

This was extracted from [claudii](https://github.com/bmmmm/claudii) where it
lived as part of a larger zsh plugin. It is now a focused, single-purpose tool
because that is the correct scope for this kind of thing.

---

## Demo

```
[plain, 22:30]       ☾ 22:30

[approaching, 22:45] ✦ 22:45  almost time…             (cyan sparkle, breathing pulse)

[mode 1, 23:14]     🌙 23:14 +14m   GO TO BED           (rainbow clock + shame, slow blink)

[mode 2, 00:21]     🦉 00:21 +1h21m   BRAIN = MUSH       (+ underline)

[mode 3, 01:47]     💤 01:47 +2h47m   KERNEL PANIC — YOU (+ matrix-drip prefix, rapid blink)

[mode 4, 02:35]     🔥 02:35 +3h35m   COMMIT AND SLEEP   (+ reverse pulse on odd seconds, strobe)

[mode 5, 04:12]     💀 04:12 +5h12m   GOOD MORNING. GOODBYE.   (char-decay clock, glyph swarm, doom)
```

> The mode-5 clock is shown intact above for readability. In a live render about
> 30% of its digits are replaced with `█` — a per-second decay glitch that
> reseeds every second — so the time gets deliberately harder to read the longer
> you stay up. The `:` separator is always preserved.

The clock glyph rotates through a 26-glyph night pool (a separate 15-glyph doom
set takes over at mode 5). The color pair shifts every 3 seconds. The wave
chases across the clock digits at 3 characters per second (faster in higher
modes). All of this happens through time-driven math on the Unix timestamp, so
two renders 1 second apart are visibly different even without client-side
state.

---

## Install

```bash
git clone https://github.com/bmmmm/cc-insomnii.git
cd cc-insomnii
bash install.sh
```

With no flags, `install.sh` installs to `/usr/local/share/cc-insomnii` and
symlinks `/usr/local/bin/cc-insomnii` when **both** `/usr/local/share` and
`/usr/local/bin` are writable, otherwise it falls back to
`~/.local/share/cc-insomnii` and symlinks `~/.local/bin/cc-insomnii` — a
non-root install needs no flags.

A `--prefix` install is self-contained: the binary stays at `DIR/bin/cc-insomnii`
with no separate symlink, so add that directory to your `PATH`:

```bash
bash install.sh --prefix=/opt/cc-insomnii
```

Uninstall:

```bash
bash install.sh --uninstall
```

After installing, the script prints the exact JSON snippet to add to
`~/.claude/settings.json`. It does not edit the file itself.

---

## Configure

### Claude Code settings

There are two paths depending on whether you already have a richer statusline.

**Standalone (no other statusline plugin):** add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "cc-insomnii"
  }
}
```

See `examples/settings.json` for a copy-paste snippet.

**With [claudii](https://github.com/bmmmm/claudii) installed:** do NOT change
`~/.claude/settings.json`. Keep `claudii-cc-statusline` as your statusLine and
claudii will auto-delegate the clock segment to cc-insomnii (`statusline.cc-insomnii=auto`,
the default). Verify with:

```bash
claudii doctor | grep cc-insomnii
# → ✓ cc-insomnii detected (/usr/local/bin/cc-insomnii) — clock segment active (mode=auto)
```

To force-disable delegation: `claudii config statusline.cc-insomnii off`. Make
sure `clock` is in your layout (`claudii config statusline.lines ...`).

**With another cc-statusline framework:** use `--after=<cmd>` to put cc-insomnii
ON TOP of your existing tool instead of replacing it. cc-insomnii's line is
**always the first/top line**; the wrapped command's output appears below it:

```json
{
  "statusLine": {
    "type": "command",
    "command": "cc-insomnii --after='ccusage statusline'"
  }
}
```

Renders as:

```
😵 03:14 +4h14m   GO TO BED          ← cc-insomnii (always top)
Sonnet 4.6 | $0.42 | 5h:62% | ...    ← your existing statusline (below)
```

The installer auto-detects an existing `statusLine.command` and prints this
snippet for you (marked `RECOMMENDED`). The wrapped command gets the same
JSON payload Claude Code sent to cc-insomnii, so nothing changes from its
perspective. If the wrapped command fails or prints nothing, cc-insomnii's line
still renders cleanly — graceful degradation.

### User config

Create `~/.config/cc-insomnii/config.json` (or `$XDG_CONFIG_HOME/cc-insomnii/config.json`):

```json
{
  "bedtime": "23:00",
  "dawn": "04:00",
  "shame": { "enabled": true },
  "motivation": { "enabled": true },
  "rainbow": { "enabled": true },
  "breathing": { "enabled": true }
}
```

See `examples/config.json` for the full reference with all keys.

### Environment variables

All settings can be overridden via environment variables. These take precedence
over `config.json`.

| Variable                 | Default   | Description                                      |
|--------------------------|-----------|--------------------------------------------------|
| `CC_INSOMNII_HOME`       | auto      | Path to cc-insomnii install dir                  |
| `CC_INSOMNII_BEDTIME`    | `23:00`   | Bedtime in HH:MM (24h); `18:00`–`05:59` supported |
| `CC_INSOMNII_DAWN`       | `04:00`   | Dawn threshold; forces mode 5 when up past it during shame (must be `< 06:00`) |
| `CC_INSOMNII_SHAME`      | `true`    | Enable shame messages                            |
| `CC_INSOMNII_MOTIVATION` | `true`    | Enable morning motivation (07:00-15:59)          |
| `CC_INSOMNII_RAINBOW`    | `true`    | Enable rainbow character-chase animation         |
| `CC_INSOMNII_BREATHING`  | `true`    | Enable breathing pulse on glyph and shame text color cycling (modes 1+) |
| `CC_INSOMNII_COLOR`      | (auto)    | `never`/`false`/… forces a no-color line; `always`/`force` keeps color even under `NO_COLOR` |
| `CC_INSOMNII_ASCII`      | `false`   | Swap the emoji glyph pools for 7-bit ASCII (for emoji-incapable terminals) |
| `CC_INSOMNII_ACCESSIBLE` | `false`   | Screen-reader-friendly line: no color, ASCII glyphs, no blink/decay/swarm/drip |
| `CC_INSOMNII_MODEL`      | `false`   | Show the model (`model.display_name`) as a badge in the calm modes (plain/motivation/dawn) |
| `CC_INSOMNII_CONTEXT`    | `false`   | Red `[!]` clock marker in shame modes when the context window is ≥ 80% full (or `exceeds_200k_tokens`) |
| `CC_INSOMNII_DURATION`   | `false`   | Append the session duration (`cost.total_duration_ms`) to the clock in shame modes, e.g. `3h12m` |
| `CC_INSOMNII_COST`       | `false`   | Append the session cost (`$X.XX`) in shame modes; a costly session also bumps the message tier |
| `CC_INSOMNII_COST_BUMP`  | `5`       | Whole-dollar threshold at/above which `CC_INSOMNII_COST` bumps the shame message tier |
| `CC_INSOMNII_THEME`      | `vibe`    | Color theme: `vibe` (default), `mono`, `amber`, `matrix`, `ocean` |
| `CC_INSOMNII_PALETTE`    | `classic` | `escalating` gives each shame mode its own color region; `classic` is the shared cycle |
| `CC_INSOMNII_QUIET`      | (none)    | `HH:MM-HH:MM` window where shame is capped at mode 1 (no strobe/decay/swarm) |
| `CC_INSOMNII_CONFIG`     | (auto)    | Override config file path                        |
| `CC_INSOMNII_MESSAGES`   | (auto)    | Override shame messages file path                |
| `CC_INSOMNII_NOW`        | (clock)   | Preview any mode as if it were this `HH:MM` time |

> **Preview a mode without waiting for it:** `CC_INSOMNII_NOW=HH:MM` renders as
> if the clock read that time, so you can see what 2 a.m. looks like at noon:
>
> ```bash
> echo '{}' | CC_INSOMNII_NOW=02:00 CC_INSOMNII_BEDTIME=23:00 cc-insomnii
> ```

The toggle variables (`CC_INSOMNII_SHAME`, `CC_INSOMNII_MOTIVATION`,
`CC_INSOMNII_RAINBOW`, `CC_INSOMNII_BREATHING`, `CC_INSOMNII_ASCII`,
`CC_INSOMNII_ACCESSIBLE`) treat `false`, `0`, `no`, `off`, and `disabled` — in
any case — as off. Any other value is on. The four config-backed toggles
(`shame`, `motivation`, `rainbow`, `breathing`) accept the same spellings in
`config.json` too, as a scalar (`"shame": "off"`) or nested (`"shame": {
"enabled": false }`); `CC_INSOMNII_ASCII` and `CC_INSOMNII_ACCESSIBLE` are
environment-only and have no `config.json` key.

**No-color and accessible output.** cc-insomnii honors the
[`NO_COLOR`](https://no-color.org/) convention: when `NO_COLOR` is set to any
non-empty value (or `TERM=dumb`, or `CC_INSOMNII_COLOR=never`), the line renders
with no ANSI color — every escape is dropped, the rainbow chase falls back to
plain text, and the mode-5 char-decay is skipped so the clock stays legible.
`CC_INSOMNII_COLOR=always` forces color on even when `NO_COLOR` is set.
`CC_INSOMNII_ACCESSIBLE=1` goes further for screen readers: no color, ASCII
glyphs, and no blink/decay/swarm/drip — just a stable `time +elapsed message`
line in every mode. `CC_INSOMNII_ASCII=1` swaps only the emoji for ASCII while
keeping color. These are environment-only (terminal capability, not project
config) and never change the default colored render.

**Session data.** cc-insomnii receives the same JSON payload Claude Code sends
every statusline, and can weave a few of its fields into the line — all OFF by
default, so the default render is untouched. `CC_INSOMNII_MODEL` shows the model
as a calm-mode badge (`☾ 22:30  Opus`); it prints `model.display_name`
verbatim, so any model — Opus, Sonnet, Haiku, Fable, or one that ships
tomorrow — surfaces correctly with no code change. `CC_INSOMNII_DURATION`
appends how long the session has been running (`23:14 +14m 3h12m`).
`CC_INSOMNII_CONTEXT` paints a red `[!]` before the clock once the context
window is ≥ 80% full (using `context_window.used_percentage`, falling back to
the legacy `exceeds_200k_tokens`). `CC_INSOMNII_COST` appends the dollar spend
in shame modes (`GO TO BED  $4.20`) and, past `CC_INSOMNII_COST_BUMP` dollars,
escalates the shame one message tier — so an expensive 1 a.m. session reads as
harshly as a free 4 a.m. one. The duration tag, context redline and cost appear
in the shame modes (1–5), where the "look what you've done" evidence belongs;
the model badge is the one calm-mode (plain/motivation/dawn) fact. These too are
environment-only.

**Theming.** `CC_INSOMNII_THEME` swaps the whole palette — `vibe` (the default
rainbow), `mono` (grayscale), `amber`, `matrix` (green), or `ocean` (blue).
`CC_INSOMNII_PALETTE=escalating` makes each shame mode anchor a different region
of the active palette, so the mode is legible from color alone; `classic` (the
default) keeps the single shared cycle. `CC_INSOMNII_QUIET=HH:MM-HH:MM` is for
people who have to stay up: inside the window an active shame mode is capped at
mode 1 — the message and elapsed counter stay, but the strobe, char-decay and
glyph swarm do not. A malformed window warns on stderr and is ignored. All three
are environment-only and leave the default render byte-identical.

An invalid `CC_INSOMNII_BEDTIME` or `CC_INSOMNII_DAWN` (not `HH:MM`, or outside
`00:00`–`23:59`) is rejected: cc-insomnii prints a warning to stderr and falls
back to the built-in default (`23:00` for bedtime, `04:00` for dawn) so the
statusline still renders cleanly. `CC_INSOMNII_NOW`, being a preview/testing
knob, instead exits non-zero on a bad value.

### Custom shame messages

Copy `config/shame-messages.json` to `~/.config/cc-insomnii/messages.json` and
edit it. When that file exists, it replaces the shipped message catalog
entirely.

---

## Examples

The `examples/` directory contains:

- `settings.json` — the `~/.claude/settings.json` snippet
- `config.json` — full `~/.config/cc-insomnii/config.json` reference

---

## The six modes

| Mode  | When                           | Display                                                   |
|-------|--------------------------------|-----------------------------------------------------------|
| plain | >30 min before bedtime         | Dim moon glyph (☾) + current time                         |
| 0     | 0-30 min before bedtime        | Cyan sparkle (✦), breathing pulse — gentle notice         |
| 1     | 0-60 min past bedtime          | Rainbow clock + elapsed (+Xm), shame message, slow blink  |
| 2     | +1h to +2h past bedtime        | Adds underline to the shame text                          |
| 3     | +2h to +3h past bedtime        | Adds a matrix-drip prefix, rapid blink                    |
| 4     | +3h to +4h past bedtime        | Adds reverse pulse on odd seconds, strobe                 |
| 5     | +4h past bedtime, or past dawn while still up | Char-decay clock, three-glyph swarm, doom glyph set |

The elapsed counter is the shortest signed distance to your bedtime on the
24-hour clock, so it is correct for an **evening, night, or after-midnight
bedtime** (`18:00`–`05:59`, e.g. `23:00`, `01:00`): it counts up from bedtime,
wraps across midnight, and the night runs until the ~06:00 morning cutoff, after
which the dawn and motivation windows take over. While a shame mode is active,
being up past the dawn threshold (between dawn and 06:00) forces mode 5. A
**daytime bedtime** (`06:00`–`17:59`, e.g. `09:00`, `14:00`) is outside this
range — the night-window model assumes the night spans the 06:00 cutoff, so the
escalation there is inaccurate; use an evening or night bedtime.

Dawn greeting (🌅, dawn threshold to 07:00): when no shame mode is active in
that window — typically with shame disabled — a dim sunrise glyph and a quiet
dawn message appear instead of the post-dawn chaos.

Morning motivation (07:00-15:59): when neither shame mode nor blinking is
active, a calm motivation message replaces the shame output. This is the carrot.
The rest is the stick.

---

## Testing

```bash
make test
# or
bash tests/run.sh --summary
```

---

## Credits

The bedtime shaming logic originated in
[claudii](https://github.com/bmmmm/claudii) (`bin/claudii-cc-statusline`,
lines 422-557) where it was first named `insomnii`. The rainbow character-chase
animation, vibe-coma mode naming, glyph rotation, and time-driven math are all
from that implementation.

Statusline protocol inspiration: [wynandw87/claude-code-status-line](https://github.com/wynandw87/claude-code-status-line)
and [jarrodwatts/claude-hud](https://github.com/jarrodwatts/claude-hud).

---

## License

MIT. See [LICENSE](LICENSE).
