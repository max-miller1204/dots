# File layout

How this repo is organized and where everything ends up on the machine. The
design is a direct port of omarchy's architecture, minus the parts that only
make sense for a packaged Linux distro (pacman packages, /etc/skel, systemd
units, the Quickshell desktop).

## Mental model

The checkout at `~/dotfiles` *is* the install — there is no distro package
layer. The same checkout runs on macOS, Ubuntu, and WSL; tools come from mise
(manifest: `config/mise/config.toml`), never brew or apt.
`$DOTS_PATH` points at it (set by `default/bash/env-bootstrap`, sourced from
`~/.bashrc` and `~/.zshrc`; non-default locations are recorded in
`~/.config/dots/dots.conf`, the analog of omarchy's `/etc/omarchy.conf`).

Three layers populate `$HOME` (omarchy's seed / finalize / resync):

1. **Seed** — `dots install` copies `config/**` → `~/.config/**` and
   `default/{bashrc,zshrc}` → `~/`, backing up anything it replaces. This
   stands in for `/etc/skel`, which macOS doesn't have.
2. **Finalize** — `install/config/all.sh` and `install/user/all.sh` handle
   what a plain copy can't: macOS `defaults`, first-run theme, identity checks.
3. **Resync** — `dots refresh config <path>` (one file, backup + diff) and
   `dots reinstall configs` (everything, clobbers) reset to shipped defaults.

Your live files in `~/.config` are yours; the repo holds the defaults.

## Map (repo → live paths)

```
bin/dots-*                 →  on PATH via env-bootstrap (checkout, not /usr/bin)
config/**                  →  ~/.config/**                  (seed + resync source)
default/bashrc, zshrc      →  ~/.bashrc, ~/.zshrc           (seeded once, then yours)
default/bash/env-bootstrap →  sourced by both rc files      (DOTS_PATH + PATH)
default/themed/*.tpl       →  rendered into the active theme
install/**                 →  run by dots-install
migrations/*.sh            →  run by dots-migrate            (markers in state dir)
themes/<name>/colors.toml  →  staged + rendered by dots-theme-set
```

## State vs config

- `~/.local/state/dots/` — machine state, never versioned: migration markers
  (`migrations/`), done markers (`done/`), the generated active theme
  (`current/theme`, `current/theme.name`), and `install.log`.
- `~/.config/dots/` — files you may intentionally version: hooks
  (`hooks/<event>.d/`), user themes (`themes/<name>/`), user templates
  (`themed/*.tpl`), and `dots.conf` for non-default checkout locations.

## Theme activation flow

`dots theme set <name>`:

1. Build a clean staging dir at `~/.local/state/dots/current/next-theme`
2. Copy the first-party theme from `themes/<name>/`
3. Overlay user theme files from `~/.config/dots/themes/<name>/`
4. Render templates (user `~/.config/dots/themed/*.tpl` first, then
   `default/themed/*.tpl`; existing files are never overwritten, so
   hand-written theme files beat templates and user templates shadow built-ins)
5. Swap staging into `~/.local/state/dots/current/theme`, write `theme.name`,
   fire the `theme-set` hook (theme name in `$1`)

Rendering only happens when the staged theme has a `colors.toml`.

## Quick reference: where does X live?

| Goal | Touch |
| --- | --- |
| Default file at `~/.config/foo/` | `config/foo/`, then `dots refresh config foo/...` |
| Adopt a live config into the repo | `dots config import foo/...` |
| Shell alias/export for every shell | `default/bashrc` + `default/zshrc` |
| One-time setup step at install | leaf under `install/config/` or `install/user/`, wired into its `all.sh` |
| One-time fix for existing installs | `migrations/$(date +%s).sh` |
| New theme | `themes/<name>/colors.toml` |
| App output that should follow themes | `default/themed/<file>.tpl` |
| Personal machine-only theme/template/hook | `~/.config/dots/` |
| New user-facing command | `bin/dots-<group>-<verb>` + `group_description()` in `bin/dots` |
