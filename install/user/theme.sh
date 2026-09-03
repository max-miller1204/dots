# Sourced by dots-install: apply the default theme on first install only.

if [[ ! -e $HOME/.local/state/dots/current/theme ]]; then
  dots-theme-set tokyo-night
fi
