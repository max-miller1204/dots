# File layout

How this repo is organized and where everything ends up on the machine. The
design is a direct port of omarchy's architecture, minus the parts that only
make sense for a packaged Linux distro (pacman packages, /etc/skel, systemd
units, the Quickshell desktop).

## Mental model

Stable dots runs from immutable GitHub release bundles, not from the editable
checkout. Releases live under `~/.local/share/dots/releases/<version>/`, with
transaction-protected `current` and `previous` symlinks. The checkout at
`~/dotfiles` remains an optional authoring tree, recorded separately in
`~/.config/dots/source-path`.
`dots dev link` explicitly makes that checkout the runtime; `dots dev unlink`
returns to the stable `current` release.

The same runtime runs on macOS, Ubuntu, and WSL; tools come from mise (manifest:
`config/mise/config.toml`), never brew or apt. The one exception: on macOS,
`install/config/macos.sh` uses Homebrew to install modern bash and flock.

`$DOTS_PATH` identifies the active runtime. Its canonical path is stored as
plain, non-executable data in `~/.config/dots/path`; the file must be a regular,
non-symlink file containing exactly one non-empty line, and paths containing a
newline or colon are rejected. Stable mode stores
`~/.local/share/dots/current`; developer mode stores the checkout path. Shell
startup and direct commands resolve the same authority, and commands reached
through an inactive release or checkout delegate before mutating state.

Three layers populate `$HOME` (omarchy's seed / finalize / resync):

1. **Seed** — `dots install` copies `config/**` → `~/.config/**` and
   `default/{bashrc,zshrc}` → `~/`, backing up anything it replaces. This
   stands in for `/etc/skel`, which macOS doesn't have.
2. **Finalize** — `install/config/all.sh` and `install/user/all.sh` handle
   what a plain copy can't: macOS `defaults`, first-run theme, identity checks.
3. **Resync** — `dots refresh config <path>` (one file, backup + diff) and
   `dots reinstall configs` (everything, clobbers) reset to shipped defaults.
   File replacement rejects final and parent-directory symlinks rather than
   following writes outside the owned HOME or checkout tree.

Your live files in `~/.config` are yours; the repo holds the defaults.

## Map (repo → live paths)

```
bin/dots-*                 →  on PATH via env-bootstrap (active release or dev checkout)
config/**                  →  ~/.config/**                  (seed + resync source)
default/bashrc, bash_profile, zshrc
                           →  ~/.bashrc, ~/.bash_profile, ~/.zshrc  (seeded, then yours;
                              bash_profile delegates to bashrc for macOS login shells)
default/bash/env-bootstrap →  sourced by both rc files      (DOTS_PATH + PATH)
default/bash/{shell,aliases,functions,init}
                           →  sourced by both rc files      (portable shell UX)
default/bash/inputrc       →  loaded by interactive Bash   (Readline settings)
default/bash/completions   →  loaded by interactive Bash   (dots command completion)
default/zsh/completions    →  sourced before Zsh tool integrations (completion setup)
default/zsh/site-functions →  added to interactive Zsh fpath (native completions)
default/themed/*.tpl       →  rendered into the active theme
install/**                 →  run by dots-install
migrations/*.sh            →  run by dots-migrate            (markers in state dir)
themes/<name>/colors.toml  →  staged + rendered by dots-theme-set
```

## State vs config

- `~/.local/share/dots/` — owned release store: immutable
  `releases/<version>/` trees, `current`/`previous` pointers, and durable
  pointer-transaction recovery state.
- `~/.local/state/dots/` — machine state, never versioned: migration markers
  (`migrations/`), done markers (`done/`), immutable theme generations
  (`theme-generations/`), atomic active/previous pointers (`current`,
  `theme-previous`), install/update transcripts (`install.log`, `update.log`),
  and `restart-*-required` markers.
- `~/.config/dots/` — user configuration: the active runtime `path`, optional editable `source-path`, user-only hooks (`hooks/<event>.d/`), user themes (`themes/<name>/`), and user templates
  (`themed/*.tpl`). First-party theme integrations remain versioned in `bin/`.

## Theme activation flow

`dots theme set <name>`:

1. Validate the lowercase theme identifier and reject source-tree symlinks.
2. Serialize transitions with `flock` and remove abandoned private staging dirs.
3. Build a unique generation under `~/.local/state/dots/theme-generations/`
   with a durable dots-ownership marker and complete theme/name payload.
4. Copy the first-party theme, overlay regular user theme files, and render
   user templates before built-ins. Existing regular generation outputs are
   not overwritten, so hand-written theme files and user templates still win;
   symlinks and non-regular output occupants are rejected.
5. Revalidate the renamed generation's marker and contents, atomically prepare
   `theme-previous` with the current generation, then replace
   the `current` symlink. `current/theme` and `current/theme.name` therefore
   change together, while a SIGKILL after commit still preserves the real prior
   generation.
6. Run maintained app synchronizers, prune to active plus previous generations
   through resumable atomic trash renames, run the separate user `theme-set`
   hook, then release the lock.

Template rendering occurs when the staged theme has `colors.toml`. Supported placeholders are `{{ key }}`,
`{{ key_strip }}`, and `{{ key_rgb }}` for quoted top-level palette keys, plus
selection foreground/background fallbacks. Mix, gradient, nested TOML, and
remote-theme payload semantics are intentionally unsupported. Theme trees are
trusted local data, but may not contain symlinks. A rendered output that still
contains a supported placeholder is rejected before the generation is
published.

## Quick reference: where does X live?

| Goal | Touch |
| --- | --- |
| Default file at `~/.config/foo/` | `config/foo/`, then `dots refresh config foo/...` |
| Adopt a live config into the repo | `dots config import foo/...` |
| Portable shell alias/function/default | shared file under `default/bash/`, sourced by both rc files |
| Shell-specific startup behavior | `default/bashrc` or `default/zshrc` |
| `dots` shell completion | `default/bash/completions`, `default/zsh/completions`, `default/zsh/site-functions/_dots`, and `bin/dots-completion-candidates` |
| One-time setup step at install | leaf under `install/config/` or `install/user/`, wired into its `all.sh` |
| One-time fix for existing installs | `migrations/$(date +%s).sh` |
| New theme | `themes/<name>/colors.toml` |
| App output that should follow themes | `default/themed/<file>.tpl` |
| Personal machine-only theme/template/hook | `~/.config/dots/` |
| New user-facing command | `bin/dots-<group>-<verb>` + `GROUP_DESCRIPTIONS` in `bin/dots` |
