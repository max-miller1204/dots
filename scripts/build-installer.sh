#!/usr/bin/env bash

# Render the portable GitHub Release installer with immutable release metadata.

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
version=${1:-}
archive=${2:-}
sha=${3:-}
output=${4:-}

if (($# != 4)); then
  echo "Usage: ${0##*/} <version> <archive> <sha256> <output>" >&2
  exit 1
fi
version_pattern='(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})'
if [[ ! $version =~ ^${version_pattern}$ ]]; then
  echo "Invalid release version: $version" >&2
  exit 1
fi
if [[ $archive != "dots-$version.tar.gz" ]]; then
  echo "Invalid release archive name: $archive" >&2
  exit 1
fi
if [[ ! $sha =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "Invalid release SHA-256: $sha" >&2
  exit 1
fi
if [[ -z $output || -d $output ]]; then
  echo "Installer output must be a file path." >&2
  exit 1
fi

template_path=${DOTS_INSTALLER_TEMPLATE:-"$ROOT/scripts/install.sh.tpl"}
archive_helper_path=${DOTS_ARCHIVE_HELPER:-"$ROOT/install/helpers/archive.sh"}
[[ -f $template_path && ! -L $template_path ]] || {
  echo "Installer template is not a regular file: $template_path" >&2
  exit 1
}
[[ -f $archive_helper_path && ! -L $archive_helper_path ]] || {
  echo "Archive helper is not a regular file: $archive_helper_path" >&2
  exit 1
}
validator=$(awk '
  /^# DOTS_ARCHIVE_VALIDATOR_BEGIN$/ { capture = 1; next }
  /^# DOTS_ARCHIVE_VALIDATOR_END$/ { capture = 0; found = 1; next }
  capture { print }
  END { if (!found) exit 1 }
' "$archive_helper_path") || {
  echo "Archive helper contains no embeddable validator: $archive_helper_path" >&2
  exit 1
}
[[ $validator == *"dots_archive_validate()"* ]] || {
  echo "Archive helper contains an invalid embeddable validator: $archive_helper_path" >&2
  exit 1
}
template=$(<"$template_path")
for placeholder in @DOTS_RELEASE_VERSION@ @DOTS_RELEASE_ARCHIVE@ @DOTS_RELEASE_SHA256@ @DOTS_ARCHIVE_VALIDATOR@; do
  [[ $template == *"$placeholder"* ]] || {
    echo "Installer template is missing $placeholder." >&2
    exit 1
  }
done
template=${template//@DOTS_RELEASE_VERSION@/$version}
template=${template//@DOTS_RELEASE_ARCHIVE@/$archive}
template=${template//@DOTS_RELEASE_SHA256@/${sha,,}}
while IFS= read -r line || [[ -n $line ]]; do
  if [[ $line == "@DOTS_ARCHIVE_VALIDATOR@" ]]; then
    printf '%s\n' "$validator"
  else
    printf '%s\n' "$line"
  fi
done <<<"$template" >"$output"
chmod +x "$output"
