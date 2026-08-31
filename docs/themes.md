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

Normal theme changes do not take over Pi or Claude preferences. Activate the generated theme once when wanted:

```bash
dots theme sync pi --activate
dots theme sync claude --activate
```

Later theme changes update the payload behind that stable theme name.

The synchronizers preserve files they cannot prove dots owns. They also validate active and previous generation pointers before using them for ownership recovery.

## User themes and templates

User-owned additions live under `~/.config/dots/`:

- `themes/<name>/` — machine-specific theme files
- `themed/*.tpl` — machine-wide templates that shadow built-ins with the same output name

Regular files supplied directly by a theme override rendered templates. Theme source trees may not contain symlinks, and generated output occupants must be regular files. Rendering fails before publication if a supported placeholder remains unresolved.

Supported palette parsing covers quoted top-level values and derived selection foreground/background values. Omarchy mix, gradient, nested TOML, and remote-theme payload semantics are intentionally unsupported.

Shipped palettes, templates, and portable defaults adapted from Omarchy retain its [`LICENSE.omarchy`](../LICENSE.omarchy).
