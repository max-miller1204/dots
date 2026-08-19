# Sourced by test suites. Expects $ROOT to point at the repo checkout.
# Shared assertions plus sandbox setup, so suites never touch the real $HOME
# (the role of omarchy's test/shell.d/base-test.sh).

assertions=0

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() { # assert_contains <haystack> <needle> <label>
  case "$1" in
    *"$2"*) assertions=$((assertions + 1)) ;;
    *) fail "$3: expected to find '$2' in output:
$1" ;;
  esac
}

setup_sandbox() { # isolate $HOME; call once per suite
  SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/dots-test.XXXXXX")
  trap 'rm -rf "$SANDBOX"' EXIT
  export HOME="$SANDBOX"
  export DOTS_PATH="$ROOT"
  export PATH="$ROOT/bin:$PATH"
  # Ambient config must not reach the suites: pipeline knobs exported in the
  # developer's shell, and host git config via the non-HOME lookup paths.
  unset DOTS_UPDATE_FORCE DOTS_UPDATE_MIN_FREE_KB DOTS_UPDATE_LOCK XDG_CONFIG_HOME
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
}
