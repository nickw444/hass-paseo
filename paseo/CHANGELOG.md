# Changelog

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
