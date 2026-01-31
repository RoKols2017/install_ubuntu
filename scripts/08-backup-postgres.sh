#!/bin/bash

# Скрипт резервного копирования PostgreSQL (Supabase)
# Требует установленный postgresql-client

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

# Проверка pg_dump
if ! command -v pg_dump &> /dev/null; then
    log_error "pg_dump не установлен. Установите: sudo apt install postgresql-client"
    exit 1
fi

# Определяем путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_DIR="$PROJECT_ROOT/docker-compose"
ENV_FILE="$COMPOSE_DIR/.env"

# Параметры подключения по умолчанию
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-54322}"
DB_NAME="${DB_NAME:-postgres}"
DB_USER="${DB_USER:-postgres}"

# Путь для бэкапов
BACKUP_DIR="${BACKUP_DIR:-/opt/backups}"

# Получаем пароль из .env или запрашиваем вручную
DB_PASSWORD=""
if [ -f "$ENV_FILE" ]; then
    DB_PASSWORD=$(grep "^SUPABASE_DB_PASSWORD=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | sed "s/^[\"']//;s/[\"']$//" | xargs || echo "")
fi

if [ -z "$DB_PASSWORD" ]; then
    log_warn "SUPABASE_DB_PASSWORD не найден в .env, введите пароль вручную"
    read -sp "Пароль PostgreSQL: " DB_PASSWORD
    echo ""
fi

if [ -z "$DB_PASSWORD" ]; then
    log_error "Пароль PostgreSQL не задан"
    exit 1
fi

# Создаём директорию для бэкапов
mkdir -p "$BACKUP_DIR"

# Используем временный PGPASSFILE, чтобы не светить пароль в окружении
PGPASS_FILE=$(mktemp)
chmod 600 "$PGPASS_FILE"
echo "$DB_HOST:$DB_PORT:$DB_NAME:$DB_USER:$DB_PASSWORD" > "$PGPASS_FILE"
export PGPASSFILE="$PGPASS_FILE"
trap 'rm -f "$PGPASS_FILE"' EXIT

# Создаём бэкап
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/postgres_${TIMESTAMP}.sql.gz"

log_info "Начинаем бэкап PostgreSQL..."
log_info "  Хост: $DB_HOST"
log_info "  Порт: $DB_PORT"
log_info "  База: $DB_NAME"
log_info "  Файл: $BACKUP_FILE"

pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" | gzip > "$BACKUP_FILE"

log_info "Бэкап завершён успешно"
