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

Terminals opened from the Paseo web UI start with `/bin/bash`. The container
sets both the image `SHELL` environment and the supervisor's runtime `SHELL`
value so Paseo's POSIX terminal resolver consistently selects Bash.

## Authentication boundaries

There are three independent identities:

1. Home Assistant authenticates access to the administrator-only ingress panel.
2. Paseo authenticates paired remote devices and its encrypted relay relationship.
3. Codex authenticates the OpenAI/Codex provider.

The container also includes the official Home Assistant ha CLI. The add-on
requests hassio_api: true with the manager role. Home Assistant Supervisor
injects a short-lived SUPERVISOR_TOKEN when the add-on starts. The startup
script keeps that variable available and sets the Supervisor endpoint to
http://supervisor, so commands such as ha info and ha core info work in Paseo
terminals without an interactive login.

The Supervisor token is not stored in /data/paseo-home, a config file, or the
image. It can rotate when Home Assistant restarts or the add-on updates. The
manager role gives agents access to Supervisor management commands. Use agent
approval controls and review commands before execution.

The add-on deliberately does not force Codex login during startup. Authenticate interactively from Paseo's terminal:

```bash
codex login --device-auth
```

Codex credentials persist below `/data/paseo-home/.codex`; Claude Code credentials use `/data/paseo-home/.claude`; GitHub Copilot uses `/data/paseo-home/.copilot`; Cursor uses the persistent HOME/XDG paths, including `/data/paseo-home/.config/cursor` and `/data/paseo-home/.cursor`; and OpenCode and Pi use the persistent HOME/XDG directories under `/data/paseo-home`. Paseo state and relay pairing persist below `/data/paseo-home/.paseo`.

GitHub CLI authentication uses `GH_CONFIG_DIR=/data/paseo-home/.config/gh`.
SSH keys, SSH configuration, and `known_hosts` use `/data/paseo-home/.ssh`.
These paths are inside the persistent add-on data directory, so they survive
container restarts and add-on image updates. The startup script creates the
directories and sets restrictive directory permissions. It does not generate,
copy, or overwrite authentication files or SSH keys. Treat these paths as
secrets and include them in the add-on backup policy.

Authenticate GitHub CLI from the Paseo terminal with `gh auth login`. Select
SSH as the Git protocol if you want GitHub CLI to use an SSH key. Use
`--skip-ssh-key` if you want to manage the key yourself. Do not put a token in
add-on options or logs.

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

When the URL is set, the add-on writes the `home_assistant` server to the
native user configuration for each built-in provider. It preserves unrelated
settings and stores a small ownership record below `/data/paseo-home/.paseo`.
If the option is later cleared, the add-on restores an entry that it created
unless the user changed that entry. The URL is not printed in logs.

The provider files are:

- Codex: `/data/paseo-home/.codex/config.toml`.
- Claude Code: `/data/paseo-home/.claude.json`.
- OpenCode 1.18: `/data/paseo-home/.config/opencode/opencode.json`.
- Cursor Agent: `/data/paseo-home/.cursor/mcp.json`.
- GitHub Copilot: `/data/paseo-home/.copilot/mcp-config.json`.
- Pi: `/data/paseo-home/.pi/agent/mcp.json`.

The add-on includes the pinned `pi-mcp-adapter` extension and registers it in
Pi's persistent settings. This enables Pi's native MCP support. Paseo also
adds its own capability-scoped `paseo` MCP server to launched agents by its
normal upstream mechanism. The Home Assistant entry remains a provider-owned
configuration entry, so it is also available to provider sessions started in
the Paseo terminal.

The add-on uses the provider-native schemas. Claude uses an HTTP entry with
`type` and `url`, OpenCode 1.18 uses `mcp.home_assistant` with
`type: "remote"`, Copilot uses `type: "http"` and `tools: ["*"]`, and Pi
uses its adapter's `url`, `auth: false`, and `oauth: false` fields. See the
[Claude MCP documentation](https://code.claude.com/docs/en/mcp), [OpenCode MCP documentation](https://opencode.ai/v2/docs/mcp-servers), [Cursor MCP documentation](https://prod.cursor.com/docs/mcp), and [Copilot CLI MCP documentation](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers) for the native formats.

The image includes six provider choices: Codex (`codex`), Claude Code
(`claude`), OpenCode (`opencode`), Pi (`pi`), GitHub Copilot (`copilot`), and
Cursor (`cursor-agent`). Each provider still requires its own native login or
API configuration; installing a CLI does not authenticate it automatically.
Codex login is performed from the Paseo terminal as described above.

To authenticate GitHub Copilot from the Paseo terminal, use the device flow:

```bash
copilot login --device-code
```

Copilot stores its configuration and authentication below
`/data/paseo-home/.copilot`. An active GitHub Copilot subscription is required.
Do not assume that GitHub CLI authentication alone means that Copilot CLI is
authenticated.

To use Cursor, open Paseo's provider catalog and select **Cursor**. Paseo
launches its ACP command as `cursor-agent acp`. Authenticate from the Paseo
terminal with `cursor-agent login`, or provide `CURSOR_API_KEY` for a headless
workflow. Cursor configuration and authentication remain below the persistent
`/data/paseo-home` directory. Cursor Agent is a beta service and requires a
Cursor account or API access.

## Agent tooling

The image includes a compact Debian Bookworm toolset for normal coding and
Home Assistant maintenance: `rg`, `grep`, `sed`, `awk`, `fd`, `find`, `file`,
`patch`, `diff`, `jq`, `yq`, `git`, `gh`, `ssh`, `rsync`, `python3` with virtual
environments, `tree`, `less`, and common tar/zip/bzip2/xz utilities. `fd` is
provided as a compatibility alias for Debian's `fdfind`. These tools do not
change the Codex policy: Codex agents remain restricted to `/config` for
writes and have network access disabled.

## Codex sandbox

The add-on requests the `SYS_ADMIN` capability and ships a custom Home
Assistant AppArmor profile in `apparmor.txt`. These permissions let Codex use
bubblewrap to create its inner Linux sandbox. The add-on does not enable
`full_access`, host networking, or unrestricted Codex access.

At startup, the add-on runs a bubblewrap preflight check. If the host kernel,
container runtime, or Supervisor security policy does not allow the required
user and network namespaces, startup stops with a diagnostic. This is safer
than starting the panel and failing only when an agent reads a file.

The Codex policy remains `workspace-write` with `/config` as the only writable
root and network access disabled. A Home Assistant OS or Supervisor update can
change the available namespace policy. If the preflight fails, review the
add-on log and confirm that the installation uses a supported Home Assistant
OS/Supervisor version and a native `amd64` or `aarch64` host. Do not work
around the failure by enabling Codex Full Access unless you accept that agents
can access all files and network resources visible inside the container.

## Troubleshooting

- If startup reports an unreachable MCP endpoint, check the raw URL and ensure it is reachable from an add-on container.
- If Codex is unauthenticated, open the Paseo terminal and repeat `codex login --device-auth`.
- If the panel is blank or the browser reports `URL constructor: // is not a valid URL`, update to add-on `0.1.3` or newer. The proxy validates Home Assistant's `X-Ingress-Path` and the web bundle contains a narrow Expo Router root-path guard. Inspect browser requests to confirm that JavaScript, CSS, manifest, and WebSocket URLs all begin with the current `/api/hassio_ingress/<token>` prefix; do not reuse a cached ingress URL after opening a new sidebar session.
- Review the add-on logs for Nginx or daemon health failures. Requests without a valid Supervisor ingress source are rejected by design.
- Back up `/config` before testing write operations.
