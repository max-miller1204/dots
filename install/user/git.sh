# Sourced by dots-install: verify machine-local Git identity is in place.

if ! git config --global --get user.name >/dev/null 2>&1 ||
  ! git config --global --get user.email >/dev/null 2>&1; then
  echo "Git identity is not set. Configure it in your live user config:"
  echo '  git config --global user.name "Your Name"'
  echo '  git config --global user.email "you@example.com"'
fi
