# Migrations and hooks

## Migrations

Use a migration to make a one-time change to an existing installation:

```bash
$EDITOR "migrations/$(date +%s).sh"
```

A migration must be idempotent. `dots migrate` runs only one migration process
at a time. The command records each successful migration in
`~/.local/state/dots/migrations/`. `dots update` automatically runs pending
migrations. A new installation already has the current repository state.
Thus, the installation marks all included migrations as complete.

If a migration fails, `dots` keeps the migration pending. `dots` continues to
run the remaining migrations. After the migration process, `dots` returns the
exit status of the first failure. The next migration process retries each
failed migration.

Use these commands:

```bash
dots migrate --pending
dots migrate
```

The `--pending` option does not wait for a migration lock. The option returns
exit code `0` when migrations are pending. It also lists the pending files. The
option returns exit code `1` when no migrations are pending. It returns exit
code `2` when another migration process owns the lock. It also returns exit
code `2` when the marker state is unsafe or corrupt. Completion markers must
be empty regular files. `dots` rejects nonempty files, symbolic links, and
other types of file-system entries.

If a migration changes a loaded component, create a restart marker. For
example, shell configuration is a loaded component.

```bash
touch ~/.local/state/dots/restart-shell-required
```

After migration or update processing, `dots` reports the restart markers.
Then, `dots` clears the restart markers.

## Hooks

Put user hook scripts in `~/.config/dots/hooks/<event>.d/`. `dots` supports
these events:

- `post-install`
- `post-update`
- `theme-set`: The event receives the selected theme name as `$1`.

Use the first command to install a script. Use the second command to run the
script:

```bash
dots hook install post-update ~/my-update-hook
dots hook post-update
```

Sample hooks are in [`config/dots/hooks/`](../config/dots/hooks/). To activate
a sample hook, remove the `.sample` suffix in the live configuration tree.

Hook installation accepts lowercase event names that contain hyphens. It
rejects destination parent directories that are symbolic links. The runner
follows symbolic links that you create manually. It follows a symbolic link
for an event file or for its `.d` directory. This behavior is the same as the
behavior in Omarchy Quattro. You can use this behavior to keep hooks in a
different repository. Changes at the symbolic-link target change the code that
`dots` runs. New files at that target also change the code that `dots` runs.
Create links only to locations that you trust.

Implement built-in application behavior in version-controlled scripts in
`bin/`. Use hooks only for extensions that users own.
