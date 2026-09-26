# Packages

Mise is the only cross-platform layer for development tools. The repository
manifest is [`config/mise/config.toml`](../config/mise/config.toml).
Installation copies the manifest to `~/.config/mise/config.toml`.

`dots install` and `dots update` run mise against the live manifest. Thus,
each machine gets the same tool set.

## Add a tool

```bash
dots pkg add ripgrep
dots config import mise/config.toml
git add config/mise/config.toml
git commit -m "Add ripgrep"
```

`dots pkg add` is a wrapper for `mise use --global`. Import the live
configuration to write it to the registered editable checkout. Commit the
change. Publish the change in a Dots release. Then, `dots update` installs the
tool on stable machines.

## Remove a tool

```bash
dots pkg drop ripgrep
dots config import mise/config.toml
```

Then, commit the manifest change.

## Versions

The manifest currently uses rolling versions for command-line tools. It uses
the active long-term support (LTS) line for Node. The manifest intentionally sets
`minimum_release_age = "0s"`. Thus, newly published tool versions are
immediately eligible on each managed machine. Dots does not pin mise. The
official standalone installation tracks current releases through
`mise self-update`.

Use these commands to examine the state:

```bash
mise --version
mise current
mise outdated
mise doctor
```

Dots expects the official standalone mise installation on macOS, Ubuntu, and
Windows Subsystem for Linux (WSL). See [`docs/setup.md`](setup.md) for
installation instructions and the
comparison with Omarchy.

## Aube and npm tools

Mise uses the embedded Aube package manager to install `npm:` tools. Before
installation, Aube applies security and popularity checks.

This setup includes Stepstone. Stepstone has a low npm download count. The
Stepstone manifest entry uses this limited exception:

```toml
"npm:stepstone" = { version = "latest", allow_low_downloads = true }
```

The option approves only the requested Stepstone package for the Aube
download-count gate. The option does not disable the gate globally. The option
does not automatically exempt transitive dependencies. By design, the separate
global release-age policy remains `0s`.

## Fonts

The Terminal and Starship defaults use only platform font glyphs. Dots does not
automatically install a Nerd Font. Dots does not require a Nerd Font.
