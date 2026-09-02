# dots

Personal dotfiles for macOS, Ubuntu, and WSL. Configs are copied—not symlinked—while immutable release bundles keep the runtime separate from an editable source checkout. [mise](https://mise.jdx.dev) installs the same tools on every platform.

## Setup

Install `git` and `curl` first. macOS also requires [Homebrew](https://brew.sh). For broader Bash completion beyond the built-in `dots` commands, install the optional platform framework using the commands in [Shell completion setup](docs/setup.md#optional-bash-completion-framework).

1. Install the official standalone mise release:

   ```bash
   curl https://mise.run | sh
   ```

2. Clone the editable source and install the latest stable dots release:

   ```bash
   git clone https://github.com/max-miller1204/dots.git ~/dotfiles
   ~/dotfiles/bin/dots-install
   exec "$SHELL" -l
   ```

The checkout remains available for authoring, but daily commands run from the packaged release under `~/.local/share/dots`. To run unreleased checkout code, use `dots dev link ~/dotfiles`; return with `dots dev unlink`.

`mise` must be installed before dots. If Ubuntu already has the apt package, follow [Replacing apt-managed mise](docs/setup.md#replacing-apt-managed-mise) first. The installer is safe to rerun after a failure.

## Daily use

```bash
dots                         # list commands
dots update                  # update dots and installed tools
dots update available        # check for published releases
dots version rollback        # return to the previous runtime release
dots theme list              # list themes
dots theme set tokyo-night   # select a theme
```

## Documentation

- Setup, mise ownership, and troubleshooting — [`docs/setup.md`](docs/setup.md)
- Commands — [`docs/commands.md`](docs/commands.md)
- Tool and package management — [`docs/packages.md`](docs/packages.md)
- Configuration and repository layout — [`docs/file-layout.md`](docs/file-layout.md)
- Themes — [`docs/themes.md`](docs/themes.md)
- Migrations and hooks — [`docs/extending.md`](docs/extending.md)
- Update pipeline — [`docs/update-process.md`](docs/update-process.md)
- Versioning and publishing releases — [`docs/releases.md`](docs/releases.md)

Run the test suite with `./test/all`.
