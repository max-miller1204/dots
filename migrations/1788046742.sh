#!/usr/bin/env bash
# Adopt the portable Omarchy-derived defaults on existing dots installs without
# overwriting user-managed configs. Fresh installs already receive these files
# from config/ and default/.

set -euo pipefail

: "${DOTS_PATH:?DOTS_PATH must identify the active dots runtime}"
source "$DOTS_PATH/install/helpers/files.sh"

migration_failed=""

install_config_if_missing() { # install_config_if_missing <repo-relative-config-path>
  local rel=$1 src="$DOTS_PATH/config/$1" dest="$HOME/.config/$1"

  if [[ ! -f $src ]]; then
    echo "Missing shipped config required by migration: $src" >&2
    return 1
  fi
  [[ ! -e $dest && ! -L $dest ]] || return 0
  if ! dots_file_replace "$src" "$dest" discard; then
    return 1
  fi
  echo "Installed missing config: ~/.config/$rel"
}

# Add the defaults introduced by this migration only where the user has no
# file already. This historical inventory is intentionally fixed rather than
# enumerating the current release, which may contain later unrelated configs.
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
  nvim/stylua.toml
  opencode/opencode.jsonc
  opencode/tui.jsonc
  starship.toml
  tmux/tmux.conf
)
for rel in "${config_files[@]}"; do
  if ! install_config_if_missing "$rel"; then
    echo "Could not install missing config $rel; the migration will retry it next update." >&2
    migration_failed=1
  fi
done

# Preserve existing Git policy while filling in only the new opinionated
# defaults that are currently unset.
if command -v git >/dev/null 2>&1; then
  set_git_default() { # set_git_default <key> <value>
    local key=$1 value=$2

    git config --global --get "$key" >/dev/null 2>&1 && return 0
    if ! git config --global -- "$key" "$value"; then
      echo "Could not set Git default $key; the migration will retry it next update." >&2
      return 1
    fi
  }

  git_defaults=(
    diff.algorithm histogram
    diff.colorMoved plain
    diff.mnemonicPrefix true
    commit.verbose true
    column.ui auto
    column.status never
    branch.sort -committerdate
    tag.sort -version:refname
    rerere.enabled true
    rerere.autoupdate true
    alias.br branch
    alias.ci commit
  )
  for ((index = 0; index < ${#git_defaults[@]}; index += 2)); do
    set_git_default "${git_defaults[$index]}" "${git_defaults[$((index + 1))]}" || migration_failed=1
  done
else
  echo "git is required to adopt the shipped defaults; the migration will retry next update." >&2
  migration_failed=1
fi

# Merge the shipped tool suite into the live global manifest. `mise use` keeps
# unrelated user tools instead of replacing ~/.config/mise/config.toml.
if command -v mise >/dev/null 2>&1; then
  tools=(
    bat@latest
    claude@2
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
    npm:@playwright/cli@latest
    npm:stepstone@latest
    opencode@latest
    pi@latest
    python@latest
    ripgrep@latest
    starship@latest
    tmux@latest
    zoxide@latest
  )
  tool_merge_failed=""
  for tool in "${tools[@]}"; do
    if ! mise use --global "$tool"; then
      echo "Could not merge $tool; the migration will retry it next update." >&2
      migration_failed=1
    fi
  done
else
  echo "mise is required to adopt the shipped tool suite; the migration will retry next update." >&2
  migration_failed=1
fi

# Replace only the exact shell defaults shipped before the modular shell setup.
# Historical snapshots live as inspectable fixtures instead of executable
# heredocs. Any user-edited rc file is left untouched.
fixture_dir="$DOTS_PATH/migrations/fixtures/1788046742"
old_bashrc="$fixture_dir/bashrc.old"
old_zshrc="$fixture_dir/zshrc.old"
fixtures_valid=1
for fixture in "$old_bashrc" "$old_zshrc"; do
  if [[ -L $fixture || ! -f $fixture ]]; then
    echo "Missing or unsafe migration fixture: $fixture" >&2
    migration_failed=1
    fixtures_valid=""
  fi
done

shell_changed=""
if [[ -n $fixtures_valid ]]; then
  for shell_name in bash zsh; do
    live="$HOME/.${shell_name}rc"
    old_var="old_${shell_name}rc"
    old=${!old_var}
    shipped="$DOTS_PATH/default/${shell_name}rc"

    if [[ -f $live && ! -L $live ]] && cmp -s "$live" "$old"; then
      if [[ ! -f $shipped || -L $shipped ]]; then
        echo "Missing or unsafe shipped shell config: $shipped" >&2
        migration_failed=1
      elif dots_file_replace "$shipped" "$live" backup; then
        shell_changed=1
        echo "Updated stock ~/.${shell_name}rc for modular shell defaults (backup at $DOTS_FILE_BACKUP)."
      else
        echo "Could not update stock ~/.${shell_name}rc; the migration will retry it next update." >&2
        migration_failed=1
      fi
    elif [[ -f $live && ! -L $live && -f $shipped ]] && ! cmp -s "$live" "$shipped"; then
      echo "Left customized ~/.${shell_name}rc unchanged; compare it with $shipped" >&2
    fi
  done
fi

if [[ -n $shell_changed ]]; then
  restart_source=$(mktemp "${TMPDIR:-/tmp}/dots-restart-marker.XXXXXX") || migration_failed=1
  if [[ -n ${restart_source:-} ]]; then
    if ! dots_file_replace "$restart_source" "$HOME/.local/state/dots/restart-shell-required" discard; then
      migration_failed=1
    fi
    rm -f "$restart_source"
  fi
fi

# Re-render the selected theme so the newly installed templates and built-in
# integrations take effect immediately.
current_theme="$HOME/.local/state/dots/current/theme.name"
if [[ -f $current_theme ]] && ! "$DOTS_PATH/bin/dots-theme-set" "$(<"$current_theme")"; then
  echo "Could not re-render the current theme; the migration will retry it next update." >&2
  migration_failed=1
fi

if [[ -n $migration_failed ]]; then
  exit 1
fi
