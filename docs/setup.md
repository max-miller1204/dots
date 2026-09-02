# Setup

## Recommended installation

Dots supports macOS, Ubuntu, and WSL. Install `curl` first. On macOS, install [Homebrew](https://brew.sh) as well; dots uses it for `flock` and a modern Bash command runtime without changing the configured login shell. Broader Bash completion is an optional package described below.

### Optional Bash completion framework

Dots provides its own nested-command completion without extra packages. For broader command-specific completion for tools such as Git and system utilities, install the platform's `bash-completion` package:

**macOS (Apple Silicon or Intel):**

```bash
brew install bash-completion@2
```

**Ubuntu or WSL:**

```bash
sudo apt-get update
sudo apt-get install -y bash-completion
```

For reference, other common Linux package commands are:

```bash
# Arch Linux; Omarchy already includes this package
sudo pacman -S bash-completion

# Fedora
sudo dnf install bash-completion
```

Dots does not install optional system packages automatically. Its interactive
`~/.bashrc` discovers completion loaders in standard system locations and under
prefixes already present on `PATH`, so the same configuration works with `/usr`,
Homebrew, and Linuxbrew. It also loads context-aware completion for nested
`dots` commands. Zsh uses its native completion system and does not use the
`bash-completion` package.

### Optional Bash login shell on macOS

Dots uses Homebrew Bash to run its commands, but it neither registers Bash as a
login shell nor changes the account's current login shell. A standard macOS
account therefore remains on Zsh, while an existing custom shell is also
preserved. To opt into Bash for interactive sessions, register the Homebrew
binary and select it explicitly:

```bash
brew install bash
brew_bash="$(brew --prefix)/bin/bash"
grep -qxF "$brew_bash" /etc/shells || printf '%s\n' "$brew_bash" | sudo tee -a /etc/shells
chsh -s "$brew_bash"
exec "$brew_bash" -l
```

If the optional completion framework is installed, verify both it and the
built-in dots completion after Bash starts:

```bash
type _completion_loader
complete -p dots
```

Switch back to the macOS default at any time with `chsh -s /bin/zsh`.

Use mise's official standalone release on every platform:

```bash
curl https://mise.run | sh
```

The installer places mise at `~/.local/bin/mise`. Dots can find that path even before the current shell reloads.

Then run the installer published with the latest GitHub release:

```bash
installer=$(mktemp)
curl -fsSL https://github.com/max-miller1204/dots/releases/latest/download/install.sh -o "$installer" && bash "$installer"
rm -f "$installer"
exec "$SHELL" -l
```

The installer contains the release's exact version and SHA-256, verifies the downloaded archive before extraction, and activates it under `~/.local/share/dots/releases/`. It copies the released defaults, installs the mise tool manifest, configures the shell, and selects the default theme. Re-run the same command after a failed installation; completed steps are safe to converge again.

## Developer mode

A Git checkout is not part of a normal installation. Clone one only to author configuration or test unreleased code:

```bash
git clone https://github.com/max-miller1204/dots.git ~/dotfiles
dots dev link ~/dotfiles
```

Return to the verified stable runtime without deleting the checkout:

```bash
dots dev unlink
```

For a deliberately checkout-backed installation from the start, run `~/dotfiles/bin/dots-install --developer`.

Verify the installation:

```bash
command -v mise
mise --version
command -v dots
dots
```

The recommended mise path is `~/.local/bin/mise`.

## Replacing apt-managed mise

Ubuntu's apt package is valid, but it gives apt ownership of mise itself and disables `mise self-update`. Using the standalone release keeps every dots machine on the same update model and matches the macOS setup.

Remove only the apt package, then install the standalone release:

```bash
sudo apt remove mise
curl https://mise.run | sh
hash -r
command -v mise
mise --version
```

Removing the apt package does not remove mise's user data under `~/.config/mise` or `~/.local/share/mise`.

Dots expects the standalone installation because `dots update` uses `mise self-update`. Keeping the apt package would restore the self-update error that this setup avoids.

## Who installs mise?

For **dots**, the user installs mise first. `dots-install` deliberately stops with an actionable error when it cannot find `mise` rather than downloading executable code implicitly.

Omarchy has a different boundary because it owns the operating-system package layer:

- [`install/omarchy-base.packages`](https://github.com/basecamp/omarchy/blob/quattro/install/omarchy-base.packages) includes `mise-bin`, so Omarchy users do not install mise separately.
- [`migrations/1786952219.sh`](https://github.com/basecamp/omarchy/blob/quattro/migrations/1786952219.sh) moved existing systems from Arch's `mise` package to Omarchy's `mise-bin` package, built from mise's release artifacts.
- [`omarchy-update-system-pkgs`](https://github.com/basecamp/omarchy/blob/quattro/bin/omarchy-update-system-pkgs) lets pacman update the mise binary.
- [`omarchy-update-mise`](https://github.com/basecamp/omarchy/blob/quattro/bin/omarchy-update-mise) runs `mise up` for mise-managed tools; it does not run `mise self-update`.

Dots cannot use that exact model across macOS, Ubuntu, and WSL because it does not own a common OS package repository. Its setup therefore requires the official standalone mise binary before dots is installed.

## Version policy

The repository's [`config/mise/config.toml`](../config/mise/config.toml) declares the desired tool versions. Most tools track `latest`; Node tracks `lts`.

`dots update` runs `mise install` and `mise upgrade` for those tools, then `mise self-update` for the standalone mise binary. Dots does not pin or declare a minimum mise version; the official installer starts with the current release and subsequent updates keep it current.

## Troubleshooting

Collect the basic state with:

```bash
command -v mise
mise --version
mise doctor
mise install
```

### `aube install failed: user aborted`

Mise's npm backend uses the embedded Aube package manager. Aube refuses low-download packages unless the manifest explicitly approves them. Stepstone is a reviewed first-party tool for this setup, so its manifest entry has the narrow `allow_low_downloads = true` exception. The setting does not disable Aube's checks globally or approve transitive packages.

Update to the corrected release and rerun the installer:

```bash
dots update
dots install
```

### `mise self-update` fails under apt

Replace apt-managed mise using the instructions above. Dots intentionally uses the official standalone installation on every supported platform.

### An activated Python virtualenv is missing from the prompt

Starship owns the prompt in both Bash and Zsh, so Python's activation script
cannot reliably preserve its direct `PS1` change. The shipped Starship config
instead reads `VIRTUAL_ENV` through its Python module and renders `(name)`.
Run `dots update` to migrate an unchanged stock config, or refresh a customized
copy when you are ready to replace it (the old file is backed up and diffed):

```bash
dots refresh config starship.toml
```

Install and update transcripts live at:

- `~/.local/state/dots/install.log`
- `~/.local/state/dots/update.log`
