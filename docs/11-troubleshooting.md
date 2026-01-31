# Устранение неполадок

Краткий справочник типовых проблем и решений.

## 1. Контейнеры не запускаются
```bash
cd docker-compose
docker compose ps
docker compose logs --tail 100
```

Проверьте:
- есть ли файл `.env`
- заданы ли обязательные переменные (`REDIS_PASSWORD`, `SUPABASE_DB_PASSWORD`, `N8N_BASIC_AUTH_PASSWORD`, `GRAFANA_PASSWORD`)

## 2. Ошибка подключения к PostgreSQL
```bash
docker ps | grep supabase_db
docker logs supabase_db
psql -h localhost -p 54322 -U postgres -d postgres -c "SELECT 1;"
```

## 3. Ошибка подключения к Redis
```bash
docker ps | grep redis
docker logs redis
redis-cli -h 127.0.0.1 -p 6379 -a YOUR_REDIS_PASSWORD ping
```

## 4. n8n не открывается
```bash
docker ps | grep n8n
docker logs n8n
curl -f http://localhost:5678/healthz
```

## 5. Конфликт портов
```bash
ss -tlnp
```
Если порт занят, измените привязку в `docker-compose.yml`.

## 6. Supabase Studio не открывается
```bash
docker ps | grep supabase_studio
docker logs supabase_studio
docker ps | grep supabase_meta
```
Studio требует запущенный `supabase_meta`.

## Источники
- https://docs.docker.com/engine/reference/commandline/docker/
- https://docs.docker.com/compose/reference/
