# Быстрый старт

Короткий путь от чистого Ubuntu/VPS сервера до Docker-based инфраструктуры для AI automation: n8n, Supabase/PostgreSQL, Redis, pgvector, monitoring и backup-ready checks.

## Перед началом

| Требование | Минимум |
|------------|---------|
| OS | Ubuntu 22.04 LTS или 24.04 LTS |
| RAM | 4 GB, рекомендуется 8 GB+ |
| Disk | 50 GB+ |
| Access | root или sudo |
| Network | SSH-доступ и открытые 80/443 при использовании Nginx |

Для bare metal с новым железом сначала проверьте [драйверы и совместимость](docs/08-hardware-drivers.md).

## 1. Получите проект

```bash
git clone https://github.com/RoKols2017/install_ubuntu.git
cd install_ubuntu
```

Если проект копируется без git, важно сохранить структуру каталогов `scripts/`, `docker-compose/`, `docs/`, `templates/` и `requirements/`.

## 2. Проверьте сервер

```bash
sudo bash scripts/00-preflight-check.sh
```

Проверьте CPU/RAM/disk, версию Ubuntu, сетевые интерфейсы и базовый hardware profile до изменений.

## 3. Подготовьте SSH-ключи

На клиентской машине, не на сервере:

```bash
bash scripts/01-setup-ssh-keys.sh
```

Скрипт поддерживает отдельные сценарии для GitHub, VPS/root, deploy-пользователя, резервного доступа и существующего ключа. Перед hardening убедитесь, что доступ по ключу работает. Это снижает риск заблокировать SSH-доступ.

Минимальная проверка прав на клиентской машине:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config
```

Подробности: [SSH Keys](docs/ssh-keys.md).

## 4. Harden Ubuntu server

```bash
sudo bash scripts/02-secure-server.sh
```

Скрипт настраивает UFW, SSH hardening, fail2ban и security updates. Подробности: [Server Security](docs/01-server-security.md).

## 5. Установите Docker

```bash
sudo bash scripts/03-install-docker.sh
newgrp docker
```

Проверьте установку:

```bash
docker --version
docker compose version
```

Подробности: [Docker Installation](docs/02-docker-installation.md).

## 6. Создайте секреты

```bash
sudo bash scripts/12-generate-secrets.sh
```

Скрипт создаёт `docker-compose/.env` из `env.example` и заполняет обязательные секреты. Проверьте файл перед запуском production-сервисов.

Критичные переменные:

| Переменная | Назначение |
|------------|------------|
| `REDIS_PASSWORD` | пароль Redis |
| `SUPABASE_DB_PASSWORD` | пароль PostgreSQL/Supabase |
| `N8N_BASIC_AUTH_PASSWORD` | пароль n8n |
| `N8N_ENCRYPTION_KEY` | ключ шифрования n8n |
| `N8N_USER_MANAGEMENT_JWT_SECRET` | JWT secret n8n |
| `GRAFANA_PASSWORD` | пароль Grafana |

Подробности: [Secrets](docs/13-secrets.md).

## 7. Запустите инфраструктуру

Рекомендуемый путь через единый compose stack:

```bash
cd docker-compose
docker compose --env-file .env up -d
docker compose ps
```

По умолчанию PostgreSQL, Redis, Supabase Studio и n8n привязаны к `127.0.0.1`. Для внешнего доступа используйте SSH tunnel или [Nginx](docs/07-nginx.md).

## 8. Проверьте готовность

Из корня проекта:

```bash
sudo bash scripts/99-ready-checks.sh
```

Быстрые smoke checks:

```bash
cd docker-compose
docker compose ps
curl -f http://localhost:5678/healthz
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" ping
```

Подробности: [Quality Checks](docs/12-quality-checks.md) и [Ready Rules](docs/14-ready-rules.md).

## 9. Откройте интерфейсы локально

| Сервис | URL |
|--------|-----|
| n8n | `http://localhost:5678` |
| Supabase Studio | `http://localhost:54323` |
| Prometheus | `http://localhost:9090` |
| Grafana | `http://localhost:3000` |

Если сервер удалённый, используйте SSH tunnel или reverse proxy. Не открывайте внутренние порты публично без явной необходимости.

## 10. Следующие шаги

| Задача | Команда или ссылка |
|--------|--------------------|
| pgvector/RAG setup | [pgvector](docs/06-vector-db.md) |
| n8n credentials | [n8n](docs/04-n8n.md) |
| Monitoring | [Monitoring](docs/09-monitoring.md) |
| PostgreSQL backup | `sudo bash scripts/10-backup-postgres.sh` |
| Backup schedule | `sudo bash scripts/11-setup-backup-cron.sh` |
| Public HTTPS access | [Nginx](docs/07-nginx.md) |
| Troubleshooting | [Troubleshooting](docs/11-troubleshooting.md) |

## Полезные команды

```bash
cd docker-compose

# Логи всех сервисов
docker compose logs -f

# Логи одного сервиса
docker compose logs -f n8n

# Перезапуск сервиса
docker compose restart n8n

# Остановка стека без удаления данных
docker compose down

# Остановка с удалением volumes: удалит данные
docker compose down -v
```

## Документация

- [README](README.md) — landing page проекта.
- [Infrastructure Setup](docs/03-infrastructure-setup.md) — общий порядок установки.
- [Scripts Order](docs/15-scripts-order.md) — каноническая последовательность скриптов.
- [Architecture](docs/architecture.md) — компоненты и data flow.
