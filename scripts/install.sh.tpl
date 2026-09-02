#!/usr/bin/env bash

# Install one immutable dots release directly from GitHub.
# This bootstrap intentionally stays compatible with macOS's system Bash 3.2;
# the packaged installer establishes the modern command runtime it needs.

main() {
  set -eo pipefail

  local release_version='@DOTS_RELEASE_VERSION@'
  local archive_name='@DOTS_RELEASE_ARCHIVE@'
  local expected_sha='@DOTS_RELEASE_SHA256@'
  local release_base_url=${DOTS_RELEASE_BASE_URL:-https://github.com/max-miller1204/dots/releases}
  local archive_url=${DOTS_RELEASE_ARCHIVE_URL:-$release_base_url/download/v$release_version/$archive_name}
  local required_command temporary_dir archive actual_sha verbose_listing
  local listing_line entry_type archive_listing archive_root entry payload required_path

  if (($#)); then
    echo "Usage: install.sh" >&2
    exit 1
  fi
  for required_command in curl tar; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
      echo "$required_command is required to install dots." >&2
      exit 1
    fi
  done
  if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    echo "sha256sum or shasum is required to install dots." >&2
    exit 1
  fi

  temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/dots-bootstrap.XXXXXX")
  cleanup() {
    chmod -R u+w "$temporary_dir" 2>/dev/null || true
    rm -rf "$temporary_dir"
  }
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  archive="$temporary_dir/$archive_name"

  printf 'Downloading dots %s...\n' "$release_version"
  curl -fsSL --connect-timeout 10 --max-time 600 --retry 2 "$archive_url" -o "$archive"
  if command -v sha256sum >/dev/null 2>&1; then
    actual_sha=$(sha256sum "$archive" | awk '{ print $1 }')
  else
    actual_sha=$(shasum -a 256 "$archive" | awk '{ print $1 }')
  fi
  actual_sha=$(printf '%s' "$actual_sha" | tr '[:upper:]' '[:lower:]')
  if [[ $actual_sha != "$expected_sha" ]]; then
    echo "Checksum verification failed for dots $release_version." >&2
    exit 1
  fi

  verbose_listing=$(tar -tvzf "$archive") || {
    echo "Cannot read the dots release archive." >&2
    exit 1
  }
  while IFS= read -r listing_line; do
    [[ -n $listing_line ]] || continue
    entry_type=${listing_line:0:1}
    if [[ $entry_type != "-" && $entry_type != "d" ]]; then
      echo "The dots release archive contains a link or special entry." >&2
      exit 1
    fi
  done <<LISTING
$verbose_listing
LISTING

  archive_listing=$(tar -tzf "$archive") || {
    echo "Cannot list the dots release archive." >&2
    exit 1
  }
  archive_root="dots-$release_version"
  while IFS= read -r entry; do
    [[ -n $entry ]] || continue
    case "$entry" in
      "$archive_root" | "$archive_root/"*) ;;
      *)
        echo "Unsafe path in dots release archive: $entry" >&2
        exit 1
        ;;
    esac
    case "/$entry/" in
      */../*)
        echo "Unsafe path in dots release archive: $entry" >&2
        exit 1
        ;;
    esac
  done <<LISTING
$archive_listing
LISTING

  tar -xzf "$archive" -C "$temporary_dir"
  payload="$temporary_dir/$archive_root"
  for required_path in bin config default install migrations themes version; do
    [[ -e $payload/$required_path ]] || {
      echo "The dots release is missing $required_path." >&2
      exit 1
    }
  done
  [[ -x $payload/bin/dots-install ]] || {
    echo "The dots release installer is not executable." >&2
    exit 1
  }
  [[ $(<"$payload/version") == "$release_version" ]] || {
    echo "The dots release version does not match its installer." >&2
    exit 1
  }

  "$payload/bin/dots-install" --bootstrap-release \
    "$release_version" "$archive" "$expected_sha"
  cleanup
  trap - EXIT INT TERM
}

main "$@"
