# Update process

`dots update` owns the visible update pipeline, following omarchy's design:
one blessed command that runs everything in order, armored against the ways
updates go wrong.

```text
dots-update
  ├─ dots-update-lock                  serialize concurrent runs
  │    (flock(1) on an fd the pipeline inherits: the kernel releases the
  │     lock when the last holder exits, SIGKILL included — util-linux on
  │     Ubuntu/WSL, discoteq flock via brew on macOS)
  ├─ transcript: script(1) records the run off a real pty into
  │    ~/.local/state/dots/update.log (BSD and util-linux flag syntax
  │    differ, so this is the repo's one sanctioned uname guard)
  ├─ dots-update-requires-free-space   abort below 1 GiB free on $HOME
  │    (DOTS_UPDATE_FORCE=1 bypasses; unknown free space is skipped;
  │     a deliberate abort writes "Update aborted." so the next run
  │     doesn't misreport it as a crash)
  ├─ git pull --ff-only                only when the checkout is clean
  ├─ mise install / upgrade            sync tools to the manifest
  ├─ dots-migrate                      run pending migrations
  ├─ dots-hook post-update             user hooks
  ├─ dots-update-analyze-logs          flag known failure signatures
  └─ dots-update-restart               report restart-*-required markers
```

## State and coordination files

| Path | Purpose |
| --- | --- |
| `~/.local/state/dots/update.lock` | Update lock file, held via flock(1) on an inherited fd (deliberately not under TMPDIR, which differs between GUI and cron/ssh contexts). The file persists between runs — the kernel, not the file, owns the lock; its content is only a holder-pid breadcrumb for refusal messages. Override with `DOTS_UPDATE_LOCK`. |
| `~/.local/state/dots/update-prev-incomplete` | One-shot marker from the locked stage to the transcribed stage that the previous transcript was rotated to `.prev`; consumed when the note is printed. |
| `~/.local/state/dots/update.log` | Transcript of the last `dots update`, read by the analyzer. |
| `~/.local/state/dots/update.log.prev` | Preserved transcript of a run that died or aborted; the next update reports it instead of silently truncating. |
| `~/.local/state/dots/restart-<component>-required` | Restart markers, reported and cleared at the end of an update. |
| `~/.local/state/dots/migrations/` | Per-machine migration completion markers. |

## Restart markers

A migration or hook that changes something already loaded (shell config,
a running service) should signal it:

```bash
touch ~/.local/state/dots/restart-shell-required
```

`dots update` reports each marker at the end of the run and clears it, and
a standalone `dots migrate` reports markers as soon as its migrations
finish.

## Update indicator

`dots update available` is the omarchy `omarchy-update-available` port.
Exit codes are distinct so scripts can tell the states apart:

- `0` — updates available (pending commits printed)
- `1` — up to date
- `2` — cannot determine (not a checkout, no remote, or no upstream)

A failed fetch is quiet and falls back to the existing remote-tracking
state, so it works offline. Wire it into a prompt segment, a login check,
or a scheduled job as you like.
