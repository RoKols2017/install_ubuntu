# Установка Redis

Redis используется как кэш и очередь задач для n8n.

## Предварительные требования

- Docker установлен ([Этап 2](02-docker-installation.md))
- Порт: 6379

## Шаг 1: Установка Redis

```bash
# Используя скрипт (рекомендуется)
sudo bash scripts/05-setup-redis.sh

# Или вручную через основной docker-compose.yml
cd docker-compose
docker compose up -d redis
```

## Шаг 2: Настройка пароля Redis

Скрипт автоматически генерирует пароль и сохраняет его в основной `.env` файл (`docker-compose/.env`).

Если устанавливаете вручную, убедитесь, что в файле `docker-compose/.env` есть переменная:

```bash
REDIS_PASSWORD=your-secure-redis-password
```

**Важно:** Сохраните этот пароль! Он понадобится для настройки n8n.

## Шаг 3: Проверка работы

```bash
# Подключение к Redis
docker exec -it redis redis-cli -a your-redis-password

# В Redis CLI:
PING  # Должно вернуть PONG
INFO  # Информация о сервере
EXIT  # Выход
```

Или через скрипт:

```bash
docker exec redis redis-cli -a YOUR_PASSWORD ping
```

## Конфигурация

### Настройка персистентности

Redis настроен на AOF (Append Only File) для персистентности данных. Это означает, что все операции записываются в файл и восстанавливаются при перезапуске.

### Настройка памяти

По умолчанию установлен лимит 512 MB. Для изменения отредактируйте основной `docker-compose/docker-compose.yml`:

```yaml
command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes --maxmemory 1gb --maxmemory-policy allkeys-lru
```

### Политики eviction

- `allkeys-lru` - удаляет наименее используемые ключи при достижении лимита памяти
- Другие варианты: `volatile-lru`, `allkeys-random`, `noeviction`

## Использование с n8n

Redis используется n8n для:
- Очередей задач (Bull queues)
- Кэширования результатов
- Pub/Sub для real-time коммуникации

Настройте в n8n через переменные окружения:
- `QUEUE_BULL_REDIS_HOST=redis`
- `QUEUE_BULL_REDIS_PORT=6379`
- `QUEUE_BULL_REDIS_PASSWORD=your-redis-password`

## Мониторинг

```bash
# Информация о сервере
docker exec redis redis-cli -a YOUR_PASSWORD INFO server

# Статистика памяти
docker exec redis redis-cli -a YOUR_PASSWORD INFO memory

# Количество ключей
docker exec redis redis-cli -a YOUR_PASSWORD DBSIZE

# Список всех ключей (осторожно на production!)
docker exec redis redis-cli -a YOUR_PASSWORD KEYS "*"
```

## Резервное копирование

```bash
# Создание RDB снимка
docker exec redis redis-cli -a YOUR_PASSWORD --rdb /data/dump.rdb

# Копирование файла AOF
docker cp redis:/data/appendonly.aof ./backup/
```

## Устранение неполадок

### Проблема: Redis не запускается

```bash
# Проверьте логи
docker logs redis

# Проверьте порт
sudo netstat -tlnp | grep 6379
```

### Проблема: Ошибка аутентификации

```bash
# Проверьте пароль в .env файле
# Убедитесь, что используете правильный пароль при подключении
```

### Проблема: Нехватка памяти

```bash
# Проверьте использование памяти
docker exec redis redis-cli -a YOUR_PASSWORD INFO memory

# Увеличьте лимит в docker-compose.yml или очистите старые ключи
docker exec redis redis-cli -a YOUR_PASSWORD FLUSHDB  # ОСТОРОЖНО!
```

## Оптимизация производительности

### Настройка для production

1. **Отключите персистентность** (если данные не критичны):
   ```yaml
   command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 1gb
   ```

2. **Используйте репликацию** для высокой доступности

3. **Настройте мониторинг** через Redis INFO команды

## Следующие шаги

После установки Redis:
1. Установите n8n: [04-n8n.md](04-n8n.md)

## Источники

- [Официальная документация Redis](https://redis.io/docs/)
- [Redis Best Practices](https://redis.io/docs/manual/patterns/)

