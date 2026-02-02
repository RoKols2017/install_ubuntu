#!/bin/bash

# Скрипт предварительной проверки сервера перед установкой

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
ENV_FILE="$PROJECT_ROOT/docker-compose/.env"

log_info "=== Preflight проверка ==="

# Проверка ОС
if ! grep -qi "ubuntu" /etc/os-release; then
  log_error "ОС должна быть Ubuntu Server"
  exit 1
fi

OS_VERSION="$(. /etc/os-release && echo "${VERSION_ID}")"
if [ "$OS_VERSION" != "24.04" ] && [ "$OS_VERSION" != "22.04" ]; then
  log_warn "Рекомендуется Ubuntu 24.04 LTS (обнаружено: $OS_VERSION)"
fi

# Проверка архитектуры
ARCH="$(uname -m)"
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
  log_warn "Рекомендуется архитектура x86_64 (обнаружено: $ARCH)"
fi

# Проверка RAM
RAM_MB="$(free -m | awk '/Mem:/{print $2}')"
if [ "$RAM_MB" -lt 4096 ]; then
  log_error "Недостаточно RAM: ${RAM_MB}MB (минимум 4096MB)"
  exit 1
fi

# Проверка диска
DISK_GB="$(df -BG / | awk 'NR==2{gsub("G","",$4); print $4}')"
if [ "$DISK_GB" -lt 50 ]; then
  log_error "Недостаточно места на диске: ${DISK_GB}GB (минимум 50GB)"
  exit 1
fi

# Проверка ключевых утилит
if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
  log_warn "curl/wget не установлен (нужен для healthcheck)"
fi

if ! command -v docker &> /dev/null; then
  log_warn "Docker не установлен (Этап 2)"
fi

if ! docker compose version &> /dev/null; then
  log_warn "Docker Compose не установлен (Этап 2)"
fi

# Проверка .env (если есть)
if [ -f "$ENV_FILE" ]; then
  log_info "Файл .env найден: $ENV_FILE"
else
  log_warn "Файл .env не найден (создаётся позже на этапе настройки)"
fi

# Сбор аппаратной информации (для матрицы совместимости)
log_info "Сводка железа:"
dmidecode -t system -t baseboard || true
lspci -nnk || true
lsusb || true
uname -r || true

log_info "Preflight проверка завершена"
