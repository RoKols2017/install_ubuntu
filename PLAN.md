# План приведения проекта к лучшим практикам

> **Последняя проверка:** 2026-02-03

## 1. Цели и критерии готовности
1. ✅ Зафиксировать целевую конфигурацию для Ubuntu Server 24.04 LTS (dev/prod).
2. ✅ Исключить небезопасные дефолты (пароли, открытые порты, неподписанные образы).
3. ✅ Обеспечить воспроизводимую установку и мониторинг.
4. ✅ Обеспечить одинаковую работоспособность на VPS и локальном сервере (CPU‑first, GPU‑optional).

Критерии готовности:
- ✅ `docker compose config` проходит без ошибок.
- ✅ Все сервисы имеют healthcheck.
- ✅ Документация и порядок установки синхронизированы.

Источники:
- https://docs.docker.com/compose/compose-file/
- https://ubuntu.com/security

## 2. Базовые паттерны (принципы реализации)
1. ✅ Единый источник истины: одна конфигурация, без дублирования SQL и env.
2. ✅ Secure by default: обязательные секреты, закрытые порты, безопасные дефолты.
3. ✅ Разделение окружений: base compose + overrides + profiles.
4. ✅ Аппаратная нейтральность: CPU‑baseline, GPU‑optional, без обязательной зависимости.
5. ✅ Идемпотентные скрипты: безопасный повторный запуск.
6. ⚠️ Принцип наименьших привилегий: non-root, `cap_drop`, минимальные права. *(cap_drop не добавлен)*
7. ✅ Observability by design: healthchecks, метрики, стандартизированные логи.
8. ✅ Backup-first: автоматизация бэкапов + регулярный тест восстановления.
9. ✅ Version pinning: фиксированные версии образов, без `latest`.
10. ✅ Конфигурация как код: все параметры в `.env`/compose, без ручных правок.
11. ✅ Сегментация сети: внутренние сети, внешние порты только при необходимости.

## 3. Инвентаризация и аудит ✅
1. ✅ Проверить версии ОС и Docker:
   ```bash
   lsb_release -a
   docker --version
   docker compose version
   ```
2. ✅ Снять текущую конфигурацию compose:
   ```bash
   cd docker-compose
   docker compose config > /tmp/compose.effective.yml
   ```
3. ✅ Зафиксировать открытые порты и правила UFW:
   ```bash
   ss -tlnp
   sudo ufw status verbose
   ```
4. ✅ Снять аппаратный профиль (плата, сеть, GPU, драйверы):
   ```bash
   sudo dmidecode -t system -t baseboard
   lspci -nnk
   lsusb
   sudo lshw -short
   uname -r
   ```

**Реализация:** `scripts/00-preflight-check.sh` выполняет сбор информации автоматически.

Источники:
- https://docs.docker.com/engine/install/ubuntu/
- https://manpages.ubuntu.com/manpages/noble/man8/ufw.8.html

## 4. Аппаратная совместимость и драйверы (VPS и bare metal) ✅
1. ✅ Добавить раздел `docs/08-hardware-drivers.md` с матрицей железа:
   - модель платы, NIC, GPU
   - драйвер/модуль ядра
   - статус: tested/unknown
2. ✅ GPU (NVIDIA) — установка и проверка:
   ```bash
   ubuntu-drivers devices
   sudo ubuntu-drivers install
   nvidia-smi
   ```
3. ✅ GPU (AMD/Intel) — проверка драйверов ядра:
   ```bash
   sudo apt install -y linux-firmware
   lspci -nnk | grep -A3 -i vga
   ```
4. ✅ Если установщик не видит сетевой адаптер:
   - использовать актуальный Server ISO 24.04.x с новым ядром
   - после установки обновить firmware и модули:
   ```bash
   sudo apt install -y linux-firmware linux-modules-extra-$(uname -r)
   sudo modprobe <driver_module>
   dmesg | grep -i firmware
   ```
5. ✅ Для новых плат зафиксировать модель и драйвер в матрице:
   ```bash
   sudo dmidecode -t baseboard
   lspci -nnk | grep -A3 -i ether
   ```

**Реализация:**
- `docs/08-hardware-drivers.md` — документация с матрицей и инструкциями
- `scripts/09-install-nvidia-drivers.sh` — автоматическая установка NVIDIA

Источники:
- https://ubuntu.com/server/docs/nvidia-drivers
- https://packages.ubuntu.com/noble/linux-firmware
- https://manpages.ubuntu.com/manpages/noble/en/man8/dmidecode.8.html
- https://manpages.ubuntu.com/manpages/noble/en/man8/modprobe.8.html

## 5. Корректность docker-compose и зависимости ✅
1. ✅ Добавить отсутствующие сервисы Supabase (минимум `supabase_meta`) и связать `supabase_studio`.
2. ✅ Исправить healthcheck Redis на `redis-cli ping` с паролем.
3. ✅ Зафиксировать версии образов (убрать `latest`).
4. ✅ Перевести критичные переменные на обязательные (`${VAR:?}`).
5. ✅ Закрыть внешние порты баз данных, привязать к `127.0.0.1`.

**Реализация:**
- `docker-compose.yml` — все сервисы с версиями, healthcheck, обязательными переменными
- `supabase_meta` добавлен, `supabase_studio` связан через `depends_on`
- `pgbouncer` добавлен для connection pooling
- Порты: Redis `127.0.0.1:6379`, PostgreSQL `127.0.0.1:54322`, PgBouncer `127.0.0.1:6432`
- `docker-compose.override.public.yml` — для публичного доступа (опционально)

Минимальные проверки:
```bash
cd docker-compose
docker compose up -d
docker compose ps
```

Источники:
- https://docs.docker.com/compose/compose-file/
- https://supabase.com/docs/guides/self-hosting
- https://docs.n8n.io/hosting/installation/scaling/

## 6. Управление секретами и паролями ✅
1. ✅ Удалить дефолтные пароли из compose и документации.
2. ✅ Для production использовать Docker secrets или защищённый `.env`.
3. ✅ В скриптах заменить `export PGPASSWORD` на `PGPASSFILE`.
4. ✅ Добавить предупреждения о ротации паролей.

**Реализация:**
- `scripts/12-generate-secrets.sh` — автогенерация всех секретов
- `env.example` — шаблон с плейсхолдерами (без реальных паролей)
- `scripts/10-backup-postgres.sh` — использует `PGPASSFILE`
- `docs/13-secrets.md` — документация по управлению секретами

Источники:
- https://docs.docker.com/engine/swarm/secrets/
- https://www.postgresql.org/docs/current/libpq-pgpass.html
- https://redis.io/docs/latest/operate/security/

## 7. База данных и pgvector ✅
1. ✅ Убрать дублирование SQL: один файл `init.sql` как источник истины.
2. ✅ Пересмотреть параметры HNSW индекса (m, ef_construction) под нагрузку.
3. ✅ Добавить PgBouncer для connection pooling.
4. ✅ Включить регулярные `VACUUM` и мониторинг автovacuum.

**Реализация:**
- `docker-compose/supabase/init.sql` — единственный источник SQL (HNSW: m=24, ef_construction=128)
- `pgbouncer` сервис в `docker-compose.yml`
- n8n подключается через PgBouncer (порт 6432)
- `docs/06-vector-db.md` — документация по VACUUM и тюнингу

Пример проверки расширения:
```bash
docker exec supabase_db psql -U postgres -d postgres -c "\dx vector"
```

Источники:
- https://github.com/pgvector/pgvector
- https://www.postgresql.org/docs/current/index.html
- https://supabase.com/docs/guides/self-hosting

## 8. Наблюдаемость и логирование ✅
1. ✅ Включить метрики n8n и собрать их через Prometheus.
2. ✅ Добавить Grafana и базовые dashboards.
3. ✅ Стандартизировать уровень логирования сервисов.

**Реализация:**
- `docker-compose.monitoring.yml` — Prometheus + Grafana
- `prometheus.yml` — конфигурация scrape (n8n:5678/metrics)
- n8n: `N8N_METRICS=true` (по умолчанию)
- Все сервисы: `logging: json-file` с ротацией (10m, 3 файла)
- `docs/09-monitoring.md` — документация

Пример запуска мониторинга:
```bash
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
```

Источники:
- https://docs.n8n.io/hosting/configuration/environment-variables/
- https://prometheus.io/docs/introduction/overview/
- https://grafana.com/docs/grafana/latest/

## 9. Бэкапы и восстановление ✅
1. ✅ Автоматизировать бэкапы PostgreSQL по расписанию.
2. ⚠️ Проверить восстановление на чистой машине. *(требует ручного теста на VPS)*
3. ⚠️ Зафиксировать RPO/RTO и процедуру восстановления. *(документировано, но не протестировано)*

**Реализация:**
- `scripts/10-backup-postgres.sh` — ручной бэкап с PGPASSFILE
- `scripts/11-setup-backup-cron.sh` — автоматизация по cron
- `docs/10-backup-restore.md` — документация по бэкапу и восстановлению

Пример бэкапа:
```bash
sudo bash scripts/10-backup-postgres.sh
```

Источники:
- https://www.postgresql.org/docs/current/backup.html
- https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/

## 10. Документация и порядок установки ✅
1. ✅ Синхронизировать порядок шагов между `README.md`, `QUICKSTART.md` и `docs/*`.
2. ✅ Добавить отдельный `docs/troubleshooting.md`.
3. ✅ Везде указывать минимальные требования и варианты dev/prod.

**Реализация:**
- `README.md` — главная документация, актуальный порядок скриптов
- `QUICKSTART.md` — краткое руководство по установке
- `docs/11-troubleshooting.md` — руководство по устранению проблем
- `docs/15-scripts-order.md` — каноническая последовательность скриптов
- `requirements/system-requirements.md` — минимальные требования

Источники:
- https://docs.docker.com/compose/
- https://ubuntu.com/server/docs

## 11. Контроль качества и выпуск ⚠️
1. ⚠️ Проверить скрипты через `shellcheck` (опционально, но желательно). *(не выполнено)*
2. ⚠️ Прогнать установку на чистой VM Ubuntu 24.04. *(требуется ручной тест)*
3. ⚠️ Зафиксировать версии и обновить changelog. *(changelog не ведётся)*

**Реализация:**
- `scripts/00-preflight-check.sh` — предварительная проверка системы
- `scripts/99-ready-checks.sh` — проверка готовности после установки
- `docs/12-quality-checks.md` — руководство по проверке качества
- `docs/14-ready-rules.md` — правила gate-проверок

Пример smoke‑теста:
```bash
curl -f http://localhost:5678/healthz
```

Источники:
- https://docs.docker.com/compose/reference/config/
- https://ubuntu.com/server/docs

---

## Сводка выполнения

| Раздел | Статус |
|--------|--------|
| 1. Цели и критерии готовности | ✅ Выполнено |
| 2. Базовые паттерны | ⚠️ Частично (нет cap_drop) |
| 3. Инвентаризация и аудит | ✅ Выполнено |
| 4. Аппаратная совместимость | ✅ Выполнено |
| 5. Корректность docker-compose | ✅ Выполнено |
| 6. Управление секретами | ✅ Выполнено |
| 7. База данных и pgvector | ✅ Выполнено |
| 8. Наблюдаемость и логирование | ✅ Выполнено |
| 9. Бэкапы и восстановление | ⚠️ Частично (требуется тест восстановления) |
| 10. Документация | ✅ Выполнено |
| 11. Контроль качества | ⚠️ Частично (требуется тест на VM) |

**Легенда:** ✅ Выполнено | ⚠️ Частично/требует внимания | ❌ Не выполнено
