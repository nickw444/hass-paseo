#!/usr/bin/env bash
set -euo pipefail

sentinel='/__PASEO_INGRESS__'
sample='<head><link rel="manifest" href="/__PASEO_INGRESS__/manifest.json"><script src="/__PASEO_INGRESS__/_expo/static/js/index.js"></script></head><script>const ws="ws://host/__PASEO_INGRESS__/ws"</script>'
rewrite() {
  local prefix="$1"
  printf '%s' "${sample}" | sed "s#${sentinel}#${prefix}#g"
}

first="$(rewrite /api/hassio_ingress/paseo)"
second="$(rewrite /api/hassio_ingress/paseo-session-2)"
grep -q '/api/hassio_ingress/paseo/_expo' <<<"${first}"
grep -q '/api/hassio_ingress/paseo/manifest.json' <<<"${first}"
grep -q '/api/hassio_ingress/paseo-session-2/_expo' <<<"${second}"
if grep -q "${sentinel}" <<<"${first}${second}"; then exit 1; fi
if grep -q 'paseo-session-2' <<<"${first}"; then exit 1; fi
grep -q 'ws://host/api/hassio_ingress/paseo/ws' <<<"${first}"
if grep -q '/api/hassio_ingress/paseo//\|//api/hassio_ingress' <<<"${first}${second}"; then exit 1; fi

canonicalize() {
  local value="${1%/}"
  if [[ -z "${1}" ]]; then
    printf ''
  elif [[ "${value}" =~ ^/api/hassio_ingress/[A-Za-z0-9_-]+$ ]]; then
    printf '%s' "${value}"
  else
    return 1
  fi
}
[[ "$(canonicalize /api/hassio_ingress/token)" == /api/hassio_ingress/token ]]
[[ "$(canonicalize /api/hassio_ingress/token/)" == /api/hassio_ingress/token ]]
if canonicalize // >/dev/null 2>&1; then exit 1; fi
if canonicalize '/api/hassio_ingress/"quoted"' >/dev/null 2>&1; then exit 1; fi

if command -v nginx >/dev/null 2>&1; then
  nginx -t -c "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/nginx.conf" 2>/dev/null
fi

echo "ingress rewrite checks passed"
