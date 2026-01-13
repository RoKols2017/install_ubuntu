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

# Функция генерации безопасного пароля
generate_password() {
    # Генерируем пароль длиной 32 символа из букв, цифр и спецсимволов
    openssl rand -base64 24 | tr -d "=+/" | cut -c1-32
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
    log_info "Создание файла .env с автоматически сгенерированными паролями..."
    
    if [ -f "$N8N_COMPOSE_DIR/env.example" ]; then
        # Пытаемся подтянуть пароли из основного .env файла (если есть)
        MAIN_ENV_FILE="$PROJECT_DIR/docker-compose/.env"
        if [ -f "$MAIN_ENV_FILE" ]; then
            log_info "Используем пароли из основного .env файла..."
            SUPABASE_PASSWORD=$(grep "^SUPABASE_DB_PASSWORD=" "$MAIN_ENV_FILE" | cut -d'=' -f2 || echo "")
            REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" "$MAIN_ENV_FILE" | cut -d'=' -f2 || echo "")
        else
            SUPABASE_PASSWORD=""
            REDIS_PASSWORD=""
        fi
        
        # Генерируем пароли, если они не были найдены
        if [ -z "$SUPABASE_PASSWORD" ]; then
            SUPABASE_PASSWORD=$(generate_password)
            log_warn "Пароль для Supabase не найден в основном .env, сгенерирован новый"
        fi
        
        if [ -z "$REDIS_PASSWORD" ]; then
            REDIS_PASSWORD=$(generate_password)
            log_warn "Пароль для Redis не найден в основном .env, сгенерирован новый"
        fi
        
        # Генерируем пароль для n8n
        N8N_PASSWORD=$(generate_password)
        
        # Создаём .env файл на основе env.example
        sed -e "s/your-secure-password-here/${N8N_PASSWORD}/" \
            -e "s/your-supabase-password-here/${SUPABASE_PASSWORD}/" \
            -e "s/your-redis-password-here/${REDIS_PASSWORD}/" \
            "$N8N_COMPOSE_DIR/env.example" > "$N8N_COMPOSE_DIR/.env"
        
        log_info "Файл .env создан с автоматически сгенерированными паролями"
    else
        log_error "Файл env.example не найден в $N8N_COMPOSE_DIR"
        exit 1
    fi
else
    log_info "Файл .env уже существует"
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

