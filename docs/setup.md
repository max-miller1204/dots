# Setup

## Recommended installation

Dots supports macOS, Ubuntu, and Windows Subsystem for Linux (WSL). Install
`curl` first. On macOS, also install [Homebrew](https://brew.sh). On macOS, Dots
uses the Homebrew `flock` command. On macOS, Dots also uses Homebrew Bash to run
commands. Dots does not change the configured login shell. The optional Bash
completion framework gives more completion functions.

### Optional Bash completion framework

Dots supplies completion for its nested commands. This completion does not
require an additional package. To get command-specific completion for tools
such as Git and system utilities, install the `bash-completion` package for
your platform.

**macOS (Apple Silicon or Intel):**

```bash
brew install bash-completion@2
```

**Ubuntu or WSL:**

```bash
sudo apt-get update
sudo apt-get install -y bash-completion
```

For reference, use these commands on other common Linux platforms:

```bash
# Arch Linux. Omarchy already includes this package.
sudo pacman -S bash-completion

# Fedora
sudo dnf install bash-completion
```

Dots does not automatically install optional system packages. The interactive
`~/.bashrc` searches standard system locations for completion loaders. The file
also searches prefixes that are on `PATH`. Thus, the same configuration
operates with `/usr`, Homebrew, and Linuxbrew. The configuration also loads
context-sensitive completion for nested `dots` commands. Zsh uses the native
Zsh completion system. Zsh does not use the `bash-completion` package.

### Optional Bash login shell on macOS

Dots uses Homebrew Bash to run commands. Dots does not register Bash as a login
shell. Dots also does not change the current login shell of the account. Thus,
a standard macOS account continues to use Zsh. Dots does not change an existing
custom shell.

To use Bash for interactive sessions, register the Homebrew binary. Then,
select the binary explicitly:

```bash
brew install bash
brew_bash="$(brew --prefix)/bin/bash"
grep -qxF "$brew_bash" /etc/shells || printf '%s\n' "$brew_bash" | sudo tee -a /etc/shells
chsh -s "$brew_bash"
exec "$brew_bash" -l
```

If you installed the optional completion framework, start Bash. Then, verify
the optional framework and the built-in Dots completion:

```bash
type _completion_loader
complete -p dots
```

To restore the macOS default shell, run `chsh -s /bin/zsh` at any time.

### Install mise and dots

Use the official standalone mise release on each platform:

```bash
curl https://mise.run | sh
```

The installer puts mise in `~/.local/bin/mise`. Dots can find this path before
you reload the current shell.

Then, run the installer from the latest GitHub release:

```bash
installer=$(mktemp)
curl -fsSL https://github.com/max-miller1204/dots/releases/latest/download/install.sh -o "$installer" && bash "$installer"
rm -f "$installer"
exec "$SHELL" -l
```

The installer contains the exact release version and SHA-256 checksum. Before
extraction, the installer verifies the integrity of the downloaded archive.
The installer activates the release under `~/.local/share/dots/releases/`. The
checksum detects corruption or substitution only if the published checksum is
trustworthy. The release artifacts do not have cryptographic signatures.

The installer copies the released defaults. It installs the mise tool manifest.
It configures the shell. It also selects the default theme. If an installation
fails, run the same command again. You can safely run completed steps again to
reach the specified state.

Dots does not supply a Git name or email. When Dots prompts you, configure the
identity in the live user configuration:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

## Developer mode

A normal installation does not use a Git checkout. Clone a checkout only when
you change configuration files or test unreleased code:

```bash
git clone https://github.com/max-miller1204/dots.git ~/dotfiles
dots dev link ~/dotfiles
```

To return to the verified stable runtime without deleting the checkout, run:

```bash
dots dev unlink
```

To use a checkout-backed installation from the start, run
`~/dotfiles/bin/dots-install --developer`.

Verify the installation:

```bash
command -v mise
mise --version
command -v dots
dots
```

The recommended mise path is `~/.local/bin/mise`.

## Replacing apt-managed mise

The Ubuntu apt package is valid. However, apt then owns mise and disables
`mise self-update`. With the standalone release, each Dots machine uses the
same update method. This method also matches the macOS setup.

Remove only the apt package. Then, install the standalone release:

```bash
sudo apt remove mise
curl https://mise.run | sh
hash -r
command -v mise
mise --version
```

When you remove the apt package, mise user data remains in `~/.config/mise` and
`~/.local/share/mise`.

Dots expects the standalone installation because `dots update` uses
`mise self-update`. If you keep the apt package, the self-update error occurs
again.

## Who installs mise?

For **Dots**, install mise before you install Dots. If `dots-install` cannot
find `mise`, the command stops and shows corrective instructions. The command
does not download executable code without an explicit instruction.

Omarchy has a different boundary because Omarchy controls the operating-system package layer:

- [`install/omarchy-base.packages`](https://github.com/basecamp/omarchy/blob/quattro/install/omarchy-base.packages)
  includes `mise-bin`. Thus, Omarchy users do not install mise separately.
- [`migrations/1786952219.sh`](https://github.com/basecamp/omarchy/blob/quattro/migrations/1786952219.sh)
  moved existing systems from the Arch `mise` package to the Omarchy
  `mise-bin` package. Omarchy builds `mise-bin` from the mise release artifacts.
- [`omarchy-update-system-pkgs`](https://github.com/basecamp/omarchy/blob/quattro/bin/omarchy-update-system-pkgs)
  lets pacman update the mise binary.
- [`omarchy-update-mise`](https://github.com/basecamp/omarchy/blob/quattro/bin/omarchy-update-mise)
  runs `mise up` for tools that mise manages. The command does not run
  `mise self-update`.

Dots cannot use the same method on macOS, Ubuntu, and WSL. Dots does not control
a common operating-system package repository. Therefore, install the official
standalone mise binary before you install Dots.

## Version policy

The manifest at
[`config/mise/config.toml`](../config/mise/config.toml) specifies the required
tool versions. Most tools track `latest`. Node tracks long-term support (`lts`).

For the specified tools, `dots update` runs `mise install` and `mise upgrade`.
The command then runs `mise self-update` for the standalone mise binary. Dots
does not pin mise or specify a minimum mise version. The official installer
installs the current release. Subsequent updates keep mise current.

## Troubleshooting

Collect the basic state with these commands:

```bash
command -v mise
mise --version
mise doctor
mise install
```

### `aube install failed: user aborted`

The mise npm backend uses the embedded Aube package manager. Aube rejects
packages with low download counts unless the manifest explicitly approves the
packages. Stepstone is a reviewed first-party tool for this setup. Therefore,
the Stepstone manifest entry has the narrow `allow_low_downloads = true`
exception. The setting does not disable the Aube checks globally. The setting
also does not approve transitive packages.

Update to the corrected release. Then, run the installer again:

```bash
dots update
dots install
```

### `mise self-update` fails under apt

Use the preceding instructions to replace the apt-managed mise installation.
Dots intentionally uses the official standalone installation on each supported
platform.

### An activated Python virtualenv is missing from the prompt

Starship controls the prompt in Bash and Zsh. Therefore, the Python activation
script cannot reliably keep its direct `PS1` change. Instead, the supplied
Starship configuration reads `VIRTUAL_ENV` through the Python module. The
configuration displays `(name)`.

Run `dots update` to migrate an unchanged supplied configuration. If you
customized the configuration, refresh the copy only when you are ready to
replace it. The refresh command backs up the old file and shows a diff:

```bash
dots refresh config starship.toml
```

Installation and update transcripts are at these paths:

- `~/.local/state/dots/install.log`
- `~/.local/state/dots/update.log`
