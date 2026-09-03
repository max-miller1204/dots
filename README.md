# dots

Dots manages personal configuration files for macOS, Ubuntu, and Windows
Subsystem for Linux (WSL).\
Immutable GitHub release bundles provide the command runtime.
[mise](https://mise.jdx.dev) installs the same tools on each platform.

## Setup

First, install `curl`. On macOS, also install [Homebrew](https://brew.sh).
Homebrew supplies Bash for the command runtime. Homebrew also supplies `flock`.
The installer does not change your configured login shell. The built-in
completion supports only the `dots` commands. Dots uses mise to install Bash
completion for other commands. For more information, refer to
[Shell completion setup](docs/setup.md#bash-completion-framework).

1. Install the official standalone mise release:

   ```bash
   curl https://mise.run | sh
   ```

2. Install the latest stable dots release:

   ```bash
   installer=$(mktemp)
   curl -fsSL https://github.com/max-miller1204/dots/releases/latest/download/install.sh -o "$installer" && bash "$installer"
   rm -f "$installer"
   exec "$SHELL" -l
   ```

The daily commands use the packaged release in `~/.local/share/dots`. Use a
Git checkout only to contribute or to test unreleased code. For more
information, refer to [Developer mode](docs/setup.md#developer-mode).

Install `mise` before you install Dots. If Ubuntu already has the apt package,
first follow [Replacing apt-managed mise](docs/setup.md#replacing-apt-managed-mise).
Run the installer again after a failure.

## Daily use

```bash
dots                         # List commands
dots update                  # Update dots and installed tools
dots update available        # Check for published releases
dots version rollback        # Return to the previous runtime release
dots version prune           # Remove inactive verified releases
dots theme list              # List themes
dots theme set tokyo-night   # Select a theme
```

## Documentation

- For setup, mise ownership, and troubleshooting, refer to
  [`docs/setup.md`](docs/setup.md).
- For commands, refer to [`docs/commands.md`](docs/commands.md).
- For tool and package management, refer to
  [`docs/packages.md`](docs/packages.md).
- For the configuration and repository layout, refer to
  [`docs/file-layout.md`](docs/file-layout.md).
- For themes, refer to [`docs/themes.md`](docs/themes.md).
- For migrations and hooks, refer to [`docs/extending.md`](docs/extending.md).
- For the update process, refer to
  [`docs/update-process.md`](docs/update-process.md).
- For versioning and release publication, refer to
  [`docs/releases.md`](docs/releases.md).

To run the test suite, use `./test/all`.
