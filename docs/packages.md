# Packages

Mise is the only cross-platform development-tool layer. The repository manifest is [`config/mise/config.toml`](../config/mise/config.toml); installation copies it to `~/.config/mise/config.toml`.

`dots install` and `dots update` run mise against the live manifest so each machine converges on the same tool set.

## Add a tool

```bash
dots pkg add ripgrep
dots config import mise/config.toml
git add config/mise/config.toml
git commit -m "Add ripgrep"
```

`dots pkg add` is a wrapper around `mise use --global`. Importing the live config makes the change part of the repository defaults. After that commit is shared, `dots update` on another machine installs it.

## Remove a tool

```bash
dots pkg drop ripgrep
dots config import mise/config.toml
```

Then commit the manifest change.

## Versions

The manifest currently uses rolling versions for command-line tools and the active LTS line for Node. Mise itself is not pinned; the official standalone installation tracks current releases through `mise self-update`.

Use these commands to inspect state:

```bash
mise --version
mise current
mise outdated
mise doctor
```

Dots expects the official standalone mise installation on macOS, Ubuntu, and WSL. See [`docs/setup.md`](setup.md) for installation instructions and the Omarchy comparison.

## Aube and npm tools

Mise installs `npm:` tools with its embedded Aube package manager. Aube applies security and popularity checks before installation.

Stepstone is maintained as part of this setup but has a low npm download count. Its manifest entry uses a scoped exception:

```toml
"npm:stepstone" = { version = "latest", allow_low_downloads = true }
```

That option approves only the requested Stepstone package for Aube's download-count gate. It does not disable the gate globally and does not automatically exempt transitive dependencies.

## Fonts

Terminal and Starship defaults use platform-font glyphs only. Dots does not silently install or require a Nerd Font.
