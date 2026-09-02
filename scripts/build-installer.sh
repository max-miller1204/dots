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
[[ -f $template_path && ! -L $template_path ]] || {
  echo "Installer template is not a regular file: $template_path" >&2
  exit 1
}
template=$(<"$template_path")
for placeholder in @DOTS_RELEASE_VERSION@ @DOTS_RELEASE_ARCHIVE@ @DOTS_RELEASE_SHA256@; do
  [[ $template == *"$placeholder"* ]] || {
    echo "Installer template is missing $placeholder." >&2
    exit 1
  }
done
template=${template//@DOTS_RELEASE_VERSION@/$version}
template=${template//@DOTS_RELEASE_ARCHIVE@/$archive}
template=${template//@DOTS_RELEASE_SHA256@/${sha,,}}
printf '%s\n' "$template" >"$output"
chmod +x "$output"
