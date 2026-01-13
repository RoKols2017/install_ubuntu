#!/bin/bash

# Скрипт установки Supabase (Self-hosted через Docker Compose)
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

log_info "Начинаем установку Supabase через Docker Compose..."

# Определяем путь к директории проекта (где находится docker-compose.yml)
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
    log_warn "Файл .env не найден. Создаём из примера..."
    if [ -f "env.example" ]; then
        cp env.example .env
        log_warn "Создан файл .env из env.example"
        log_warn "ВАЖНО: Отредактируйте .env и измените пароли перед продолжением!"
        log_warn "Файл: $COMPOSE_DIR/.env"
        read -p "Нажмите Enter после изменения паролей в .env, или Ctrl+C для отмены..."
    else
        log_error "Файл env.example не найден!"
        exit 1
    fi
fi

# Запуск сервиса Supabase PostgreSQL
log_info "Запуск Supabase PostgreSQL..."
docker compose up -d supabase_db

# Ожидание готовности БД
log_info "Ожидание готовности базы данных..."
sleep 5

# Проверка статуса
if docker compose ps supabase_db | grep -q "Up"; then
    log_info "Supabase PostgreSQL запущен"
else
    log_error "Не удалось запустить Supabase PostgreSQL"
    docker compose logs supabase_db
    exit 1
fi

# Выводим информацию о подключении
log_info "=== Информация о подключении ==="
echo ""
log_info "PostgreSQL:"
log_info "  Хост: localhost"
log_info "  Порт: 54322"
log_info "  База данных: postgres"
log_info "  Пользователь: postgres"
log_info "  Пароль: см. в файле .env (SUPABASE_DB_PASSWORD)"
echo ""
log_warn "Примечание: Supabase Studio требует дополнительной настройки и не включён в этот скрипт"
echo ""

# Проверка подключения к БД
log_info "Проверка подключения к базе данных..."
if docker compose exec -T supabase_db pg_isready -U postgres > /dev/null 2>&1; then
    log_info "Подключение к базе данных успешно!"
else
    log_warn "Не удалось проверить подключение к базе данных"
fi

log_info "Установка Supabase завершена!"
log_warn "Не забудьте сохранить пароли из файла .env!"
