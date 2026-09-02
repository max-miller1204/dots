#!/usr/bin/env bash

set -eo pipefail

usage() {
  echo "Usage: scripts/build-release.sh <vX.Y.Z> [output-directory]" >&2
}

if (($# < 1 || $# > 2)); then
  usage
  exit 1
fi

tag=$1
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
output_dir=${2:-"$repo_root/dist"}
version_pattern='(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})'

if [[ ! $tag =~ ^v${version_pattern}$ ]]; then
  echo "Invalid release tag '$tag'; expected vX.Y.Z." >&2
  exit 1
fi

if ! git -C "$repo_root" rev-parse --verify HEAD >/dev/null 2>&1 ||
  ! git -C "$repo_root" cat-file -e HEAD:version 2>/dev/null; then
  echo "Release artifacts must be built from a Git commit containing version." >&2
  exit 1
fi
mapfile -t version_lines < <(git -C "$repo_root" show HEAD:version)
if ((${#version_lines[@]} != 1)) || [[ ! ${version_lines[0]} =~ ^${version_pattern}$ ]]; then
  echo "Committed version file is invalid; expected exactly one X.Y.Z line." >&2
  exit 1
fi
version=${version_lines[0]}

if [[ $tag != "v$version" ]]; then
  echo "Release tag $tag does not match committed version $version." >&2
  exit 1
fi

archive_root="dots-$version"
archive_name="$archive_root.tar.gz"
archive="$output_dir/$archive_name"
checksum="$output_dir/SHA256SUMS"
manifest="$output_dir/dots-release.txt"
temporary_archive="$output_dir/.$archive_name.tmp.$$"
smoke_dir=""
success=0

cleanup() {
  [[ -n $smoke_dir ]] && rm -rf -- "$smoke_dir"
  rm -f -- "$temporary_archive"
  if ((success == 0)); then
    rm -f -- "$archive" "$checksum" "$manifest"
  fi
}
trap cleanup EXIT

mkdir -p -- "$output_dir"
rm -f -- "$archive" "$checksum" "$manifest" "$temporary_archive"

payload=(bin config default install migrations themes version)
COPYFILE_DISABLE=1 git -C "$repo_root" archive \
  --format=tar \
  --prefix="$archive_root/" \
  HEAD \
  -- "${payload[@]}" | gzip -n >"$temporary_archive"

smoke_dir=$(mktemp -d "${TMPDIR:-/tmp}/dots-release.XXXXXX")
COPYFILE_DISABLE=1 tar -xzf "$temporary_archive" -C "$smoke_dir"
extracted="$smoke_dir/$archive_root"

for path in "${payload[@]}"; do
  if [[ ! -e $extracted/$path ]]; then
    echo "Smoke test failed: archive is missing $path." >&2
    exit 1
  fi
done

shopt -s nullglob dotglob
extracted_paths=("$extracted"/*)
shopt -u nullglob dotglob
extracted_entries=()
for path in "${extracted_paths[@]}"; do
  extracted_entries+=("${path##*/}")
done
mapfile -t extracted_entries < <(printf '%s\n' "${extracted_entries[@]}" | LC_ALL=C sort)
mapfile -t expected_entries < <(printf '%s\n' "${payload[@]}" | LC_ALL=C sort)
if [[ ${extracted_entries[*]} != "${expected_entries[*]}" ]]; then
  echo "Smoke test failed: archive contains an unexpected runtime payload." >&2
  exit 1
fi

if [[ ! -x $extracted/bin/dots || ! -x $extracted/bin/dots-version ]]; then
  echo "Smoke test failed: runtime commands are not executable." >&2
  exit 1
fi

mkdir -p -- "$smoke_dir/home"
version_output=$(HOME="$smoke_dir/home" DOTS_PATH="$extracted" "$extracted/bin/dots-version")
if [[ $version_output != "dots $version (unmanaged)" ]]; then
  echo "Smoke test failed: expected unmanaged dots $version, got '$version_output'." >&2
  exit 1
fi

mv -- "$temporary_archive" "$archive"
if command -v sha256sum >/dev/null 2>&1; then
  (cd -- "$output_dir" && sha256sum "$archive_name" >SHA256SUMS)
elif command -v shasum >/dev/null 2>&1; then
  (cd -- "$output_dir" && shasum -a 256 "$archive_name" >SHA256SUMS)
else
  echo "Neither sha256sum nor shasum is available." >&2
  exit 1
fi

archive_sha=$(awk -v name="$archive_name" '$2 == name || $2 == "*" name { print $1; exit }' "$checksum")
cat >"$manifest" <<EOF
dots-release-v1
version=$version
archive=$archive_name
sha256=$archive_sha
EOF

success=1
printf 'Built %s\n' "$archive"
printf 'Built %s\n' "$checksum"
printf 'Built %s\n' "$manifest"
