# Контроль качества и проверка установки

Этот чек‑лист помогает проверить корректность конфигурации и работоспособность инфраструктуры.

## 1. Проверка конфигурации Docker Compose
```bash
cd docker-compose
docker compose config
```

## 1.1 Автоматический ready‑чек
```bash
sudo bash scripts/99-ready-checks.sh
```

## 2. Проверка скриптов (shellcheck)
```bash
sudo apt install -y shellcheck
shellcheck scripts/*.sh
```

## 3. Smoke‑тесты сервисов

### 3.1 n8n
```bash
curl -f http://localhost:5678/healthz
```

### 3.2 PostgreSQL (Supabase)
```bash
psql -h localhost -p 54322 -U postgres -d postgres -c "SELECT 1;"
```

### 3.3 PgBouncer
```bash
psql -h localhost -p 6432 -U postgres -d postgres -c "SELECT 1;"
```

### 3.4 Redis
```bash
redis-cli -h 127.0.0.1 -p 6379 -a YOUR_REDIS_PASSWORD ping
```

## 4. Проверка мониторинга
```bash
curl -f http://localhost:9090/-/healthy
curl -f http://localhost:3000/api/health
```

## 5. Проверка на чистой VM
1. Разверните чистую VM Ubuntu 24.04 LTS.
2. Пройдите все шаги из `QUICKSTART.md`.
3. Повторите Smoke‑тесты.

## Источники
- https://github.com/koalaman/shellcheck
- https://docs.docker.com/compose/reference/config/
