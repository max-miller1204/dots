# Themes

Each first-party theme is in `themes/<name>/`. The theme defines its palette in
`colors.toml`. Templates in `default/themed/*.tpl` render outputs for
applications. The templates use placeholders such as `{{ accent }}`,
`{{ accent_strip }}`, and `{{ accent_rgb }}`.

## Select a theme

```bash
dots theme list
dots theme set tokyo-night
dots theme current
```

Dots builds a theme change as a new immutable generation. The generation is
under `~/.local/state/dots/theme-generations/`. Dots validates and renders the
complete generation. Dots then atomically switches
`~/.local/state/dots/current`. Dots keeps the previous generation for recovery.

Application configurations can point to generated files. For example, Ghostty
uses this configuration:

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

The supplied btop configuration sets `save_config_on_exit = false`. Thus, an
interactive session cannot automatically rewrite the copied baseline when it
exits. To keep a btop preference, edit the live configuration. Then, import it
explicitly.

A normal theme change does not change Pi or Claude preferences. To use the
generated theme, activate it one time:

```bash
dots theme sync pi --activate
dots theme sync claude --activate
```

Subsequent theme changes update the payload that is associated with the stable
theme name.

The synchronizers preserve each file if they cannot prove that Dots owns the
file. The synchronizers also validate the active and previous generation
pointers. They do this validation before they use the pointers for ownership
recovery.

## User themes and templates

User-owned additions are under `~/.config/dots/`:

- `themes/<name>/` - machine-specific theme files
- `themed/*.tpl` - machine-wide templates that have precedence over built-in
  templates with the same output name

A user theme can have the same name as a built-in theme. In this case, the user
theme overlays the built-in theme. Files from the user directory replace
built-in files with the same name. All other built-in files remain available.
A user-only name creates a separate theme. A regular file directly supplied by
either source has precedence over a rendered template. Theme source trees must
not contain symlinks. Each existing item at a generated output path must be a
regular file. Before publication, rendering fails if a supported placeholder
remains unresolved.

Palette files use a strict TOML subset. The subset permits blank lines and
comments. It permits unique top-level bare keys that contain letters, numbers,
and underscores. Assign each key to a double-quoted basic string. The parser
accepts spaces and trailing comments. It decodes escaped quotes, backslashes,
tabs, and permitted Unicode scalars. The parser also accepts literal tabs. It
rejects an escape that produces a line control character or another unsafe
control character. It also rejects raw input that produces an unsafe control
character. These restrictions keep each rendered palette value on one line.
Malformed assignments and duplicate keys cause theme publication to fail.
Tables, dotted keys, quoted keys, multiline strings, and other TOML value types
also cause theme publication to fail.

Dots derives `selection_background` from a non-empty `selection`. Dots derives
`selection_foreground` from a non-empty `bright_foreground`. Dots does not
derive a key when the corresponding derived key is explicitly present. This
rule also applies when the explicit value is empty. Dots intentionally does not
support Omarchy mix, gradient, nested TOML, or remote-theme payload semantics.

The supplied palettes, templates, and portable defaults are adaptations of
Omarchy. These items retain the Omarchy
[`LICENSE.omarchy`](../LICENSE.omarchy).
