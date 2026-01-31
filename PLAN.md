# План приведения проекта к лучшим практикам

## 1. Цели и критерии готовности
1. Зафиксировать целевую конфигурацию для Ubuntu Server 24.04 LTS (dev/prod).
2. Исключить небезопасные дефолты (пароли, открытые порты, неподписанные образы).
3. Обеспечить воспроизводимую установку и мониторинг.
4. Обеспечить одинаковую работоспособность на VPS и локальном сервере (CPU‑first, GPU‑optional).

Критерии готовности:
- `docker compose config` проходит без ошибок.
- Все сервисы здоровы по healthcheck.
- Документация и порядок установки一致ны.

Источники:
- https://docs.docker.com/compose/compose-file/
- https://ubuntu.com/security

## 2. Базовые паттерны (принципы реализации)
1. Единый источник истины: одна конфигурация, без дублирования SQL и env.
2. Secure by default: обязательные секреты, закрытые порты, безопасные дефолты.
3. Разделение окружений: base compose + overrides + profiles.
4. Аппаратная нейтральность: CPU‑baseline, GPU‑optional, без обязательной зависимости.
5. Идемпотентные скрипты: безопасный повторный запуск.
6. Принцип наименьших привилегий: non-root, `cap_drop`, минимальные права.
7. Observability by design: healthchecks, метрики, стандартизированные логи.
8. Backup-first: автоматизация бэкапов + регулярный тест восстановления.
9. Version pinning: фиксированные версии образов, без `latest`.
10. Конфигурация как код: все параметры в `.env`/compose, без ручных правок.
11. Сегментация сети: внутренние сети, внешние порты только при необходимости.

## 3. Инвентаризация и аудит
1. Проверить версии ОС и Docker:
   ```bash
   lsb_release -a
   docker --version
   docker compose version
   ```
2. Снять текущую конфигурацию compose:
   ```bash
   cd docker-compose
   docker compose config > /tmp/compose.effective.yml
   ```
3. Зафиксировать открытые порты и правила UFW:
   ```bash
   ss -tlnp
   sudo ufw status verbose
   ```
4. Снять аппаратный профиль (плата, сеть, GPU, драйверы):
   ```bash
   sudo dmidecode -t system -t baseboard
   lspci -nnk
   lsusb
   sudo lshw -short
   uname -r
   ```

Источники:
- https://docs.docker.com/engine/install/ubuntu/
- https://manpages.ubuntu.com/manpages/noble/man8/ufw.8.html

## 4. Аппаратная совместимость и драйверы (VPS и bare metal)
1. Добавить раздел `docs/08-hardware-drivers.md` с матрицей железа:
   - модель платы, NIC, GPU
   - драйвер/модуль ядра
   - статус: tested/unknown
2. GPU (NVIDIA) — установка и проверка:
   ```bash
   ubuntu-drivers devices
   sudo ubuntu-drivers install
   nvidia-smi
   ```
3. GPU (AMD/Intel) — проверка драйверов ядра:
   ```bash
   sudo apt install -y linux-firmware
   lspci -nnk | grep -A3 -i vga
   ```
4. Если установщик не видит сетевой адаптер:
   - использовать актуальный Server ISO 24.04.x с новым ядром
   - после установки обновить firmware и модули:
   ```bash
   sudo apt install -y linux-firmware linux-modules-extra-$(uname -r)
   sudo modprobe <driver_module>
   dmesg | grep -i firmware
   ```
5. Для новых плат зафиксировать модель и драйвер в матрице:
   ```bash
   sudo dmidecode -t baseboard
   lspci -nnk | grep -A3 -i ether
   ```

Источники:
- https://ubuntu.com/server/docs/nvidia-drivers
- https://packages.ubuntu.com/noble/linux-firmware
- https://manpages.ubuntu.com/manpages/noble/en/man8/dmidecode.8.html
- https://manpages.ubuntu.com/manpages/noble/en/man8/modprobe.8.html

## 5. Корректность docker-compose и зависимости
1. Добавить отсутствующие сервисы Supabase (минимум `supabase_meta`) и связать `supabase_studio`.
2. Исправить healthcheck Redis на `redis-cli ping` с паролем.
3. Зафиксировать версии образов (убрать `latest`).
4. Перевести критичные переменные на обязательные (`${VAR:?}`).
5. Закрыть внешние порты баз данных, привязать к `127.0.0.1`.

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

## 6. Управление секретами и паролями
1. Удалить дефолтные пароли из compose и документации.
2. Для production использовать Docker secrets или защищённый `.env`.
3. В скриптах заменить `export PGPASSWORD` на `PGPASSFILE`.
4. Добавить предупреждения о ротации паролей.

Источники:
- https://docs.docker.com/engine/swarm/secrets/
- https://www.postgresql.org/docs/current/libpq-pgpass.html
- https://redis.io/docs/latest/operate/security/

## 7. База данных и pgvector
1. Убрать дублирование SQL: один файл `init.sql` как источник истины.
2. Пересмотреть параметры HNSW индекса (m, ef_construction) под нагрузку.
3. Добавить PgBouncer для connection pooling.
4. Включить регулярные `VACUUM` и мониторинг автovacuum.

Пример проверки расширения:
```bash
docker exec supabase_db psql -U postgres -d postgres -c "\dx vector"
```

Источники:
- https://github.com/pgvector/pgvector
- https://www.postgresql.org/docs/current/index.html
- https://supabase.com/docs/guides/self-hosting

## 8. Наблюдаемость и логирование
1. Включить метрики n8n и собрать их через Prometheus.
2. Добавить Grafana и базовые dashboards.
3. Стандартизировать уровень логирования сервисов.

Пример запуска мониторинга:
```bash
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
```

Источники:
- https://docs.n8n.io/hosting/configuration/environment-variables/
- https://prometheus.io/docs/introduction/overview/
- https://grafana.com/docs/grafana/latest/

## 9. Бэкапы и восстановление
1. Автоматизировать бэкапы PostgreSQL по расписанию.
2. Проверить восстановление на чистой машине.
3. Зафиксировать RPO/RTO и процедуру восстановления.

Пример бэкапа:
```bash
docker exec supabase_db pg_dump -U postgres postgres > /opt/backups/backup.sql
```

Источники:
- https://www.postgresql.org/docs/current/backup.html
- https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/

## 10. Документация и порядок установки
1. Синхронизировать порядок шагов между `README.md`, `QUICKSTART.md` и `docs/*`.
2. Добавить отдельный `docs/troubleshooting.md`.
3. Везде указывать минимальные требования и варианты dev/prod.

Источники:
- https://docs.docker.com/compose/
- https://ubuntu.com/server/docs

## 11. Контроль качества и выпуск
1. Проверить скрипты через `shellcheck` (опционально, но желательно).
2. Прогнать установку на чистой VM Ubuntu 24.04.
3. Зафиксировать версии и обновить changelog.

Пример smoke‑теста:
```bash
curl -f http://localhost:5678/healthz
```

Источники:
- https://docs.docker.com/compose/reference/config/
- https://ubuntu.com/server/docs
