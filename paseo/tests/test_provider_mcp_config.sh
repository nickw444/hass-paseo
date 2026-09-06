#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

export HOME="${tmp}/home"
export PASEO_HOME="${HOME}/.paseo"
export XDG_CONFIG_HOME="${HOME}/.config"
export COPILOT_HOME="${HOME}/.copilot"
export PI_CODING_AGENT_DIR="${HOME}/.pi/agent"
mkdir -p "${PASEO_HOME}" "${HOME}/.cursor" "${COPILOT_HOME}" "${PI_CODING_AGENT_DIR}" "${XDG_CONFIG_HOME}/opencode"

fatal() {
  echo "${1}" >&2
  exit 1
}

# shellcheck disable=SC1091
source "${root}/mcp-config.sh"

printf '%s\n' '{"theme":"dark"}' >"${HOME}/.claude.json"
printf '%s\n' '{"mcp":{"other":{"type":"remote","url":"https://example.invalid/mcp"}}}' >"${XDG_CONFIG_HOME}/opencode/opencode.json"
printf '%s\n' '{"mcpServers":{"other":{"url":"https://example.invalid/mcp"}}}' >"${HOME}/.cursor/mcp.json"
printf '%s\n' '{"mcpServers":{"other":{"type":"http","url":"https://example.invalid/mcp","tools":["*"]}}}' >"${COPILOT_HOME}/mcp-config.json"
printf '%s\n' '{"settings":{"toolPrefix":"mcp"}}' >"${PI_CODING_AGENT_DIR}/mcp.json"

url='http://homeassistant.local:8123/api/mcp'
configure_provider_mcp "${url}"

jq -e --arg url "${url}" '.theme == "dark" and .mcpServers.home_assistant == {type:"http",url:$url}' "${HOME}/.claude.json" >/dev/null
jq -e --arg url "${url}" '.mcp.other.url == "https://example.invalid/mcp" and .mcp.home_assistant == {type:"remote",url:$url,enabled:true}' "${XDG_CONFIG_HOME}/opencode/opencode.json" >/dev/null
jq -e --arg url "${url}" '.mcpServers.other.url == "https://example.invalid/mcp" and .mcpServers.home_assistant == {type:"http",url:$url}' "${HOME}/.cursor/mcp.json" >/dev/null
jq -e --arg url "${url}" '.mcpServers.other.url == "https://example.invalid/mcp" and .mcpServers.home_assistant == {type:"http",url:$url,tools:["*"]}' "${COPILOT_HOME}/mcp-config.json" >/dev/null
jq -e --arg url "${url}" '.settings.toolPrefix == "mcp" and .mcpServers.home_assistant == {url:$url,auth:false,oauth:false}' "${PI_CODING_AGENT_DIR}/mcp.json" >/dev/null

configure_provider_mcp ""
jq -e '.mcpServers.home_assistant == null and .theme == "dark"' "${HOME}/.claude.json" >/dev/null
jq -e '.mcp.home_assistant == null and .mcp.other.url == "https://example.invalid/mcp"' "${XDG_CONFIG_HOME}/opencode/opencode.json" >/dev/null
jq -e '.mcpServers.home_assistant == null and .mcpServers.other.url == "https://example.invalid/mcp"' "${HOME}/.cursor/mcp.json" >/dev/null
jq -e '.mcpServers.home_assistant == null and .mcpServers.other.url == "https://example.invalid/mcp"' "${COPILOT_HOME}/mcp-config.json" >/dev/null
jq -e '.mcpServers.home_assistant == null and .settings.toolPrefix == "mcp"' "${PI_CODING_AGENT_DIR}/mcp.json" >/dev/null

echo "provider MCP configuration checks passed"
