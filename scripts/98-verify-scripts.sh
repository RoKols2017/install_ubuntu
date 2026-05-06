#!/bin/bash

# Безопасная локальная проверка first-party shell scripts.

set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info "Проверка синтаксиса Bash для scripts/*.sh"
bash -n "$SCRIPT_DIR"/*.sh

if command -v shellcheck &> /dev/null; then
  log_info "Запуск ShellCheck для scripts/*.sh"
  shellcheck "$SCRIPT_DIR"/*.sh
else
  log_warn "ShellCheck не установлен; пропускаю статический анализ"
  log_warn "Установите: sudo apt install -y shellcheck"
fi

log_info "Проверки shell scripts завершены"
