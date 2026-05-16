# install_ubuntu

> Secure Ubuntu/VPS bootstrap for self-hosted AI automation: Docker, n8n, Supabase, Redis, pgvector, monitoring, backups and production-ready checks.

`install_ubuntu` is a practical infrastructure starter kit for AI automation projects. It helps prepare a clean Ubuntu server for real workloads: Telegram bots, LLM workflows, RAG systems, internal automation, and self-hosted services.

This repository fits the RoKols2017 stack: **Linux/VPS · Docker · Python/LLM infrastructure · Telegram bots · RAG · automation workflows**. It is not a demo setup. It is a repeatable path from a fresh server to a safer Docker-based AI environment.

## Why It Exists

Most AI automation projects need the same foundation before product work starts:

- hardened SSH access, firewall, fail2ban and security updates;
- Docker and Docker Compose installed correctly;
- PostgreSQL/Supabase, Redis and pgvector ready for workflows and RAG;
- n8n main/worker setup for automation pipelines;
- Nginx, SSL, monitoring, backups and readiness checks for production use.

This repo turns that foundation into documented steps, scripts and compose files.

## What You Get

| Area | Included |
|------|----------|
| Server baseline | Ubuntu hardening, SSH keys, UFW, fail2ban, unattended upgrades |
| Container runtime | Docker Engine, Docker Compose, daemon configuration |
| AI automation stack | n8n, Redis, Supabase/PostgreSQL, pgvector, PgBouncer |
| Production support | Nginx reverse proxy, SSL path, monitoring, backups, ready checks |
| Safety | Secret generation, closed local ports, healthchecks, version-pinned compose |
| Documentation | Step-by-step guides for VPS and local server installation |

## Infrastructure Flow

```text
Fresh Ubuntu server
  -> preflight check
  -> SSH keys from client machine
  -> server hardening
  -> Docker installation
  -> Supabase + PostgreSQL + pgvector
  -> Redis + n8n main/worker
  -> optional Nginx reverse proxy
  -> monitoring, backups, ready checks
```

## Quick Start

```bash
# 1. Check the server before changing it
sudo bash scripts/00-preflight-check.sh

# 2. Prepare SSH keys on the client machine
bash scripts/01-setup-ssh-keys.sh

# 3. Harden the server
sudo bash scripts/02-secure-server.sh

# 4. Install Docker
sudo bash scripts/03-install-docker.sh

# 5. Generate secrets and start the compose stack
sudo bash scripts/12-generate-secrets.sh
cd docker-compose
docker compose --env-file .env up -d

# 6. Verify readiness
sudo bash ../scripts/99-ready-checks.sh
```

For the full installation path, use [QUICKSTART.md](QUICKSTART.md). For GitHub, VPS/root, deploy and backup key scenarios, see [SSH Keys](docs/ssh-keys.md).

## Real Use Cases

- Prepare a VPS for AI assistants and Telegram bots.
- Run n8n workflows with Redis queue mode and PostgreSQL storage.
- Build a self-hosted RAG base with Supabase/PostgreSQL and pgvector.
- Standardize repeatable infrastructure setup for client AI automation projects.
- Keep deployment knowledge in scripts and docs instead of one-off terminal history.

## Repository Map

| Path | Purpose |
|------|---------|
| [scripts/](scripts/) | Installation, security, backup and readiness scripts |
| [docker-compose/](docker-compose/) | Main compose stack and service configuration |
| [docs/](docs/) | Detailed component guides and operating notes |
| [requirements/](requirements/) | System requirements and compatibility notes |
| [templates/](templates/) | Reusable Nginx and firewall templates |
| [QUICKSTART.md](QUICKSTART.md) | Copy-paste installation walkthrough |

## Documentation

| Guide | Description |
|-------|-------------|
| [Quick Start](QUICKSTART.md) | End-to-end installation path |
| [System Requirements](requirements/system-requirements.md) | CPU, RAM, disk and OS requirements |
| [Server Security](docs/01-server-security.md) | SSH, UFW, fail2ban and hardening |
| [SSH Keys](docs/ssh-keys.md) | Key naming, GitHub/VPS/deploy scenarios and permissions |
| [Security Hardening Details](docs/01-server-security-hardening.md) | Advanced SSH, sysctl and audit notes |
| [Docker Installation](docs/02-docker-installation.md) | Docker Engine and Compose setup |
| [Infrastructure Setup](docs/03-infrastructure-setup.md) | Stack overview and deployment order |
| [Architecture](docs/architecture.md) | Runtime components and data flow |
| [Architecture Operations](docs/architecture-operations.md) | Scaling, backups and performance notes |
| [Supabase](docs/03-supabase.md) | Self-hosted Supabase setup |
| [n8n](docs/04-n8n.md) | n8n main/worker deployment |
| [Redis](docs/05-redis.md) | Redis setup for queues and caching |
| [pgvector](docs/06-vector-db.md) | Vector search setup for RAG |
| [Nginx](docs/07-nginx.md) | Reverse proxy and SSL path |
| [Nginx Operations](docs/07-nginx-operations.md) | Advanced proxy and troubleshooting |
| [Hardware Drivers](docs/08-hardware-drivers.md) | GPU, NIC and bare-metal compatibility |
| [Monitoring](docs/09-monitoring.md) | Prometheus and Grafana notes |
| [Backups](docs/10-backup-restore.md) | PostgreSQL backup and restore |
| [Troubleshooting](docs/11-troubleshooting.md) | Common failure modes and fixes |
| [Quality Checks](docs/12-quality-checks.md) | Validation and readiness checks |
| [Secrets](docs/13-secrets.md) | Passwords, `.env` and rotation |
| [Ready Rules](docs/14-ready-rules.md) | Installation readiness gates |
| [Scripts Order](docs/15-scripts-order.md) | Canonical script execution sequence |
| [Project Plan](PLAN.md) | Roadmap and remaining quality gates |

## When To Use This Repo

Use it when you need a practical base for AI automation infrastructure on Ubuntu: small VPS, dedicated server, internal lab, or client deployment sandbox.

Do not use it as a blind one-command installer. Read the relevant guide before each stage, especially before security hardening and public reverse proxy setup.

## Safety Notes

- Run scripts with `sudo` only after reading the matching documentation.
- Change or generate all secrets before exposing services.
- Keep databases and internal tools bound to localhost unless public access is intentional.
- Configure backups before using the stack for production data.

## Related Profile

Built in the same practical direction as [RoKols2017](https://github.com/RoKols2017): AI automation, LLM workflows, Telegram bots and self-hosted Linux/VPS infrastructure for real working tasks.

## License

This project is provided "as is" for educational and commercial use.
