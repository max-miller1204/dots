# Working on this repo

This repo replicates omarchy's dotfiles architecture on macOS. Read
[`docs/file-layout.md`](docs/file-layout.md) for how everything fits together.

# Style

- Two spaces for indentation, no tabs
- Shebangs must use `#!/bin/bash` consistently (never `#!/usr/bin/env bash`)
- Scripts under `install/` are sourced and intentionally omit shebangs
- **macOS `/bin/bash` is 3.2** — unlike omarchy's bash 5 rules, do NOT use
  `declare -A`, `mapfile`, `${var,,}`, `&>>`, or globstar. `[[ ]]`, `(( ))`,
  `[[ =~ ]]`, and `${@:n}` slicing are fine.
- **Scripts must run on macOS (BSD userland) and Ubuntu/WSL (GNU userland)** —
  avoid flags that differ between them (`sed -i` without a suffix, `date -r`,
  `ls --color` outside a `uname` guard). mise is the only package layer; never
  reach for brew or apt in shared code (OS-specific leaves under
  `install/config/` are the place for that).
- Use `[[ ]]` for string/file tests and `(( ))` for numeric tests
- In `[[ ]]`, don't quote variables, but do quote string literals when comparing
- For strings/paths with spaces, quote them instead of escaping spaces

# Command naming

All commands start with `dots-` and route through `bin/dots`:
`dots theme set x` → `bin/dots-theme-set x`. The authoritative list of
user-facing groups lives in `group_description()` in `bin/dots`; keep it
updated when adding a new browsable prefix. A group whose commands are all
hidden gets no entry.

Command metadata is comment-based, scanned from the first 20 lines:

```bash
# dots:summary=One-line description shown in listings
# dots:args=<arg> [optional-arg]
# dots:examples=dots theme set tokyo-night
# dots:hidden=true
```

# Helper commands

Use these instead of raw shell commands:

- `dots-cmd-missing` / `dots-cmd-present` — check for commands
- `dots-pkg-add` / `dots-pkg-drop` — global tools via `mise use/unuse --global`
- `dots-done <check|mark|ensure> <name>` — one-time-step markers
- `dots-refresh-config <path>` — copy a shipped config to `~/.config` with backup

# Migrations

One-time repair scripts for existing installs, `migrations/<unix-timestamp>.sh`
(create with `migrations/$(date +%s).sh`). They run through `dots-migrate`
during `dots update`; completion markers live in
`~/.local/state/dots/migrations/<filename>`. Migrations must be idempotent.
Fresh installs mark all shipped migrations as applied.

# Config structure

- `config/` — default configs copied to `~/.config/` (never symlinked)
- `default/themed/*.tpl` — templates with `{{ key }}` placeholders for theme
  colors (`{{ key }}`, `{{ key_strip }}`, `{{ key_rgb }}`; no mix/gradient
  helpers, unlike omarchy)
- `themes/*/colors.toml` — theme palettes (accent, selection, muted,
  background/foreground ramps, named colors and bright_* variants)

# Tests

Run `./test/all` after changes to `bin/` or the theme system. Tests run in a
sandbox `$HOME` and must not touch the real one.
