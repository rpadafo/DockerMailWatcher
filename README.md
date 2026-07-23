# 🐳 Docker Mail Watcher

[![Docker Image](https://img.shields.io/badge/ghcr.io-dockermailwatcher-blue?logo=docker)](https://github.com/rpadafo/DockerMailWatcher/pkgs/container/dockermailwatcher)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

**Docker Mail Watcher** is an ultra-lightweight container based on Alpine Linux designed to monitor Docker socket (`/var/run/docker.sock`) events in real-time and send instant email notifications (via SMTP) whenever a container stops unexpectedly.

---

## ⚡ Features

- 🪶 **Ultra-lightweight:** Built on Alpine Linux (~15 MB memory footprint).
- ⏱️ **Passive monitoring:** Listens exclusively to critical events (`die`, `oom`) without polling or wasting CPU in the background.
- 🔒 **Zero inbound exposure:** Connects directly to your SMTP server (OVH, Gmail, SendGrid, etc.) without exposing any inbound ports.
- 🚀 **Plug-and-play:** Ready to deploy directly from GitHub Container Registry (`ghcr.io`).

---

## 🚀 Quick Start

Inside this repository, you will find a template file named `docker-compose_EXAMPLE.yaml`. You can rename or copy it to `docker-compose.yml`: