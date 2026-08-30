# dotfiles

Personal dotfiles for macOS, Ubuntu, and WSL, built the way [omarchy](https://github.com/basecamp/omarchy) does it: configs are **copied, not symlinked**, a namespaced CLI in `bin/` manages everything, one-time repairs ship as **migrations**, and colors come from a **theme system** that renders templates from `colors.toml` palettes.

[mise](https://mise.jdx.dev) is the only package layer — the same tool manifest installs the same tools on every OS, so there's no Homebrew/apt split to maintain.

## Install

Prerequisites: git and [mise](https://mise.jdx.dev/getting-started.html). On macOS also [Homebrew](https://brew.sh) — the install uses it to set up modern bash (the system `/bin/bash` is frozen at 3.2, and it becomes your login shell) plus `flock` for locks. Runtime commands only diagnose a missing `flock`; re-run `dots install` to provision it through the sanctioned install path. Dev tools still come only from mise.

```bash
git clone <your-remote> ~/dotfiles
~/dotfiles/bin/dots-install
```

Then restart your shell. `dots install` is safe to re-run.

## The model

The repo is the source of truth for *defaults*; your live files are yours.

1. **Seed** — `dots install` copies `config/**` into `~/.config/**` (backing up anything it replaces) and seeds `~/.bashrc` / `~/.zshrc` from `default/`.
2. **Edit freely** — the copies in `~/.config` belong to you. Nothing overwrites them behind your back.
3. **Resync deliberately** — `dots refresh config <path>` re-copies one file (with a unique backup and a diff), `dots reinstall configs` clobbers everything back to defaults, and `dots config import <path>` adopts a live file back into the repo. Replacement never follows destination or parent-directory symlinks into another tree, and both backup and discard modes keep the old live entry present until the atomic publication step.

## Commands

Run `dots` for the full listing, and `dots help <group>` to list one group's commands.
`dots <command> --help` (or `-h`) prints that command's usage and examples without running it.
Highlights:

| Command | Purpose |
| --- | --- |
| `dots install` | First-time setup: packages, configs, shell, default theme |
| `dots update` | The full pipeline: lock, transcript log, free-space check, pull, package sync, migrations, hooks, failure scan, restart checks ([details](docs/update-process.md)) |
| `dots update available` | Exit 0 + pending commits when behind; 1 when current; 2 when it can't tell |
| `dots migrate [--pending]` | Run (or list) pending migrations |
| `dots refresh config <path>` | Reset one config file to the shipped default, with backup + diff |
| `dots reinstall configs` | Reset all configs to shipped defaults |
| `dots config import <path>` | Copy a file from `~/.config` into the repo |
| `dots theme list` / `set <name>` / `current` | Theme management |
| `dots hook <event>` / `hook install <event> <script>` | Run or install user hooks |
| `dots pkg add <tool>` / `drop <tool>` | Add/remove global tools via mise |

## Packages

The tool manifest is [config/mise/config.toml](config/mise/config.toml), seeded to `~/.config/mise/config.toml`. `dots install` and `dots update` run `mise install` against it, so every machine converges on the same tools. The workflow:

```bash
dots pkg add ripgrep              # mise use --global ripgrep
dots config import mise/config.toml   # persist the manifest in the repo
```

Then commit, and `dots update` on your other machines picks it up. Terminal and Starship defaults use platform-font glyphs only; dots does not silently install or require a Nerd Font.

## Themes

`themes/<name>/colors.toml` defines a palette; `default/themed/*.tpl` are templates with `{{ key }}` placeholders (`{{ accent }}`, `{{ accent_strip }}`, `{{ accent_rgb }`). The renderer accepts quoted, top-level palette values plus the derived `selection_background` and `selection_foreground` keys; it deliberately does not implement Omarchy's mix or gradient expressions.

`dots theme set <name>` validates the identifier, takes an exclusive lock, builds a unique generation, overlays regular files from `~/.config/dots/themes/<name>/`, renders templates when the theme provides `colors.toml`, and atomically switches `~/.local/state/dots/current` to the complete generation. The immediately previous generation is retained for recovery. Theme source trees are trusted local inputs but may not contain symlinks; there is intentionally no remote-theme installer.

Point app configs at the generated files, e.g. for ghostty:

```
config-file = ~/.local/state/dots/current/theme/ghostty.conf
```

Versioned synchronizers in `bin/` integrate apps before the separate user `theme-set` hook runs. They link btop as `dots-system.theme`, link the Neovim Lazy plugin as `dots-system.lua`, copy theme payloads for configured Pi and Claude installations, and refresh live tmux styles. Btop and Neovim replace only missing or demonstrably dots-owned links. Pi and Claude preserve unowned payloads unless their bytes match the active or immediately previous generated payload, in which case dots safely adopts them; checking the retained generation lets older dots-managed payloads survive the first ownership-aware theme transition, and publication is recoverable after interruption. The generated `tmux.conf` is sourced by the base tmux config, so new servers inherit the active theme. The generated `obsidian.css` is available for an Obsidian CSS theme or snippet.

Normal theme changes never take over Pi or Claude preferences. Activate the stable generated theme explicitly once with `dots theme sync pi --activate` or `dots theme sync claude --activate`; subsequent dots theme changes update the payload behind that stable name.

Add your own machine-wide templates in `~/.config/dots/themed/*.tpl`; they shadow built-ins with the same output name. Hand-written regular files in a theme dir win over templates; symlinks and non-regular output occupants are rejected. Rendering also fails before publication if a supported `{{ key }}` placeholder remains unresolved, leaving the active generation unchanged. Shipped palettes, templates, and portable defaults adapted from omarchy retain its [MIT license](LICENSE.omarchy).

## Migrations

One-time change on existing installs? Add `migrations/$(date +%s).sh` — idempotent, runs once per machine via `dots migrate` (called by `dots update`). Standalone migration runs are serialized before marker checks. Completion markers live in `~/.local/state/dots/migrations/`. Fresh installs mark all shipped migrations as already applied.

## Hooks

Executable scripts in `~/.config/dots/hooks/<event>.d/` run on: `post-install`, `post-update`, and `theme-set` (theme name in `$1`). Sample files ship in `config/dots/hooks/`; drop the `.sample` suffix to activate one, or run `dots hook install <event> <script>`. Hook installation accepts lowercase hyphenated event names and refuses symlinked destination parents.

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
