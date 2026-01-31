# Резервное копирование и восстановление

Это руководство описывает базовый процесс бэкапа PostgreSQL (Supabase) и восстановления.

## Предварительные требования
1. Запущен `supabase_db`.
2. Установлен `postgresql-client`.

## 1. Установка клиента PostgreSQL
```bash
sudo apt update
sudo apt install -y postgresql-client
```

## 2. Бэкап PostgreSQL (скрипт)
```bash
sudo bash scripts/08-backup-postgres.sh
```

По умолчанию бэкапы сохраняются в `/opt/backups`.

## 3. Автоматизация по расписанию (cron)
```bash
sudo bash scripts/09-setup-backup-cron.sh
```

Пример расписания:
- `0 2 * * *` — ежедневно в 02:00

Удаление cron:
```bash
sudo rm -f /etc/cron.d/install-ubuntu-backup
```

## 4. Бэкап PostgreSQL (вручную)
```bash
pg_dump -h localhost -p 54322 -U postgres -d postgres | gzip > /opt/backups/postgres_manual.sql.gz
```

## 5. Восстановление из бэкапа
```bash
gunzip -c /opt/backups/postgres_YYYYMMDD_HHMMSS.sql.gz | psql -h localhost -p 54322 -U postgres -d postgres
```

## 6. Рекомендации
1. Храните бэкапы на отдельном диске или сервере.
2. Проверяйте восстановление минимум раз в месяц.
3. Зафиксируйте RPO/RTO в документации проекта.

## Источники
- https://www.postgresql.org/docs/current/backup.html
