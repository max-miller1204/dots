# Commands

Run `dots` for the complete generated command listing or `dots help <group>` for one group. Every command also supports `--help` or `-h`. Interactive Bash and Zsh complete visible groups, nested commands, options, themes, hook events, and config paths.

| Command | Purpose |
| --- | --- |
| `dots install` | Install the latest stable runtime, configs, shell, and tools |
| `dots install --developer` | Install directly from the current checkout |
| `dots update` | Update the stable release or dev checkout, then tools and migrations |
| `dots update available` | Report a published release or pending dev commits |
| `dots version install [version]` | Install and activate a stable release |
| `dots version adopt` | Move a checkout-backed install to stable releases |
| `dots version list` | List installed releases (`*` current, `-` previous) |
| `dots version rollback` | Switch the runtime back to the previous release |
| `dots dev link <checkout>` | Use an editable checkout as the active runtime |
| `dots dev unlink` | Return to the current stable release |
| `dots migrate [--pending\|--check]` | Run or list pending migrations |
| `dots refresh config <path>` | Reset one live config from the repository, with backup and diff |
| `dots reinstall configs` | Reset every live config to the shipped defaults |
| `dots config import <path>` | Copy a live config into the registered source checkout |
| `dots theme list` | List available themes |
| `dots theme current` | Print the active theme |
| `dots theme set <name>` | Select and render a theme |
| `dots theme sync pi --activate` | Make Pi use the generated dots theme |
| `dots theme sync claude --activate` | Make Claude use the generated dots theme |
| `dots hook <event>` | Run one user hook event |
| `dots hook install <event> <script>` | Install a user hook script |
| `dots pkg add <tool>` | Add a tool to the live global mise manifest |
| `dots pkg drop <tool>` | Remove a tool from the live global mise manifest |

## Update availability exit codes

`dots update available` uses distinct statuses for scripts and prompt integrations:

- `0` — updates are available
- `1` — the installed release or developer checkout is current
- `2` — release metadata or developer upstream state cannot be determined

See [`docs/update-process.md`](update-process.md) for the full update order and failure behavior.
