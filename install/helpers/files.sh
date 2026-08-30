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
