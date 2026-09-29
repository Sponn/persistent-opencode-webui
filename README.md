# persistent-opencode-webui

Docker Compose setup for [OpenCode](https://opencode.ai) (`opencode web`). Settings, credentials, sessions, and workspace files persist across restarts.

## What this provides

| Service       | Purpose                                                                 |
| ------------- | ----------------------------------------------------------------------- |
| `volume-init` | One-shot (root): creates the data directories and fixes ownership, then exits with code `0`. |
| `opencode`    | Web UI and API on container port `4096`, running as root inside the container so it can install packages and system tools when needed. |

- Image: `node:22-bookworm-slim`.
- The `opencode` service runs as root inside the container (`UID/GID 0`).
- The `opencode` service runs **privileged** so the agent can run containers with Podman (see below).
- The web UI is published on **host port `4096`** by default.
- The UI binds to **`0.0.0.0`** by default.

## Security notice

This setup intentionally gives the OpenCode agent root inside the container so it can install packages and use system-level tools. That is powerful and should be treated as privileged access.

To let the agent run containers (Podman), the `opencode` container also runs with `privileged: true`, `seccomp=unconfined`, `apparmor=unconfined`, `label=disable`, the host cgroup namespace, and `/dev/fuse` exposed. **This is close to root access on the Docker host**: anyone who can use the web UI can likely take over the host. Treat access to the UI like SSH root access to the host.

If you do not need containers inside the container, set `OPENCODE_PRIVILEGED=false` (for example in `.env`) to drop privileged mode. Podman will then not work, and you can also remove the other nesting options from `docker-compose.yml`.

Before exposing this container to a network, make sure you do at least one of the following:

- bind only to localhost or a trusted private network/VPN (for example `OPENCODE_WEBUI_BIND_ADDR=127.0.0.1`),
- set a strong `OPENCODE_SERVER_PASSWORD`,
- place it behind a VPN, firewall, or authenticated reverse proxy.

Doing both (localhost/VPN binding **and** a strong password) is strongly recommended.

Do not expose the web UI directly to the public internet without additional protection.

## Quick start

From the repository directory:

```bash
docker compose up -d --build
docker compose ps -a
```

Open <http://127.0.0.1:4096> on the Docker host. In the UI, open or create a project under `/workspace`.

## Custom host port

Set `OPENCODE_WEBUI_PORT` to choose the host port. The container always listens on `4096`.

```bash
OPENCODE_WEBUI_PORT=4096 docker compose up -d --build
```

### With `sudo`

`sudo` drops variables that you set before it. Put `env` **after** `sudo` instead:

```bash
# Preflight: check the resolved port mapping first
sudo env OPENCODE_WEBUI_PORT=4096 docker compose config

# Build and start
sudo env OPENCODE_WEBUI_PORT=4096 docker compose up -d --build
```

In the `config` output, the `opencode` service should show a host bind address of `0.0.0.0` and target `4096`.

### Using a `.env` file

You can also create a `.env` file next to `docker-compose.yml`. Compose reads it automatically, including under `sudo`.

```env
OPENCODE_WEBUI_PORT=4096
# OPENCODE_WEBUI_BIND_ADDR=0.0.0.0
# OPENCODE_VERSION=latest
# OPENCODE_SERVER_PASSWORD=change-me
# OPENCODE_PRIVILEGED=true
```

Do not commit secrets to `.env`.

## Remote access

OpenCode lets anyone who can reach it run commands and edit files as the agent. It has no built-in login unless you set `OPENCODE_SERVER_PASSWORD`, so do not expose it directly to the public internet without a firewall or reverse proxy in front of it.

## Installing packages / tools

Because the agent runs as root inside the container, it can install packages with `apt`, `npm`, `pip`, or similar tools as part of its work.

For one-off package installation inside the running container:

```bash
sudo docker compose exec -it opencode bash
apt-get update
apt-get install -y <package>
```

If you want a package to exist by default after a rebuild, add it to the `Dockerfile` and recreate the container.

## Running containers inside the container (Podman)

Podman, Buildah, and Skopeo are preinstalled, so the agent can run `podman build` / `podman run` (Docker is not installed; `podman` accepts the same commands). Podman runs rootful (the agent is root in the container) with the `crun` runtime, `cgroupfs` cgroup manager, and the `overlay` storage driver via `fuse-overlayfs`. Short image names such as `alpine` resolve via `docker.io`.

Smoke test:

```bash
sudo docker compose exec -it opencode podman info
sudo docker compose exec -it opencode podman run --rm docker.io/library/alpine echo ok
```

The second command should print `ok`.

Image layers and containers are stored in the `opencode-containers` volume (`/var/lib/containers`), so pulled and built images survive restarts and rebuilds.

Host requirements:

- `/dev/fuse` must exist on the Docker host (`ls -l /dev/fuse`; load it with `sudo modprobe fuse` if missing).
- Tested with cgroup v2 (`stat -fc %T /sys/fs/cgroup` prints `cgroup2fs`).
- The Docker engine must allow privileged containers (rootless Docker or restricted runtimes may not).

If nested containers cannot reach the network on your host, try `podman run --network host ...`. As a last resort, add `netns = "host"` under a `[containers]` section in `/etc/containers/containers.conf` (in the `Dockerfile`) to make that the default.

## Provider login / API keys

You can log in with the OpenCode CLI inside the container:

```bash
sudo docker compose exec -it opencode opencode auth login
```

Credentials go under the persistent `/data` volume. You can also set API key environment variables in `docker-compose.yml`.

## Persistence

| Volume               | Mounted at   | Contents |
| -------------------- | ------------ | -------- |
| `opencode-data`      | `/data`      | HOME, config, state, cache, auth, and session data |
| `opencode-workspace` | `/workspace` | Your project files |
| `opencode-containers` | `/var/lib/containers` | Podman images, layers, and containers |

The volumes survive restarts, rebuilds, and `docker compose down`. **Do not run `docker compose down -v`**, because that deletes them.

To put existing code into the workspace, you can either clone it from the OpenCode terminal, or copy it in:

```bash
sudo docker compose cp ./myproject opencode:/workspace/myproject
sudo docker compose exec -u 0 opencode chown -R 0:0 /workspace/myproject
```

## Updating

To pick up a new release, rebuild without cache:

```bash
sudo docker compose build --pull --no-cache
sudo docker compose up -d
```

## Healthcheck / smoke test

```bash
sudo docker compose ps -a
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:4096/
```

## Troubleshooting

When reporting a problem, include the output of:

```bash
sudo docker compose ps -a
sudo docker compose logs --tail=100
```
