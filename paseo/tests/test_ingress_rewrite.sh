#!/usr/bin/env bash
set -euo pipefail

sentinel='/__PASEO_INGRESS__'
sample='<head><script src="/__PASEO_INGRESS__/_expo/static/js/index.js"></script></head><script>const ws="ws://host/__PASEO_INGRESS__/ws"</script>'
rewrite() {
  local prefix="$1"
  printf '%s' "${sample}" | sed "s#${sentinel}#${prefix}#g"
}

first="$(rewrite /api/hassio_ingress/paseo)"
second="$(rewrite /api/hassio_ingress/paseo-session-2)"
grep -q '/api/hassio_ingress/paseo/_expo' <<<"${first}"
grep -q '/api/hassio_ingress/paseo-session-2/_expo' <<<"${second}"
if grep -q "${sentinel}" <<<"${first}${second}"; then exit 1; fi
if grep -q 'paseo-session-2' <<<"${first}"; then exit 1; fi
grep -q 'ws://host/api/hassio_ingress/paseo/ws' <<<"${first}"

if command -v nginx >/dev/null 2>&1; then
  nginx -t -c "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/nginx.conf" 2>/dev/null
fi

echo "ingress rewrite checks passed"
