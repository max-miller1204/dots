#!/usr/bin/env bash
# The update lock now runs through flock(1). Ubuntu/WSL ship it in
# util-linux; existing macOS installs predate install/config/macos.sh
# learning to brew-install it, so heal them here during the update that
# pulls this in. Replicates that script's guarded flock block (sourcing it
# would re-run unrelated interactive steps mid-update).
[[ $(uname -s) == "Darwin" ]] || exit 0

if command -v flock >/dev/null 2>&1; then
  exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "flock(1) is required by dots update; install Homebrew, then run: brew install flock" >&2
  exit 1
fi

brew install flock
