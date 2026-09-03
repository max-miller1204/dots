# Commands

Run `dots` to show the complete generated command list. Run `dots help <group>`
to show one group. Use `--help` or `-h` with each command. Interactive Bash and
Zsh shells complete visible groups, nested commands, options, themes, hook
events, and configuration paths.

| Command | Purpose |
| --- | --- |
| `dots install` | Install the latest stable runtime, configuration files, shell, and tools. |
| `dots install --developer` | Install directly from the current checkout. |
| `dots update` | Update the stable release or developer checkout. Then update tools. Run migrations. |
| `dots update available` | Report an available release or pending developer commits. |
| `dots version` | Show the active Dots version and runtime mode. |
| `dots version install [version]` | Install a release. Activate the release. Then update tools. Run migrations. |
| `dots version adopt` | Change an installation from checkout mode to stable mode. Then update tools. Run migrations. |
| `dots version list` | List releases. `*` is current, `-` is previous, and `!` is invalid. |
| `dots version prune [--force]` | Remove inactive verified releases. Keep the current and previous releases. |
| `dots version rollback` | Change the runtime to the previous release. |
| `dots dev link <checkout>` | Use an editable checkout as the active runtime. |
| `dots dev unlink` | Return to the current stable release. |
| `dots migrate [--pending\|--check]` | Run or list pending migrations. |
| `dots refresh config <path>` | Reset one live configuration from the repository. Create a backup. Show the differences. |
| `dots reinstall configs` | Reset all live configuration files to the supplied defaults. |
| `dots config import <path>` | Copy a live configuration into the registered source checkout. |
| `dots theme list` | List available themes. |
| `dots theme current` | Show the active theme. |
| `dots theme set <name>` | Select a theme. Render its templates. |
| `dots theme sync pi --activate` | Configure Pi to use the generated dots theme. |
| `dots theme sync claude --activate` | Configure Claude to use the generated dots theme. |
| `dots hook <event>` | Run one user hook event. |
| `dots hook install <event> <script>` | Install a user hook script. |
| `dots pkg add <tool>` | Add a tool to the live global mise manifest. |
| `dots pkg drop <tool>` | Remove a tool from the live global mise manifest. |

## Update availability exit codes

`dots update available` uses these exit codes in scripts and prompt
integrations:

- `0`: Updates are available.
- `1`: The installed release or developer checkout is current.
- `2`: The command cannot determine the release metadata or the upstream state
  of the developer checkout.

For the complete update sequence and failure behavior, refer to
[`docs/update-process.md`](update-process.md).
