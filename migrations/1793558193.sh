#!/usr/bin/env bash

# Repoint GitHub credential helpers that `gh auth setup-git` pinned to one
# mise install path. Those paths break when mise upgrades gh, so use the shim.

set -euo pipefail

git_config="$HOME/.config/git/config"
shim_helper='!"$HOME/.local/share/mise/shims/gh" auth git-credential'

[[ -f $git_config && ! -L $git_config ]] || exit 0

if ! command -v git >/dev/null 2>&1; then
  echo "git is required to repair GitHub credential helpers; the migration will retry next update." >&2
  exit 1
fi

for host in github.com gist.github.com; do
  key="credential.https://$host.helper"
  pinned=0
  while IFS= read -r helper; do
    [[ $helper == *"/mise/installs/gh/"*"/gh auth git-credential" ]] && pinned=1
  done < <(git config --file "$git_config" --get-all "$key" 2>/dev/null || true)
  ((pinned)) || continue

  git config --file "$git_config" --replace-all "$key" ""
  git config --file "$git_config" --add "$key" "$shim_helper"
  echo "Repointed the $host credential helper at the mise gh shim."
done
