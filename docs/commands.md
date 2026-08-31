# Commands

Run `dots` for the complete generated command listing or `dots help <group>` for one group. Every command also supports `--help` or `-h`.

| Command | Purpose |
| --- | --- |
| `dots install` | Run first-time package, config, shell, and theme setup |
| `dots update` | Update the checkout, tools, migrations, and hooks |
| `dots update available` | Report pending commits |
| `dots migrate [--pending]` | Run or list pending migrations |
| `dots refresh config <path>` | Reset one live config from the repository, with backup and diff |
| `dots reinstall configs` | Reset every live config to the shipped defaults |
| `dots config import <path>` | Copy a live config back into the repository |
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
- `1` — the checkout is current
- `2` — the state cannot be determined

See [`docs/update-process.md`](update-process.md) for the full update order and failure behavior.
