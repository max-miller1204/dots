# Shared helpers for publishing generated theme integrations.

source "$DOTS_PATH/install/helpers/files.sh"

dots_theme_sync_link() { # <generated-file> <label> <config-dir> <destination>
  local generated_file=$1 label=$2 config_dir=$3 destination=$4
  local source_path="$HOME/.local/state/dots/current/theme/$generated_file"
  local destination_dir=${destination%/*}

  DOTS_THEME_SYNC_APPLIED=""
  if [[ -L $source_path ]]; then
    echo "Refusing symlinked $label source: $source_path" >&2
    return 1
  fi
  [[ -d $config_dir && -f $source_path ]] || return 0
  "$DOTS_PATH/bin/dots-theme-source-valid" "$generated_file" || {
    echo "Refusing unowned $label source: $source_path" >&2
    return 1
  }
  dots_file_assert_safe_parents "$destination" "$HOME" || return 1

  mkdir -p "$destination_dir"
  if [[ -e $destination || -L $destination ]]; then
    if [[ ! -L $destination || $(readlink "$destination") != "$source_path" ]]; then
      echo "Skipping $label link: $destination is not dots-owned" >&2
      return 0
    fi
  else
    ln -s "$source_path" "$destination"
  fi
  DOTS_THEME_SYNC_APPLIED=1
}

dots_theme_sync_json_activation() ( # <settings> <app-label> <theme-value> <temp-label>
  local settings_path=$1 app_label=$2 theme_value=$3 temp_label=$4
  local tmp_settings=""

  trap '[[ -z $tmp_settings ]] || rm -f "$tmp_settings"' EXIT

  if ! "$DOTS_PATH/bin/dots-cmd-present" jq; then
    echo "Cannot activate $app_label theme: jq is not installed" >&2
    return 1
  fi
  if [[ -L $settings_path ]]; then
    echo "Refusing $app_label settings symlink: $settings_path" >&2
    return 1
  fi

  tmp_settings=$(mktemp "${TMPDIR:-/tmp}/dots-$temp_label-settings.XXXXXX")
  if [[ -f $settings_path ]]; then
    jq --arg theme "$theme_value" '.theme = $theme' "$settings_path" >"$tmp_settings"
  else
    jq -n --arg theme "$theme_value" '{theme: $theme}' >"$tmp_settings"
  fi
  dots_file_replace "$tmp_settings" "$settings_path" discard
  rm -f "$tmp_settings"
  tmp_settings=""
)

dots_theme_sync_json_app() { # <command> <app> <config-dir> <payload> <destination> <theme> [args]
  local command=$1 app_label=$2 config_dir=$3 generated_file=$4
  local destination=$5 theme_value=$6 activate=false
  shift 6

  case ${1:-} in
    "") ;;
    --activate) activate=true ;;
    *)
      echo "Usage: $command [--activate]" >&2
      return 1
      ;;
  esac
  (( $# <= 1 )) || {
    echo "Usage: $command [--activate]" >&2
    return 1
  }

  dots_theme_sync_payload \
    "$generated_file" "$app_label theme" "$config_dir" "$destination" "$activate"
  $activate || return 0
  dots_theme_sync_json_activation \
    "$config_dir/settings.json" "$app_label" "$theme_value" "${command##*-}"
}

dots_theme_sync_payload() { # <generated-file> <label> <config-dir> <destination> <activate>
  local generated_file=$1 label=$2 config_dir=$3 destination=$4 activate=$5
  local state_root="$HOME/.local/state/dots"
  local source_path="$state_root/current/theme/$generated_file"
  local previous_pointer="$state_root/theme-previous"
  local previous_source_path="" previous_target ownership_path="$destination.dots-owned"
  local settings_path="$config_dir/settings.json"

  if [[ -L $source_path ]]; then
    echo "Refusing symlinked $label source: $source_path" >&2
    return 1
  fi
  if [[ ! -f $source_path ]]; then
    if $activate; then
      echo "Cannot activate $label: generated payload is missing: $source_path" >&2
      return 1
    fi
    return 0
  fi
  if ! "$DOTS_PATH/bin/dots-theme-source-valid" "$generated_file"; then
    echo "Refusing unowned $label source: $source_path" >&2
    return 1
  fi
  if "$DOTS_PATH/bin/dots-theme-source-valid" --previous "$generated_file"; then
    previous_target=$(readlink "$previous_pointer")
    previous_source_path="$state_root/$previous_target/theme/$generated_file"
  fi
  if ! $activate && [[ ! -d $config_dir ]]; then
    return 0
  fi
  dots_file_assert_safe_parents "$destination" "$HOME" || return 1
  dots_file_assert_safe_parents "$ownership_path" "$HOME" || return 1
  dots_file_assert_safe_parents "$settings_path" "$HOME" || return 1

  mkdir -p "${destination%/*}"
  dots_file_sync_owned_payload \
    "$source_path" "$destination" "$ownership_path" "$label" "$previous_source_path"
}
