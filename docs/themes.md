# Themes

Each first-party theme lives under `themes/<name>/` and defines its palette in `colors.toml`. Templates in `default/themed/*.tpl` render application-specific outputs using placeholders such as `{{ accent }}`, `{{ accent_strip }}`, and `{{ accent_rgb }}`.

## Select a theme

```bash
dots theme list
dots theme set tokyo-night
dots theme current
```

A theme change is built as a new immutable generation under `~/.local/state/dots/theme-generations/`. Dots validates and renders the whole generation before atomically switching `~/.local/state/dots/current`. The immediately previous generation is retained for recovery.

Application configs can point at generated files. Ghostty, for example, uses:

```text
config-file = ~/.local/state/dots/current/theme/ghostty.conf
```

## Application integration

Versioned synchronizers in `bin/` connect generated themes to supported applications:

- btop uses the `dots-system.theme` link.
- Neovim uses the `dots-system.lua` Lazy plugin link.
- tmux sources the generated `tmux.conf`.
- Pi and Claude receive stable generated theme payloads.
- `obsidian.css` is available for an Obsidian CSS theme or snippet.

The shipped btop config sets `save_config_on_exit = false` so an interactive
session cannot silently rewrite the copied baseline. Edit the live config and
import it explicitly when a btop preference should persist.

Normal theme changes do not take over Pi or Claude preferences. Activate the generated theme once when wanted:

```bash
dots theme sync pi --activate
dots theme sync claude --activate
```

Later theme changes update the payload behind that stable theme name.

The synchronizers preserve files they cannot prove dots owns. They also validate active and previous generation pointers before using them for ownership recovery.

## User themes and templates

User-owned additions live under `~/.config/dots/`:

- `themes/<name>/` - machine-specific theme files
- `themed/*.tpl` - machine-wide templates that shadow built-ins with the same output name

A user theme whose name matches a built-in overlays that built-in: files from
the user directory replace same-named shipped files, while all other built-in
files remain available. A user-only name creates a standalone theme. Regular
files supplied directly by either source override rendered templates. Theme
source trees may not contain symlinks, and generated output occupants must be
regular files. Rendering fails before publication if a supported placeholder
remains unresolved.

Palette files use a strict TOML subset: blank lines and comments, plus unique
top-level bare keys made of letters, numbers, and underscores assigned to
double-quoted basic strings. Spaces and trailing comments are accepted. Quote,
backslash, tab, and valid non-NUL Unicode scalar escapes are decoded.
Basic-string escapes that produce line or other unsafe control characters are
rejected because rendered palette values are single-line. Malformed
assignments, duplicate keys, tables, dotted or quoted keys, multiline strings,
and other TOML value types fail theme publication clearly.

`selection_background` is derived from a non-empty `selection`, and
`selection_foreground` from a non-empty `bright_foreground`, unless the
corresponding derived key is explicitly present (including when explicitly
empty). Omarchy mix, gradient, nested TOML, and remote-theme payload semantics
are intentionally unsupported.

Shipped palettes, templates, and portable defaults adapted from Omarchy retain its [`LICENSE.omarchy`](../LICENSE.omarchy).
