# Sourced by dots-install: mirror all install output into a log file.

DOTS_LOG_FILE="$HOME/.local/state/dots/install.log"
dots_file_assert_safe_parents "$DOTS_LOG_FILE" "$HOME"
mkdir -p "${DOTS_LOG_FILE%/*}"
dots_file_assert_safe_parents "$DOTS_LOG_FILE" "$HOME"
if [[ -L $DOTS_LOG_FILE || ( -e $DOTS_LOG_FILE && ! -f $DOTS_LOG_FILE ) ]]; then
  echo "Refusing unsafe install log path: $DOTS_LOG_FILE" >&2
  return 1
fi

exec > >(tee -a "$DOTS_LOG_FILE") 2>&1

echo
echo "=== dots install run: $(date) ==="
