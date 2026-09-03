#!/usr/bin/env bash

# Add the upstream bash-completion release to existing mise manifests.

set -euo pipefail

source "$DOTS_PATH/install/helpers/files.sh"

if ! "$DOTS_PATH/bin/dots-pkg-add" github:scop/bash-completion@latest; then
  echo "Could not add Bash completion. The migration will retry during the next update." >&2
  exit 1
fi

restart_source=$(mktemp "${TMPDIR:-/tmp}/dots-restart-marker.XXXXXX")
trap 'rm -f "$restart_source"' EXIT
dots_file_replace "$restart_source" "$HOME/.local/state/dots/restart-shell-required" discard
