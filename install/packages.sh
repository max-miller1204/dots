# Sourced by dots-install: install tools with mise.
#
# The package manifest is config/mise/config.toml, seeded to
# ~/.config/mise/config.toml — the same manifest on every OS (macOS, Ubuntu,
# WSL). `mise install` installs whatever it pins.

echo "Installing packages..."

mise_bin=""
if command -v mise >/dev/null 2>&1; then
  mise_bin=$(command -v mise)
elif [[ -x "$HOME/.local/bin/mise" ]]; then
  mise_bin="$HOME/.local/bin/mise"
fi

if [[ -n $mise_bin ]]; then
  "$mise_bin" install || echo "Some mise tools failed to install; re-run 'mise install' to retry."
else
  echo "mise not found — install it first (https://mise.jdx.dev/getting-started.html),"
  echo "then re-run: dots install"
fi
