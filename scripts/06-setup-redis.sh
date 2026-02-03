#!/bin/bash

# Скрипт установки Redis (использует основной docker-compose.yml)
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

if ! docker compose version &> /dev/null; then
    log_error "Docker Compose не установлен. Установите Docker Compose сначала."
    exit 1
fi

log_info "Начинаем установку Redis..."

# Определяем путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_DIR="$PROJECT_ROOT/docker-compose"

# Проверяем наличие docker-compose.yml
if [ ! -f "$COMPOSE_DIR/docker-compose.yml" ]; then
    log_error "Файл docker-compose.yml не найден в $COMPOSE_DIR"
    exit 1
fi

cd "$COMPOSE_DIR"

# Проверяем наличие .env файла
if [ ! -f ".env" ]; then
    log_info "Файл .env не найден. Создаём с автоматически сгенерированным паролем..."
    if [ -f "env.example" ]; then
        # Функция генерации безопасного пароля
        generate_password() {
            openssl rand -base64 24 | tr -d "=+/" | cut -c1-32
        }
        
        # Генерируем пароли
        REDIS_PASSWORD=$(generate_password)
        SUPABASE_PASSWORD=$(generate_password)
        N8N_PASSWORD=$(generate_password)
        
        # Создаём .env файл с сгенерированными паролями
        sed -e "s/your-secure-redis-password-here/${REDIS_PASSWORD}/" \
            -e "s/your-secure-supabase-password-here/${SUPABASE_PASSWORD}/" \
            -e "s/your-secure-n8n-password-here/${N8N_PASSWORD}/" \
            env.example > .env
        
        log_info "Файл .env создан с автоматически сгенерированными паролями"
    else
        log_error "Файл env.example не найден!"
        exit 1
    fi
else
    log_info "Файл .env уже существует"
fi

# Проверяем, что переменная REDIS_PASSWORD есть в .env
if ! grep -q "^REDIS_PASSWORD=" .env 2>/dev/null; then
    log_warn "Переменная REDIS_PASSWORD не найдена в .env"
    log_info "Добавляем переменную REDIS_PASSWORD в .env..."
    
    # Функция генерации безопасного пароля
    generate_password() {
        openssl rand -base64 24 | tr -d "=+/" | cut -c1-32
    }
    
    REDIS_PASSWORD=$(generate_password)
    
    # Добавляем переменную REDIS_PASSWORD в .env
    if grep -q "^# Redis" .env; then
        sed -i "/^# Redis/a REDIS_PASSWORD=${REDIS_PASSWORD}" .env
    else
        echo "" >> .env
        echo "# Redis" >> .env
        echo "REDIS_PASSWORD=${REDIS_PASSWORD}" >> .env
    fi
    
    log_info "Переменная REDIS_PASSWORD добавлена в .env"
fi

# Запуск Redis из основного docker-compose.yml
log_info "Запуск Redis..."
docker compose up -d redis

# Ждём запуска
log_info "Ожидание запуска Redis..."
sleep 5

# Проверка статуса
log_info "=== Статус контейнера ==="
docker compose ps redis

# Получаем пароль для тестирования
REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" .env | cut -d'=' -f2)

# Тестирование подключения
log_info "=== Тестирование подключения ==="
if docker compose exec -T redis redis-cli -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q PONG; then
    log_info "Redis работает корректно!"
else
    log_warn "Не удалось подключиться к Redis (возможно, ещё запускается)"
    log_info "Проверяем логи..."
    docker compose logs --tail 20 redis
fi

# Выводим информацию
log_info "=== Информация о Redis ==="
log_info "Хост: localhost"
log_info "Порт: 6379"
log_info "Пароль: см. в файле .env (REDIS_PASSWORD)"
log_info "Для просмотра пароля: grep REDIS_PASSWORD $COMPOSE_DIR/.env"
echo ""

log_info "Установка Redis завершена!"
log_warn "Пароль Redis сохранён в файле .env"
