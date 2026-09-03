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
  trap 'chmod -R u+w "$SANDBOX" 2>/dev/null || true; rm -rf "$SANDBOX"' EXIT
  export HOME="$SANDBOX"
  export DOTS_PATH="$ROOT"
  mkdir -p "$SANDBOX/stub"
  cat >"$SANDBOX/stub/tmux" <<'TMUX'
#!/usr/bin/env bash
exit 0
TMUX
  cat >"$SANDBOX/stub/brew" <<'BREW'
#!/usr/bin/env bash
echo "test attempted to invoke Homebrew" >&2
exit 125
BREW
  chmod +x "$SANDBOX/stub/tmux" "$SANDBOX/stub/brew"
  export PATH="$SANDBOX/stub:$ROOT/bin:$PATH"
  # Ambient config must not reach the suites: pipeline knobs exported in the
  # developer's shell, and host git config via the non-HOME lookup paths.
  unset DOTS_FILE_TEST_CRASH_AFTER_PAYLOAD \
    DOTS_FILE_TEST_CRASH_AFTER_PAYLOAD_PRECOMMIT \
    DOTS_FILE_TEST_CRASH_BEFORE_PUBLISH DOTS_RELEASE_BASE_URL \
    DOTS_RELEASE_HOME DOTS_RELEASE_MANIFEST_URL DOTS_RELEASE_TEST_CRASH_AT \
    DOTS_RELEASE_TEST_FAIL_AT DOTS_RELEASE_TEST_PAUSE_AT \
    DOTS_TEST_CURL_TRACE DOTS_TEST_FLOCK_TRACE DOTS_TEST_HOMEBREW_BIN \
    DOTS_TEST_REAL_CURL DOTS_TEST_REAL_FLOCK DOTS_TEST_REAL_SCRIPT \
    DOTS_THEME_TEST_CRASH_AT DOTS_THEME_TEST_CRASH_DURING_PRUNE \
    DOTS_THEME_TEST_PRECREATE_GENERATION DOTS_UPDATE_FORCE \
    DOTS_UPDATE_MIN_FREE_KB DOTS_UPDATE_LOCK DOTS_UPDATE_LOCK_PID \
    DOTS_UPDATE_SKIP_RELEASE_ONCE DOTS_UPDATE_TEST_CRASH_AFTER_NOTE \
    DOTS_UPDATE_TEST_FAIL_REEXEC DOTS_UPDATE_TEST_KILL_AFTER_SCRIPT \
    XDG_CONFIG_HOME
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
}
