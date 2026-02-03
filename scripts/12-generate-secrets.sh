#!/bin/bash

# Скрипт генерации секретов для .env и Supabase config.toml

set -euo pipefail

# Цвета для вывода
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m' # No Color

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
COMPOSE_DIR="$PROJECT_ROOT/docker-compose"
ENV_EXAMPLE="$COMPOSE_DIR/env.example"
ENV_FILE="$COMPOSE_DIR/.env"
SUPABASE_CONFIG="$COMPOSE_DIR/supabase/config.toml"

generate_password() {
  if command -v openssl &> /dev/null; then
    openssl rand -base64 24 | tr -d "=+/" | cut -c1-32
  else
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
  fi
}

is_placeholder() {
  local value="$1"
  if [ -z "$value" ]; then
    return 0
  fi
  if echo "$value" | grep -qiE "your-secure|change-me|example|password-here"; then
    return 0
  fi
  return 1
}

get_env_value() {
  local key="$1"
  grep "^${key}=" "$ENV_FILE" 2>/dev/null | head -n1 | cut -d'=' -f2- | sed "s/^[\"']//;s/[\"']$//"
}

set_env_value() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s/^${key}=.*/${key}=${value}/" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

if [ ! -f "$ENV_EXAMPLE" ]; then
  log_error "Файл env.example не найден: $ENV_EXAMPLE"
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  log_info "Создаём .env из env.example"
  cp "$ENV_EXAMPLE" "$ENV_FILE"
fi

read -rp "Пересоздать все секреты (rotation)? (y/N): " ROTATE
ROTATE="${ROTATE:-N}"

SECRETS=(
  "REDIS_PASSWORD"
  "SUPABASE_DB_PASSWORD"
  "N8N_BASIC_AUTH_PASSWORD"
  "N8N_ENCRYPTION_KEY"
  "N8N_USER_MANAGEMENT_JWT_SECRET"
  "GRAFANA_PASSWORD"
)

for key in "${SECRETS[@]}"; do
  current="$(get_env_value "$key")"
  if [[ "$ROTATE" =~ ^[Yy]$ ]]; then
    new_val="$(generate_password)"
    set_env_value "$key" "$new_val"
    log_info "Обновлён $key"
    continue
  fi
  if is_placeholder "$current"; then
    new_val="$(generate_password)"
    set_env_value "$key" "$new_val"
    log_info "Сгенерирован $key"
  else
    log_info "Сохранён существующий $key"
  fi
done

# Обновляем Supabase config.toml (пароль БД)
if [ -f "$SUPABASE_CONFIG" ]; then
  SUPABASE_DB_PASSWORD="$(get_env_value SUPABASE_DB_PASSWORD)"
  if [ -z "$SUPABASE_DB_PASSWORD" ]; then
    log_warn "SUPABASE_DB_PASSWORD пустой — config.toml не обновлён"
  else
    if grep -q "^password = " "$SUPABASE_CONFIG"; then
      sed -i "s/^password = .*/password = \"${SUPABASE_DB_PASSWORD}\"/" "$SUPABASE_CONFIG"
      log_info "Обновлён пароль в config.toml"
    else
      log_warn "Не найдена строка password в config.toml"
    fi
  fi
else
  log_warn "config.toml не найден: $SUPABASE_CONFIG"
fi

log_info "Генерация секретов завершена"
log_info "Файл: $ENV_FILE"
