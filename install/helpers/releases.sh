# Shared helpers for immutable, versioned dots release bundles.
# Callers must source install/helpers/files.sh first.

DOTS_RELEASE_HOME=${DOTS_RELEASE_HOME:-$HOME/.local/share/dots}
DOTS_RELEASES_DIR="$DOTS_RELEASE_HOME/releases"
DOTS_RELEASE_CURRENT="$DOTS_RELEASE_HOME/current"
DOTS_RELEASE_PREVIOUS="$DOTS_RELEASE_HOME/previous"
DOTS_RELEASE_POINTER_TRANSACTION="$DOTS_RELEASE_HOME/.pointer-transaction"
DOTS_RELEASE_BASE_URL=${DOTS_RELEASE_BASE_URL:-https://github.com/max-miller1204/dots/releases}
DOTS_RELEASE_MANIFEST_URL=${DOTS_RELEASE_MANIFEST_URL:-$DOTS_RELEASE_BASE_URL/latest/download/dots-release.txt}

_dots_release_path_file() {
  printf '%s\n' "$HOME/.config/dots/path"
}

_dots_release_source_file() {
  printf '%s\n' "$HOME/.config/dots/source-path"
}

dots_release_validate_version() {
  [[ $1 =~ ^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})$ ]]
}

dots_release_compare_versions() { # compare <left> <right>: 0 equal, 1 left newer, 2 left older
  local left=$1 right=$2
  local -a left_parts right_parts
  local index left_part right_part

  dots_release_validate_version "$left" && dots_release_validate_version "$right" || return 3
  IFS=. read -r -a left_parts <<<"$left"
  IFS=. read -r -a right_parts <<<"$right"
  for index in 0 1 2; do
    left_part=$((10#${left_parts[$index]}))
    right_part=$((10#${right_parts[$index]}))
    ((left_part > right_part)) && return 1
    ((left_part < right_part)) && return 2
  done
  return 0
}

dots_release_read_one_line() { # read_one_line <regular-file>
  local file=$1
  local -a lines=()

  [[ -f $file && ! -L $file ]] || return 1
  mapfile -t lines <"$file"
  ((${#lines[@]} == 1)) && [[ -n ${lines[0]} ]] || return 1
  printf '%s\n' "${lines[0]}"
}

dots_release_configured_path() {
  dots_release_read_one_line "$(_dots_release_path_file)"
}

dots_release_source_path() {
  dots_release_read_one_line "$(_dots_release_source_file)"
}

dots_release_is_stable_mode() {
  local configured
  configured=$(dots_release_configured_path 2>/dev/null) || return 1
  [[ $configured == "$DOTS_RELEASE_CURRENT" ]]
}

dots_release_lock_fd_valid() {
  local lock=${DOTS_UPDATE_LOCK:-$HOME/.local/state/dots/update.lock} lock_id fd_id

  [[ ${DOTS_UPDATE_LOCK_PID:-} == "$$" ]] || return 1
  { true >&9; } 2>/dev/null || return 1
  command -v flock >/dev/null 2>&1 || return 1
  dots_file_assert_safe_parents "$lock" "$HOME" >/dev/null 2>&1 || return 1
  if [[ $(uname -s) == "Darwin" ]]; then
    lock_id=$(stat -f '%d:%i' "$lock" 2>/dev/null) || return 1
    fd_id=$(perl -e 'open(my $fh, "<&=9") or exit 1; my @s = stat($fh); print "$s[0]:$s[1]"' 2>/dev/null) || return 1
  else
    lock_id=$(stat -Lc '%d:%i' "$lock" 2>/dev/null) || return 1
    fd_id=$(stat -Lc '%d:%i' /proc/self/fd/9 2>/dev/null) || return 1
  fi
  [[ $lock_id == "$fd_id" ]] || return 1
  flock -n 9
}

dots_release_write_path() { # write_path <path>
  local path=$1 source

  [[ -n $path && $path != *$'\n'* && $path != *:* ]] || {
    echo "Invalid dots path: $path" >&2
    return 1
  }
  source=$(mktemp "${TMPDIR:-/tmp}/dots-release-path.XXXXXX") || return 1
  printf '%s\n' "$path" >"$source"
  if ! dots_file_replace "$source" "$(_dots_release_path_file)" discard; then
    rm -f "$source"
    return 1
  fi
  rm -f "$source"
}

dots_release_write_source_path() { # write_source_path <checkout>
  local checkout=$1 source

  checkout=$(cd -- "$checkout" && pwd -P) || return 1
  [[ $checkout != *$'\n'* && $checkout != *:* ]] || {
    echo "Invalid dots source path: $checkout" >&2
    return 1
  }
  git -C "$checkout" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "Not a Git checkout: $checkout" >&2
    return 1
  }
  source=$(mktemp "${TMPDIR:-/tmp}/dots-source-path.XXXXXX") || return 1
  printf '%s\n' "$checkout" >"$source"
  if ! dots_file_replace "$source" "$(_dots_release_source_file)" discard; then
    rm -f "$source"
    return 1
  fi
  rm -f "$source"
}

dots_release_assert_store() {
  local marker="$DOTS_RELEASE_HOME/.dots-release-store" marker_source
  local -a occupants=() marker_lines=()

  dots_file_assert_safe_parents "$DOTS_RELEASES_DIR/release" "$HOME" || return 1
  for path in "$DOTS_RELEASE_HOME" "$DOTS_RELEASES_DIR"; do
    if [[ -L $path || ( -e $path && ! -d $path ) ]]; then
      echo "Refusing unsafe dots release directory: $path" >&2
      return 1
    fi
  done
  if [[ -f $marker && ! -L $marker ]]; then
    mapfile -t marker_lines <"$marker"
    if ((${#marker_lines[@]} != 1)) || [[ ${marker_lines[0]} != "dots-release-store-v1" ]]; then
      echo "Invalid dots release store marker: $marker" >&2
      return 1
    fi
  elif [[ -e $marker || -L $marker ]]; then
    echo "Refusing unsafe dots release store marker: $marker" >&2
    return 1
  else
    if [[ -d $DOTS_RELEASE_HOME ]]; then
      shopt -s nullglob dotglob
      occupants=("$DOTS_RELEASE_HOME"/*)
      shopt -u nullglob dotglob
      ((${#occupants[@]} == 0)) || {
        echo "Refusing unowned dots release store: $DOTS_RELEASE_HOME" >&2
        return 1
      }
    fi
    mkdir -p "$DOTS_RELEASE_HOME"
    marker_source=$(mktemp "${TMPDIR:-/tmp}/dots-release-store.XXXXXX") || return 1
    printf 'dots-release-store-v1\n' >"$marker_source"
    if ! dots_file_replace "$marker_source" "$marker" discard; then
      rm -f "$marker_source"
      return 1
    fi
    rm -f "$marker_source"
  fi
  mkdir -p "$DOTS_RELEASES_DIR"
  dots_file_assert_safe_parents "$DOTS_RELEASES_DIR/release" "$HOME"
}

_dots_release_pointer_version() {
  local pointer=$1 target version marker integrity prefix

  [[ $pointer == "$DOTS_RELEASE_CURRENT" || $pointer == "$DOTS_RELEASE_PREVIOUS" ]] || return 1
  [[ -L $pointer ]] || return 1
  target=$(readlink "$pointer") || return 1
  [[ $target =~ ^releases/((0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8}))$ ]] || return 1
  [[ -d "$DOTS_RELEASE_HOME/$target" && ! -L "$DOTS_RELEASE_HOME/$target" ]] || return 1
  version=${BASH_REMATCH[1]}
  marker=$(dots_release_read_one_line "$DOTS_RELEASE_HOME/$target/.dots-release") || return 1
  prefix="dots-release-v1:$version:"
  [[ $marker == "$prefix"* ]] || return 1
  integrity=${marker#"$prefix"}
  [[ $integrity =~ ^[0-9a-f]{64}$ ]] || return 1
  printf '%s\n' "$version"
}

dots_release_reconcile_pointers() {
  local transaction=$DOTS_RELEASE_POINTER_TRANSACTION current previous target
  local actual_current="-" actual_previous="-" desired_previous release_version
  local -a lines=()

  [[ -e $transaction || -L $transaction ]] || return 0
  [[ -f $transaction && ! -L $transaction ]] || {
    echo "Refusing unsafe dots release pointer transaction: $transaction" >&2
    return 1
  }
  mapfile -t lines <"$transaction"
  ((${#lines[@]} == 4)) && [[ ${lines[0]} == "dots-release-pointer-transaction-v1" &&
    ${lines[1]} == current=* && ${lines[2]} == previous=* && ${lines[3]} == target=* ]] || {
    echo "Invalid dots release pointer transaction: $transaction" >&2
    return 1
  }
  current=${lines[1]#current=}
  previous=${lines[2]#previous=}
  target=${lines[3]#target=}
  [[ $current == "-" ]] || dots_release_validate_version "$current" || return 1
  [[ $previous == "-" ]] || dots_release_validate_version "$previous" || return 1
  dots_release_validate_version "$target" || return 1
  for release_version in "$current" "$previous" "$target"; do
    [[ $release_version == "-" ]] && continue
    dots_release_verify_installed "$DOTS_RELEASES_DIR/$release_version" "$release_version" || return 1
  done

  actual_current=$(_dots_release_pointer_version "$DOTS_RELEASE_CURRENT" 2>/dev/null) || {
    [[ ! -e $DOTS_RELEASE_CURRENT && ! -L $DOTS_RELEASE_CURRENT ]] || return 1
    actual_current="-"
  }
  actual_previous=$(_dots_release_pointer_version "$DOTS_RELEASE_PREVIOUS" 2>/dev/null) || {
    [[ ! -e $DOTS_RELEASE_PREVIOUS && ! -L $DOTS_RELEASE_PREVIOUS ]] || return 1
    actual_previous="-"
  }

  desired_previous=$current
  [[ $desired_previous != "-" ]] || desired_previous=$previous
  if [[ $actual_current == "$target" && $actual_previous == "$desired_previous" ]]; then
    dots_release_write_path "$DOTS_RELEASE_CURRENT" || return 1
  else
    if [[ $current == "-" ]]; then
      dots_file_remove "$DOTS_RELEASE_CURRENT" discard "$DOTS_RELEASE_HOME" || return 1
    else
      dots_release_atomic_pointer "$DOTS_RELEASE_CURRENT" "$current" || return 1
    fi
    if [[ $previous == "-" ]]; then
      dots_file_remove "$DOTS_RELEASE_PREVIOUS" discard "$DOTS_RELEASE_HOME" || return 1
    else
      dots_release_atomic_pointer "$DOTS_RELEASE_PREVIOUS" "$previous" || return 1
    fi
  fi
  dots_file_remove "$transaction" discard "$DOTS_RELEASE_HOME"
}

dots_release_pointer_version() { # pointer_version <current|previous>
  dots_release_reconcile_pointers || return 1
  _dots_release_pointer_version "$1"
}

dots_release_atomic_pointer() { # atomic_pointer <current|previous> <version>
  local pointer=$1 version=$2 temp_dir temp

  dots_release_validate_version "$version" || return 1
  dots_release_assert_store || return 1
  if [[ -e $pointer || -L $pointer ]] && ! _dots_release_pointer_version "$pointer" >/dev/null 2>&1; then
    echo "Refusing unsafe dots release pointer: $pointer" >&2
    return 1
  fi
  temp_dir=$(mktemp -d "$DOTS_RELEASE_HOME/.pointer.XXXXXX") || return 1
  temp="$temp_dir/link"
  ln -s "releases/$version" "$temp" || {
    rmdir "$temp_dir"
    return 1
  }
  if [[ $(uname -s) == "Darwin" ]]; then
    mv -fh "$temp" "$pointer" || {
      rm -f "$temp"
      rmdir "$temp_dir"
      return 1
    }
  else
    mv -fT "$temp" "$pointer" || {
      rm -f "$temp"
      rmdir "$temp_dir"
      return 1
    }
  fi
  rmdir "$temp_dir"
}

dots_release_activate() { # activate <version>
  local version=$1 current="-" previous="-" transaction_source

  dots_release_validate_version "$version" || {
    echo "Invalid dots release version: $version" >&2
    return 1
  }
  [[ -d "$DOTS_RELEASES_DIR/$version" && ! -L "$DOTS_RELEASES_DIR/$version" ]] || {
    echo "Dots release is not installed safely: $version" >&2
    return 1
  }
  dots_release_verify_installed "$DOTS_RELEASES_DIR/$version" "$version" || return 1
  dots_release_reconcile_pointers || return 1
  current=$(_dots_release_pointer_version "$DOTS_RELEASE_CURRENT" 2>/dev/null) || current="-"
  previous=$(_dots_release_pointer_version "$DOTS_RELEASE_PREVIOUS" 2>/dev/null) || previous="-"
  if [[ $current == "$version" ]]; then
    dots_release_write_path "$DOTS_RELEASE_CURRENT"
    return
  fi
  transaction_source=$(mktemp "${TMPDIR:-/tmp}/dots-pointer-transaction.XXXXXX") || return 1
  printf 'dots-release-pointer-transaction-v1\ncurrent=%s\nprevious=%s\ntarget=%s\n' \
    "$current" "$previous" "$version" >"$transaction_source"
  if ! dots_file_replace "$transaction_source" "$DOTS_RELEASE_POINTER_TRANSACTION" discard "$DOTS_RELEASE_HOME"; then
    rm -f "$transaction_source"
    return 1
  fi
  rm -f "$transaction_source"
  if [[ $current != "-" ]]; then
    dots_release_atomic_pointer "$DOTS_RELEASE_PREVIOUS" "$current" || return 1
  fi
  if [[ ${DOTS_RELEASE_TEST_PAUSE_AT:-} == "after-previous" ]]; then kill -STOP "$$"; fi
  [[ ${DOTS_RELEASE_TEST_FAIL_AT:-} != "after-previous" ]] || return 86
  if [[ ${DOTS_RELEASE_TEST_CRASH_AT:-} == "after-previous" ]]; then kill -KILL "$$"; fi
  dots_release_atomic_pointer "$DOTS_RELEASE_CURRENT" "$version" || return 1
  [[ ${DOTS_RELEASE_TEST_FAIL_AT:-} != "after-current" ]] || return 86
  if [[ ${DOTS_RELEASE_TEST_CRASH_AT:-} == "after-current" ]]; then kill -KILL "$$"; fi
  dots_release_write_path "$DOTS_RELEASE_CURRENT" || return 1
  dots_file_remove "$DOTS_RELEASE_POINTER_TRANSACTION" discard "$DOTS_RELEASE_HOME"
}

dots_release_sha256() { # sha256 <file>
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    shasum -a 256 "$1" | awk '{ print $1 }'
  fi
}

dots_release_validate_tree() { # validate_tree <release-dir> <version>
  local release_dir=$1 version=$2 file listed_version symlinks
  local -a required=(bin config default install migrations themes)

  [[ -d $release_dir && ! -L $release_dir ]] || return 1
  symlinks=$(find "$release_dir" -type l -print) || return 1
  if [[ -n $symlinks ]]; then
    echo "Release contains symlinks: $version" >&2
    return 1
  fi
  for file in "${required[@]}"; do
    [[ -d "$release_dir/$file" ]] || {
      echo "Release $version is missing $file/" >&2
      return 1
    }
  done
  listed_version=$(dots_release_read_one_line "$release_dir/version") || {
    echo "Release $version has an invalid version file." >&2
    return 1
  }
  [[ $listed_version == "$version" ]] || {
    echo "Release version mismatch: expected $version, found $listed_version" >&2
    return 1
  }
  [[ -x "$release_dir/bin/dots" && -x "$release_dir/bin/dots-update" ]] || {
    echo "Release $version is missing executable commands." >&2
    return 1
  }
}

dots_release_build_inventory() { # build_inventory <release-dir> <output>
  local release_dir=$1 output=$2 entry relative digest special

  special=$(find "$release_dir" ! -type d ! -type f -print) || return 1
  [[ -z $special ]] || {
    echo "Release contains links or special entries." >&2
    return 1
  }
  : >"$output"
  while IFS= read -r -d '' entry; do
    [[ $entry == "$release_dir" ]] && continue
    relative=${entry#"$release_dir"/}
    [[ $relative != *$'\n'* ]] || {
      echo "Release contains a newline-bearing path: $relative" >&2
      return 1
    }
    printf 'D  %s\n' "$relative" >>"$output"
  done < <(find "$release_dir" -type d -print0)
  while IFS= read -r -d '' entry; do
    relative=${entry#"$release_dir"/}
    [[ $relative == ".dots-release" || $relative == ".dots-release-integrity" ]] && continue
    [[ $relative != *$'\n'* ]] || {
      echo "Release contains a newline-bearing path: $relative" >&2
      return 1
    }
    digest=$(dots_release_sha256 "$entry") || return 1
    printf 'F %s  %s\n' "$digest" "$relative" >>"$output"
  done < <(find "$release_dir" -type f -print0)
  LC_ALL=C sort -o "$output" "$output"
}

dots_release_write_integrity() { # write_integrity <release-dir> <version>
  local release_dir=$1 version=$2
  local manifest="$release_dir/.dots-release-integrity" manifest_sha

  dots_release_build_inventory "$release_dir" "$manifest" || return 1
  manifest_sha=$(dots_release_sha256 "$manifest") || return 1
  printf 'dots-release-v1:%s:%s\n' "$version" "$manifest_sha" >"$release_dir/.dots-release"
}

dots_release_verify_installed() { # verify_installed <release-dir> <version>
  local release_dir=$1 version=$2 marker manifest manifest_sha expected_sha prefix
  local actual_inventory writable

  [[ -d $release_dir && ! -L $release_dir ]] || return 1
  dots_release_validate_tree "$release_dir" "$version" || return 1
  marker=$(dots_release_read_one_line "$release_dir/.dots-release" 2>/dev/null) || marker=""
  prefix="dots-release-v1:$version:"
  if [[ $marker != "$prefix"* ]]; then
    echo "Dots release has an invalid ownership marker: $version" >&2
    return 1
  fi
  expected_sha=${marker#"$prefix"}
  [[ $expected_sha =~ ^[0-9a-f]{64}$ ]] || {
    echo "Dots release has an invalid ownership marker: $version" >&2
    return 1
  }
  manifest="$release_dir/.dots-release-integrity"
  [[ -f $manifest && ! -L $manifest ]] || {
    echo "Dots release has no integrity manifest: $version" >&2
    return 1
  }
  manifest_sha=$(dots_release_sha256 "$manifest") || return 1
  [[ $manifest_sha == "$expected_sha" ]] || {
    echo "Dots release integrity manifest was modified: $version" >&2
    return 1
  }
  actual_inventory=$(mktemp "${TMPDIR:-/tmp}/dots-release-inventory.XXXXXX") || return 1
  if ! dots_release_build_inventory "$release_dir" "$actual_inventory" || ! cmp -s "$manifest" "$actual_inventory"; then
    rm -f "$actual_inventory"
    echo "Dots release contents were modified: $version" >&2
    return 1
  fi
  rm -f "$actual_inventory"
  writable=$(find "$release_dir" -perm -200 -print) || return 1
  [[ -z $writable ]] || {
    echo "Dots release contains writable entries: $version" >&2
    return 1
  }
}

dots_release_install_archive() { # install_archive <version> <archive> <sha256>
  local version=$1 archive=$2 expected_sha=$3 actual_sha stage extracted ready final marker
  local entry verbose_listing listing_line entry_type

  dots_release_validate_version "$version" || {
    echo "Invalid dots release version: $version" >&2
    return 1
  }
  [[ $expected_sha =~ ^[0-9a-fA-F]{64}$ ]] || {
    echo "Invalid SHA-256 for dots $version" >&2
    return 1
  }
  [[ -f $archive && ! -L $archive ]] || {
    echo "Release archive is not a regular file: $archive" >&2
    return 1
  }
  actual_sha=$(dots_release_sha256 "$archive") || return 1
  [[ ${actual_sha,,} == ${expected_sha,,} ]] || {
    echo "Checksum verification failed for dots $version" >&2
    return 1
  }

  dots_release_assert_store || return 1
  final="$DOTS_RELEASES_DIR/$version"
  if [[ -d $final && ! -L $final && -f $final/.dots-release ]]; then
    dots_release_verify_installed "$final" "$version"
    return
  fi
  [[ ! -e $final && ! -L $final ]] || {
    echo "Refusing unowned dots release path: $final" >&2
    return 1
  }

  if ! verbose_listing=$(tar -tvzf "$archive"); then
    echo "Cannot read dots release archive: $archive" >&2
    return 1
  fi
  while IFS= read -r listing_line; do
    [[ -n $listing_line ]] || continue
    entry_type=${listing_line:0:1}
    if [[ $entry_type != "-" && $entry_type != "d" ]]; then
      echo "Release archive contains a link or special entry." >&2
      return 1
    fi
  done <<<"$verbose_listing"
  while IFS= read -r entry; do
    [[ -n $entry ]] || continue
    if [[ $entry == /* || $entry == ".." || $entry == ../* || $entry == */../* || $entry == */.. ||
          $entry != "dots-$version" && $entry != "dots-$version/"* ]]; then
      echo "Unsafe path in dots release archive: $entry" >&2
      return 1
    fi
  done < <(tar -tzf "$archive")

  stage=$(mktemp -d "$DOTS_RELEASES_DIR/.staging-$version.XXXXXX") || return 1
  if ! tar -xzf "$archive" -C "$stage"; then
    rm -rf "$stage"
    return 1
  fi
  extracted="$stage/dots-$version"
  if ! dots_release_validate_tree "$extracted" "$version"; then
    rm -rf "$stage"
    return 1
  fi
  marker="$extracted/.dots-release"
  if ! dots_release_write_integrity "$extracted" "$version"; then
    rm -rf "$stage"
    return 1
  fi
  ready=$(mktemp -d "$DOTS_RELEASES_DIR/.ready-$version.XXXXXX") || {
    rm -rf "$stage"
    return 1
  }
  if ! rmdir "$ready"; then
    rm -rf "$ready" "$stage"
    return 1
  fi
  if ! mv "$extracted" "$ready" || ! rmdir "$stage"; then
    chmod -R u+w "$ready" "$stage" 2>/dev/null || true
    rm -rf "$ready" "$stage"
    return 1
  fi
  if ! chmod -R a-w "$ready"; then
    chmod -R u+w "$ready" 2>/dev/null || true
    rm -rf "$ready"
    return 1
  fi
  if [[ ${DOTS_RELEASE_TEST_CRASH_AT:-} == "after-release-ready" ]]; then kill -KILL "$$"; fi
  # BSD mv refuses to move a non-writable directory across parents. The
  # immutable ready tree is now a sibling of its final path, so this is one
  # same-parent atomic rename with no writable final-path window.
  if ! mv "$ready" "$final"; then
    chmod -R u+w "$ready" 2>/dev/null || true
    rm -rf "$ready"
    return 1
  fi
}

dots_release_parse_manifest() { # parse_manifest <file>; sets DOTS_LATEST_*
  local file=$1 line key value
  local header=""

  DOTS_LATEST_VERSION=""
  DOTS_LATEST_ARCHIVE=""
  DOTS_LATEST_SHA256=""
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ -z $header ]]; then
      [[ $line == "dots-release-v1" ]] || return 1
      header=1
      continue
    fi
    [[ $line == *=* ]] || return 1
    key=${line%%=*}
    value=${line#*=}
    case "$key" in
      version) DOTS_LATEST_VERSION=$value ;;
      archive) DOTS_LATEST_ARCHIVE=$value ;;
      sha256) DOTS_LATEST_SHA256=$value ;;
      *) return 1 ;;
    esac
  done <"$file"
  dots_release_validate_version "$DOTS_LATEST_VERSION" || return 1
  [[ $DOTS_LATEST_ARCHIVE == "dots-$DOTS_LATEST_VERSION.tar.gz" ]] || return 1
  [[ $DOTS_LATEST_SHA256 =~ ^[0-9a-fA-F]{64}$ ]]
}

dots_release_fetch_latest_manifest() {
  local manifest

  command -v curl >/dev/null 2>&1 || {
    echo "curl is required to check dots releases." >&2
    return 1
  }
  manifest=$(mktemp "${TMPDIR:-/tmp}/dots-release-manifest.XXXXXX") || return 1
  if ! curl -fsSL --connect-timeout 10 --max-time 60 --retry 2 "$DOTS_RELEASE_MANIFEST_URL" -o "$manifest"; then
    rm -f "$manifest"
    return 1
  fi
  if ! dots_release_parse_manifest "$manifest"; then
    echo "Invalid dots release manifest." >&2
    rm -f "$manifest"
    return 1
  fi
  rm -f "$manifest"
}

dots_release_download() { # download <version> <archive-name> <sha256>; sets DOTS_DOWNLOADED_*
  local version=$1 archive_name=$2 sha256=$3 archive url

  dots_release_validate_version "$version" || return 1
  [[ $archive_name == "dots-$version.tar.gz" ]] || return 1
  [[ $sha256 =~ ^[0-9a-fA-F]{64}$ ]] || return 1
  archive=$(mktemp "${TMPDIR:-/tmp}/dots-$version.tar.gz.XXXXXX") || return 1
  url="$DOTS_RELEASE_BASE_URL/download/v$version/$archive_name"
  if ! curl -fsSL --connect-timeout 10 --max-time 600 --retry 2 "$url" -o "$archive"; then
    rm -f "$archive"
    return 1
  fi
  DOTS_DOWNLOADED_VERSION=$version
  DOTS_DOWNLOADED_ARCHIVE=$archive
  DOTS_DOWNLOADED_SHA256=$sha256
}

dots_release_download_latest() {
  dots_release_fetch_latest_manifest || return 1
  dots_release_download "$DOTS_LATEST_VERSION" "$DOTS_LATEST_ARCHIVE" "$DOTS_LATEST_SHA256"
}

dots_release_install_downloaded() { # install_downloaded; activates DOTS_DOWNLOADED_*
  if ! dots_release_install_archive "$DOTS_DOWNLOADED_VERSION" "$DOTS_DOWNLOADED_ARCHIVE" "$DOTS_DOWNLOADED_SHA256"; then
    rm -f "$DOTS_DOWNLOADED_ARCHIVE"
    return 1
  fi
  rm -f "$DOTS_DOWNLOADED_ARCHIVE"
  dots_release_activate "$DOTS_DOWNLOADED_VERSION"
}

dots_release_install_latest() { # install_latest; sets DOTS_RELEASE_CHANGED
  local current="" compare_rc=0

  DOTS_RELEASE_CHANGED=""
  dots_release_fetch_latest_manifest || return 1
  current=$(dots_release_pointer_version "$DOTS_RELEASE_CURRENT" 2>/dev/null) || true
  if [[ -n $current ]]; then
    dots_release_verify_installed "$DOTS_RELEASES_DIR/$current" "$current" || return 1
    dots_release_compare_versions "$DOTS_LATEST_VERSION" "$current" || compare_rc=$?
    if ((compare_rc == 2)); then
      echo "Installed dots $current is newer than published $DOTS_LATEST_VERSION; keeping it."
      dots_release_write_path "$DOTS_RELEASE_CURRENT"
      return 0
    fi
    if ((compare_rc == 0)); then
      dots_release_write_path "$DOTS_RELEASE_CURRENT"
      return 0
    fi
  fi
  dots_release_download "$DOTS_LATEST_VERSION" "$DOTS_LATEST_ARCHIVE" "$DOTS_LATEST_SHA256" || return 1
  dots_release_install_downloaded || return 1
  DOTS_RELEASE_CHANGED=1
}
