# Последовательность и нумерация скриптов

Цель: единая логика запуска, без ошибок из‑за устаревших имён.

## 1. Актуальный порядок выполнения

1. `scripts/00-preflight-check.sh` — preflight проверки (VPS)
2. `scripts/01-setup-ssh-keys.sh` — SSH ключи (клиентская машина)
3. `scripts/02-secure-server.sh` — базовая безопасность сервера
4. `scripts/03-install-docker.sh` — установка Docker/Compose
5. `scripts/04-setup-supabase.sh` — Supabase (PostgreSQL)
6. `scripts/06-setup-redis.sh` — Redis
7. `scripts/07-setup-vector-db.sh` — pgvector таблицы/индексы
8. `scripts/05-setup-n8n.sh` — n8n (после Redis + DB)
9. `scripts/08-setup-nginx.sh` — Nginx (опционально)
10. `scripts/09-install-nvidia-drivers.sh` — NVIDIA (опционально)
11. `scripts/10-backup-postgres.sh` — бэкап БД
12. `scripts/11-setup-backup-cron.sh` — cron бэкапов
13. `scripts/99-ready-checks.sh` — ready‑проверки

## 2. Важно
- Нумерация **историческая**, но **порядок запуска** указан выше.
- Устаревшие имена **удалены** — используйте только актуальные.

## 3. Пример запуска по порядку
```bash
sudo bash scripts/00-preflight-check.sh
bash scripts/01-setup-ssh-keys.sh
sudo bash scripts/02-secure-server.sh
sudo bash scripts/03-install-docker.sh
sudo bash scripts/04-setup-supabase.sh
sudo bash scripts/06-setup-redis.sh
sudo bash scripts/07-setup-vector-db.sh
sudo bash scripts/05-setup-n8n.sh
sudo bash scripts/99-ready-checks.sh
```
