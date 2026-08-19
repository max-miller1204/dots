# Update process

`dots update` owns the visible update pipeline, following omarchy's design:
one blessed command that runs everything in order, armored against the ways
updates go wrong.

```text
dots-update
  ├─ dots-update-lock                  serialize concurrent runs
  │    (mkdir lock + stale-PID reclaim; macOS has no flock)
  ├─ transcript: tee everything to ~/.local/state/dots/update.log
  ├─ dots-update-requires-free-space   abort below 1 GiB free on $HOME
  │    (DOTS_UPDATE_FORCE=1 bypasses; unknown free space is skipped)
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
| `${TMPDIR:-/tmp}/dots-update-<uid>.lock/` | Update lock (dir + `pid` file). Stale locks are reclaimed. |
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

`dots update` reports each marker at the end of the run and clears it.

## Update indicator

`dots update available` is the omarchy `omarchy-update-available` port.
Exit codes are distinct so scripts can tell the states apart:

- `0` — updates available (pending commits printed)
- `1` — up to date
- `2` — cannot determine (not a checkout, no remote, or no upstream)

A failed fetch is quiet and falls back to the existing remote-tracking
state, so it works offline. Wire it into a prompt segment, a login check,
or a scheduled job as you like.
