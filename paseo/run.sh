#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

fatal() {
  echo "[FATAL] $1" >&2
  exit 1
}

export HOME=/data/paseo-home
# Paseo resolves its POSIX terminal command from $SHELL.  Set this explicitly
# instead of relying on the base image's login-shell entry so every terminal
# opened through the web UI starts in Bash.
export SHELL=/bin/bash
export PASEO_HOME="${HOME}/.paseo"
export CODEX_HOME="${HOME}/.codex"
export CLAUDE_CONFIG_DIR="${HOME}/.claude"
export XDG_CONFIG_HOME="${HOME}/.config"
export GH_CONFIG_DIR="${XDG_CONFIG_HOME}/gh"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"
export PASEO_LISTEN=127.0.0.1:6767
# Home Assistant ingress preserves the browser's external Host header. The
# daemon therefore must accept that authority; Nginx remains restricted to
# Supervisor ingress traffic and the daemon is still loopback-only.
export PASEO_HOSTNAMES=true
export PASEO_WEB_UI_ENABLED=true
export PASEO_WEB_UI_DIST_DIR=/opt/hass-paseo-web-ui
export PASEO_LOG_FORMAT=json
export PASEO_LOG_LEVEL=info

command -v paseo >/dev/null 2>&1 || fatal "Paseo CLI/daemon host is missing from the runtime image."
command -v nginx >/dev/null 2>&1 || fatal "Nginx is missing from the runtime image."
command -v bwrap >/dev/null 2>&1 || fatal "bubblewrap is missing from the runtime image."
command -v codex >/dev/null 2>&1 || fatal "Codex CLI is missing from the runtime image."
codex_version="$(codex --version 2>/dev/null || true)"
[[ "${codex_version}" == codex-cli\ * ]] || fatal "Codex CLI is not the real app-server-capable binary (got: ${codex_version:-unknown})."
codex app-server --help >/dev/null 2>&1 || fatal "Codex app-server command is unavailable."
codex remote-control --help >/dev/null 2>&1 || fatal "Codex Remote Control command is unavailable."
command -v claude >/dev/null 2>&1 || fatal "Claude Code CLI is missing from the runtime image."
command -v opencode >/dev/null 2>&1 || fatal "OpenCode CLI is missing from the runtime image."
command -v pi >/dev/null 2>&1 || fatal "Pi coding-agent CLI is missing from the runtime image."
command -v gh >/dev/null 2>&1 || fatal "GitHub CLI is missing from the runtime image."
gh --version >/dev/null 2>&1 || fatal "GitHub CLI is not executable."
codex_version_pin="${CODEX_VERSION:-}"
[[ -n "${codex_version_pin}" ]] || fatal "CODEX_VERSION is not set in the runtime image."

mkdir -p "${PASEO_HOME}" "${CODEX_HOME}" "${CLAUDE_CONFIG_DIR}" "${GH_CONFIG_DIR}" "${HOME}/.ssh" "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}" "${XDG_DATA_HOME}" "${XDG_STATE_HOME}"
chmod 700 "${HOME}" "${PASEO_HOME}" "${CODEX_HOME}" "${CLAUDE_CONFIG_DIR}" "${GH_CONFIG_DIR}" "${HOME}/.ssh"

[[ -d /config && -w /config ]] || fatal "/config is not present or is not writable. Check the homeassistant_config map."

options_file=/data/options.json
[[ -r "${options_file}" ]] || fatal "Home Assistant options file is missing at ${options_file}."
mcp_url="$(jq -er '.ha_mcp_url // empty' "${options_file}" 2>/dev/null || true)"
if jq -e 'has("codex_remote_control")' "${options_file}" >/dev/null 2>&1; then
  remote_enabled="$(jq -r '.codex_remote_control' "${options_file}")"
else
  remote_enabled=true
fi
case "${remote_enabled}" in
  true|false) ;;
  *) fatal "codex_remote_control must be true or false." ;;
esac

config_tmp="$(mktemp "${CODEX_HOME}/config.toml.XXXXXX")"
cat >"${config_tmp}" <<EOF
approval_policy = "on-request"
approvals_reviewer = "auto_review"
sandbox_mode = "workspace-write"
cli_auth_credentials_store = "file"

[sandbox_workspace_write]
writable_roots = ["/config"]
network_access = false

[projects."/config"]
trust_level = "trusted"
EOF
if [[ -n "${mcp_url}" ]]; then
  [[ "${mcp_url}" =~ ^https?:// ]] || fatal "ha_mcp_url must use http:// or https://."
  [[ ! "${mcp_url}" =~ ^https?://(localhost|127\.0\.0\.1|\[::1\])([/:]|$) ]] || fatal "ha_mcp_url must not point at loopback from inside the container."
  probe_status="$(curl --silent --output /dev/null --write-out '%{http_code}' --connect-timeout 5 --max-time 10 "${mcp_url}" 2>/dev/null || true)"
  case "${probe_status}" in
    200|400|405|406) ;;
    *) fatal "HA-MCP endpoint is unreachable or invalid (HTTP ${probe_status:-000})." ;;
  esac
  toml_url="$(jq -Rn --arg value "${mcp_url}" '$value')"
  cat >>"${config_tmp}" <<EOF

[mcp_servers.home_assistant]
url = ${toml_url}
enabled = true
default_tools_approval_mode = "writes"
startup_timeout_sec = 30
tool_timeout_sec = 120
EOF
else
  echo "[INFO] Home Assistant MCP is disabled because ha_mcp_url is empty." >&2
fi
chmod 600 "${config_tmp}"
mv -f "${config_tmp}" "${CODEX_HOME}/config.toml"

if [[ ! -f "${PASEO_HOME}/config.json" ]]; then
  paseo_tmp="$(mktemp "${PASEO_HOME}/config.json.XXXXXX")"
  cat >"${paseo_tmp}" <<'EOF'
{
  "$schema": "https://paseo.sh/schemas/paseo.config.v1.json",
  "version": 1,
  "daemon": {
    "relay": { "enabled": false },
    "mcp": { "enabled": true, "injectIntoAgents": true }
  }
}
EOF
  chmod 600 "${paseo_tmp}"
  mv -f "${paseo_tmp}" "${PASEO_HOME}/config.json"
fi

cd /config
remote_control_started=0
remote_control_cleanup_needed=0

prepare_codex_managed_layout() {
  local target managed_root managed_release
  case "$(uname -m)" in
    x86_64) target=x86_64-unknown-linux-musl ;;
    aarch64) target=aarch64-unknown-linux-musl ;;
    *) fatal "Unsupported container architecture: $(uname -m)." ;;
  esac
  managed_root="${CODEX_HOME}/packages/standalone"
  managed_release="${managed_root}/releases/${codex_version_pin}-${target}"
  if [[ ! -x "${managed_release}/bin/codex" || ! -x "${managed_release}/codex-resources/bwrap" ]]; then
    rm -rf "${managed_release}"
    mkdir -p "${managed_root}/releases"
    cp -a /opt/codex "${managed_release}"
    ln -sfn bin/codex "${managed_release}/codex"
  fi
  ln -sfn "releases/${codex_version_pin}-${target}" "${managed_root}/current"
  chmod 700 "${CODEX_HOME}/packages" "${managed_root}" "${managed_root}/releases" "${managed_release}"
}

# Reclaim a daemon left behind by an interrupted container stop. Paseo's
# persistent PID lock is intentionally kept under PASEO_HOME. Only ask Paseo
# to stop the prior supervisor when the recorded PID is still a Paseo process;
# otherwise remove the stale lock (this avoids PID-reuse false positives).
pid_file="${PASEO_HOME}/paseo.pid"
if [[ -f "${pid_file}" ]]; then
  lock_pid="$(jq -er '.pid // empty' "${pid_file}" 2>/dev/null || true)"
  lock_cmd=""
  if [[ "${lock_pid}" =~ ^[1-9][0-9]*$ && -r "/proc/${lock_pid}/cmdline" ]]; then
    lock_cmd="$(tr '\0' ' ' <"/proc/${lock_pid}/cmdline" 2>/dev/null || true)"
  fi
  if [[ -z "${lock_cmd}" || "${lock_cmd}" != *paseo* ]]; then
    rm -f "${pid_file}"
  else
    paseo daemon stop --force --timeout 3 >/dev/null 2>&1 || true
  fi
fi
paseo daemon start --foreground >"${HOME}/paseo-daemon.log" 2>&1 &
paseo_pid=$!

# The cleanup function is invoked indirectly by the EXIT/INT/TERM trap.
# shellcheck disable=SC2329
cleanup() {
  if (( remote_control_cleanup_needed == 1 )); then
    codex remote-control stop >/dev/null 2>&1 || true
  fi
  kill "${nginx_pid:-}" "${paseo_pid:-}" 2>/dev/null || true
  wait "${nginx_pid:-}" "${paseo_pid:-}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

healthy=0
for _ in $(seq 1 60); do
  if curl --silent --fail --max-time 2 http://127.0.0.1:6767/api/health >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 1
done
(( healthy == 1 )) || { tail -40 "${HOME}/paseo-daemon.log" >&2 || true; fatal "Paseo daemon did not become healthy."; }

paseo project create /config --json >/dev/null 2>&1 || fatal "Could not register /config as a Paseo project."

nginx -t -c /paseo-nginx.conf >/dev/null || fatal "Invalid Nginx configuration."
nginx -c /paseo-nginx.conf -g 'daemon off;' &
nginx_pid=$!

if [[ "${remote_enabled}" == true ]]; then
  if ! codex login status >/dev/null 2>&1; then
    echo "[WARN] Codex Remote Control is enabled but Codex is not authenticated. Run 'codex login --device-auth' in Paseo's terminal, then restart the add-on." >&2
  else
    prepare_codex_managed_layout
    remote_start_json="$(mktemp /tmp/codex-remote-start.XXXXXX)"
    chmod 600 "${remote_start_json}"
    remote_control_cleanup_needed=1
    if ! codex remote-control start --json >"${remote_start_json}"; then
      rm -f "${remote_start_json}"
      fatal "Codex Remote Control failed to start."
    fi
    if ! jq -e '.status == "connected"' "${remote_start_json}" >/dev/null 2>&1; then
      rm -f "${remote_start_json}"
      fatal "Codex Remote Control did not report connected status."
    fi
    rm -f "${remote_start_json}"
    remote_control_started=1
    echo "[INFO] Codex Remote Control daemon is connected. Pair native clients manually from a Paseo terminal." >&2
  fi
fi

while kill -0 "${paseo_pid}" 2>/dev/null && kill -0 "${nginx_pid}" 2>/dev/null; do
  if (( remote_control_started == 1 )) && ! codex app-server daemon version >/dev/null 2>&1; then
    fatal "Codex Remote Control daemon stopped unexpectedly."
  fi
  sleep 15
done
fatal "Paseo or Nginx exited unexpectedly."
