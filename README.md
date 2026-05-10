# insomnii

A Claude Code statusline that watches the clock and judges you for it.

---

## What it is

**insomnii** is a standalone statusline plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).
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
[normal, 22:30]     ☾ 22:30

[warning, 22:45]    ☾ 22:45

[approaching, 22:58] ☾ 22:58

[mode 1, 23:14]     ☾ 23:14 +14m         (blinking red)

[mode 2, 00:21]     🌙 00:21 +1h21m   GO TO BED   (rainbow clock, shame)

[mode 3, 01:47]     💤 01:47 +2h47m   THIS IS GETTING RIDICULOUS   (underline, rapid blink)

[mode 4, 03:05]     🔥 03:05 +4h5m    COMMIT AND SLEEP   (reverse pulse, strobe)

[mode 5, 04:12]     💀 04:12 +5h12m   DAWN. WHY.   (full doom)
```

The clock glyph rotates through a pool of 15 options. The color pair shifts
every 4 seconds. The wave chases across the clock digits at 3 characters per
second. All of this happens through time-driven math on the Unix timestamp, so
two renders 1 second apart are visibly different even without client-side
state.

---

## Install

```bash
git clone https://github.com/bmmmm/insomnii.git
cd insomnii
bash install.sh
```

Non-root (installs to `~/.local/share/insomnii`, symlinks to `~/.local/bin/`):

```bash
bash install.sh --prefix=~/.local/share/insomnii
```

Custom prefix:

```bash
bash install.sh --prefix=/opt/insomnii
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

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "insomnii"
  }
}
```

See `examples/settings.json` for a copy-paste snippet.

### User config

Create `~/.config/insomnii/config.json` (or `$XDG_CONFIG_HOME/insomnii/config.json`):

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

| Variable              | Default   | Description                                      |
|-----------------------|-----------|--------------------------------------------------|
| `INSOMNII_HOME`       | auto      | Path to insomnii install dir                     |
| `INSOMNII_BEDTIME`    | `23:00`   | Bedtime in HH:MM (24h)                           |
| `INSOMNII_DAWN`       | `04:00`   | Dawn threshold — triggers mode 5 regardless      |
| `INSOMNII_SHAME`      | `true`    | Enable shame messages                            |
| `INSOMNII_MOTIVATION` | `true`    | Enable morning motivation (07:00-15:59)          |
| `INSOMNII_RAINBOW`    | `true`    | Enable rainbow character-chase animation         |
| `INSOMNII_BREATHING`  | `true`    | Enable breathing pulse on glyph                  |
| `INSOMNII_CONFIG`     | (auto)    | Override config file path                        |
| `INSOMNII_MESSAGES`   | (auto)    | Override shame messages file path                |

### Custom shame messages

Copy `config/shame-messages.json` to `~/.config/insomnii/messages.json` and
edit it. When that file exists, it replaces the shipped message catalog
entirely.

---

## Examples

The `examples/` directory contains:

- `settings.json` — the `~/.claude/settings.json` snippet
- `config.json` — full `~/.config/insomnii/config.json` reference

---

## The six modes

| Mode | When                              | Display                                          |
|------|-----------------------------------|--------------------------------------------------|
| 0    | >30 min before bedtime            | Dim moon glyph, current time                     |
| 0    | 10-30 min before                  | Cyan glyph — gentle notice                       |
| 0    | 0-10 min before                   | Yellow glyph — window closing                    |
| 1    | 0-60 min past bedtime             | Blinking red clock + elapsed time (+Xm)          |
| 2    | +1h to +2h past bedtime           | Rainbow clock, shame messages, slow blink        |
| 3    | +2h to +3h past bedtime           | Underline added, messages escalate, rapid blink  |
| 4    | +3h to +4h past bedtime           | Reverse pulse, strobe, maximum urgency           |
| 5    | +4h past bedtime, or past dawn    | Full doom. The glyph rotates. Text unhinged.     |

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
lines 422-557). The rainbow character-chase animation, vibe-coma mode naming,
glyph rotation, and time-driven math are all from that implementation.

Statusline protocol inspiration: [wynandw87/claude-code-status-line](https://github.com/wynandw87/claude-code-status-line)
and [jarrodwatts/claude-hud](https://github.com/jarrodwatts/claude-hud).

---

## License

MIT. See [LICENSE](LICENSE).
