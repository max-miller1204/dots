#!/usr/bin/env bash

# Complete the durability remediation for stock shell startup and Starship:
# resolve non-default runtimes before env-bootstrap is sourced, and remove the
# remaining private-use glyph dependency from the shipped prompt.

set -euo pipefail

DOTS_PATH=${DOTS_PATH:-$HOME/dotfiles}
source "$DOTS_PATH/install/helpers/files.sh"
source "$DOTS_PATH/install/helpers/theme-generation.sh"

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dots-durability-final.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT
fixture_dir="$DOTS_PATH/migrations/fixtures/1788051792"
fixture_names=(
  bashrc.old zshrc.old bashrc.intermediate zshrc.intermediate
  bashrc.41d3229 zshrc.41d3229 starship.old
)
for fixture_name in "${fixture_names[@]}"; do
  fixture="$fixture_dir/$fixture_name"
  if [[ -L $fixture || ! -f $fixture ]]; then
    echo "Missing or unsafe migration fixture: $fixture" >&2
    exit 1
  fi
done

shell_changed=""
if [[ -f $HOME/.bashrc && ! -L $HOME/.bashrc ]] &&
  { cmp -s "$HOME/.bashrc" "$fixture_dir/bashrc.old" ||
    cmp -s "$HOME/.bashrc" "$fixture_dir/bashrc.intermediate" ||
    cmp -s "$HOME/.bashrc" "$fixture_dir/bashrc.41d3229"; }; then
  dots_file_replace "$DOTS_PATH/default/bashrc" "$HOME/.bashrc" backup
  echo "Updated stock ~/.bashrc (backup at $DOTS_FILE_BACKUP)"
  shell_changed=1
fi
if [[ -f $HOME/.zshrc && ! -L $HOME/.zshrc ]] &&
  { cmp -s "$HOME/.zshrc" "$fixture_dir/zshrc.old" ||
    cmp -s "$HOME/.zshrc" "$fixture_dir/zshrc.intermediate" ||
    cmp -s "$HOME/.zshrc" "$fixture_dir/zshrc.41d3229"; }; then
  dots_file_replace "$DOTS_PATH/default/zshrc" "$HOME/.zshrc" backup
  echo "Updated stock ~/.zshrc (backup at $DOTS_FILE_BACKUP)"
  shell_changed=1
fi

starship_path="$HOME/.config/starship.toml"
if [[ -f $starship_path && ! -L $starship_path ]] && cmp -s "$starship_path" "$fixture_dir/starship.old"; then
  dots_file_replace "$DOTS_PATH/config/starship.toml" "$starship_path" backup
  echo "Updated stock Starship glyphs (backup at $DOTS_FILE_BACKUP)"
fi

printf 'dots-theme-generation-v1\n' >"$tmp_dir/generation-marker"
mark_generation_pointer() { # mark_generation_pointer <pointer>
  local pointer=$1 target generation marker
  [[ -L $pointer ]] || return 0
  target=$(readlink "$pointer")
  [[ $target =~ ^theme-generations/(generation|recovery)\.[A-Za-z0-9]+$ ]] || {
    echo "Refusing foreign theme pointer during migration: $pointer" >&2
    return 1
  }
  generation="$HOME/.local/state/dots/$target"
  marker="$generation/$DOTS_THEME_GENERATION_MARKER_NAME"
  dots_theme_generation_layout_valid "$HOME/.local/state/dots" "$target" || {
    echo "Refusing malformed theme generation during migration: $generation" >&2
    return 1
  }
  if [[ -L $marker || ( -e $marker && ! -f $marker ) ]]; then
    echo "Refusing foreign generation marker: $marker" >&2
    return 1
  fi
  if [[ -f $marker ]]; then
    mapfile -t generation_marker_lines <"$marker"
    ((${#generation_marker_lines[@]} == 1)) &&
      [[ ${generation_marker_lines[0]} == "$DOTS_THEME_GENERATION_MARKER_VALUE" ]] || {
        echo "Refusing unknown generation marker: $marker" >&2
        return 1
      }
  else
    dots_file_replace "$tmp_dir/generation-marker" "$marker" discard
  fi
}
mark_generation_pointer "$HOME/.local/state/dots/current"
mark_generation_pointer "$HOME/.local/state/dots/theme-previous"

if [[ -f $HOME/.local/state/dots/current/theme.name ]]; then
  current_theme=$(cat "$HOME/.local/state/dots/current/theme.name")
  [[ $current_theme =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || {
    echo "Refusing invalid current theme name during migration: $current_theme" >&2
    exit 1
  }
  "$DOTS_PATH/bin/dots-theme-set" "$current_theme"
fi

if [[ -n $shell_changed ]]; then
  : >"$tmp_dir/restart-marker"
  dots_file_replace "$tmp_dir/restart-marker" "$HOME/.local/state/dots/restart-shell-required" discard
fi
