#!/bin/bash

# Скрипт установки Supabase (Self-hosted)
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

log_info "Начинаем установку Supabase..."

# Создаём директорию для проекта
SUPABASE_DIR="$HOME/supabase"
mkdir -p "$SUPABASE_DIR"
cd "$SUPABASE_DIR"

# Проверяем, установлен ли Supabase CLI
if ! command -v supabase &> /dev/null; then
    log_info "Установка Supabase CLI через Docker..."
    # Используем Docker для запуска Supabase CLI
    alias supabase="docker run --rm -it -v $(pwd):/workspace -w /workspace supabase/cli:latest"
    log_info "Supabase CLI будет использоваться через Docker"
fi

# Инициализация проекта (если ещё не инициализирован)
if [ ! -f "config.toml" ]; then
    log_info "Инициализация проекта Supabase..."
    
    # Создаём базовую конфигурацию
    cat > config.toml <<'EOF'
[project]
name = "supabase-project"

[auth]
site_url = "http://localhost:3000"
additional_redirect_urls = []

[api]
port = 54321
schemas = ["public", "storage", "graphql_public"]
extra_search_path = ["public", "extensions"]

[db]
port = 54322
password = "your-super-secret-password-CHANGE-ME"
EOF
    
    log_warn "Создан файл config.toml. Пожалуйста, измените пароль БД!"
    log_warn "Редактируйте: $SUPABASE_DIR/config.toml"
    
    read -p "Нажмите Enter после изменения пароля в config.toml, или Ctrl+C для отмены..."
fi

# Запуск Supabase
log_info "Запуск Supabase..."
if command -v supabase &> /dev/null && ! command supabase | grep -q docker; then
    supabase start
else
    # Используем Docker для запуска Supabase
    docker run --rm -it \
        -v "$(pwd):/workspace" \
        -w /workspace \
        supabase/cli:latest start
fi

log_info "Supabase запущен!"

# Выводим информацию о подключении
log_info "=== Информация о подключении ==="
if command -v supabase &> /dev/null && ! command supabase | grep -q docker; then
    supabase status
else
    docker run --rm -it \
        -v "$(pwd):/workspace" \
        -w /workspace \
        supabase/cli:latest status
fi

log_info "Установка Supabase завершена!"
log_warn "Не забудьте сохранить API ключи и пароли!"
