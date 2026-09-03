# Shared helpers for installing repository-owned files without following a
# destination symlink. This file is sourced by commands and install scripts.

# Reject a destination whose existing parent path below an ownership root uses
# a symlink. Checking only the final component is insufficient: mkdir, mktemp,
# and mv would otherwise operate in the symlink target.
dots_file_assert_safe_parents() {
  local dest=$1 root=$2 relative parent current component

  if [[ $dest != "$root"/* ]]; then
    echo "Destination is outside its ownership root: $dest" >&2
    return 1
  fi

  relative=${dest#"$root"/}
  if [[ $relative == ".." || $relative == ../* || $relative == */../* || $relative == */.. ||
        $relative == "." || $relative == ./* || $relative == */./* || $relative == */. ]]; then
    echo "Destination contains unsafe path components: $dest" >&2
    return 1
  fi

  parent=${dest%/*}
  [[ -n $parent ]] || parent=/
  [[ $parent == "$root" ]] && return 0
  relative=${parent#"$root"/}
  current=$root
  while [[ -n $relative ]]; do
    if [[ $relative == */* ]]; then
      component=${relative%%/*}
      relative=${relative#*/}
    else
      component=$relative
      relative=""
    fi
    current="$current/$component"
    if [[ -L $current ]]; then
      echo "Refusing destination beneath symlinked directory: $current" >&2
      return 1
    fi
    if [[ -e $current && ! -d $current ]]; then
      echo "Destination parent is not a directory: $current" >&2
      return 1
    fi
  done
}

# Compare a pathname with an already-open descriptor without trusting a
# platform-specific /dev/fd inode representation. Both device and inode are
# required: inode numbers are unique only within one filesystem.
dots_file_path_matches_fd() { # dots_file_path_matches_fd <path> <fd-number>
  local path=$1 fd=$2 path_id fd_id

  [[ $fd =~ ^[0-9]+$ ]] || return 1
  if [[ $(uname -s) == "Darwin" ]]; then
    path_id=$(stat -f '%d:%i' "$path") || return 1
    fd_id=$(perl -e '
      my $fd = shift;
      open(my $fh, "<&=$fd") or exit 1;
      my @stat = stat($fh);
      print "$stat[0]:$stat[1]";
    ' "$fd") || return 1
  else
    path_id=$(stat -Lc '%d:%i' "$path") || return 1
    fd_id=$(stat -Lc '%d:%i' "/proc/self/fd/$fd") || return 1
  fi
  [[ $path_id == "$fd_id" ]]
}

# Safely create and open a lock file on the runtime's standard inherited fd.
# The caller still chooses blocking or nonblocking flock behavior.
dots_lock_open_fd9() { # dots_lock_open_fd9 <path> <label> [ownership-root]
  local path=$1 label=$2 root=${3:-$HOME} parent

  dots_file_assert_safe_parents "$path" "$root" || return 1
  parent=${path%/*}
  [[ -n $parent ]] || parent=/
  mkdir -p "$parent" || return 1
  dots_file_assert_safe_parents "$path" "$root" || return 1
  if [[ -L $path || ( -e $path && ! -f $path ) ]]; then
    echo "Refusing unsafe $label lock path: $path" >&2
    return 1
  fi

  exec 9>>"$path" || return 1
  if [[ -L $path || ! -f $path ]] || ! dots_file_path_matches_fd "$path" 9; then
    echo "$label lock path changed during open: $path" >&2
    exec 9>&-
    return 1
  fi
}

# Verify that fd 9 is the still-open, currently held lock represented by path.
# Re-taking flock on an inherited open file description succeeds without
# weakening the lock and distinguishes it from an unrelated writable fd.
dots_lock_fd9_valid() { # dots_lock_fd9_valid <path> [ownership-root]
  local path=$1 root=${2:-$HOME}

  { true >&9; } 2>/dev/null || return 1
  command -v flock >/dev/null 2>&1 || return 1
  dots_file_assert_safe_parents "$path" "$root" >/dev/null 2>&1 || return 1
  [[ ! -L $path && -f $path ]] || return 1
  dots_file_path_matches_fd "$path" 9 >/dev/null 2>&1 || return 1
  flock -n 9
}

# Enumerate shipped config files relative to their config root. Keep the
# NUL-delimited contract so names containing whitespace or newlines are safe.
dots_config_find_files() { # dots_config_find_files <config-root>
  local root=$1

  [[ -d $root && ! -L $root ]] || return 1
  (cd "$root" && find . -type f ! -name '.DS_Store' -print0)
}

dots_config_for_each_file() { # dots_config_for_each_file <config-root> <callback>
  local root=$1 callback=$2 file manifest rc=0

  manifest=$(mktemp "${TMPDIR:-/tmp}/dots-config-files.XXXXXX") || return 1
  if ! dots_config_find_files "$root" >"$manifest"; then
    rm -f "$manifest"
    return 1
  fi
  while IFS= read -r -d '' file; do
    "$callback" "$file" || {
      rc=$?
      break
    }
  done <"$manifest"
  rm -f "$manifest"
  return "$rc"
}

# Replace a destination with a regular file copied from src.
# Usage: dots_file_replace <src> <dest> <backup|discard> [ownership-root]
# The ownership root defaults to $HOME. Sets DOTS_FILE_CHANGED and
# DOTS_FILE_BACKUP for the caller.
dots_file_replace() {
  local src=$1 dest=$2 policy=$3 root=${4:-$HOME} parent temp backup_dir occupied="" publish_rc=0

  DOTS_FILE_CHANGED=""
  DOTS_FILE_BACKUP=""

  if [[ ! -f $src ]]; then
    echo "Source is not a file: $src" >&2
    return 1
  fi

  dots_file_assert_safe_parents "$dest" "$root" || return 1

  # A symlink to a directory is replaceable; an actual directory is not.
  if [[ -d $dest && ! -L $dest ]]; then
    echo "Refusing to replace directory: $dest" >&2
    return 1
  fi

  if [[ $policy != "backup" && $policy != "discard" ]]; then
    echo "Unknown file replacement policy: $policy" >&2
    return 1
  fi

  # Do not churn an already-owned regular file. In particular, never use cmp
  # on a symlink, since that would read through it.
  if [[ -f $dest && ! -L $dest ]] && cmp -s "$src" "$dest"; then
    return 0
  fi

  parent=${dest%/*}
  [[ -n $parent ]] || parent=/
  mkdir -p "$parent"
  # Recheck after creation so a pre-existing missing path cannot quietly resolve
  # through a parent link introduced before the temporary file is opened.
  dots_file_assert_safe_parents "$dest" "$root" || return 1

  # Prepare the new file beside its destination before moving the old entry.
  # Both BSD and GNU mktemp accept a template ending in at least six Xs.
  temp=$(mktemp "$dest.tmp.XXXXXX") || return 1
  if ! cp -p -f "$src" "$temp"; then
    rm -f "$temp"
    return 1
  fi

  if [[ -e $dest || -L $dest ]]; then
    occupied=1
    if [[ $policy == "backup" ]]; then
      # Copy the occupied entry into a unique backup before publication. The
      # live destination stays present until the atomic replacement commits.
      backup_dir=$(mktemp -d "$dest.bak.XXXXXX") || {
        rm -f "$temp"
        return 1
      }
      DOTS_FILE_BACKUP="$backup_dir/original"
      if [[ -L $dest ]]; then
        cp -Pp "$dest" "$DOTS_FILE_BACKUP" || publish_rc=$?
      else
        cp -p "$dest" "$DOTS_FILE_BACKUP" || publish_rc=$?
      fi
      if ((publish_rc != 0)); then
        rm -rf "$backup_dir"
        rm -f "$temp"
        DOTS_FILE_BACKUP=""
        return 1
      fi
    fi
  fi

  if [[ ${DOTS_FILE_TEST_CRASH_BEFORE_PUBLISH:-} == "1" ]]; then
    kill -KILL "$$"
  fi

  publish_rc=0
  if [[ -n $occupied ]]; then
    # Replace the final entry atomically without following a symlink to a
    # directory. The old file remains present until the rename commits.
    if [[ $(uname -s) == "Darwin" ]]; then
      mv -fh "$temp" "$dest" || publish_rc=$?
    else
      mv -fT "$temp" "$dest" || publish_rc=$?
    fi
  else
    mv -f "$temp" "$dest" || publish_rc=$?
  fi
  if ((publish_rc != 0)); then
    rm -f "$temp"
    if [[ -n $DOTS_FILE_BACKUP && ! -e $dest && ! -L $dest ]]; then
      mv "$DOTS_FILE_BACKUP" "$dest" 2>/dev/null || true
      rmdir "$(dirname "$DOTS_FILE_BACKUP")" 2>/dev/null || true
      DOTS_FILE_BACKUP=""
    fi
    return 1
  fi

  DOTS_FILE_CHANGED=1
}

# Remove an occupied non-directory path without following symlinks.
# Usage: dots_file_remove <dest> <backup|discard> [ownership-root]
# Sets DOTS_FILE_CHANGED and DOTS_FILE_BACKUP for the caller.
dots_file_remove() {
  local dest=$1 policy=$2 root=${3:-$HOME} backup_dir

  DOTS_FILE_CHANGED=""
  DOTS_FILE_BACKUP=""

  dots_file_assert_safe_parents "$dest" "$root" || return 1
  [[ -e $dest || -L $dest ]] || return 0
  if [[ -d $dest && ! -L $dest ]]; then
    echo "Refusing to remove directory: $dest" >&2
    return 1
  fi
  if [[ $policy != "backup" && $policy != "discard" ]]; then
    echo "Unknown file removal policy: $policy" >&2
    return 1
  fi

  if [[ $policy == "backup" ]]; then
    backup_dir=$(mktemp -d "$dest.bak.XXXXXX") || return 1
    DOTS_FILE_BACKUP="$backup_dir/original"
    if ! mv "$dest" "$DOTS_FILE_BACKUP"; then
      rmdir "$backup_dir" 2>/dev/null || true
      DOTS_FILE_BACKUP=""
      return 1
    fi
  else
    rm -f "$dest"
  fi

  DOTS_FILE_CHANGED=1
}

dots_file_sync_owned_payload() {
  local src=$1 dest=$2 marker=$3 label=$4 trusted_existing=${5:-}
  local precommit="$marker.precommit" marker_source precommit_source recovered_source owned=""
  local -a marker_lines=()

  dots_file_assert_safe_parents "$dest" "$HOME" || return 1
  dots_file_assert_safe_parents "$marker" "$HOME" || return 1
  dots_file_assert_safe_parents "$precommit" "$HOME" || return 1

  if [[ -L $dest || ( -e $dest && ! -f $dest ) ]]; then
    echo "Refusing unsafe $label payload: $dest" >&2
    return 1
  fi
  if [[ -L $marker || ( -e $marker && ! -f $marker ) ]]; then
    echo "Refusing unsafe $label ownership marker: $marker" >&2
    return 1
  fi
  if [[ -L $precommit || ( -e $precommit && ! -f $precommit ) ]]; then
    echo "Refusing unsafe $label ownership precommit: $precommit" >&2
    return 1
  fi

  if [[ -f $precommit ]]; then
    IFS= read -r precommit_header <"$precommit" || true
    if [[ $precommit_header != "dots-owned-theme-payload-precommit-v1" ]]; then
      echo "Refusing invalid $label ownership precommit: $precommit" >&2
      return 1
    fi
    recovered_source=$(mktemp "${TMPDIR:-/tmp}/dots-owned-recovery.XXXXXX") || return 1
    tail -n +2 "$precommit" >"$recovered_source"
  fi

  if [[ -f $marker ]]; then
    mapfile -t marker_lines <"$marker"
    if ((${#marker_lines[@]} != 1)) || [[ ${marker_lines[0]} != "dots-owned-theme-payload-v1" ]]; then
      echo "Refusing invalid $label ownership marker: $marker" >&2
      return 1
    fi
    owned=1
  fi

  if [[ -z $owned && -n ${recovered_source:-} && -f $dest ]] && cmp -s "$recovered_source" "$dest"; then
    marker_source=$(mktemp "${TMPDIR:-/tmp}/dots-owned-payload.XXXXXX") || {
      rm -f "$recovered_source"
      return 1
    }
    printf 'dots-owned-theme-payload-v1\n' >"$marker_source"
    if ! dots_file_replace "$marker_source" "$marker" discard; then
      rm -f "$marker_source" "$recovered_source"
      return 1
    fi
    rm -f "$marker_source"
    owned=1
  fi

  if [[ -n ${recovered_source:-} ]]; then
    rm -f "$recovered_source"
    recovered_source=""
    dots_file_remove "$precommit" discard || return 1
  fi

  if [[ -n $owned ]]; then
    dots_file_replace "$src" "$dest" discard || return 1
    return 0
  fi

  if [[ -f $dest && -z $owned ]] && ! cmp -s "$src" "$dest"; then
    if [[ -z $trusted_existing || -L $trusted_existing || ! -f $trusted_existing ]] ||
      ! cmp -s "$trusted_existing" "$dest"; then
      echo "Refusing unowned $label payload: $dest" >&2
      return 1
    fi
  fi

  precommit_source=$(mktemp "${TMPDIR:-/tmp}/dots-owned-precommit.XXXXXX") || return 1
  {
    printf 'dots-owned-theme-payload-precommit-v1\n'
    cat "$src"
  } >"$precommit_source"
  if ! dots_file_replace "$precommit_source" "$precommit" discard; then
    rm -f "$precommit_source"
    return 1
  fi
  rm -f "$precommit_source"

  if [[ ${DOTS_FILE_TEST_CRASH_AFTER_PAYLOAD_PRECOMMIT:-} == "1" ]]; then
    kill -KILL "$$"
  fi

  dots_file_replace "$src" "$dest" discard || return 1

  if [[ ${DOTS_FILE_TEST_CRASH_AFTER_PAYLOAD:-} == "1" ]]; then
    kill -KILL "$$"
  fi

  marker_source=$(mktemp "${TMPDIR:-/tmp}/dots-owned-payload.XXXXXX") || return 1
  printf 'dots-owned-theme-payload-v1\n' >"$marker_source"
  if ! dots_file_replace "$marker_source" "$marker" discard; then
    rm -f "$marker_source"
    return 1
  fi
  rm -f "$marker_source"
  dots_file_remove "$precommit" discard
}
