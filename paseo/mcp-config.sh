#!/usr/bin/env bash

# Provider-native MCP configuration helpers.  Paseo starts the provider CLIs,
# so the supported way to make an MCP server available to every built-in
# provider is to write each provider's own user-global configuration.
# shellcheck disable=SC2016

set -Eeuo pipefail

MCP_MANAGED_STATE="${PASEO_HOME}/ha-mcp-managed.json"

mcp_state_init() {
  if [[ ! -e "${MCP_MANAGED_STATE}" ]]; then
    local tmp
    tmp="$(mktemp "${MCP_MANAGED_STATE}.XXXXXX")"
    printf '{"providers":{}}\n' >"${tmp}"
    chmod 600 "${tmp}"
    mv -f "${tmp}" "${MCP_MANAGED_STATE}"
    return
  fi

  jq empty "${MCP_MANAGED_STATE}" >/dev/null 2>&1 ||
    fatal "Managed Home Assistant MCP state is not valid JSON: ${MCP_MANAGED_STATE}"
}

mcp_state_update() {
  local filter="${!#}"
  local tmp
  local -a jq_args=("$@")
  unset 'jq_args[${#jq_args[@]}-1]'
  tmp="$(mktemp "${MCP_MANAGED_STATE}.XXXXXX")"
  jq "${jq_args[@]}" "${filter}" "${MCP_MANAGED_STATE}" >"${tmp}" || {
    rm -f "${tmp}"
    fatal "Could not update managed Home Assistant MCP state."
  }
  chmod 600 "${tmp}"
  mv -f "${tmp}" "${MCP_MANAGED_STATE}"
}

mcp_json_shape() {
  case "$1" in
    claude|cursor) printf '%s\n' mcpServers ;;
    copilot) printf '%s\n' copilotMcpServers ;;
    pi) printf '%s\n' piMcpServers ;;
    opencode) printf '%s\n' mcp ;;
    *) fatal "Unknown provider MCP configuration: $1" ;;
  esac
}

mcp_json_entry() {
  local path="$1"
  local shape="$2"
  if [[ ! -e "${path}" ]]; then
    printf 'null\n'
    return
  fi
  jq -c --arg shape "${shape}" '
    if type != "object" then error("root must be an object") else . end |
    if ($shape == "mcpServers" or $shape == "piMcpServers" or $shape == "copilotMcpServers") then (.mcpServers.home_assistant // null)
    else (.mcp.home_assistant // null)
    end
  ' "${path}" || fatal "Invalid JSON MCP configuration: ${path}"
}

mcp_json_write() {
  local path="$1"
  local shape="$2"
  local url="$3"
  local directory tmp

  directory="$(dirname "${path}")"
  mkdir -p "${directory}"
  chmod 700 "${directory}"
  if [[ -e "${path}" ]]; then
    jq empty "${path}" >/dev/null 2>&1 || fatal "Invalid JSON MCP configuration: ${path}"
  fi

  tmp="$(mktemp "${path}.XXXXXX")"
  if [[ "${shape}" == mcpServers || "${shape}" == piMcpServers || "${shape}" == copilotMcpServers ]]; then
    if [[ "${shape}" == piMcpServers ]]; then
      jq --arg url "${url}" '
        if type != "object" then error("root must be an object") else . end |
        if .mcpServers == null then .mcpServers = {}
        elif (.mcpServers | type) != "object" then error("mcpServers must be an object")
        else . end |
        .mcpServers.home_assistant = {url: $url, auth: false, oauth: false}
      ' "${path}" 2>/dev/null >"${tmp}" || {
        if [[ ! -e "${path}" ]]; then
          printf '{}\n' | jq --arg url "${url}" '.mcpServers = {home_assistant: {url: $url, auth: false, oauth: false}}' >"${tmp}"
        else
          rm -f "${tmp}"
          fatal "Could not update JSON MCP configuration: ${path}"
        fi
      }
    elif [[ "${shape}" == copilotMcpServers ]]; then
      jq --arg url "${url}" '
        if type != "object" then error("root must be an object") else . end |
        if .mcpServers == null then .mcpServers = {}
        elif (.mcpServers | type) != "object" then error("mcpServers must be an object")
        else . end |
        .mcpServers.home_assistant = {type: "http", url: $url, tools: ["*"]}
      ' "${path}" 2>/dev/null >"${tmp}" || {
        if [[ ! -e "${path}" ]]; then
          printf '{}\n' | jq --arg url "${url}" '.mcpServers = {home_assistant: {type: "http", url: $url, tools: ["*"]}}' >"${tmp}"
        else
          rm -f "${tmp}"
          fatal "Could not update JSON MCP configuration: ${path}"
        fi
      }
    else
      jq --arg url "${url}" '
        if type != "object" then error("root must be an object") else . end |
        if .mcpServers == null then .mcpServers = {}
        elif (.mcpServers | type) != "object" then error("mcpServers must be an object")
        else . end |
        .mcpServers.home_assistant = {type: "http", url: $url}
      ' "${path}" 2>/dev/null >"${tmp}" || {
        if [[ ! -e "${path}" ]]; then
          printf '{}\n' | jq --arg url "${url}" '.mcpServers = {home_assistant: {type: "http", url: $url}}' >"${tmp}"
        else
          rm -f "${tmp}"
          fatal "Could not update JSON MCP configuration: ${path}"
        fi
      }
    fi
  else
    jq --arg url "${url}" '
      if type != "object" then error("root must be an object") else . end |
      if .mcp == null then .mcp = {}
      elif (.mcp | type) != "object" then error("mcp must be an object")
      else . end |
      .mcp.home_assistant = {type: "remote", url: $url, enabled: true}
    ' "${path}" 2>/dev/null >"${tmp}" || {
      if [[ ! -e "${path}" ]]; then
        printf '{}\n' | jq --arg url "${url}" '.mcp = {home_assistant: {type: "remote", url: $url, enabled: true}}' >"${tmp}"
      else
        rm -f "${tmp}"
        fatal "Could not update JSON MCP configuration: ${path}"
      fi
    }
  fi
  chmod 600 "${tmp}"
  mv -f "${tmp}" "${path}"
}

mcp_json_restore() {
  local path="$1"
  local shape="$2"
  local provider="$3"
  local current managed previous tmp

  [[ -e "${path}" ]] || {
    mcp_state_update --arg provider "${provider}" 'del(.providers[$provider])'
    return
  }
  jq empty "${path}" >/dev/null 2>&1 || fatal "Invalid JSON MCP configuration: ${path}"
  current="$(mcp_json_entry "${path}" "${shape}")"
  managed="$(jq -c --arg provider "${provider}" '.providers[$provider].managed // null' "${MCP_MANAGED_STATE}")"
  if [[ "${current}" != "${managed}" ]]; then
    echo "[WARN] ${provider} Home Assistant MCP entry changed by the user; leaving it in place." >&2
    mcp_state_update --arg provider "${provider}" 'del(.providers[$provider])'
    return
  fi

  previous="$(jq -c --arg provider "${provider}" '.providers[$provider].previous // null' "${MCP_MANAGED_STATE}")"
  tmp="$(mktemp "${path}.XXXXXX")"
  if [[ "${shape}" == mcpServers || "${shape}" == piMcpServers || "${shape}" == copilotMcpServers ]]; then
    if [[ "${previous}" == null ]]; then
      jq 'del(.mcpServers.home_assistant)' "${path}" >"${tmp}"
    else
      jq --argjson value "${previous}" '.mcpServers.home_assistant = $value' "${path}" >"${tmp}"
    fi
  elif [[ "${previous}" == null ]]; then
    jq 'del(.mcp.home_assistant)' "${path}" >"${tmp}"
  else
    jq --argjson value "${previous}" '.mcp.home_assistant = $value' "${path}" >"${tmp}"
  fi
  chmod 600 "${tmp}"
  mv -f "${tmp}" "${path}"
  mcp_state_update --arg provider "${provider}" 'del(.providers[$provider])'
}

configure_json_provider_mcp() {
  local provider="$1"
  local path="$2"
  local url="$3"
  local shape previous current managed

  shape="$(mcp_json_shape "${provider}")"
  if [[ -z "${url}" ]]; then
    if jq -e --arg provider "${provider}" '.providers[$provider] != null' "${MCP_MANAGED_STATE}" >/dev/null 2>&1; then
      mcp_json_restore "${path}" "${shape}" "${provider}"
    fi
    return
  fi

  if [[ ! -e "${path}" ]]; then
    previous=null
  else
    previous="$(mcp_json_entry "${path}" "${shape}")"
  fi

  if ! jq -e --arg provider "${provider}" '.providers[$provider] != null' "${MCP_MANAGED_STATE}" >/dev/null 2>&1; then
    mcp_state_update --arg provider "${provider}" --argjson previous "${previous}" \
      '.providers[$provider] = {previous: $previous, managed: null}'
  fi

  mcp_json_write "${path}" "${shape}" "${url}"
  current="$(mcp_json_entry "${path}" "${shape}")"
  managed="$(jq -c --arg provider "${provider}" '.providers[$provider].managed // null' "${MCP_MANAGED_STATE}")"
  if [[ "${current}" != "${managed}" ]]; then
    mcp_state_update --arg provider "${provider}" --argjson managed "${current}" \
      '.providers[$provider].managed = $managed'
  fi
}

ensure_pi_mcp_adapter() {
  local settings="${PI_CODING_AGENT_DIR}/settings.json"
  local adapter_dir=/usr/local/lib/node_modules/pi-mcp-adapter
  local tmp

  [[ -d "${adapter_dir}" ]] || fatal "Pi MCP adapter is missing from the runtime image."
  if [[ -e "${settings}" ]]; then
    jq empty "${settings}" >/dev/null 2>&1 || fatal "Pi settings are not valid JSON: ${settings}"
  fi
  tmp="$(mktemp "${settings}.XXXXXX")"
  if [[ -e "${settings}" ]]; then
    jq --arg adapter_dir "${adapter_dir}" '
      if type != "object" then error("settings root must be an object") else . end |
      if .packages == null then .packages = []
      elif (.packages | type) != "array" then error("packages must be an array")
      else . end |
      if any(.packages[]?;
        (type == "string" and (contains("pi-mcp-adapter") or . == $adapter_dir)) or
        (type == "object" and ((.source // "" | tostring) | contains("pi-mcp-adapter")))
      ) then . else .packages += [$adapter_dir] end
    ' "${settings}" >"${tmp}" || { rm -f "${tmp}"; fatal "Could not update Pi settings."; }
  else
    jq -n --arg adapter_dir "${adapter_dir}" '{packages: [$adapter_dir]}' >"${tmp}"
  fi
  chmod 600 "${tmp}"
  mv -f "${tmp}" "${settings}"
}

configure_provider_mcp() {
  local url="$1"

  mcp_state_init
  configure_json_provider_mcp claude "${HOME}/.claude.json" "${url}"
  configure_json_provider_mcp opencode "${XDG_CONFIG_HOME}/opencode/opencode.json" "${url}"
  configure_json_provider_mcp cursor "${HOME}/.cursor/mcp.json" "${url}"
  configure_json_provider_mcp copilot "${COPILOT_HOME}/mcp-config.json" "${url}"
  configure_json_provider_mcp pi "${PI_CODING_AGENT_DIR}/mcp.json" "${url}"
}
