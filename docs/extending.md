# Migrations and hooks

## Migrations

Use a migration for a one-time change that existing installations need:

```bash
$EDITOR "migrations/$(date +%s).sh"
```

Migrations must be idempotent. `dots migrate` serializes execution and records successful completion under `~/.local/state/dots/migrations/`. `dots update` runs pending migrations automatically. A fresh installation already contains the current repository state, so it marks all shipped migrations complete.

Useful commands:

```bash
dots migrate --pending
dots migrate
```

If a migration changes something already loaded, such as shell configuration, create a restart marker:

```bash
touch ~/.local/state/dots/restart-shell-required
```

Dots reports and clears restart markers after migration or update processing.

## Hooks

User hook scripts live under `~/.config/dots/hooks/<event>.d/`. Supported events are:

- `post-install`
- `post-update`
- `theme-set` — receives the selected theme name as `$1`

Install a script with:

```bash
dots hook install post-update ~/my-update-hook
dots hook post-update
```

Sample hooks ship under [`config/dots/hooks/`](../config/dots/hooks/). Remove the `.sample` suffix in the live config tree to activate one.

Hook installation accepts lowercase hyphenated event names and rejects symlinked destination parents. Built-in application behavior belongs in versioned scripts under `bin/`; hooks are for user-owned extensions.
