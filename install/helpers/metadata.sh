# Shared reader for the comment metadata at the top of dots commands.
# This file is sourced by the router and completion candidate generator.

dots_command_metadata() { # dots_command_metadata <file> <key>
  local file=$1 key=$2 line count=0 prefix
  local scan_limit=${DOTS_METADATA_SCAN_LIMIT:-20}

  prefix="# dots:$key="
  while ((count < scan_limit)); do
    line=""
    IFS= read -r line || [[ -n $line ]] || break
    count=$((count + 1))
    if [[ $line == "$prefix"* ]]; then
      printf '%s\n' "${line#"$prefix"}"
      return 0
    fi
  done <"$file"
}
