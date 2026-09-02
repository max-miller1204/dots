# Sourced by dots-install: macOS system defaults.

if [[ $(uname -s) != "Darwin" ]]; then
  return 0 2>/dev/null || exit 0
fi

# Do not change the account login shell. Dots bootstraps Homebrew Bash
# separately as its command runtime; users who prefer an interactive Bash
# login can opt in using the steps in docs/setup.md.

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
