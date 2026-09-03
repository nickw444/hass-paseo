# syntax=docker/dockerfile:1

ARG NODE_IMAGE=node:22-bookworm-slim
FROM --platform=$BUILDPLATFORM ${NODE_IMAGE} AS paseo-web-builder

ARG PASEO_VERSION=0.7.2
ARG PASEO_COMMIT=9400a49af670fdb5db4af58e73f8df98588dbea9
ENV ONNXRUNTIME_NODE_INSTALL=skip
WORKDIR /tmp/paseo-src
COPY vendor/paseo/ ./
COPY patches/ /tmp/paseo-patches/

RUN apt-get update && apt-get install -y --no-install-recommends git patch ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    test "$(node -p "require('./package.json').version")" = "${PASEO_VERSION}"; \
    node -e 'const fs=require("node:fs"); const p=JSON.parse(fs.readFileSync("package.json","utf8")); delete p.scripts.prepare; fs.writeFileSync("package.json", JSON.stringify(p)+"\n")'; \
    git apply --check /tmp/paseo-patches/0001-ingress-base-url-build.patch; \
    git apply --check /tmp/paseo-patches/0002-ingress-websocket-path.patch; \
    git apply /tmp/paseo-patches/0001-ingress-base-url-build.patch; \
    git apply /tmp/paseo-patches/0002-ingress-websocket-path.patch; \
    npm ci

RUN CI=1 EXPO_NO_TELEMETRY=1 PASEO_WEB_BASE_URL=/__PASEO_INGRESS__ npm run build:web --workspace=@getpaseo/app

FROM ghcr.io/getpaseo/paseo:0.7.2

ARG PASEO_VERSION=0.7.2
ARG BUILD_ARCH
ARG CODEX_VERSION=0.152.1
ARG CODEX_RELEASE_TAG=rust-v0.152.1
ARG CLAUDE_CODE_VERSION=2.1.259
ARG OPENCODE_VERSION=1.18.27
ARG PI_CODING_AGENT_VERSION=0.73.1

USER root
ENV HOME=/data/paseo-home \
    PASEO_HOME=/data/paseo-home/.paseo \
    CODEX_HOME=/data/paseo-home/.codex \
    CODEX_VERSION=${CODEX_VERSION} \
    CLAUDE_CONFIG_DIR=/data/paseo-home/.claude \
    XDG_CONFIG_HOME=/data/paseo-home/.config \
    XDG_CACHE_HOME=/data/paseo-home/.cache \
    XDG_DATA_HOME=/data/paseo-home/.local/share \
    XDG_STATE_HOME=/data/paseo-home/.local/state \
    PASEO_LISTEN=127.0.0.1:6767 \
    PASEO_WEB_UI_ENABLED=true \
    PASEO_WEB_UI_DIST_DIR=/opt/hass-paseo-web-ui \
    PASEO_LOG_FORMAT=json \
    PASEO_LOG_LEVEL=info \
    ONNXRUNTIME_NODE_INSTALL=skip

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash bzip2 bubblewrap ca-certificates coreutils curl diffutils fd-find file \
      findutils gawk git grep jq less nginx openssh-client patch procps python3 \
      python3-venv ripgrep rsync sed tar tree unzip xz-utils yq zip \
    && rm -rf /var/lib/apt/lists/*

# The web bundle is only the browser half of Paseo.  Assert that the runtime
# image also contains the pinned CLI/daemon host that run.sh will supervise.
RUN set -eux; \
    command -v paseo; \
    paseo --version | grep -F "${PASEO_VERSION}"

RUN set -eux; \
    ln -s /usr/bin/fdfind /usr/local/bin/fd; \
    for command in bash bzip2 bwrap curl diff fd file find gawk git grep jq less patch \
      python3 rg rsync sed tar tree unzip yq zip; do \
      command -v "${command}"; \
    done

RUN set -eux; \
    case "${BUILD_ARCH}" in \
      amd64) target=x86_64 ;; \
      aarch64) target=aarch64 ;; \
      *) echo "Unsupported BUILD_ARCH: ${BUILD_ARCH}" >&2; exit 1 ;; \
    esac; \
    archive="codex-package-${target}-unknown-linux-musl.tar.gz"; \
    base="https://github.com/openai/codex/releases/download/${CODEX_RELEASE_TAG}"; \
    mkdir -p /tmp/codex /opt/codex; \
    curl --fail --location --retry 3 --output "/tmp/codex/${archive}" "${base}/${archive}"; \
    curl --fail --location --retry 3 --output /tmp/codex/SHA256SUMS "${base}/codex-package_SHA256SUMS"; \
    grep "  ${archive}$" /tmp/codex/SHA256SUMS > /tmp/codex/SHA256SUMS.selected; \
    (cd /tmp/codex && sha256sum -c SHA256SUMS.selected); \
    tar -xzf "/tmp/codex/${archive}" -C /opt/codex; \
    test -x /opt/codex/bin/codex; \
    ln -s /opt/codex/bin/codex /usr/local/bin/codex; \
    if [ -x /opt/codex/bin/codex-code-mode-host ]; then ln -s /opt/codex/bin/codex-code-mode-host /usr/local/bin/codex-code-mode-host; fi; \
    /usr/local/bin/codex --version | grep -F "${CODEX_VERSION}"; \
    /usr/local/bin/codex app-server --help >/dev/null; \
    rm -rf /tmp/codex

# Install the provider CLIs from their official, version-pinned npm packages.
# Their postinstall scripts select the native Linux binary for the target
# architecture (Claude and OpenCode) while Pi is a Node CLI.
RUN npm install --global --no-fund --no-audit \
      "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
      "opencode-ai@${OPENCODE_VERSION}" \
      "@mariozechner/pi-coding-agent@${PI_CODING_AGENT_VERSION}" \
    && command -v claude \
    && command -v opencode \
    && command -v pi \
    && claude --version \
    && opencode --version \
    && pi --version

COPY --from=paseo-web-builder /tmp/paseo-src/packages/app/dist /opt/hass-paseo-web-ui
COPY nginx.conf /paseo-nginx.conf
COPY run.sh /run.sh
RUN chmod 0755 /run.sh && mkdir -p /data/paseo-home /var/lib/nginx /var/log/nginx /run/nginx

WORKDIR /config
EXPOSE 8099
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/run.sh"]
