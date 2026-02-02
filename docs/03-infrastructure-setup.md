# Инфраструктура для мультиагентных ассистентов

Это руководство описывает установку и настройку всех компонентов инфраструктуры для мультиагентных ассистентов на базе n8n с Supabase, Redis и pgvector.

## Предварительные требования

- Ubuntu сервер с настроенной безопасностью ([Этап 1](01-server-security.md))
- Docker и Docker Compose установлены ([Этап 2](02-docker-installation.md))
- Минимум 4 GB RAM (рекомендуется 8 GB+)
- 50 GB свободного места на диске
- Для нового железа (bare metal): [драйверы и совместимость](08-hardware-drivers.md)

## Обзор компонентов

- **Supabase** - Self-hosted база данных PostgreSQL с аутентификацией и API
- **pgvector** - Расширение PostgreSQL для векторного поиска
- **PgBouncer** - пул соединений PostgreSQL (для n8n)
- **Redis** - Кэш и очередь задач
- **n8n** - Платформа автоматизации с поддержкой воркеров
- **ChatGPT API** - Интеграция для мультиагентных ассистентов

## Документация по компонентам

Каждый компонент имеет отдельное руководство:

1. **[Установка Supabase](03-supabase.md)** - Self-hosted PostgreSQL с pgvector
2. **[Установка Redis](05-redis.md)** - Кэш и очередь задач
3. **[Настройка векторной БД](06-vector-db.md)** - pgvector таблицы и функции
4. **[Установка n8n](04-n8n.md)** - Платформа автоматизации с воркерами
5. **[Установка Nginx](07-nginx.md)** - Reverse proxy с SSL (опционально, для production)
6. **[Драйверы и совместимость](08-hardware-drivers.md)** - GPU/NIC/платы
7. **[Мониторинг](09-monitoring.md)** - Prometheus + Grafana
8. **[Бэкапы и восстановление](10-backup-restore.md)** - PostgreSQL
9. **[Устранение неполадок](11-troubleshooting.md)** - диагностика
10. **[Контроль качества](12-quality-checks.md)** - проверка установки
11. **[Управление секретами](13-secrets.md)** - production‑практики
12. **[Правила готовности](14-ready-rules.md)** - gate‑процедуры

## Рекомендуемый порядок установки

1. **Supabase** - базовая инфраструктура БД
   ```bash
   sudo bash scripts/03-setup-supabase.sh
   ```
   См. [03-supabase.md](03-supabase.md) для подробностей

2. **Redis** - очередь задач (можно установить параллельно с Supabase)
   ```bash
   sudo bash scripts/05-setup-redis.sh
   ```
   См. [05-redis.md](05-redis.md) для подробностей

3. **Векторная БД** - настройка pgvector в Supabase
   ```bash
   sudo bash scripts/06-setup-vector-db.sh
   ```
   См. [06-vector-db.md](06-vector-db.md) для подробностей

4. **n8n** - требует Supabase и Redis
   ```bash
   sudo bash scripts/04-setup-n8n.sh
   ```
   См. [04-n8n.md](04-n8n.md) для подробностей

## Объединённая установка

Для быстрой установки всех компонентов используйте единый Docker Compose:

```bash
cd docker-compose
cp env.example .env
# Отредактируйте .env и измените пароли (обязательные значения)
docker compose --env-file .env up -d
```

Для публичного доступа (опционально):
```bash
docker compose -f docker-compose.yml -f docker-compose.override.public.yml up -d
```

Примечания:
- Порты БД и Redis привязаны к `127.0.0.1` для безопасности.
- Для внешнего доступа используйте SSH‑туннель или reverse proxy.
- Supabase Studio требует сервис `supabase_meta` (он включён в compose).
- n8n подключается к БД через PgBouncer (`localhost:6432` для хоста).
- n8n по умолчанию доступен только на `127.0.0.1`, для внешнего доступа используйте override.
- Для production используйте защищённый `.env` или Docker secrets.
- Рекомендуется регулярная ротация паролей (минимум раз в 90 дней).

См. [QUICKSTART.md](../QUICKSTART.md) для подробных инструкций.

## Интеграция с ChatGPT API

После установки всех компонентов настройте интеграцию с ChatGPT API в n8n:

1. Добавьте OpenAI credentials в n8n (Settings → Credentials)
2. Создайте базовый RAG workflow:
   - Webhook → OpenAI Embedding → Postgres (vector search) → OpenAI Chat
3. Настройте мультиагентную архитектуру через несколько workflow

Подробности см. в [04-n8n.md](04-n8n.md), раздел "Интеграция с ChatGPT API".

## Мониторинг и обслуживание

### Проверка статуса сервисов

```bash
docker ps
docker compose -f docker-compose/docker-compose.yml ps
```

### Просмотр логов

```bash
docker logs n8n
docker logs redis
docker logs supabase_db
```

### Резервное копирование

```bash
# Бэкап PostgreSQL
docker exec supabase_db pg_dump -U postgres postgres > backup.sql

# Бэкап Redis
docker exec redis redis-cli -a YOUR_PASSWORD --rdb /data/dump.rdb
```

## Архитектура решения

Подробное описание архитектуры см. в [architecture.md](architecture.md).

## Источники

- [Supabase Self-hosting](https://supabase.com/docs/guides/self-hosting)
- [n8n Documentation](https://docs.n8n.io/)
- [n8n Workers](https://docs.n8n.io/hosting/installation/scaling/)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [Redis Documentation](https://redis.io/docs/)

