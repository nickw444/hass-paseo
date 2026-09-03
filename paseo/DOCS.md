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

## Home Assistant MCP

Copy the raw MCP endpoint from the HA-MCP add-on logs into the `ha_mcp_url` add-on option. The startup script validates and probes the endpoint without printing the URL. Codex receives the same safety policy as the reference `hass-codex` add-on: workspace writes are limited to `/config`, network access is disabled, and Home Assistant MCP writes require approval.

Paseo injects its own capability-scoped `paseo` MCP server into launched agents while preserving the global `home_assistant` MCP server.

The image includes four provider choices: Codex (`codex`), Claude Code
(`claude`), OpenCode (`opencode`), and Pi (`pi`). Each provider still requires
its own native login or API configuration; installing a CLI does not
authenticate it automatically. Codex login is performed from the Paseo
terminal as described above.

## Troubleshooting

- If startup reports an unreachable MCP endpoint, check the raw URL and ensure it is reachable from an add-on container.
- If Codex is unauthenticated, open the Paseo terminal and repeat `codex login --device-auth`.
- If the panel is blank, inspect browser requests for the current ingress prefix and review the add-on logs for Nginx or daemon health failures.
- Back up `/config` before testing write operations.
