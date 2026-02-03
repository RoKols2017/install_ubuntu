#!/bin/bash

# Скрипт установки драйверов NVIDIA (если видеокарта обнаружена)

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

log_info "Проверка наличия видеокарты NVIDIA..."

if ! command -v lspci &> /dev/null; then
  log_warn "lspci не найден. Устанавливаю пакет pciutils..."
  apt update
  apt install -y pciutils
fi

if ! lspci | grep -qi nvidia; then
  log_warn "Видеокарта NVIDIA не обнаружена. Нечего устанавливать."
  exit 0
fi

log_info "Видеокарта NVIDIA обнаружена"

log_info "Проверка Secure Boot..."
if command -v mokutil &> /dev/null; then
  if mokutil --sb-state | grep -qi "enabled"; then
    log_warn "Secure Boot включен. Драйверы NVIDIA могут не загрузиться."
    log_warn "Рекомендуется отключить Secure Boot в BIOS/UEFI."
  else
    log_info "Secure Boot выключен"
  fi
else
  log_warn "mokutil не установлен, не могу проверить Secure Boot."
  log_warn "Установите mokutil или проверьте статус Secure Boot вручную."
fi

log_info "Установка рекомендованного драйвера NVIDIA..."

if ! command -v ubuntu-drivers &> /dev/null; then
  log_info "Устанавливаю ubuntu-drivers-common..."
  apt update
  apt install -y ubuntu-drivers-common
fi

ubuntu-drivers devices || true

if ubuntu-drivers install; then
  log_info "Драйверы NVIDIA установлены"
  log_warn "Рекомендуется перезагрузить систему"
else
  log_error "Ошибка при установке драйверов NVIDIA"
  exit 1
fi
