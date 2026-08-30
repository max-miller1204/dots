#!/usr/bin/env bash
# Move existing installs onto the durable checkout-path, shell, and built-in
# theme-integration ownership model.

source "$DOTS_PATH/install/helpers/files.sh"

if [[ $DOTS_PATH == *$'\n'* || $DOTS_PATH == *:* ]]; then
  echo "The dots checkout path cannot contain a newline or colon: $DOTS_PATH" >&2
  exit 1
fi

path_source=$(mktemp "${TMPDIR:-/tmp}/dots-path.XXXXXX")
legacy_hook_source=$(mktemp "${TMPDIR:-/tmp}/dots-theme-hook.XXXXXX")
old_bashrc=$(mktemp "${TMPDIR:-/tmp}/dots-modular-bashrc.XXXXXX")
old_zshrc=$(mktemp "${TMPDIR:-/tmp}/dots-modular-zshrc.XXXXXX")
trap 'rm -f "$path_source" "$legacy_hook_source" "$old_bashrc" "$old_zshrc"' EXIT

printf '%s\n' "$DOTS_PATH" >"$path_source"
dots_file_replace "$path_source" "$HOME/.config/dots/path" backup
if [[ -n $DOTS_FILE_BACKUP ]]; then
  echo "Updated ~/.config/dots/path (backup at $DOTS_FILE_BACKUP)"
fi

legacy_conf="$HOME/.config/dots/dots.conf"
if [[ -e $legacy_conf || -L $legacy_conf ]]; then
  dots_file_remove "$legacy_conf" backup
  echo "Retired executable checkout config (backup at $DOTS_FILE_BACKUP)"
fi

cat >"$legacy_hook_source" <<'LEGACY_HOOK'
#!/usr/bin/env bash

# Keep installed applications pointed at the newly rendered active theme.

DOTS_PATH=${DOTS_PATH:-$HOME/dotfiles}

"$DOTS_PATH/bin/dots-theme-sync-btop"
"$DOTS_PATH/bin/dots-theme-sync-neovim"
"$DOTS_PATH/bin/dots-theme-sync-pi"
"$DOTS_PATH/bin/dots-theme-sync-claude"
"$DOTS_PATH/bin/dots-theme-sync-tmux"
LEGACY_HOOK

legacy_hook="$HOME/.config/dots/hooks/theme-set.d/10-sync-app-themes"
if [[ -f $legacy_hook && ! -L $legacy_hook ]] && cmp -s "$legacy_hook" "$legacy_hook_source"; then
  dots_file_remove "$legacy_hook" backup
  echo "Retired legacy built-in theme hook (backup at $DOTS_FILE_BACKUP)"
elif [[ -e $legacy_hook || -L $legacy_hook ]]; then
  echo "Left user-owned theme hook unchanged: $legacy_hook" >&2
fi

# Remove only the exact links created by the earlier dots integration. Foreign
# links and regular files are user-owned and remain untouched.
old_btop_link="$HOME/.config/btop/themes/current.theme"
old_nvim_link="$HOME/.config/nvim/lua/plugins/theme.lua"
old_btop_target="$HOME/.local/state/dots/current/theme/btop.theme"
old_nvim_target="$HOME/.local/state/dots/current/theme/neovim.lua"
had_old_btop_link=""
if [[ -L $old_btop_link && $(readlink "$old_btop_link") == "$old_btop_target" ]]; then
  had_old_btop_link=1
  dots_file_remove "$old_btop_link" discard
fi
if [[ -L $old_nvim_link && $(readlink "$old_nvim_link") == "$old_nvim_target" ]]; then
  dots_file_remove "$old_nvim_link" discard
fi

# Select the new namespaced btop target only when the prior dots-owned link
# proves that the old value belonged to this integration.
btop_config="$HOME/.config/btop/btop.conf"
if [[ -n $had_old_btop_link && -f $btop_config && ! -L $btop_config ]] && grep -q '^color_theme = "current"$' "$btop_config"; then
  btop_source=$(mktemp "${TMPDIR:-/tmp}/dots-btop-config.XXXXXX")
  sed 's/^color_theme = "current"$/color_theme = "dots-system"/' "$btop_config" >"$btop_source"
  dots_file_replace "$btop_source" "$btop_config" backup
  rm -f "$btop_source"
  echo "Updated btop to the namespaced dots-system theme (backup at $DOTS_FILE_BACKUP)"
fi

cat >"$old_bashrc" <<'OLD_BASHRC'
# This file is yours. It is seeded from ~/dotfiles/default/bashrc at install
# (with a backup of any previous version) and never touched by `dots update`.
# `dots reinstall configs` resets it to the shipped default.

[[ -f $HOME/.config/dots/dots.conf ]] && . "$HOME/.config/dots/dots.conf"
. "${DOTS_PATH:-$HOME/dotfiles}/default/bash/env-bootstrap"

. "$DOTS_PATH/default/bash/shell"
. "$DOTS_PATH/default/bash/aliases"
. "$DOTS_PATH/default/bash/functions"
. "$DOTS_PATH/default/bash/init"

if [[ $- == *i* ]]; then
  bind -f "$DOTS_PATH/default/bash/inputrc"
fi
OLD_BASHRC

cat >"$old_zshrc" <<'OLD_ZSHRC'
# This file is yours. It is seeded from ~/dotfiles/default/zshrc at install
# (with a backup of any previous version) and never touched by `dots update`.
# `dots reinstall configs` resets it to the shipped default.

[[ -f $HOME/.config/dots/dots.conf ]] && . "$HOME/.config/dots/dots.conf"
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
OLD_ZSHRC

shell_changed=""
if [[ -f $HOME/.bashrc && ! -L $HOME/.bashrc ]] && cmp -s "$HOME/.bashrc" "$old_bashrc"; then
  dots_file_replace "$DOTS_PATH/default/bashrc" "$HOME/.bashrc" backup
  shell_changed=1
  echo "Updated stock ~/.bashrc (backup at $DOTS_FILE_BACKUP)"
fi
if [[ -f $HOME/.zshrc && ! -L $HOME/.zshrc ]] && cmp -s "$HOME/.zshrc" "$old_zshrc"; then
  dots_file_replace "$DOTS_PATH/default/zshrc" "$HOME/.zshrc" backup
  shell_changed=1
  echo "Updated stock ~/.zshrc (backup at $DOTS_FILE_BACKUP)"
fi
if [[ -n $shell_changed ]]; then
  restart_source=$(mktemp "${TMPDIR:-/tmp}/dots-restart-marker.XXXXXX")
  dots_file_replace "$restart_source" "$HOME/.local/state/dots/restart-shell-required" discard
  rm -f "$restart_source"
fi

current_theme="$HOME/.local/state/dots/current/theme.name"
if [[ -f $current_theme ]]; then
  "$DOTS_PATH/bin/dots-theme-set" "$(<"$current_theme")"
fi
