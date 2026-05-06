[← n8n](04-n8n.md) · [Back to README](../README.md) · [pgvector →](06-vector-db.md)

# Установка Redis

Redis используется как кэш и очередь задач для n8n worker mode. В основном compose-файле сервис закрыт на `127.0.0.1`, защищён паролем из `.env` и настроен с AOF persistence.

## Предварительные требования

- Docker и Docker Compose установлены: [Docker Installation](02-docker-installation.md).
- Файл `docker-compose/.env` создан из `env.example` или через `scripts/12-generate-secrets.sh`.
- Переменная `REDIS_PASSWORD` задана и не содержит placeholder-значение.

## Шаг 1: Установка Redis

Рекомендуемый путь через скрипт:

```bash
sudo bash scripts/06-setup-redis.sh
```

Альтернатива через общий compose-стек:

```bash
cd docker-compose
docker compose --env-file .env up -d redis
```

## Шаг 2: Настройка пароля

Сгенерируйте секреты автоматически:

```bash
sudo bash scripts/12-generate-secrets.sh
```

Или проверьте переменную вручную в `docker-compose/.env`:

```bash
REDIS_PASSWORD=your-secure-redis-password-here
```

Не используйте значение из примера в production. Пароль нужен для Redis healthcheck, n8n queue mode и ручной диагностики.

## Шаг 3: Проверка работы

```bash
cd docker-compose
docker compose ps redis
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" ping
```

Ожидаемый ответ:

```text
PONG
```

Если переменные окружения не загружены в shell, можно взять пароль из `docker-compose/.env` и передать его явно.

## Конфигурация

Актуальная Redis-команда находится в `docker-compose/docker-compose.yml`:

```yaml
command: redis-server --requirepass ${REDIS_PASSWORD:?REDIS_PASSWORD is required} --appendonly yes --maxmemory 512mb --maxmemory-policy allkeys-lru
```

Что это означает:

| Параметр | Назначение |
|----------|------------|
| `--requirepass` | Требует пароль из `.env` |
| `--appendonly yes` | Включает AOF persistence |
| `--maxmemory 512mb` | Ограничивает память Redis |
| `--maxmemory-policy allkeys-lru` | Удаляет наименее используемые ключи при лимите памяти |

## Использование с n8n

n8n подключается к Redis внутри Docker-сети по имени сервиса `redis`:

```env
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379
QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}
```

Эти значения уже заданы в `docker-compose/docker-compose.yml` для сервисов `n8n` и `n8n-worker`.

## Мониторинг

Базовые команды диагностики:

```bash
cd docker-compose
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" INFO server
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" INFO memory
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" DBSIZE
```

Не используйте `KEYS "*"` на production с большим количеством ключей: команда может заблокировать Redis на время выполнения.

## Резервное копирование

Для ручного RDB-снимка:

```bash
cd docker-compose
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" --rdb /data/dump.rdb
```

Для инфраструктурного backup-процесса используйте [Backups](10-backup-restore.md).

## Устранение неполадок

### Redis не запускается

```bash
cd docker-compose
docker compose logs --tail 100 redis
docker compose config
```

Проверьте, что `REDIS_PASSWORD` задан в `.env` и порт `6379` не занят другим процессом.

### Ошибка аутентификации

```bash
cd docker-compose
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" ping
```

Если команда не возвращает `PONG`, сравните пароль в `docker-compose/.env` с переменной, которую использует текущий shell.

### Нехватка памяти

```bash
cd docker-compose
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" INFO memory
```

Если памяти недостаточно, увеличьте `--maxmemory` в `docker-compose/docker-compose.yml` и перезапустите Redis.

## Источники

- [Redis Documentation](https://redis.io/docs/)
- [Redis Persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/)
- [Redis Memory Optimization](https://redis.io/docs/latest/operate/oss_and_stack/management/optimization/memory-optimization/)

## See Also

- [n8n](04-n8n.md) — сервис, использующий Redis для очередей.
- [Monitoring](09-monitoring.md) — Prometheus/Grafana слой для runtime-наблюдения.
- [Troubleshooting](11-troubleshooting.md) — общие команды диагностики compose-стека.
