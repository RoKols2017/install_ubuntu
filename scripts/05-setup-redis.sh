#!/bin/bash

# Скрипт установки Redis
# Требует Docker и Docker Compose

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

log_info "Начинаем установку Redis..."

# Создаём директорию для конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REDIS_COMPOSE_DIR="$PROJECT_DIR/docker-compose/redis"
mkdir -p "$REDIS_COMPOSE_DIR"

# Создаём .env файл, если его нет
if [ ! -f "$REDIS_COMPOSE_DIR/.env" ]; then
    log_info "Создание файла .env..."
    # Генерируем случайный пароль
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    cat > "$REDIS_COMPOSE_DIR/.env" <<EOF
REDIS_PASSWORD=$REDIS_PASSWORD
EOF
    log_info "Пароль Redis сгенерирован и сохранён в .env"
    log_warn "Пароль Redis: $REDIS_PASSWORD"
    log_warn "Сохраните этот пароль! Он понадобится для настройки n8n."
else
    log_info "Файл .env уже существует"
    REDIS_PASSWORD=$(grep REDIS_PASSWORD "$REDIS_COMPOSE_DIR/.env" | cut -d'=' -f2)
fi

# Создаём docker-compose.yml
log_info "Создание docker-compose.yml..."
cat > "$REDIS_COMPOSE_DIR/docker-compose.yml" <<'EOF'
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes --maxmemory 512mb --maxmemory-policy allkeys-lru
    volumes:
      - redis-data:/data
    networks:
      - n8n-network
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 3s
      retries: 3

volumes:
  redis-data:

networks:
  n8n-network:
    external: true
EOF

# Создаём сеть Docker, если её нет
if ! docker network ls | grep -q n8n-network; then
    log_info "Создание Docker сети n8n-network..."
    docker network create n8n-network
fi

# Запуск Redis
log_info "Запуск Redis..."
cd "$REDIS_COMPOSE_DIR"
docker compose up -d

# Ждём запуска
log_info "Ожидание запуска Redis..."
sleep 5

# Проверка статуса
log_info "=== Статус контейнера ==="
docker ps | grep redis

# Тестирование подключения
log_info "=== Тестирование подключения ==="
if docker exec redis redis-cli -a "$REDIS_PASSWORD" ping | grep -q PONG; then
    log_info "Redis работает корректно!"
else
    log_error "Не удалось подключиться к Redis"
    exit 1
fi

# Выводим информацию
log_info "=== Информация о Redis ==="
docker exec redis redis-cli -a "$REDIS_PASSWORD" INFO server | head -10

log_info "Установка Redis завершена!"
log_warn "Пароль Redis: $REDIS_PASSWORD"
log_warn "Используйте этот пароль в настройках n8n и других сервисов"
