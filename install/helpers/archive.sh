# Shared archive-entry validation for release builds and the installed runtime.
# The standalone installer keeps a small copy because it runs before extraction.

dots_archive_regular_entries_only() { # dots_archive_regular_entries_only <tar.gz>
  local archive=$1 verbose_listing listing_line entry_type

  DOTS_ARCHIVE_VALIDATION_ERROR=""
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
}
