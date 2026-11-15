#!/usr/bin/env bash

# tmux 3.8 changed the default window-status-current-style to underscore, which
# underlines the active tab in existing configs. Add the shipped override next
# to the current-window format, and only where the user has not set a style.

set -euo pipefail

: "${DOTS_PATH:?DOTS_PATH must identify the active dots runtime}"
source "$DOTS_PATH/install/helpers/files.sh"

tmux_config="$HOME/.config/tmux/tmux.conf"
format_pattern='^set -g window-status-current-format '
style_line='set -g window-status-current-style "none"'

[[ -f $tmux_config && ! -L $tmux_config ]] || exit 0

# Leave configs that already choose a style, and configs that no longer carry
# the shipped format line this edit is anchored to.
if grep -q 'window-status-current-style' "$tmux_config" ||
  ! grep -q "$format_pattern" "$tmux_config"; then
  exit 0
fi

tmux_source=$(mktemp "${TMPDIR:-/tmp}/dots-tmux-config.XXXXXX")
trap 'rm -f "$tmux_source"' EXIT

awk -v line="$style_line" '{ print } /^set -g window-status-current-format / { print line }' \
  "$tmux_config" >"$tmux_source"
dots_file_replace "$tmux_source" "$tmux_config" discard
echo "Added window-status-current-style to ~/.config/tmux/tmux.conf; reload tmux (prefix q) to apply."
