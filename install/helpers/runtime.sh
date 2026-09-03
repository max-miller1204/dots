# Shared active-runtime resolution and stale-command delegation.
# Source this once near the top of a command under bin/.

_dots_runtime_command=${BASH_SOURCE[1]}
_dots_runtime_error_status=${DOTS_RUNTIME_ERROR_STATUS:-1}
if ! SELF_DIR=$(cd -- "$(dirname -- "$_dots_runtime_command")" && pwd); then
  exit "$_dots_runtime_error_status"
fi
DOTS_PATH=$("$SELF_DIR/dots-path-resolve") || exit "$_dots_runtime_error_status"
DOTS_PATH=$(cd -- "$DOTS_PATH" && pwd) || exit "$_dots_runtime_error_status"
export DOTS_PATH
if [[ $SELF_DIR != "$DOTS_PATH/bin" ]]; then
  exec "$DOTS_PATH/bin/${_dots_runtime_command##*/}" "$@"
fi
unset _dots_runtime_command _dots_runtime_error_status DOTS_RUNTIME_ERROR_STATUS
