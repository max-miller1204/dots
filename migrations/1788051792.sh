#!/usr/bin/env bash

# Complete the durability remediation for stock shell startup and Starship:
# resolve non-default checkouts before env-bootstrap is sourced, and remove the
# remaining private-use glyph dependency from the shipped prompt.

set -euo pipefail

DOTS_PATH=${DOTS_PATH:-$HOME/dotfiles}
source "$DOTS_PATH/install/helpers/files.sh"

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dots-durability-final.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/bashrc.old" <<'EOF'
# This file is yours. It is seeded from ~/dotfiles/default/bashrc at install
# (with a backup of any previous version) and never touched by `dots update`.
# `dots reinstall configs` resets it to the shipped default.

. "${DOTS_PATH:-$HOME/dotfiles}/default/bash/env-bootstrap"

# Non-interactive Bash needs only DOTS_PATH and PATH. Keep aliases, history,
# completion, directory hooks, and prompts out of SSH command and script shells.
[[ $- == *i* ]] || return 0 2>/dev/null || exit 0

. "$DOTS_PATH/default/bash/shell"
. "$DOTS_PATH/default/bash/aliases"
. "$DOTS_PATH/default/bash/functions"
. "$DOTS_PATH/default/bash/init"

if [[ $- == *i* ]]; then
  bind -f "$DOTS_PATH/default/bash/inputrc"
fi
EOF

cat >"$tmp_dir/zshrc.old" <<'EOF'
# This file is yours. It is seeded from ~/dotfiles/default/zshrc at install
# (with a backup of any previous version) and never touched by `dots update`.
# `dots reinstall configs` resets it to the shipped default.

. "${DOTS_PATH:-$HOME/dotfiles}/default/bash/env-bootstrap"

# These defaults intentionally use syntax shared by Bash 5 and Zsh.
. "$DOTS_PATH/default/bash/shell"
. "$DOTS_PATH/default/bash/aliases"
. "$DOTS_PATH/default/bash/functions"
. "$DOTS_PATH/default/bash/init"

# Zsh uses ZLE rather than Readline, so mirror the useful inputrc bindings.
if [[ -o interactive ]]; then
  bindkey -e
  autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
  zle -N up-line-or-beginning-search
  zle -N down-line-or-beginning-search
  bindkey '^[[A' up-line-or-beginning-search
  bindkey '^[[B' down-line-or-beginning-search
  bindkey '^[[Z' reverse-menu-complete
  zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
  zstyle ':completion:*' menu select
fi
EOF

cat >"$tmp_dir/bashrc.intermediate" <<'EOF'
# This file is yours. It is seeded from ~/dotfiles/default/bashrc at install
# (with a backup of any previous version) and never touched by `dots update`.
# `dots reinstall configs` resets it to the shipped default.

# Resolve plain checkout-path data before env-bootstrap itself is available.
dots_bootstrap_path=${DOTS_PATH:-}
if [[ -z $dots_bootstrap_path && -f $HOME/.config/dots/path ]]; then
  dots_bootstrap_path=$(cat -- "$HOME/.config/dots/path")
fi
if [[ -z $dots_bootstrap_path || $dots_bootstrap_path == *$'\n'* || $dots_bootstrap_path == *:* ]]; then
  dots_bootstrap_path="$HOME/dotfiles"
fi
. "$dots_bootstrap_path/default/bash/env-bootstrap"
unset dots_bootstrap_path

# Non-interactive Bash needs only DOTS_PATH and PATH. Keep aliases, history,
# completion, directory hooks, and prompts out of SSH command and script shells.
[[ $- == *i* ]] || return 0 2>/dev/null || exit 0

. "$DOTS_PATH/default/bash/shell"
. "$DOTS_PATH/default/bash/aliases"
. "$DOTS_PATH/default/bash/functions"
. "$DOTS_PATH/default/bash/init"

if [[ $- == *i* ]]; then
  bind -f "$DOTS_PATH/default/bash/inputrc"
fi
EOF

cat >"$tmp_dir/zshrc.intermediate" <<'EOF'
# This file is yours. It is seeded from ~/dotfiles/default/zshrc at install
# (with a backup of any previous version) and never touched by `dots update`.
# `dots reinstall configs` resets it to the shipped default.

# Resolve plain checkout-path data before env-bootstrap itself is available.
dots_bootstrap_path=${DOTS_PATH:-}
if [[ -z $dots_bootstrap_path && -f $HOME/.config/dots/path ]]; then
  dots_bootstrap_path=$(cat -- "$HOME/.config/dots/path")
fi
if [[ -z $dots_bootstrap_path || $dots_bootstrap_path == *$'\n'* || $dots_bootstrap_path == *:* ]]; then
  dots_bootstrap_path="$HOME/dotfiles"
fi
. "$dots_bootstrap_path/default/bash/env-bootstrap"
unset dots_bootstrap_path

# These defaults intentionally use syntax shared by Bash 5 and Zsh.
. "$DOTS_PATH/default/bash/shell"
. "$DOTS_PATH/default/bash/aliases"
. "$DOTS_PATH/default/bash/functions"
. "$DOTS_PATH/default/bash/init"

# Zsh uses ZLE rather than Readline, so mirror the useful inputrc bindings.
if [[ -o interactive ]]; then
  bindkey -e
  autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
  zle -N up-line-or-beginning-search
  zle -N down-line-or-beginning-search
  bindkey '^[[A' up-line-or-beginning-search
  bindkey '^[[B' down-line-or-beginning-search
  bindkey '^[[Z' reverse-menu-complete
  zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
  zstyle ':completion:*' menu select
fi
EOF

cat >"$tmp_dir/starship.old" <<'EOF'
add_newline = true
command_timeout = 200
format = "[$directory$git_branch$git_status]($style)$character"

[character]
error_symbol = "[✗](bold cyan)"
success_symbol = "[❯](bold cyan)"

[directory]
truncation_length = 2
truncation_symbol = "…/"
repo_root_style = "bold cyan"
repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) "

[git_branch]
format = "[$branch]($style) "
style = "italic cyan"

[git_status]
format     = '[$all_status]($style)'
style      = "cyan"
ahead      = "⇡${count} "
diverged   = "⇕⇡${ahead_count}⇣${behind_count} "
behind     = "⇣${count} "
conflicted = " "
up_to_date = " "
untracked  = "? "
modified   = " "
stashed    = ""
staged     = ""
renamed    = ""
deleted    = ""
EOF

for shell_name in bash zsh; do
  awk '
    /^if \[\[ -z \$dots_bootstrap_path && -L \$HOME\/\.config\/dots\/path \]\]; then$/ { skip=1 }
    skip && /^fi$/ { skip=0; next }
    !skip { print }
  ' "$DOTS_PATH/default/${shell_name}rc" >"$tmp_dir/${shell_name}rc.pre-symlink"
done

shell_changed=""
if [[ -f $HOME/.bashrc ]] &&
  { cmp -s "$HOME/.bashrc" "$tmp_dir/bashrc.old" ||
    cmp -s "$HOME/.bashrc" "$tmp_dir/bashrc.intermediate" ||
    cmp -s "$HOME/.bashrc" "$tmp_dir/bashrc.pre-symlink"; }; then
  dots_file_replace "$DOTS_PATH/default/bashrc" "$HOME/.bashrc" backup
  echo "Updated stock ~/.bashrc (backup at $DOTS_FILE_BACKUP)"
  shell_changed=1
fi
if [[ -f $HOME/.zshrc ]] &&
  { cmp -s "$HOME/.zshrc" "$tmp_dir/zshrc.old" ||
    cmp -s "$HOME/.zshrc" "$tmp_dir/zshrc.intermediate" ||
    cmp -s "$HOME/.zshrc" "$tmp_dir/zshrc.pre-symlink"; }; then
  dots_file_replace "$DOTS_PATH/default/zshrc" "$HOME/.zshrc" backup
  echo "Updated stock ~/.zshrc (backup at $DOTS_FILE_BACKUP)"
  shell_changed=1
fi

starship_path="$HOME/.config/starship.toml"
if [[ -f $starship_path ]] && cmp -s "$starship_path" "$tmp_dir/starship.old"; then
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
  marker="$generation/.dots-theme-generation"
  [[ ! -L $generation && -d $generation && ! -L $generation/theme && -d $generation/theme &&
    ! -L $generation/theme.name && -f $generation/theme.name ]] || {
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
      [[ ${generation_marker_lines[0]} == "dots-theme-generation-v1" ]] || {
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
