#!/bin/bash

# Скрипт проверки готовности после установки

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функции для логирования
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
  log_error "Пожалуйста, запустите скрипт с правами root или через sudo"
  exit 1
fi

# Определяем путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_DIR="$PROJECT_ROOT/docker-compose"
ENV_FILE="$COMPOSE_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  log_error "Файл .env не найден: $ENV_FILE"
  exit 1
fi

# Читаем переменные из .env
get_env_value() {
  local key="$1"
  grep "^${key}=" "$ENV_FILE" | head -n1 | cut -d'=' -f2- | sed "s/^[\"']//;s/[\"']$//"
}

is_placeholder() {
  local value="$1"
  if [ -z "$value" ]; then
    return 0
  fi
  if echo "$value" | grep -qiE "your-secure|change-me|example|password-here"; then
    return 0
  fi
  return 1
}

log_info "=== Ready проверки ==="

# Валидация обязательных переменных
REQUIRED_VARS=(
  "REDIS_PASSWORD"
  "SUPABASE_DB_PASSWORD"
  "N8N_BASIC_AUTH_PASSWORD"
  "N8N_ENCRYPTION_KEY"
  "N8N_USER_MANAGEMENT_JWT_SECRET"
  "GRAFANA_PASSWORD"
)

for var in "${REQUIRED_VARS[@]}"; do
  val="$(get_env_value "$var" || true)"
  if is_placeholder "$val"; then
    log_error "Переменная $var не задана или содержит placeholder"
    exit 1
  fi
done

# Проверка docker compose config
log_info "Проверка docker compose config..."
cd "$COMPOSE_DIR"
docker compose config > /dev/null

# Проверка статуса сервисов
REQUIRED_SERVICES=(
  "supabase_db"
  "redis"
  "pgbouncer"
  "n8n"
  "n8n-worker"
)

for svc in "${REQUIRED_SERVICES[@]}"; do
  if ! docker compose ps --services --filter "status=running" | grep -q "^${svc}$"; then
    log_error "Сервис не запущен: $svc"
    exit 1
  fi
done

# Проверка n8n
if command -v curl &> /dev/null; then
  curl -f http://localhost:5678/healthz > /dev/null
elif command -v wget &> /dev/null; then
  wget -q --spider http://localhost:5678/healthz
else
  log_error "curl или wget не установлен (нужен для healthcheck)"
  exit 1
fi

# Проверка PostgreSQL напрямую
PGPASSWORD="$(get_env_value SUPABASE_DB_PASSWORD)"
docker compose exec -T supabase_db bash -lc "PGPASSWORD='${PGPASSWORD}' psql -U postgres -d postgres -c 'SELECT 1;'" > /dev/null

# Проверка PgBouncer
docker compose exec -T supabase_db bash -lc "PGPASSWORD='${PGPASSWORD}' psql -h pgbouncer -p 6432 -U postgres -d postgres -c 'SELECT 1;'" > /dev/null

# Проверка Redis
REDIS_PASSWORD="$(get_env_value REDIS_PASSWORD)"
docker compose exec -T redis redis-cli -a "$REDIS_PASSWORD" ping | grep -q PONG

# Проверка мониторинга (опционально)
if docker compose ps --services --filter "status=running" | grep -q "^prometheus$"; then
  curl -f http://localhost:9090/-/healthy > /dev/null || log_warn "Prometheus не отвечает"
fi

if docker compose ps --services --filter "status=running" | grep -q "^grafana$"; then
  curl -f http://localhost:3000/api/health > /dev/null || log_warn "Grafana не отвечает"
fi

log_info "Ready проверки пройдены успешно"
