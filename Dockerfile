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

# Podman/Buildah/Skopeo for running containers inside this container (needs the
# nesting options in docker-compose.yml: privileged, /dev/fuse, unconfined seccomp).
RUN apt-get update && apt-get install -y --no-install-recommends \
      podman buildah skopeo uidmap slirp4netns fuse-overlayfs containers-storage crun iptables \
    && rm -rf /var/lib/apt/lists/*

# Rootful Podman config for the nested environment. Image layers live in the
# `opencode-containers` volume at /var/lib/containers; runroot is ephemeral.
RUN set -eux; \
    mkdir -p /etc/containers /var/lib/containers/storage /run/containers/storage; \
    printf '%s\n' \
      '[engine]' \
      'cgroup_manager = "cgroupfs"' \
      'events_logger = "file"' \
      'runtime = "crun"' \
      > /etc/containers/containers.conf; \
    printf '%s\n' \
      '[storage]' \
      'driver = "overlay"' \
      'runroot = "/run/containers/storage"' \
      'graphroot = "/var/lib/containers/storage"' \
      '' \
      '[storage.options.overlay]' \
      'mount_program = "/usr/bin/fuse-overlayfs"' \
      'mountopt = "nodev"' \
      > /etc/containers/storage.conf; \
    touch /etc/containers/registries.conf; \
    grep -q '^unqualified-search-registries' /etc/containers/registries.conf \
      || echo 'unqualified-search-registries = ["docker.io"]' >> /etc/containers/registries.conf; \
    grep -q '^node:' /etc/subuid || echo 'node:100000:65536' >> /etc/subuid; \
    grep -q '^node:' /etc/subgid || echo 'node:100000:65536' >> /etc/subgid; \
    podman --version; buildah --version; skopeo --version

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
