#!/bin/bash

# Скрипт настройки cron для автоматических бэкапов PostgreSQL

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
BACKUP_SCRIPT="$PROJECT_ROOT/scripts/08-backup-postgres.sh"

if [ ! -f "$BACKUP_SCRIPT" ]; then
  log_error "Скрипт бэкапа не найден: $BACKUP_SCRIPT"
  exit 1
fi

# Параметры по умолчанию
DEFAULT_SCHEDULE="0 2 * * *"
DEFAULT_BACKUP_DIR="/opt/backups"
DEFAULT_LOG_FILE="/var/log/install-ubuntu-backup.log"

# Запрашиваем параметры
read -rp "Cron расписание [$DEFAULT_SCHEDULE]: " CRON_SCHEDULE
CRON_SCHEDULE="${CRON_SCHEDULE:-$DEFAULT_SCHEDULE}"

read -rp "Каталог бэкапов [$DEFAULT_BACKUP_DIR]: " BACKUP_DIR
BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"

read -rp "Файл логов [$DEFAULT_LOG_FILE]: " LOG_FILE
LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"

log_info "Будет создан cron:"
log_info "  $CRON_SCHEDULE root BACKUP_DIR=$BACKUP_DIR $BACKUP_SCRIPT >> $LOG_FILE 2>&1"

# Подтверждение (критичное изменение системы)
read -rp "Продолжить и установить cron? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  log_warn "Отменено пользователем"
  exit 1
fi

# Создаём cron файл
CRON_FILE="/etc/cron.d/install-ubuntu-backup"
cat > "$CRON_FILE" <<EOF
BACKUP_DIR=$BACKUP_DIR
$CRON_SCHEDULE root $BACKUP_SCRIPT >> $LOG_FILE 2>&1
EOF

chmod 0644 "$CRON_FILE"

log_info "Cron установлен: $CRON_FILE"
log_info "Для удаления: sudo rm -f $CRON_FILE"
