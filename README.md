# persistent-opencode-webui

Docker Compose setup for [OpenCode](https://opencode.ai) (`opencode web`). Settings, credentials, sessions, and workspace files persist across restarts.

## What this provides

| Service       | Purpose                                                                 |
| ------------- | ----------------------------------------------------------------------- |
| `volume-init` | One-shot (root): creates the data directories and fixes ownership, then exits with code `0`. |
| `opencode`    | Web UI and API on container port `4096`, running as the non-root `node` user. |

- Image: `node:22-bookworm-slim`.
- Services run as the non-root `node` user (UID/GID `1000`).
- The web UI is published on **host port `4096`** by default.
- The UI binds to **`0.0.0.0`** by default.

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
```

Do not commit secrets to `.env`.

## Remote access

OpenCode lets anyone who can reach it run commands and edit files as the agent. It has no built-in login unless you set `OPENCODE_SERVER_PASSWORD`, so do not expose it directly to the public internet without a firewall or reverse proxy in front of it.

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

The volumes survive restarts, rebuilds, and `docker compose down`. **Do not run `docker compose down -v`**, because that deletes them.

To put existing code into the workspace, you can either clone it from the OpenCode terminal, or copy it in:

```bash
sudo docker compose cp ./myproject opencode:/workspace/myproject
sudo docker compose exec -u 0 opencode chown -R 1000:1000 /workspace/myproject
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
