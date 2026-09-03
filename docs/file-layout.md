# File layout

This document explains the structure of the repository. It also shows where
each file goes on the machine. The design is a direct port of the Omarchy
architecture. The design excludes components that apply only to a packaged
Linux distribution. These components include pacman packages, `/etc/skel`,
systemd units, and the Quickshell desktop.

## Mental model

The stable version of Dots runs from immutable GitHub release bundles. It does
not run from the editable checkout. Releases are in
`~/.local/share/dots/releases/<version>/`. A transaction protects the
`current` and `previous` symlinks. The checkout at `~/dotfiles` is an optional
authoring tree. Dots records this tree separately in
`~/.config/dots/source-path`.

The `dots dev link` command explicitly uses the checkout as the runtime. The
`dots dev unlink` command returns to the stable `current` release.

The same runtime operates on macOS, Ubuntu, and Windows Subsystem for Linux
(WSL). Tools come from mise. The
manifest is `config/mise/config.toml`. Tools do not come from Homebrew or apt.
On macOS, two system-level exceptions apply. Homebrew Bash supplies the Dots
command runtime. The `flock` command supplies locking. Dots does not change the
configured login shell of the account.

`$DOTS_PATH` identifies the active runtime. Dots stores the canonical path as
plain, non-executable data in `~/.config/dots/path`. Dots uses the same format
for the optional editable checkout in `~/.config/dots/source-path`. Each file
must be a regular file and must not be a symlink. Each file must be below a
HOME directory that is not a symlink. Each file must contain exactly one
non-empty absolute path. Dots rejects a path that contains a newline or a
colon. Stable mode stores `~/.local/share/dots/current`. Developer mode stores
the checkout path. Shell startup and direct commands use the same authority. A
command from an inactive release or checkout delegates to the active runtime
before the command changes state.

Three layers populate `$HOME`. These layers correspond to the Omarchy seed,
finalize, and resync operations:

1. **Seed**: `dots install` copies `config/**` to `~/.config/**`. It also copies
   `default/{bashrc,bash_profile,zshenv,zshrc}` to `~/`. The command backs up
   each item that it replaces. This operation replaces the function of
   `/etc/skel`, which macOS does not have.
2. **Finalize**: `install/config/all.sh` and `install/user/all.sh` do tasks that
   a file copy cannot do. These tasks include macOS `defaults`, the first-run
   theme, and identity checks.
3. **Resync**: `dots refresh config <path>` resets one file to the supplied
   default. It makes a backup and shows a diff. `dots reinstall configs` resets
   all files to the supplied defaults and overwrites the live files. File
   replacement rejects a final symlink. File replacement also rejects a
   symlink in a parent directory. Thus, file replacement cannot follow a
   symlink to write outside the owned HOME tree or checkout tree.

The live files in `~/.config` belong to you. The repository contains the
defaults.

## Map (repo → live paths)

```
bin/dots-*                 →  on PATH through env-bootstrap (active release or developer checkout)
config/**                  →  ~/.config/**                  (seed + resync source)
default/bashrc, bash_profile, zshrc, zshenv
                           →  ~/.bashrc, ~/.bash_profile, ~/.zshrc, ~/.zshenv
                              (copied, then user-owned; bash_profile supports optional
                              Bash login shells; zshenv initializes noninteractive Zsh)
default/bash/env-bootstrap →  sourced by Bash rc and Zsh startup files (DOTS_PATH + PATH)
default/bash/{shell,aliases,functions,init}
                           →  sourced by both startup files (portable shell behavior)
default/bash/inputrc       →  loaded by interactive Bash   (Readline settings)
default/bash/completions   →  loaded by interactive Bash   (dots command completion)
default/zsh/completions    →  sourced before Zsh tool integrations (completion setup)
default/zsh/site-functions →  added to interactive Zsh fpath (native completions)
default/themed/*.tpl       →  rendered into the active theme
install/**                 →  run by dots-install
migrations/*.sh            →  run by dots-migrate            (markers in state directory)
migrations/fixtures/<id>/  →  exact historical inputs used by one migration
themes/<name>/colors.toml  →  staged + rendered by dots-theme-set
```

## State vs config

- `~/.local/share/dots/` is the owned release store. It contains immutable
  `releases/<version>/` trees. It also contains the `current` and `previous`
  pointers. It contains durable recovery state for pointer transactions.
- `~/.local/state/dots/` contains machine state that is never versioned. It
  contains migration markers in `migrations/` and done markers in `done/`. It
  contains immutable theme generations in `theme-generations/`. It contains
  the atomic active pointer `current` and the atomic previous pointer
  `theme-previous`. It contains install and update transcripts in `install.log`
  and `update.log`. It also contains `restart-*-required` markers.
- `~/.config/dots/` contains user configuration. The active runtime path is in
  `path`. The optional editable source path is in `source-path`. User-only hooks
  are in `hooks/<event>.d/`. User themes are in `themes/<name>/`. User templates
  are in `themed/*.tpl`. First-party theme integrations remain versioned in
  `bin/`.

## Theme activation flow

The `dots theme set <name>` command does these steps:

1. Dots validates the lowercase theme identifier. Dots rejects symlinks in the source tree.
2. Dots uses `flock` to serialize transitions. Dots removes abandoned private staging directories.
3. Dots builds a unique generation under
   `~/.local/state/dots/theme-generations/`. The generation contains a durable
   Dots ownership marker. The generation also contains the complete theme
   payload and name payload.
4. Dots copies the first-party theme. Dots overlays regular user theme files.
   Dots renders user templates before built-in templates. Dots does not
   overwrite an existing regular generation output. Therefore, manually
   written theme files and user templates have precedence. Dots rejects a
   symlink or a non-regular item at an output path.
5. Dots revalidates the marker and contents of the renamed generation. Dots
   atomically prepares `theme-previous` with the current generation. Dots then
   replaces the `current` symlink. Therefore, `current/theme` and
   `current/theme.name` change together. If SIGKILL occurs after the commit,
   Dots still preserves the actual prior generation.
6. Dots runs the maintained application synchronizers. Dots keeps only the
   active and previous generations. To remove other generations, Dots uses
   atomic trash renames that can resume. Dots runs the separate user
   `theme-set` hook. Dots then releases the lock.

Template rendering occurs when the staged theme has `colors.toml`. Templates
support `{{ key }}`, `{{ key_strip }}`, and `{{ key_rgb }}` for quoted top-level
palette keys. Templates also support selection foreground and background
fallbacks. Templates do not support mix, gradient, nested TOML, or remote-theme
payload semantics. Dots trusts theme trees as local data. Theme trees must not
contain symlinks. Before publication, Dots rejects a rendered output that still
contains a supported placeholder.

## Quick reference: where does X live?

| Goal | Touch |
| --- | --- |
| Default file at `~/.config/foo/` | `config/foo/`, then `dots refresh config foo/...` |
| Add a live configuration to the repository | `dots config import foo/...` |
| Portable shell alias, function, or default | Shared file under `default/bash/`, sourced by both rc files |
| Shell-specific startup behavior | `default/bashrc`, `default/zshenv`, or `default/zshrc` |
| `dots` shell completion | `default/bash/completions`, `default/zsh/completions`, `default/zsh/site-functions/_dots`, and `bin/dots-completion-candidates` |
| One-time setup step at install | leaf under `install/config/` or `install/user/`, wired into its `all.sh` |
| One-time fix for existing installs | `migrations/$(date +%s).sh` |
| New theme | `themes/<name>/colors.toml` |
| Application output that should follow themes | `default/themed/<file>.tpl` |
| Personal theme, template, or hook for one machine | `~/.config/dots/` |
| New user-facing command | `bin/dots-<group>-<verb>` + `GROUP_DESCRIPTIONS` in `bin/dots` |
