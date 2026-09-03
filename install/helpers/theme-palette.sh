# Parser for the supported colors.toml palette subset.
#
# Palette files contain only top-level bare keys assigned TOML basic strings.
# Blank lines and comments are accepted. The callback receives each decoded
# key/value pair; duplicate keys and every other TOML construct are rejected.

dots_theme_palette_error() { # <file> <line-number> <message>
  printf 'Invalid theme palette %s:%s: %s\n' "$1" "$2" "$3" >&2
  return 1
}

dots_theme_palette_decode_unicode() { # <codepoint>; sets DOTS_THEME_DECODED
  local codepoint=$1 encoded

  if ((codepoint <= 0x7f)); then
    printf -v encoded '\\0%03o' "$codepoint"
  elif ((codepoint <= 0x7ff)); then
    printf -v encoded '\\0%03o\\0%03o' \
      "$((0xc0 | codepoint >> 6))" \
      "$((0x80 | codepoint & 0x3f))"
  elif ((codepoint <= 0xffff)); then
    printf -v encoded '\\0%03o\\0%03o\\0%03o' \
      "$((0xe0 | codepoint >> 12))" \
      "$((0x80 | codepoint >> 6 & 0x3f))" \
      "$((0x80 | codepoint & 0x3f))"
  else
    printf -v encoded '\\0%03o\\0%03o\\0%03o\\0%03o' \
      "$((0xf0 | codepoint >> 18))" \
      "$((0x80 | codepoint >> 12 & 0x3f))" \
      "$((0x80 | codepoint >> 6 & 0x3f))" \
      "$((0x80 | codepoint & 0x3f))"
  fi
  printf -v DOTS_THEME_DECODED '%b' "$encoded"
}

# The callback is intentionally dynamic and cannot write the input in renderer use.
# shellcheck disable=SC2094
dots_theme_palette_parse() { # <colors.toml> <callback>
  local file=$1 callback=$2 line line_number=0 key rest value ch escape hex decoded
  local index length codepoint complete byte_dump
  local -A seen=()

  [[ ! -L $file && -f $file ]] || {
    echo "Invalid theme palette: expected a regular file: $file" >&2
    return 1
  }
  if ! byte_dump=$(LC_ALL=C od -An -v -t x1 "$file"); then
    echo "Invalid theme palette: could not inspect bytes: $file" >&2
    return 1
  fi
  if [[ $byte_dump =~ (^|[[:space:]])00($|[[:space:]]) ]]; then
    echo "Invalid theme palette: NUL byte is not allowed: $file" >&2
    return 1
  fi
  if ! iconv -f UTF-8 -t UTF-8 "$file" >/dev/null 2>&1; then
    echo "Invalid theme palette: input is not valid UTF-8: $file" >&2
    return 1
  fi

  while IFS= read -r line || [[ -n $line ]]; do
    ((line_number += 1))
    rest=$line
    rest=${rest#"${rest%%[!$' \t\r']*}"}
    [[ -z $rest || ${rest:0:1} == "#" ]] && continue

    if [[ ! $rest =~ ^([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*\" ]]; then
      dots_theme_palette_error "$file" "$line_number" \
        'expected a top-level bare_key = "quoted string" assignment' || return
    fi
    key=${BASH_REMATCH[1]}
    [[ -z ${seen[$key]+present} ]] || {
      dots_theme_palette_error "$file" "$line_number" "duplicate assignment for key: $key" || return
    }
    seen[$key]=1
    rest=${rest:${#BASH_REMATCH[0]}}
    value=""
    complete=""
    index=0
    length=${#rest}
    while ((index < length)); do
      ch=${rest:index:1}
      if [[ $ch == '"' ]]; then
        rest=${rest:index+1}
        rest=${rest#"${rest%%[!$' \t\r']*}"}
        [[ -z $rest || ${rest:0:1} == "#" ]] || {
          dots_theme_palette_error "$file" "$line_number" \
            'unexpected content after quoted string' || return
        }
        "$callback" "$key" "$value" || return
        complete=1
        break
      fi
      if [[ $ch == "\\" ]]; then
        ((index += 1))
        ((index < length)) || {
          dots_theme_palette_error "$file" "$line_number" 'unterminated escape sequence' || return
        }
        escape=${rest:index:1}
        case $escape in
          '"') decoded='"' ;;
          \\) decoded=$'\\' ;;
          t) decoded=$'\t' ;;
          u|U)
            if [[ $escape == "u" ]]; then
              hex=${rest:index+1:4}
              [[ $hex =~ ^[0-9A-Fa-f]{4}$ ]] || {
                dots_theme_palette_error "$file" "$line_number" 'invalid \\u escape' || return
              }
              ((index += 4))
            else
              hex=${rest:index+1:8}
              [[ $hex =~ ^[0-9A-Fa-f]{8}$ ]] || {
                dots_theme_palette_error "$file" "$line_number" 'invalid \\U escape' || return
              }
              ((index += 8))
            fi
            codepoint=$((16#$hex))
            (((codepoint == 0x09 || (codepoint >= 0x20 && codepoint != 0x7f)) &&
              codepoint <= 0x10ffff &&
              (codepoint < 0xd800 || codepoint > 0xdfff))) || {
              dots_theme_palette_error "$file" "$line_number" 'unsupported Unicode scalar escape' || return
            }
            dots_theme_palette_decode_unicode "$codepoint"
            decoded=$DOTS_THEME_DECODED
            ;;
          b|f|n|r)
            dots_theme_palette_error "$file" "$line_number" \
              "escape \\$escape is unsafe in rendered single-line palette values" || return
            ;;
          *)
            dots_theme_palette_error "$file" "$line_number" "unsupported escape: \\$escape" || return
            ;;
        esac
        value+=$decoded
      else
        [[ $ch != $'\r' && $ch != [$'\x01'-$'\x08'$'\x0b'$'\x0c'$'\x0e'-$'\x1f'$'\x7f'] ]] || {
          dots_theme_palette_error "$file" "$line_number" 'unescaped control character in string' || return
        }
        value+=$ch
      fi
      ((index += 1))
    done
    [[ -n $complete ]] || {
      dots_theme_palette_error "$file" "$line_number" 'unterminated quoted string' || return
    }
  done <"$file"
}
