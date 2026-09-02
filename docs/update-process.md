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
  ├─ converge dots runtime
  │    ├─ stable: verify, stage, and atomically activate latest release
  │    └─ developer: git pull --ff-only only with a clean checkout
  ├─ mise install / upgrade            sync tools to the manifest
  ├─ mise self-update                  update the standalone mise binary
  ├─ dots-migrate                      run pending migrations
  ├─ dots-hook post-update             user hooks (aggregate failures)
  ├─ dots-update-analyze-logs          flag known failure signatures
  └─ dots-update-restart               report restart-*-required markers
```

The command exits `0` only after every convergence stage succeeds. A stable release download or verification failure stops before tools and
migrations run. Git, mise, or post-update hook failures are reported as
`Update incomplete.` with exit status `2`; migration failures retain their own
nonzero status. A locally modified developer checkout remains untouched and is
reported as incomplete. Stable updates never inspect or mutate the editable
source checkout.

## State and coordination files

| Path | Purpose |
| --- | --- |
| `~/.local/state/dots/update.lock` | Update lock file, held via flock(1) on an inherited fd. Parent symlinks are refused, and the append-open fd's inode is checked against the still-regular path before the PID breadcrumb is written through the fd itself. Internal stages reverify the fd. The file persists between runs; the kernel owns the lock. Override with a path under `$HOME` via `DOTS_UPDATE_LOCK`. |
| `~/.local/share/dots/.pointer-transaction` | Durable record of the pre-activation `current` and `previous` releases plus the intended target. Any locked pointer operation reconciles an interrupted transition before reading or changing the pointers. |
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

`dots update available` checks the published release manifest in stable mode
and the configured Git upstream in developer mode. Exit codes are distinct so
scripts can tell the states apart:

- `0` — updates available (published version or pending commits printed)
- `1` — up to date
- `2` — cannot determine (release metadata unavailable, no developer upstream, or an update owns the lock)

The availability check shares the update lock so its release check or Git fetch
cannot race a full update. Developer mode falls back to existing
remote-tracking state after a failed fetch. Wire it into a prompt segment, a
login check, or a scheduled job as you like.

## Activation and rollback

Release archives are verified before their immutable directory is published.
Publication first prepares a verified, read-only sibling of the final release
path and then atomically renames it into place. If publication is interrupted,
a retry publishes a matching ready tree only after its ownership marker and
complete integrity inventory verify; unrelated or invalid trees are left
untouched. While holding the update lock, activation first records the old
pointer state and intended target in a durable transaction, then replaces
`previous` and `current` individually. Every operation that can read, reconcile,
or mutate these pointers holds the same lock. If activation is interrupted, the
next such operation either recognizes the completed pair or restores both old
pointers, so the prior rollback target remains recoverable. After activation,
stable update and version-install commands securely re-exec the new runtime
while retaining the lock through tool and migration convergence.

`dots version rollback` swaps the runtime pointers, but deliberately does not
undo migrations, copied configuration, or mise upgrades.
