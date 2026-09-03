# Shared archive-entry validation for release builds, the installed runtime,
# and the generated standalone installer. Keep the marked function compatible
# with Bash 3.2: scripts/build-installer.sh embeds it verbatim in install.sh.

# DOTS_ARCHIVE_VALIDATOR_BEGIN
dots_archive_validate() { # dots_archive_validate <tar.gz> <expected-root>
  local archive=$1 expected_root=$2 verbose_listing listing_line entry_type
  local archive_listing entry found_entry=""

  DOTS_ARCHIVE_VALIDATION_ERROR=""
  DOTS_ARCHIVE_VALIDATION_ENTRY=""
  if ! verbose_listing=$(tar -tvzf "$archive"); then
    DOTS_ARCHIVE_VALIDATION_ERROR=unreadable
    return 1
  fi
  while IFS= read -r listing_line || [[ -n $listing_line ]]; do
    [[ -n $listing_line ]] || continue
    entry_type=${listing_line:0:1}
    if [[ $entry_type != "-" && $entry_type != "d" ]]; then
      DOTS_ARCHIVE_VALIDATION_ERROR=special-entry
      return 1
    fi
  done <<<"$verbose_listing"

  if ! archive_listing=$(tar -tzf "$archive"); then
    DOTS_ARCHIVE_VALIDATION_ERROR=unreadable
    return 1
  fi
  while IFS= read -r entry || [[ -n $entry ]]; do
    [[ -n $entry ]] || continue
    if [[ $entry != "$expected_root" && $entry != "$expected_root/"* ]]; then
      DOTS_ARCHIVE_VALIDATION_ERROR=unsafe-path
      DOTS_ARCHIVE_VALIDATION_ENTRY=$entry
      return 1
    fi
    case "/$entry/" in
      */../* | */./*)
        DOTS_ARCHIVE_VALIDATION_ERROR=unsafe-path
        DOTS_ARCHIVE_VALIDATION_ENTRY=$entry
        return 1
        ;;
    esac
    found_entry=1
  done <<<"$archive_listing"
  if [[ -z $found_entry ]]; then
    DOTS_ARCHIVE_VALIDATION_ERROR=missing-root
    DOTS_ARCHIVE_VALIDATION_ENTRY=$expected_root
    return 1
  fi
}
# DOTS_ARCHIVE_VALIDATOR_END
