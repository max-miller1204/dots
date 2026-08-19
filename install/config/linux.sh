# Sourced by dots-install: Linux (Ubuntu / WSL) system tweaks.

if [[ $(uname -s) != "Linux" ]]; then
  return 0 2>/dev/null || exit 0
fi

# Add your Ubuntu/WSL setup here. Anything needing sudo should prompt for it
# explicitly. Examples (commented out on purpose):
#
#   # Build essentials many mise backends want
#   sudo apt-get install -y build-essential
#
#   # WSL-only tweaks
#   if grep -qi microsoft /proc/version 2>/dev/null; then
#     : # e.g. wslutilities, /etc/wsl.conf settings
#   fi

echo "No Linux system tweaks applied (edit install/config/linux.sh to add your own)."
