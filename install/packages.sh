# Sourced by dots-install: install packages and tool versions.

echo "Installing packages..."

if command -v brew >/dev/null 2>&1; then
  brew bundle --file="$DOTS_PATH/install/packages/Brewfile"
else
  echo "Homebrew not found — skipping Brewfile."
  echo "Install it from https://brew.sh, then re-run: dots install"
fi

if command -v mise >/dev/null 2>&1; then
  echo "Installing mise-managed tools..."
  mise install || true
elif [[ -x "$HOME/.local/bin/mise" ]]; then
  echo "Installing mise-managed tools..."
  "$HOME/.local/bin/mise" install || true
fi
