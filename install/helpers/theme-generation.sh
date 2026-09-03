# Shared ownership contract for retained theme generations.

DOTS_THEME_GENERATION_MARKER_NAME=".dots-theme-generation"
DOTS_THEME_GENERATION_MARKER_VALUE="dots-theme-generation-v1"
readonly DOTS_THEME_GENERATION_MARKER_NAME DOTS_THEME_GENERATION_MARKER_VALUE

dots_theme_file_has_exact_line() { # dots_theme_file_has_exact_line <file> <expected>
  local file=$1 expected=$2
  local -a lines=()
  [[ ! -L $file && -f $file ]] || return 1
  mapfile -t lines <"$file"
  ((${#lines[@]} == 1)) && [[ ${lines[0]} == "$expected" ]]
}

dots_theme_generation_layout_valid() { # <state-root> <relative-target>
  local state_root=$1 target=$2 generation

  [[ $target =~ ^theme-generations/(generation|recovery)\.[A-Za-z0-9]+$ ]] || return 1
  generation="$state_root/$target"
  [[ ! -L $generation && -d $generation ]] || return 1
  [[ ! -L $generation/theme && -d $generation/theme ]] || return 1
  [[ ! -L $generation/theme.name && -f $generation/theme.name ]] || return 1
}

dots_theme_generation_target_valid() { # <state-root> <relative-target>
  local state_root=$1 target=$2 generation theme_name=""
  local -a theme_name_lines=()

  dots_theme_generation_layout_valid "$state_root" "$target" || return 1
  generation="$state_root/$target"
  mapfile -t theme_name_lines <"$generation/theme.name"
  ((${#theme_name_lines[@]} == 1)) || return 1
  theme_name=${theme_name_lines[0]}
  [[ $theme_name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || return 1
  dots_theme_file_has_exact_line \
    "$generation/$DOTS_THEME_GENERATION_MARKER_NAME" \
    "$DOTS_THEME_GENERATION_MARKER_VALUE"
}
