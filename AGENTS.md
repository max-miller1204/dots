# Working on this repo

This repo replicates omarchy's dotfiles architecture on macOS. Read
[`docs/file-layout.md`](docs/file-layout.md) for how everything fits together.

# Style

- Two spaces for indentation, no tabs
- Shebangs must use `#!/usr/bin/env bash` consistently (never `#!/bin/bash`;
  this deliberately deviates from omarchy: macOS pins `/bin/bash` at 3.2, so the
  command runtime lives at Homebrew's prefix and is found via PATH, which
  `default/bash/env-bootstrap` guarantees)
- **Bash >= 4 is assumed; write bash 5 idioms** as omarchy does: `declare -A`,
  `mapfile`, `${var,,}`, `${var//pat/rep}` are all fine. `bin/dots` guards the
  version and points at the fix. On macOS, `bin/dots-install` bootstraps
  Homebrew Bash for scripts without changing the account's login shell.
- Scripts under `install/` are sourced and intentionally omit shebangs
- **Scripts must run on macOS (BSD userland) and Ubuntu/WSL (GNU userland)**:
  bash is uniform now, but the userland is not: avoid flags that differ
  (`sed -i` without a suffix, `date -r`, `ls --color` outside a `uname`
  guard). mise is the only layer for dev tools; Homebrew exists on macOS
  solely for system-level pieces (Bash, flock), and only inside
  `bin/dots-install` and `install/config/flock.sh`: never in shared code.
- Use `[[ ]]` for string/file tests and `(( ))` for numeric tests
- In `[[ ]]`, don't quote variables, but do quote string literals when comparing
- For strings/paths with spaces, quote them instead of escaping spaces

# Command naming

All commands start with `dots-` and route through `bin/dots`:
`dots theme set x` → `bin/dots-theme-set x`. The authoritative list of
user-facing groups lives in `GROUP_DESCRIPTIONS` in `bin/dots`; keep it
updated when adding a new browsable prefix. A group whose commands are all
hidden gets no entry.

Command metadata is comment-based, scanned from the first 20 lines:

```bash
# dots:summary=One-line description shown in listings
# dots:args=<arg> [optional-arg]
# dots:examples=dots pkg add ripgrep;;dots pkg add node@lts
# dots:hidden=true
```

Multiple examples are separated by `;;` (no spaces required). The help renderer trims whitespace around each example.

# Helper commands

Use these instead of raw shell commands:

- `dots-cmd-missing` / `dots-cmd-present` - check for commands
- `dots-pkg-add` / `dots-pkg-drop` - global tools via `mise use/unuse --global`
- `dots-done <check|mark> <name>` - one-time-step markers
- `dots-refresh-config <path>` - copy a shipped config to `~/.config` with backup

# Migrations

One-time repair scripts for existing installs, `migrations/<unix-timestamp>.sh`
(create with `migrations/$(date +%s).sh`). They run through `dots-migrate`
during `dots update`; completion markers live in
`~/.local/state/dots/migrations/<filename>`. Migrations must be idempotent.
Fresh installs mark all shipped migrations as applied. A migration that
changes something already loaded (shell config, a running service) should
`touch ~/.local/state/dots/restart-<component>-required`; the update
pipeline reports and clears these markers at the end
(see [`docs/update-process.md`](docs/update-process.md)).

# Config structure

- `config/` - default configs copied to `~/.config/` (never symlinked)
- `default/themed/*.tpl` - templates with `{{ key }}` placeholders for theme
  colors (`{{ key }}`, `{{ key_strip }}`, `{{ key_rgb }}`; no mix/gradient
  helpers, unlike omarchy)
- `themes/*/colors.toml` - theme palettes (accent, selection, muted,
  background/foreground ramps, named colors and bright_* variants)

# Tests

Run `./test/all` after changes to `bin/`, the theme system, or the update
pipeline. Suites are standalone executables under `test/` (`test/cli`,
`test/completion`, `test/install`, `test/release`, and `test/update`) sourcing
`test/helpers.sh` for shared assertions and sandbox setup; wire new suites into
`test/all`. Tests run in a sandbox `$HOME` and must not touch the real one -
stub external commands (mise, network git) rather than calling them.
