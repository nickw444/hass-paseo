# Home Assistant Paseo

This repository packages [Paseo](https://github.com/getpaseo/paseo) as a Home Assistant add-on. It embeds the Paseo web UI in Home Assistant ingress, mounts the Home Assistant configuration as `/config`, runs the real Paseo daemon, and provides Codex, Claude Code, OpenCode, and Pi as selectable agent CLIs. Codex is configured with the Home Assistant MCP server.

This is a proof of concept. Back up Home Assistant before allowing an agent to edit `/config`.

## Licensing

The original Home Assistant add-on and integration material is MIT-licensed
to Nick Whyte. Paseo and the Paseo-derived patches retain their upstream
Apache-2.0 licensing and attribution; see [NOTICE](NOTICE) and
[`paseo/vendor/paseo/LICENSE`](paseo/vendor/paseo/LICENSE).

## Install

Add this repository to the Home Assistant add-on store, install **Paseo**, and start it. The add-on is administrator-only and is exposed through the Home Assistant sidebar; no host port is published.

`ha_mcp_url` is optional. Set it to the raw MCP URL printed by the Home
Assistant MCP add-on if you want Home Assistant tools; leave it blank to run
without that MCP server. Do not use `localhost` or `127.0.0.1`; those names
resolve inside the Paseo container.

## First login

Paseo owns remote-device pairing. Codex owns its OpenAI provider credential. After opening the sidebar panel, open Paseo's terminal and run:

```bash
codex login --device-auth
```

Complete the displayed verification flow. The credential is stored in the persistent add-on data volume and is not recreated on every restart. The other provider CLIs likewise require their normal native login or API configuration when selected.

## Codex Remote Control

Remote Control is enabled by default, but first requires the terminal login
above followed by an add-on restart. Pair native clients manually from a Paseo
terminal with:

```bash
codex remote-control pair
```

No pairing code is generated during startup.

## Paseo remote access

Use Paseo's normal Settings → host → Pair a device flow to enable relay access and pair a mobile or desktop client. The relay is end-to-end encrypted. Home Assistant ingress authentication and Paseo pairing are separate controls.

If an older installation shows `URL constructor: // is not a valid URL` in
the browser console, update the add-on to `0.1.2` or newer so the ingress path
normalization and Expo Router root-path fix are installed.

## Development

The Paseo source is a Git submodule pinned to v0.7.2. Run the local checks with:

```bash
paseo/tests/test_static.sh
paseo/tests/test_ingress_rewrite.sh
```
