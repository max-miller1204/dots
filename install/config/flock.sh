# Sourced before release-store mutations and again during platform setup.

if command -v flock >/dev/null 2>&1; then
  return 0 2>/dev/null || exit 0
fi

if [[ $(uname -s) == "Darwin" ]]; then
  if command -v brew >/dev/null 2>&1; then
    brew install flock
  else
    echo "flock(1) is required. Install Homebrew, then run: brew install flock" >&2
    return 1 2>/dev/null || exit 1
  fi
else
  echo "flock(1) is required. Install your distribution's util-linux package." >&2
  return 1 2>/dev/null || exit 1
fi
