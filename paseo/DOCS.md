# Paseo add-on documentation

## What runs in the container

The browser bundle is not the daemon. On every start, `/run.sh` launches the
pinned Paseo CLI's real host process with `paseo daemon start --foreground` on
`127.0.0.1:6767`, waits for `/api/health`, registers `/config` as a project, and
then starts Nginx on the Home Assistant ingress port `8099`. The supervisor
exits if either Paseo or Nginx exits. Paseo state, sessions, projects, and
pairing data are persisted below `/data/paseo-home/.paseo`.

Nginx proxies the ingress request to that in-container daemon. It rewrites the
build sentinel to Home Assistant's current `X-Ingress-Path` and injects
`window.__PASEO_INITIAL_DAEMON_CONNECTION__` from the browser's current origin,
so the web UI connects to this daemon automatically. The patched browser
WebSocket client applies the same dynamic ingress prefix to `/ws`.

## Authentication boundaries

There are three independent identities:

1. Home Assistant authenticates access to the administrator-only ingress panel.
2. Paseo authenticates paired remote devices and its encrypted relay relationship.
3. Codex authenticates the OpenAI/Codex provider.

The add-on deliberately does not force Codex login during startup. Authenticate interactively from Paseo's terminal:

```bash
codex login --device-auth
```

Codex credentials persist below `/data/paseo-home/.codex`; Claude Code credentials use `/data/paseo-home/.claude`, and OpenCode/Pi use the persistent HOME/XDG directories under `/data/paseo-home`. Paseo state and relay pairing persist below `/data/paseo-home/.paseo`.

## Codex Remote Control

`codex_remote_control` is enabled by default. It starts Codex's outbound
Remote Control daemon after Codex has already been authenticated. It does not
publish a port and it never creates a pairing code during startup.

On a first install, open Paseo's terminal and run:

```bash
codex login --device-auth
```

Then restart the add-on. Once the logs report that Remote Control is
connected, create a short-lived native-client pairing code from Paseo's
terminal:

```bash
codex remote-control pair
```

Enter that code in the native Codex client. Treat it as a secret and do not
paste it into add-on logs or configuration. If Remote Control is not wanted,
disable `codex_remote_control` in the add-on configuration.

## Home Assistant MCP

`ha_mcp_url` is optional. Leave it unset or blank to disable Home Assistant
MCP; Paseo still provides its own orchestration MCP server. When a URL is
provided, the startup script validates and probes it without printing the
URL. Codex receives the same safety policy as the reference `hass-codex`
add-on: workspace writes are limited to `/config`, network access is
disabled, and Home Assistant MCP writes require approval.

Paseo injects its own capability-scoped `paseo` MCP server into launched agents while preserving the global `home_assistant` MCP server.

The image includes four provider choices: Codex (`codex`), Claude Code
(`claude`), OpenCode (`opencode`), and Pi (`pi`). Each provider still requires
its own native login or API configuration; installing a CLI does not
authenticate it automatically. Codex login is performed from the Paseo
terminal as described above.

## Agent tooling

The image includes a compact Debian Bookworm toolset for normal coding and
Home Assistant maintenance: `rg`, `grep`, `sed`, `awk`, `fd`, `find`, `file`,
`patch`, `diff`, `jq`, `yq`, `git`, `ssh`, `rsync`, `python3` with virtual
environments, `tree`, `less`, and common tar/zip/bzip2/xz utilities. `fd` is
provided as a compatibility alias for Debian's `fdfind`. These tools do not
change the Codex policy: Codex agents remain restricted to `/config` for
writes and have network access disabled.

## Troubleshooting

- If startup reports an unreachable MCP endpoint, check the raw URL and ensure it is reachable from an add-on container.
- If Codex is unauthenticated, open the Paseo terminal and repeat `codex login --device-auth`.
- If the panel is blank, inspect browser requests for the current ingress prefix and review the add-on logs for Nginx or daemon health failures.
- Back up `/config` before testing write operations.
