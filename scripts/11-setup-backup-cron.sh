#!/bin/bash

# Скрипт настройки cron для автоматических бэкапов PostgreSQL

set -Eeuo pipefail

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

trap 'log_error "Ошибка на строке $LINENO: $BASH_COMMAND"' ERR

prompt_value() {
  local prompt="$1"
  local default="$2"
  local value

  if [ ! -t 0 ]; then
    printf '%s\n' "$default"
    return
  fi

  read -rp "$prompt [$default]: " value
  printf '%s\n' "${value:-$default}"
}

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
  log_error "Пожалуйста, запустите скрипт с правами root или через sudo"
  exit 1
fi

# Определяем путь к директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_SCRIPT="$PROJECT_ROOT/scripts/10-backup-postgres.sh"

if [ ! -f "$BACKUP_SCRIPT" ]; then
  log_error "Скрипт бэкапа не найден: $BACKUP_SCRIPT"
  exit 1
fi

# Параметры по умолчанию
DEFAULT_SCHEDULE="0 2 * * *"
DEFAULT_BACKUP_DIR="/opt/backups"
DEFAULT_LOG_FILE="/var/log/install-ubuntu-backup.log"
DEFAULT_RETENTION_DAYS="14"

# Запрашиваем параметры
CRON_SCHEDULE="${CRON_SCHEDULE:-$(prompt_value "Cron расписание" "$DEFAULT_SCHEDULE")}"
BACKUP_DIR="${BACKUP_DIR:-$(prompt_value "Каталог бэкапов" "$DEFAULT_BACKUP_DIR")}"
LOG_FILE="${LOG_FILE:-$(prompt_value "Файл логов" "$DEFAULT_LOG_FILE")}"
RETENTION_DAYS="${RETENTION_DAYS:-$(prompt_value "Хранить бэкапы дней" "$DEFAULT_RETENTION_DAYS")}"

if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
  log_error "RETENTION_DAYS должен быть числом"
  exit 1
fi

log_info "Будет создан cron:"
log_info "  $CRON_SCHEDULE root BACKUP_DIR=$BACKUP_DIR RETENTION_DAYS=$RETENTION_DAYS $BACKUP_SCRIPT >> $LOG_FILE 2>&1"

# Подтверждение (критичное изменение системы)
if [ ! -t 0 ]; then
  CONFIRM="${CONFIRM_INSTALL_CRON:-N}"
else
  read -rp "Продолжить и установить cron? (y/N): " CONFIRM
fi
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  log_warn "Отменено пользователем"
  exit 1
fi

# Создаём cron файл
CRON_FILE="/etc/cron.d/install-ubuntu-backup"
cat > "$CRON_FILE" <<EOF
BACKUP_DIR=$BACKUP_DIR
RETENTION_DAYS=$RETENTION_DAYS
$CRON_SCHEDULE root $BACKUP_SCRIPT >> $LOG_FILE 2>&1
EOF

chmod 0644 "$CRON_FILE"

log_info "Cron установлен: $CRON_FILE"
log_info "Для удаления: sudo rm -f $CRON_FILE"
