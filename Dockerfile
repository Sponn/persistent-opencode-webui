# OpenCode (https://opencode.ai) web UI in a persistent container.
ARG NODE_IMAGE=node:22-bookworm-slim
FROM ${NODE_IMAGE}

# npm version/range of opencode-ai to install.
ARG OPENCODE_VERSION=latest

ENV NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false \
    SHELL=/bin/bash \
    TERM=xterm-256color

# Tools the agent shells out to.
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git g++ make openssh-client procps python3 ripgrep unzip \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    npm install -g "opencode-ai@${OPENCODE_VERSION}"; \
    command -v opencode; \
    opencode --version; \
    npm cache clean --force

# Persistent state under /data, projects under /workspace (owned by UID 1000 `node`).
ENV HOME=/data/home \
    XDG_CONFIG_HOME=/data/config \
    XDG_DATA_HOME=/data/share \
    XDG_STATE_HOME=/data/state \
    XDG_CACHE_HOME=/data/cache

RUN mkdir -p /data/home /data/config /data/share /data/state /data/cache /workspace \
    && chown -R node:node /data /workspace

USER node
WORKDIR /workspace
EXPOSE 4096

CMD ["opencode", "web", "--hostname", "0.0.0.0", "--port", "4096"]
