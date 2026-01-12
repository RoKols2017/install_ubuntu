#!/bin/bash

# Скрипт установки n8n с воркером
# Требует Docker, Docker Compose, PostgreSQL и Redis

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

# Проверка Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker не установлен. Установите Docker сначала."
    exit 1
fi

log_info "Начинаем установку n8n с воркером..."

# Создаём директории для данных
N8N_DATA_DIR="$HOME/n8n/data"
N8N_CONFIG_DIR="$HOME/n8n/.n8n"
mkdir -p "$N8N_DATA_DIR"
mkdir -p "$N8N_CONFIG_DIR"

log_info "Директории для данных созданы: $N8N_DATA_DIR"

# Создаём директорию для конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
N8N_COMPOSE_DIR="$PROJECT_DIR/docker-compose/n8n"
mkdir -p "$N8N_COMPOSE_DIR"

# Создаём .env файл, если его нет
if [ ! -f "$N8N_COMPOSE_DIR/.env" ]; then
    log_info "Создание файла .env..."
    cat > "$N8N_COMPOSE_DIR/.env" <<'EOF'
# Базовые настройки
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=change-me-secure-password

# База данных PostgreSQL (Supabase)
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=supabase_db
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=postgres
DB_POSTGRESDB_USER=postgres
DB_POSTGRESDB_PASSWORD=your-supabase-password

# Redis для очередей
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379
QUEUE_BULL_REDIS_PASSWORD=your-redis-password

# Настройки воркера
N8N_WORKERS_ENABLED=true
N8N_WORKERS_COUNT=2

# Webhook URL
WEBHOOK_URL=http://localhost:5678/

# Дополнительные настройки
N8N_METRICS=true
N8N_LOG_LEVEL=info
EOF
    
    log_warn "Создан файл .env. Пожалуйста, измените пароли!"
    log_warn "Редактируйте: $N8N_COMPOSE_DIR/.env"
    read -p "Нажмите Enter после изменения паролей, или Ctrl+C для отмены..."
fi

# Создаём docker-compose.yml
log_info "Создание docker-compose.yml..."
cat > "$N8N_COMPOSE_DIR/docker-compose.yml" <<'EOF'
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    env_file:
      - .env
    volumes:
      - ${HOME}/n8n/data:/home/node/.n8n
    networks:
      - n8n-network
    depends_on:
      - redis
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3

  n8n-worker:
    image: n8nio/n8n:latest
    container_name: n8n-worker
    restart: unless-stopped
    command: worker
    env_file:
      - .env
    networks:
      - n8n-network
    depends_on:
      - redis
      - n8n

networks:
  n8n-network:
    external: true
EOF

# Создаём сеть Docker, если её нет
if ! docker network ls | grep -q n8n-network; then
    log_info "Создание Docker сети n8n-network..."
    docker network create n8n-network
fi

# Запуск n8n
log_info "Запуск n8n..."
cd "$N8N_COMPOSE_DIR"
docker compose up -d

# Ждём запуска
log_info "Ожидание запуска n8n..."
sleep 10

# Проверка статуса
log_info "=== Статус контейнеров ==="
docker ps | grep n8n

log_info "=== Логи n8n (последние 20 строк) ==="
docker logs n8n --tail 20

log_info "=== Логи воркера (последние 20 строк) ==="
docker logs n8n-worker --tail 20

log_info "Установка n8n завершена!"
log_info "Откройте в браузере: http://localhost:5678"
log_warn "Используйте логин и пароль из файла .env"
