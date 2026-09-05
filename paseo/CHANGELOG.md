# Changelog

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
