# Update process

`dots update` controls the visible update pipeline. The design follows the
Omarchy update process. One command runs all stages in sequence. The pipeline
includes controls for update failures.

```text
dots-update
  ├─ dots-update-lock                  serialize concurrent runs
  │    (The pipeline uses flock(1) on an inherited file descriptor. The kernel
  │     releases the lock when the last holder exits, including after the
  │     SIGKILL operating-system signal.
  │     Ubuntu and Windows Subsystem for Linux use util-linux. macOS uses
  │     discoteq flock from Homebrew.)
  ├─ transcript: script(1) records the run from a pseudo-terminal (pty) in
  │    ~/.local/state/dots/update.log
  │    (macOS uses Berkeley Software Distribution flag syntax. Linux uses
  │     util-linux flag syntax. These syntaxes differ. Thus, this is the
  │     repository's only permitted uname guard.)
  ├─ dots-update-requires-free-space   abort below 1 gibibyte (GiB) free on $HOME
  │    (DOTS_UPDATE_FORCE=1 bypasses this check. The process skips the check
  │     if free space is unknown. An intentional abort writes
  │     "Update aborted." Thus, the next run does not report a crash.)
  ├─ converge dots runtime
  │    ├─ stable: verify, stage, and atomically activate the latest release
  │    └─ developer: run git pull --ff-only only in a clean checkout
  ├─ dots-migrate                      run pending migrations
  ├─ mise install and upgrade          synchronize tools with the manifest
  ├─ mise self-update                  update the standalone mise binary
  ├─ dots-hook post-update             run user hooks and aggregate failures
  ├─ dots-update-analyze-logs          report known failure signatures
  └─ dots-update-restart               report restart-*-required markers
```

The command exits with status `0` only if each convergence stage succeeds. A
stable release download or verification failure stops the pipeline before the
migration and tool stages. Git, mise, or post-update hook failures cause the
message `Update incomplete.` and exit status `2`. If migrations fail, the
command returns the first migration failure status.

Migration processing continues after an individual migration fails. The
pipeline then skips the post-update hook. It still runs log analysis and
restart reporting. The pipeline does not change a developer checkout that has
local modifications. It reports that update as incomplete. A stable update
does not inspect or change the editable source checkout.

## State and coordination files

| Path | Purpose |
| --- | --- |
| `~/.local/state/dots/update.lock` | This is the update lock file. The process uses flock(1) on an inherited file descriptor (fd) to hold the lock. The process rejects symlinks in parent paths. It opens the file in append mode. It then verifies that the fd inode matches the path inode. It also verifies that the path is still a regular file. The process writes the process identifier (PID) breadcrumb through the fd only after these checks. Internal stages verify the fd again. The file remains after each run, but the kernel owns the lock. Set `DOTS_UPDATE_LOCK` to a path under `$HOME` to override this path. |
| `~/.local/share/dots/.pointer-transaction` | This file is a durable record of the `current` and `previous` releases before activation. It also records the intended target. Before a locked pointer operation reads or changes the pointers, it reconciles an interrupted transition. |
| `~/.local/state/dots/update-prev-incomplete` | This file provides a one-time warning. The process publishes the warning before it rotates an incomplete transcript to `.prev`. Thus, it can report a crash at either boundary. The process removes the file after it prints the warning. The process can safely repeat this sequence after an interruption. |
| `~/.local/state/dots/update-orderly-exit` | This temporary file contains one line of status evidence. A transcribed child that exits in an orderly way atomically publishes the file. Before the locked outer stage classifies the prior transcript, it promotes valid evidence that remains. Usually, the stage accepts the evidence only if it matches the status from `script(1)`. This file is not sufficient terminal evidence by itself. |
| `~/.local/state/dots/update-terminal-status` | This terminal status file is outside the transcript. It is a sidecar file. The locked outer stage promotes it only from matching orderly-exit evidence. The stage does this after `script(1)` returns and closes the transcript. A child that crashes or receives a signal has no marker. |
| `~/.local/state/dots/update.log` | This file is the transcript of the last `dots update`. The analyzer reads it. Before `script(1)` writes the file, the process rejects a final-path symlink or an item that is not a file. The process treats a transcript without the terminal sidecar as interrupted. This rule also applies to a zero-byte file. |
| `~/.local/state/dots/update.log.prev` | This file preserves the transcript of a run that ended without a terminal marker. The next update reports this transcript. Thus, the process does not truncate it without a report. An intentional abort already contains `Update aborted.`, so the process does not rotate it. |
| `~/.local/state/dots/restart-<component>-required` | These files are restart markers. The update reports and removes them at the end. |
| `~/.local/state/dots/migrations/` | This directory contains migration completion markers for each machine. It also contains a parent-safe, inode-verified `migrate.lock`. This lock serializes pending checks and migration execution. |

## Restart markers

If a migration or hook changes a loaded component, create a restart marker. A
shell configuration or a running service is a loaded component:

```bash
touch ~/.local/state/dots/restart-shell-required
```

At the end of the run, `dots update` reports and removes each marker. A
standalone `dots migrate` command reports the markers immediately after its
migrations finish.

## Update indicator

In stable mode, `dots update available` checks the published release manifest.
In developer mode, it checks the configured Git upstream. The command uses
different exit codes for each state:

- `0`: Updates are available. The command prints the published version or the
  pending commits.
- `1`: The installation is up to date.
- `2`: The command cannot determine the state. Release metadata can be
  unavailable, the developer upstream can be absent, or an update can hold the
  lock.

The availability check uses the update lock. Thus, its release check or Git
fetch cannot occur at the same time as a full update. After a failed fetch,
developer mode uses the existing remote-tracking state. Use this command in a
prompt segment, a login check, or a scheduled job.

## Activation and rollback

The process verifies release archives before it publishes their immutable
directories. First, it prepares a verified, read-only directory next to the
final release path. It then atomically renames this directory to the final
path. If publication stops before completion, a retry can publish a matching
ready tree. Before publication, the retry verifies the ownership marker and
the complete integrity inventory. It does not change an unrelated or invalid
tree.

The activation process holds the update lock. First, it records the old pointer
state and the intended target in a durable transaction. Then, it replaces
`previous` and `current` separately. Each operation that reads, reconciles, or
changes these pointers holds the same lock.

If activation stops before completion, the next pointer operation examines the
transaction. It either recognizes the completed pointer pair or restores both
old pointers. Thus, the prior rollback target remains available. After
activation, the stable update and version-install commands securely re-execute
the new runtime. They keep the lock during tool and migration convergence.

`dots version rollback` exchanges the runtime pointers. It does not reverse
migrations, copied configuration, or mise upgrades.
