# Sourced by dots-install: macOS system defaults.

if [[ $(uname -s) != "Darwin" ]]; then
  return 0 2>/dev/null || exit 0
fi

# Modern bash as the login shell. The system /bin/bash is frozen at 3.2, so
# the dots scripts (and daily shell) use Homebrew's bash 5. This is the one
# sanctioned Homebrew use — dev tools stay mise-only.
if command -v brew >/dev/null 2>&1; then
  brew_bash="$(brew --prefix)/bin/bash"

  if [[ ! -x $brew_bash ]]; then
    brew install bash
  fi

  if [[ -x $brew_bash ]]; then
    if ! grep -qx "$brew_bash" /etc/shells; then
      echo "Registering $brew_bash in /etc/shells (needs sudo)..."
      if ! echo "$brew_bash" | sudo tee -a /etc/shells >/dev/null; then
        echo "Skipped /etc/shells registration — run manually:"
        echo "  echo $brew_bash | sudo tee -a /etc/shells"
      fi
    fi
    if grep -qx "$brew_bash" /etc/shells &&
      [[ $(dscl . -read "/Users/$USER" UserShell 2>/dev/null) != *"$brew_bash" ]]; then
      echo "Setting login shell to $brew_bash (chsh will ask for your password)..."
      if ! chsh -s "$brew_bash"; then
        echo "Skipped login shell change — run manually: chsh -s $brew_bash"
      fi
    fi
  fi
  # flock(1) for the update lock — util-linux ships it on Ubuntu/WSL, macOS
  # needs the discoteq port.
  if ! command -v flock >/dev/null 2>&1; then
    brew install flock
  fi
else
  echo "Homebrew not found — keeping /bin/bash (3.2). Install brew for modern bash and flock."
fi

# Add your `defaults write` tweaks here. Examples (all commented out on
# purpose — enable the ones you actually want):
#
#   # Faster key repeat
#   defaults write NSGlobalDomain KeyRepeat -int 2
#   defaults write NSGlobalDomain InitialKeyRepeat -int 15
#
#   # Show all file extensions in Finder
#   defaults write NSGlobalDomain AppleShowAllExtensions -bool true
#
#   # Autohide the Dock
#   defaults write com.apple.dock autohide -bool true && killall Dock

echo "No macOS defaults applied (edit install/config/macos.sh to add your own)."
