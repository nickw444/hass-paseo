# Changelog

## 0.1.15

- Run Codex without its nested Linux bubblewrap sandbox.
- Removed the add-on `SYS_ADMIN` capability and custom AppArmor profile.
- Treat the add-on container as the Codex security boundary so provider
  runtimes can execute their native scripts and shared libraries.

## 0.1.14

- Enabled Codex live web search for agents launched by Paseo.
- Kept Codex shell network access disabled; web search uses Codex's native
  provider capability.

## 0.1.13

- Allowed executable scripts under `/config` and `/tmp/paseo-work` within the
  add-on AppArmor profile.
- Added `/tmp/paseo-work` as an ephemeral Codex writable root.

## 0.1.12

- Allowed the Copilot JavaScript launcher to execute through its `/usr/bin/env`
  entry point under the custom AppArmor profile.

## 0.1.11

- Allowed the native GitHub Copilot runtime to execute under the custom
  AppArmor profile.
- Preserved Copilot startup diagnostics when a runtime check fails.

## 0.1.10

- Fixed add-on startup under the custom AppArmor profile by allowing the
  supervisor script at `/run.sh` to execute.

## 0.1.9

- Configured the Home Assistant MCP server for the native user configuration
  of every built-in provider when `ha_mcp_url` is set.
- Added the pinned Pi MCP adapter so Pi can use the same MCP configuration.
- Preserved unrelated provider settings and restore add-on-managed entries when
  Home Assistant MCP is disabled.

## 0.1.8

- Added a Home Assistant AppArmor profile for Codex bubblewrap namespaces.
- Requested only `SYS_ADMIN` for the add-on runtime.
- Added a startup preflight that reports unusable host sandbox settings before
  the Paseo panel starts.

## 0.1.7

- Persisted SSH, Git, and known-host paths in the add-on data directory.

## 0.1.6

- Added the official Home Assistant ha CLI for Supervisor management.
- Enabled the Home Assistant Supervisor API with the manager role.
- Authenticated ha automatically from the Supervisor-injected SUPERVISOR_TOKEN.
- Kept the token ephemeral; it is not written to image layers or persistent
  add-on data.

## 0.1.5

- Added the GitHub Copilot CLI as a built-in Paseo provider.
- Added the Cursor Agent CLI for Paseo's ACP provider catalog.
- Pinned the Cursor Agent release and verified its amd64 and aarch64 archives
  with SHA-256 checksums.
- Persisted Cursor and GitHub Copilot configuration and authentication below
  the add-on data directory.

## 0.1.4

- Added the GitHub CLI for repository, issue, pull request, and GitHub API
  workflows from the Paseo terminal.
- Persisted GitHub CLI authentication, SSH keys, SSH configuration, and known
  hosts in the add-on data directory.

## 0.1.3

- Set Bash as the default shell for terminals opened from the Paseo web
  interface.

## 0.1.2

- Canonicalize and validate Home Assistant ingress paths before rewriting
  browser responses or injecting runtime state.
- Guard Expo Router's invalid bare `//` root path under ingress.
- Rewrite manifest and touch-icon links beneath the active ingress prefix.

## 0.1.1

- Allow Home Assistant ingress to forward its external Host header while
  retaining the Supervisor-only Nginx boundary.

## 0.1.0

- Initial Home Assistant ingress POC for Paseo.
- Added pinned Paseo v0.7.2 with dynamic ingress-path patches.
- Added the real Paseo daemon host, pinned Codex app-server binary, and
  Claude Code, OpenCode, and Pi provider CLIs.
- Added persistent XDG/provider state directories and bubblewrap for Codex's
  workspace sandbox.
- Added optional Home Assistant MCP configuration and terminal-driven Codex
  Remote Control startup.
- Added Debian coding utilities including ripgrep, fd, yq, Python virtual
  environments, rsync, archive tools, and file inspection helpers.
