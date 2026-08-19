# Sourced by dots-install: verify git identity is in place.

if ! git config --get user.email >/dev/null 2>&1; then
  echo "Git identity is not set. Edit config/git/config, then run:"
  echo "  dots refresh config git/config"
fi
