#!/usr/bin/env bash

# Give existing Zsh installs the environment bootstrap used by non-interactive
# shells without replacing a user-owned ~/.zshenv.

set -euo pipefail

source "$DOTS_PATH/install/helpers/files.sh"

zshenv="$HOME/.zshenv"
if [[ ! -e $zshenv && ! -L $zshenv ]]; then
  dots_file_replace "$DOTS_PATH/default/zshenv" "$zshenv" discard
  echo "Installed the non-interactive Zsh environment bootstrap."
else
  echo "Left user-owned Zsh environment unchanged: $zshenv"
fi
