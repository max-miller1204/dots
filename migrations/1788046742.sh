#!/usr/bin/env bash
# Adopt the portable Omarchy-derived defaults on existing dots installs without
# overwriting user-managed configs. Fresh installs already receive these files
# from config/ and default/.

source "$DOTS_PATH/install/helpers/files.sh"

install_config_if_missing() { # install_config_if_missing <repo-relative-config-path>
  local rel=$1 src="$DOTS_PATH/config/$1" dest="$HOME/.config/$1"

  [[ -f $src && ! -e $dest && ! -L $dest ]] || return 0
  dots_file_replace "$src" "$dest" discard
  echo "Installed missing config: ~/.config/$rel"
}

# Add new app defaults only where the user has no file already.
config_files=(
  aerospace/aerospace.toml
  alacritty/alacritty.toml
  btop/btop.conf
  gh/config.yml
  ghostty/config
  git/ignore
  herdr/config.toml
  nvim/.gitignore
  nvim/init.lua
  nvim/lazy-lock.json
  nvim/lazyvim.json
  nvim/lua/config/autocmds.lua
  nvim/lua/config/keymaps.lua
  nvim/lua/config/lazy.lua
  nvim/lua/config/options.lua
  nvim/lua/plugins/example.lua
  nvim/stylua.toml
  opencode/opencode.jsonc
  opencode/tui.jsonc
  starship.toml
  tmux/tmux.conf
)
for rel in "${config_files[@]}"; do
  install_config_if_missing "$rel"
done

# Preserve existing Git policy while filling in only the new opinionated
# defaults that are currently unset.
if command -v git >/dev/null 2>&1; then
  set_git_default() { # set_git_default <key> <value>
    git config --global --get "$1" >/dev/null 2>&1 || git config --global -- "$1" "$2"
  }

  set_git_default diff.algorithm histogram
  set_git_default diff.colorMoved plain
  set_git_default diff.mnemonicPrefix true
  set_git_default commit.verbose true
  set_git_default column.ui auto
  set_git_default column.status never
  set_git_default branch.sort -committerdate
  set_git_default tag.sort -version:refname
  set_git_default rerere.enabled true
  set_git_default rerere.autoupdate true
  set_git_default alias.br branch
  set_git_default alias.ci commit
fi

# Merge the shipped tool suite into the live global manifest. `mise use` keeps
# unrelated user tools instead of replacing ~/.config/mise/config.toml.
if command -v mise >/dev/null 2>&1; then
  tools=(
    bat@latest
    claude@latest
    codex@latest
    eza@latest
    fastfetch@latest
    fd@latest
    fzf@latest
    gh@latest
    github:can1357/oh-my-pi@latest
    github:kunchenguid/no-mistakes@latest
    go@latest
    gum@latest
    herdr@latest
    jq@latest
    lazygit@latest
    neovim@latest
    node@lts
    npm:stepstone@latest
    opencode@latest
    pi@latest
    python@latest
    ripgrep@latest
    starship@latest
    tmux@latest
    zoxide@latest
  )
  if ! mise use --global "${tools[@]}"; then
    echo "Could not merge the shipped tool suite; the migration will retry next update." >&2
    exit 1
  fi
else
  echo "mise is required to adopt the shipped tool suite; the migration will retry next update." >&2
  exit 1
fi

# Replace only the exact shell defaults shipped before the modular shell setup.
# Any user-edited rc file is left untouched with a clear follow-up message.
old_bashrc=$(mktemp "${TMPDIR:-/tmp}/dots-old-bashrc.XXXXXX")
old_zshrc=$(mktemp "${TMPDIR:-/tmp}/dots-old-zshrc.XXXXXX")
trap 'rm -f "$old_bashrc" "$old_zshrc"' EXIT

cat >"$old_bashrc" <<'OLD_BASHRC'
# This file is yours. It is seeded from ~/dotfiles/default/bashrc at install
# (with a backup of any previous version) and never touched by `dots update`.
# `dots reinstall configs` resets it to the shipped default.

[ -f "$HOME/.config/dots/dots.conf" ] && . "$HOME/.config/dots/dots.conf"
. "${DOTS_PATH:-$HOME/dotfiles}/default/bash/env-bootstrap"

# Tool activation
command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"

# Aliases (BSD ls on macOS, GNU ls on Linux/WSL)
if [ "$(uname -s)" = "Darwin" ]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi
alias ll='ls -lah'
alias g='git'

# Prompt: directory in blue, $ in plain
PS1='\[\e[34m\]\W\[\e[0m\] \$ '
OLD_BASHRC

cat >"$old_zshrc" <<'OLD_ZSHRC'
# This file is yours. It is seeded from ~/dotfiles/default/zshrc at install
# (with a backup of any previous version) and never touched by `dots update`.
# `dots reinstall configs` resets it to the shipped default.

[ -f "$HOME/.config/dots/dots.conf" ] && . "$HOME/.config/dots/dots.conf"
. "${DOTS_PATH:-$HOME/dotfiles}/default/bash/env-bootstrap"

command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

if [ "$(uname -s)" = "Darwin" ]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi
alias ll='ls -lah'
alias g='git'
OLD_ZSHRC

shell_changed=""
for shell_name in bash zsh; do
  live="$HOME/.${shell_name}rc"
  old_var="old_${shell_name}rc"
  old=${!old_var}
  shipped="$DOTS_PATH/default/${shell_name}rc"

  if [[ -f $live && ! -L $live && -f $shipped ]] && cmp -s "$live" "$old"; then
    dots_file_replace "$shipped" "$live" backup
    shell_changed=1
    echo "Updated stock ~/.${shell_name}rc for modular shell defaults (backup at $DOTS_FILE_BACKUP)."
  elif [[ -f $live && ! -L $live && -f $shipped ]] && ! cmp -s "$live" "$shipped"; then
    echo "Left customized ~/.${shell_name}rc unchanged; compare it with $shipped" >&2
  fi
done

if [[ -n $shell_changed ]]; then
  restart_source=$(mktemp "${TMPDIR:-/tmp}/dots-restart-marker.XXXXXX")
  dots_file_replace "$restart_source" "$HOME/.local/state/dots/restart-shell-required" discard
  rm -f "$restart_source"
fi

# Re-render the selected theme so the newly installed templates and built-in
# integrations take effect immediately.
current_theme="$HOME/.local/state/dots/current/theme.name"
if [[ -f $current_theme ]]; then
  "$DOTS_PATH/bin/dots-theme-set" "$(<"$current_theme")"
fi
