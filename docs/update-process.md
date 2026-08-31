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
  ├─ git pull --ff-only                only with no tracked, staged, or untracked work
  ├─ mise install / upgrade            sync tools to the manifest
  ├─ mise self-update                  update the standalone mise binary
  ├─ dots-migrate                      run pending migrations
  ├─ dots-hook post-update             user hooks (aggregate failures)
  ├─ dots-update-analyze-logs          flag known failure signatures
  └─ dots-update-restart               report restart-*-required markers
```

The command exits `0` only after every convergence stage succeeds. Git, mise,
or post-update hook failures are collected and reported as `Update incomplete.`
with exit status `2`; migration failures retain their own nonzero status. An
offline or locally modified checkout may still complete safe local stages, but
is reported as incomplete rather than indistinguishable from full success.

## State and coordination files

| Path | Purpose |
| --- | --- |
| `~/.local/state/dots/update.lock` | Update lock file, held via flock(1) on an inherited fd. Parent symlinks are refused, and the append-open fd's inode is checked against the still-regular path before the PID breadcrumb is written through the fd itself. Internal stages reverify the fd. The file persists between runs; the kernel owns the lock. Override with a path under `$HOME` via `DOTS_UPDATE_LOCK`. |
| `~/.local/state/dots/update-prev-incomplete` | One-shot warning published before an incomplete transcript is rotated to `.prev`, so a crash at either boundary remains reportable; removed after the warning is printed, allowing harmless replay after interruption. |
| `~/.local/state/dots/update-orderly-exit` | Temporary one-line status evidence atomically published by an orderly transcribed child. The locked outer stage promotes valid surviving evidence before classifying the prior transcript, and normally accepts it only when it matches `script(1)`'s status. It is never terminal evidence by itself. |
| `~/.local/state/dots/update-terminal-status` | Out-of-band terminal sidecar promoted by the locked outer stage only from matching orderly-exit evidence after `script(1)` returns and closes the transcript. A crashed or signaled child remains unmarked. |
| `~/.local/state/dots/update.log` | Transcript of the last `dots update`, read by the analyzer. Final symlinks and non-file occupants are refused before `script(1)` can write. Any transcript, including a zero-byte file, without the terminal sidecar is treated as interrupted. |
| `~/.local/state/dots/update.log.prev` | Preserved transcript of a run that died without a terminal marker; the next update reports it instead of silently truncating. Deliberate aborts already carry `Update aborted.` and are not rotated. |
| `~/.local/state/dots/restart-<component>-required` | Restart markers, reported and cleared at the end of an update. |
| `~/.local/state/dots/migrations/` | Per-machine migration completion markers plus a parent-safe, inode-verified `migrate.lock`, which serializes pending checks and execution. |

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
- `2` — cannot determine (not a checkout, no remote/upstream, or an update currently owns the Git lock)

The availability check shares the update lock so its fetch cannot race a full update. A failed fetch is quiet and falls back to the existing remote-tracking
state, so it works offline. Wire it into a prompt segment, a login check,
or a scheduled job as you like.
