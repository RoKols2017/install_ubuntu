#!/bin/bash

# Скрипт настройки векторной БД (pgvector)
# Требует работающий Supabase или PostgreSQL с pgvector

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

log_info "Начинаем настройку векторной БД (pgvector)..."

# Проверка наличия psql
if ! command -v psql &> /dev/null; then
    log_error "psql не установлен. Установите PostgreSQL client: sudo apt install postgresql-client"
    exit 1
fi

# Определяем путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_DIR="$PROJECT_ROOT/docker-compose"

# Параметры подключения по умолчанию для Supabase
DB_HOST="localhost"
DB_PORT="54322"
DB_NAME="postgres"
DB_USER="postgres"

# Пытаемся прочитать пароль из .env файла
if [ -f "$COMPOSE_DIR/.env" ]; then
    # Читаем пароль, удаляя кавычки и пробелы
    DB_PASSWORD=$(grep "^SUPABASE_DB_PASSWORD=" "$COMPOSE_DIR/.env" 2>/dev/null | cut -d'=' -f2- | sed "s/^[\"']//;s/[\"']$//" | xargs || echo "")
    if [ -n "$DB_PASSWORD" ]; then
        log_info "Параметры подключения загружены из .env файла"
    else
        log_warn "Переменная SUPABASE_DB_PASSWORD не найдена в .env, запрашиваем вручную..."
        read -sp "Пароль PostgreSQL: " DB_PASSWORD
        echo ""
    fi
else
    log_warn "Файл .env не найден в $COMPOSE_DIR, запрашиваем параметры вручную..."
    log_warn "Рекомендуется сначала запустить скрипт установки Supabase (04-setup-supabase.sh)"
    echo ""
    read -p "Хост PostgreSQL [localhost]: " DB_HOST_INPUT
    DB_HOST=${DB_HOST_INPUT:-localhost}
    read -p "Порт PostgreSQL [54322]: " DB_PORT_INPUT
    DB_PORT=${DB_PORT_INPUT:-54322}
    read -p "Имя базы данных [postgres]: " DB_NAME_INPUT
    DB_NAME=${DB_NAME_INPUT:-postgres}
    read -p "Пользователь [postgres]: " DB_USER_INPUT
    DB_USER=${DB_USER_INPUT:-postgres}
    read -sp "Пароль: " DB_PASSWORD
    echo ""
fi

# Проверяем подключение
log_info "Проверка подключения к базе данных..."
log_info "  Хост: $DB_HOST"
log_info "  Порт: $DB_PORT"
log_info "  База данных: $DB_NAME"
log_info "  Пользователь: $DB_USER"

# Используем временный PGPASSFILE, чтобы не светить пароль в окружении
PGPASS_FILE=$(mktemp)
chmod 600 "$PGPASS_FILE"
echo "$DB_HOST:$DB_PORT:$DB_NAME:$DB_USER:$DB_PASSWORD" > "$PGPASS_FILE"
export PGPASSFILE="$PGPASS_FILE"
trap 'rm -f "$PGPASS_FILE"' EXIT

# Пытаемся подключиться
PSQL_OUTPUT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" 2>&1)
PSQL_EXIT_CODE=$?

if [ $PSQL_EXIT_CODE -ne 0 ]; then
    log_error "Не удалось подключиться к базе данных."
    log_error "Ошибка: $PSQL_OUTPUT"
    log_error ""
    log_error "Проверьте:"
    log_error "  1. Запущен ли контейнер supabase_db: docker ps | grep supabase_db"
    log_error "  2. Правильность пароля в файле $COMPOSE_DIR/.env (SUPABASE_DB_PASSWORD)"
    log_error "  3. Доступность порта $DB_PORT: sudo netstat -tlnp | grep $DB_PORT"
    exit 1
fi

log_info "Подключение успешно!"

# Проверяем наличие расширения pgvector
log_info "Проверка расширения pgvector..."
if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "\dx vector" | grep -q vector; then
    log_info "Расширение pgvector уже установлено"
else
    log_info "Установка расширения pgvector..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS vector;"
    log_info "Расширение pgvector установлено"
fi

# Используем единый SQL файл как источник истины
SQL_SCRIPT="$COMPOSE_DIR/supabase/init.sql"
if [ ! -f "$SQL_SCRIPT" ]; then
  log_error "SQL файл не найден: $SQL_SCRIPT"
  exit 1
fi

# Выполняем SQL скрипт
log_info "Создание таблиц и функций..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SQL_SCRIPT"

# Проверяем созданные объекты
log_info "Проверка созданных объектов..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
\dt documents
\df match_documents
EOF

log_info "=== Настройка завершена ==="
log_info "Созданы следующие объекты:"
log_info "  - Таблица documents (для хранения документов с эмбеддингами)"
log_info "  - Таблица chat_sessions (для хранения сессий чата)"
log_info "  - Функция match_documents (для векторного поиска)"
log_info "  - Индексы для оптимизации поиска"

log_warn "Пример использования функции match_documents:"
log_warn "  SELECT * FROM match_documents("
log_warn "    '[0.1, 0.2, ...]'::vector(1536),  -- ваш embedding"
log_warn "    0.7,                              -- порог схожести"
log_warn "    10                                 -- количество результатов"
log_warn "  );"

log_info "Настройка векторной БД завершена!"

