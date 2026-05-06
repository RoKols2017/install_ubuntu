[← Troubleshooting](11-troubleshooting.md) · [Back to README](../README.md) · [Secrets →](13-secrets.md)

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
bash scripts/98-verify-scripts.sh
```

Скрипт запускает `bash -n scripts/*.sh` и, если установлен ShellCheck, `shellcheck scripts/*.sh`.

Установить ShellCheck вручную:

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

## See Also

- [Ready Rules](14-ready-rules.md) — gate-критерии перед production.
- [Troubleshooting](11-troubleshooting.md) — что смотреть при падении проверок.
- [Scripts Order](15-scripts-order.md) — где запускать ready checks в install flow.
