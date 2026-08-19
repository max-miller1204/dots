# dotfiles

Personal dotfiles for macOS, built the way [omarchy](https://github.com/basecamp/omarchy) does it: configs are **copied, not symlinked**, a namespaced CLI in `bin/` manages everything, one-time repairs ship as **migrations**, and colors come from a **theme system** that renders templates from `colors.toml` palettes.

## Install

```bash
git clone <your-remote> ~/dotfiles
~/dotfiles/bin/dots-install
```

Then restart your shell. `dots install` is safe to re-run.

## The model

The repo is the source of truth for *defaults*; your live files are yours.

1. **Seed** — `dots install` copies `config/**` into `~/.config/**` (backing up anything it replaces) and seeds `~/.bashrc` / `~/.zshrc` from `default/`.
2. **Edit freely** — the copies in `~/.config` belong to you. Nothing overwrites them behind your back.
3. **Resync deliberately** — `dots refresh config <path>` re-copies one file (with a timestamped backup and a diff), `dots reinstall configs` clobbers everything back to defaults, and `dots config import <path>` adopts a live file back into the repo.

## Commands

Run `dots` for the full listing. Highlights:

| Command | Purpose |
| --- | --- |
| `dots install` | First-time setup: packages, configs, shell, default theme |
| `dots update` | Pull the repo, sync packages, run migrations, fire `post-update` hooks |
| `dots migrate [--pending]` | Run (or list) pending migrations |
| `dots refresh config <path>` | Reset one config file to the shipped default, with backup + diff |
| `dots reinstall configs` | Reset all configs to shipped defaults |
| `dots config import <path>` | Copy a file from `~/.config` into the repo |
| `dots theme list` / `set <name>` / `current` | Theme management |
| `dots hook <event>` / `hook install <event> <script>` | Run or install user hooks |
| `dots pkg add <pkg>` / `drop <pkg>` | Homebrew wrappers |

## Themes

`themes/<name>/colors.toml` defines a palette; `default/themed/*.tpl` are templates with `{{ key }}` placeholders (`{{ accent }}`, `{{ accent_strip }}`, `{{ accent_rgb }}`). `dots theme set <name>` stages the theme, overlays your files from `~/.config/dots/themes/<name>/`, renders the templates, atomically swaps the result into `~/.local/state/dots/current/theme/`, and fires the `theme-set` hook.

Point app configs at the generated files, e.g. for ghostty:

```
config-file = ~/.local/state/dots/current/theme/ghostty.conf
```

Add your own machine-wide templates in `~/.config/dots/themed/*.tpl`; they shadow built-ins with the same output name. Hand-written files in a theme dir always win over templates. Palettes for tokyo-night and catppuccin are adapted from omarchy (MIT).

## Migrations

One-time change on existing installs? Add `migrations/$(date +%s).sh` — idempotent, runs once per machine via `dots migrate` (called by `dots update`). Completion markers live in `~/.local/state/dots/migrations/`. Fresh installs mark all shipped migrations as already applied.

## Hooks

Executable scripts in `~/.config/dots/hooks/<event>.d/` run on: `post-install`, `post-update`, and `theme-set` (theme name in `$1`). Sample files ship in `config/dots/hooks/`; drop the `.sample` suffix to activate one, or run `dots hook install <event> <script>`.

## Layout

```
bin/         The dots CLI (router + dots-* commands)
config/      Default configs, copied to ~/.config
default/     Shell rc defaults, env bootstrap, theme templates (*.tpl)
install/     Install pipeline: packages, system config, per-user steps
migrations/  One-time repair scripts, named by unix timestamp
themes/      Theme palettes (colors.toml per theme)
docs/        How the system is shaped
test/        CLI test suite (./test/all)
```

State lives in `~/.local/state/dots/` (migration markers, done markers, current theme, install log). User-versioned extras (hooks, themes, templates) live in `~/.config/dots/`.
