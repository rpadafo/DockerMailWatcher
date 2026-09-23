# 🐳 Docker Mail Watcher

[![Docker Image](https://img.shields.io/badge/ghcr.io-dockermailwatcher-blue?logo=docker)](https://github.com/rpadafo/DockerMailWatcher/pkgs/container/dockermailwatcher)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

**Docker Mail Watcher** is an ultra-lightweight container based on Alpine Linux designed to monitor your Docker host in real-time and send instant email notifications (via SMTP) when something needs your attention: a container crashes, or a new image update becomes available.

---

## ⚡ Features

- 🪶 **Ultra-lightweight:** Built on Alpine Linux (~15 MB memory footprint).
- ⏱️ **Passive crash monitoring:** Listens exclusively to critical Docker socket events (`die`, `oom`) without polling or wasting CPU in the background.
- 🔄 **Update monitoring:** Periodically checks running containers against their remote registry digests and notifies you when a newer image is available, so you know when to update.
- 🎛️ **Independently configurable watchers:** Enable or disable the crash watcher and the update watcher separately to fit your needs.
- 🔒 **Zero inbound exposure:** Connects directly to your SMTP server (OVH, Gmail, SendGrid, etc.) without exposing any inbound ports.
- 🚀 **Plug-and-play:** Ready to deploy directly from GitHub Container Registry (`ghcr.io`).

---

## 🚀 Quick Start

Inside this repository, you will find a template file named `docker-compose_EXAMPLE.yaml`. You can rename or copy it to `docker-compose.yml` and adjust it to your environment:

```bash
cp docker-compose_EXAMPLE.yaml docker-compose.yml
```

Then start the container:

```bash
docker compose up -d
```

---

## ⚙️ Configuration

All configuration is done through environment variables in your `docker-compose.yml`.

### SMTP settings

| Variable | Required | Description |
|---|---|---|
| `SMTP_SERVER` | ✅ | SMTP server hostname (e.g. `smtp.server.tld`). |
| `SMTP_PORT` | ❌ | SMTP port. Defaults to `465` (SMTPS). |
| `SMTP_USER` | ✅ | SMTP authentication username. |
| `SMTP_PASS` | ✅ | SMTP authentication password. |
| `SMTP_FROM` | ✅ | Sender email address. |
| `SMTP_FROM_NAME` | ❌ | Sender display name (e.g. `Docker Alert`). |
| `SMTP_TO` | ✅ | Recipient email address for notifications. |

### Notification settings

| Variable | Required | Description |
|---|---|---|
| `SUBJECT_PREFIX` | ❌ | Subject prefix used for crash alert emails. Defaults to `[Alert]`. |
| `SUBJECT_PREFIX_UPDATE` | ❌ | Subject prefix used for update alert emails. Defaults to `[Update]`. |

### Watchers

| Variable | Required | Description |
|---|---|---|
| `ENABLE_CRASH_WATCHER` | ❌ | Enables the crash watcher, which listens to `die`/`oom` Docker events. Defaults to `true`. |
| `ENABLE_UPDATE_WATCHER` | ❌ | Enables the update watcher, which periodically checks for newer container images. Defaults to `true`. |
| `CHECK_INTERVAL` | ❌ | Interval, in seconds, between update checks performed by the update watcher. Defaults to `86400` (24 hours). |

> ⚠️ At least one of the two watchers must remain enabled. If both `ENABLE_CRASH_WATCHER` and `ENABLE_UPDATE_WATCHER` are set to `false`, the container will log an error and exit.

### Optional settings

The `docker-compose_EXAMPLE.yaml` file also includes an optional block (marked with `#Optional >>>` / `#Optional <<<`) showing additional `docker compose` options you may use if needed, such as:

- `networks`: attach the container to an existing external network with a fixed IP/MAC address.
- `deploy.resources.limits`: cap CPU and memory usage.
- `dns`: use custom DNS servers (useful if the update watcher cannot resolve registry hostnames).

These settings are entirely optional and can be removed if not needed.

---

## 🔍 How it works

- **Crash watcher** (`watcher.sh`): subscribes to the Docker socket event stream and reacts instantly to `die` and `oom` events, sending an email for the affected container.
- **Update watcher** (`update.sh`): every `CHECK_INTERVAL` seconds, inspects each running container's image digest and compares it against the digest published in its remote registry (via `skopeo`). If they differ, an update notification email is sent for that container.

Both watchers run concurrently inside the same container and can be toggled independently via the environment variables above.