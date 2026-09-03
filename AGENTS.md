# Work on this repository

This repository uses the Omarchy dotfiles architecture on macOS. Read
[`docs/file-layout.md`](docs/file-layout.md) for information about the file
structure.

# Style

- Use two spaces for indentation. Do not use tabs.
- Use `#!/usr/bin/env bash` in each shebang. Do not use `#!/bin/bash`.
  This rule is different from the Omarchy rule. macOS supplies Bash 3.2 at
  `/bin/bash`. The command runtime uses Bash from the Homebrew prefix.
  `default/bash/env-bootstrap` finds this version through `PATH`.
- Assume Bash 4 or later. Use common Bash 5 syntax as Omarchy does. Examples
  are `declare -A`, `mapfile`, `${var,,}`, and `${var//pat/rep}`.
  `bin/dots` checks the Bash version and gives correction instructions. On
  macOS, `bin/dots-install` installs Homebrew Bash for scripts. It does not
  change the login shell of the account.
- Scripts in `install/` are sourced. Do not add shebangs to these scripts.
- Scripts must operate on macOS with BSD userland. They must also operate on
  Ubuntu and Windows Subsystem for Linux (WSL) with GNU userland. The Bash
  version is the same, but the
  userland is different. Do not use options that differ between these
  userlands. Examples are `sed -i` without a suffix, `date -r`, and
  `ls --color` without a `uname` condition.
- Use mise as the only layer for development tools. On macOS, use Homebrew only
  for the Bash and `flock` system components. Use Homebrew only in
  `bin/dots-install` and `install/config/flock.sh`. Do not use Homebrew in
  shared code.
- Use `[[ ]]` for string tests and file tests. Use `(( ))` for numeric tests.
- In `[[ ]]`, do not quote simple operands. On the right of `==` or `!=`, quote
  a variable when the comparison must be literal. This prevents a glob
  comparison. Quote string literals in comparisons.
- Quote strings and paths that contain spaces. Do not escape the spaces.

# Command names

Start each command name with `dots-`. Route each command through `bin/dots`:
`dots theme set x` → `bin/dots-theme-set x`.

`GROUP_DESCRIPTIONS` in `bin/dots` contains the official list of user-visible
groups. Update this list when you add a new visible prefix. Do not add a group
when all its commands are hidden.

Command metadata uses comments. The scanner reads the first 20 lines:

```bash
# dots:summary=One-line description shown in listings
# dots:args=<arg> [optional-arg]
# dots:examples=dots pkg add ripgrep;;dots pkg add node@lts
# dots:hidden=true
```

Use `;;` to separate multiple examples. You can omit spaces around this
separator. The help renderer removes spaces at the start and end of each
example.

# Helper commands

Use these helper commands. Do not use the related raw shell commands.

- `dots-cmd-missing` and `dots-cmd-present`: Check for commands.
- `dots-pkg-add` and `dots-pkg-drop`: Manage global tools with
  `mise use --global` and `mise unuse --global`.
- `dots-done <check|mark> <name>`: Manage markers for one-time steps.
- `dots-refresh-config <path>`: Copy a supplied configuration to `~/.config`
  and make a backup.

# Migrations

Use `migrations/<unix-timestamp>.sh` for one-time repairs to existing
installations. Create the file with `migrations/$(date +%s).sh`.
`dots-migrate` runs these files during `dots update`. Completion markers are in
`~/.local/state/dots/migrations/<filename>`.

Migrations must be idempotent. Fresh installations mark all supplied migrations
as applied. Keep each migration limited to one repair. Put exact historical
comparison inputs in `migrations/fixtures/<timestamp>/`. Do not put large
heredocs in a migration.

If a migration changes a loaded component, create a restart marker. A shell
configuration or a running service is a loaded component. Use this command:

```bash
touch ~/.local/state/dots/restart-<component>-required
```

The update process reports and removes these markers at the end. See
[`docs/update-process.md`](docs/update-process.md).

# Configuration structure

- `config/`: Contains default configurations. The installer copies them to
  `~/.config/`. It does not create symlinks.
- `default/themed/*.tpl`: Contains templates with `{{ key }}` placeholders for
  theme colors. Supported forms are `{{ key }}`, `{{ key_strip }}`, and
  `{{ key_rgb }}`. The templates do not support mix and gradient helpers. This
  behavior is different from Omarchy.
- `themes/*/colors.toml`: Contains theme palettes. The palettes include accent,
  selection, muted, background and foreground ramps, named, and `bright_*`
  colors.

# Tests

Run `./test/all` after changes to `bin/`, the theme system, or the update
process. The test programs are `test/cli`, `test/completion`, `test/install`,
`test/release`, and `test/update`. Each program sources `test/helpers.sh` for
common assertions and sandbox setup. Add new test programs to `test/all`.

Tests run with a sandbox value for `$HOME`. Tests must not change the actual
home directory. Replace external commands with stubs. Examples include mise
commands and Git network commands.
