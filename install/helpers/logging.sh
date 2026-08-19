# Sourced by dots-install: mirror all install output into a log file.

DOTS_LOG_FILE="$HOME/.local/state/dots/install.log"
mkdir -p "$(dirname "$DOTS_LOG_FILE")"

exec > >(tee -a "$DOTS_LOG_FILE") 2>&1

echo
echo "=== dots install run: $(date) ==="
