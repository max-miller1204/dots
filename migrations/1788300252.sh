#!/usr/bin/env bash

# Add virtualenv context to the stock Starship prompt without replacing a
# user-customized prompt configuration.

set -euo pipefail

source "$DOTS_PATH/install/helpers/files.sh"

old_starship=$(mktemp "${TMPDIR:-/tmp}/dots-starship-before-venv.XXXXXX")
trap 'rm -f "$old_starship"' EXIT

cat >"$old_starship" <<'EOF'
add_newline = true
command_timeout = 200
format = "[$directory$git_branch$git_status]($style)$character"

[character]
error_symbol = "[✗](bold cyan)"
success_symbol = "[❯](bold cyan)"

[directory]
truncation_length = 2
truncation_symbol = "…/"
repo_root_style = "bold cyan"
repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) "

[git_branch]
format = "[$branch]($style) "
style = "italic cyan"

[git_status]
format     = '[$all_status]($style)'
style      = "cyan"
ahead      = "⇡${count} "
diverged   = "⇕⇡${ahead_count}⇣${behind_count} "
behind     = "⇣${count} "
conflicted = "= "
up_to_date = "✓ "
untracked  = "? "
modified   = "! "
stashed    = ""
staged     = ""
renamed    = ""
deleted    = ""
EOF

starship_path="$HOME/.config/starship.toml"
if [[ -f $starship_path && ! -L $starship_path ]] && cmp -s "$starship_path" "$old_starship"; then
  dots_file_replace "$DOTS_PATH/config/starship.toml" "$starship_path" backup
  echo "Enabled virtualenv names in the stock Starship prompt (backup at $DOTS_FILE_BACKUP)"
fi
