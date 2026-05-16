#!/bin/bash

# Интерактивный скрипт настройки SSH-ключей.
# Выполняется на клиентской машине (не требует root прав).

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_question() {
  echo -e "${CYAN}[?]${NC} $1"
}

log_step() {
  echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-}"
  local answer

  while true; do
    if [ -n "$default" ]; then
      log_question "$prompt (y/n) [default: $default]: "
    else
      log_question "$prompt (y/n): "
    fi
    read -r answer

    if [ -z "$answer" ] && [ -n "$default" ]; then
      answer="$default"
    fi

    case "$answer" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo]) return 1 ;;
      *) log_warn "Пожалуйста, введите 'y' или 'n'" ;;
    esac
  done
}

ask_input() {
  local prompt="$1"
  local default="${2:-}"
  local answer

  if [ -n "$default" ]; then
    log_question "$prompt [default: $default]: "
  else
    log_question "$prompt: "
  fi

  read -r answer

  if [ -z "$answer" ] && [ -n "$default" ]; then
    answer="$default"
  fi

  printf '%s\n' "$answer"
}

ask_choice() {
  local prompt="$1"
  local max_choice="$2"
  local default="${3:-}"
  local answer

  while true; do
    if [ -n "$default" ]; then
      log_question "$prompt [default: $default]: "
    else
      log_question "$prompt: "
    fi
    read -r answer

    if [ -z "$answer" ] && [ -n "$default" ]; then
      answer="$default"
    fi

    if [[ "$answer" =~ ^[0-9]+$ ]] && [ "$answer" -ge 1 ] && [ "$answer" -le "$max_choice" ]; then
      printf '%s\n' "$answer"
      return 0
    fi

    log_warn "Введите число от 1 до ${max_choice}"
  done
}

ensure_ssh_dir() {
  if [ ! -d "$HOME/.ssh" ]; then
    log_info "Создаю директорию ~/.ssh"
    mkdir -p "$HOME/.ssh"
  fi
  chmod 700 "$HOME/.ssh"
}

sanitize_component() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  value="$(printf '%s' "$value" | sed -E 's/[[:space:]]+/-/g; s/[^a-z0-9_.-]//g; s/\.\.//g; s/_+/_/g; s/-+/-/g; s/^[._-]+//; s/[._-]+$//')"

  if [ -z "$value" ]; then
    value="unknown"
  fi

  printf '%s\n' "$value"
}

generate_key_name() {
  local purpose="$1"
  local account_or_server="$2"
  local device="$3"

  purpose="$(sanitize_component "$purpose")"
  account_or_server="$(sanitize_component "$account_or_server")"
  device="$(sanitize_component "$device")"

  printf '%s_%s_%s\n' "$purpose" "$account_or_server" "$device"
}

build_key_comment() {
  local email="$1"
  local purpose="$2"
  local account_or_server="$3"
  local device="$4"
  local date_value

  if [ -z "$email" ]; then
    email="no-email"
  fi

  date_value="$(date +%F)"
  printf '%s | %s | %s | %s | %s\n' "$email" "$purpose" "$account_or_server" "$device" "$date_value"
}

fix_key_permissions() {
  local key_path="$1"

  ensure_ssh_dir

  if [ -f "$key_path" ]; then
    chmod 600 "$key_path"
  fi
  if [ -f "${key_path}.pub" ]; then
    chmod 644 "${key_path}.pub"
  fi
  if [ -f "$HOME/.ssh/config" ]; then
    chmod 600 "$HOME/.ssh/config"
  fi
}

warn_private_key_safety() {
  log_warn "Приватный ключ нельзя копировать в GitHub, чаты, тикеты или репозитории."
  log_warn "В GitHub, authorized_keys и документацию добавляется только файл .pub."
}

choose_empty_passphrase() {
  local purpose="$1"

  case "$purpose" in
    github|vps-root|backup|rescue)
      log_info "Для сценария '${purpose}' рекомендуется passphrase."
      if ask_yes_no "Ввести passphrase через стандартный prompt ssh-keygen?" "y"; then
        return 1
      fi
      ;;
    deploy)
      log_warn "Пустая passphrase для deploy-ключа удобна для автоматизации, но повышает риск при утечке ключа."
      ;;
  esac

  if ask_yes_no "Создать ключ с пустой passphrase?" "n"; then
    log_warn "Вы явно выбрали пустую passphrase. Ограничьте права ключа и регулярно ротируйте доступ."
    return 0
  fi

  return 1
}

generate_ssh_key() {
  local key_path="$1"
  local comment="$2"
  local purpose="$3"

  ensure_ssh_dir

  warn_private_key_safety


  if [ -f "$key_path" ]; then
    log_warn "Ключ уже существует: ${key_path}"
    if ask_yes_no "Использовать существующий ключ?" "y"; then
      fix_key_permissions "$key_path"
      return 0
    fi
    if ask_yes_no "Перезаписать существующий ключ?" "n"; then
      rm -f "$key_path" "${key_path}.pub"
    else
      log_info "Отменено пользователем"
      return 1
    fi
  fi

  log_info "Генерирую SSH-ключ: ${key_path}"
  log_info "Комментарий ключа: ${comment}"

  if choose_empty_passphrase "$purpose"; then
    ssh-keygen -t ed25519 -f "$key_path" -C "$comment" -N ""
  else
    ssh-keygen -t ed25519 -f "$key_path" -C "$comment"
  fi

  fix_key_permissions "$key_path"
  log_info "SSH-ключ готов: ${key_path}"
}

get_public_key() {
  local key_path="$1"

  if [ ! -f "${key_path}.pub" ]; then
    log_error "Публичный ключ не найден: ${key_path}.pub"
    return 1
  fi

  printf '%s\n' "$(< "${key_path}.pub")"
}

show_public_key() {
  local key_path="$1"

  warn_private_key_safety
  log_info "Публичный ключ (${key_path}.pub):"
  get_public_key "$key_path"
  echo ""
}

copy_key_to_server() {
  local key_path="$1"
  local server_user="$2"
  local server_host="$3"
  local server_port="${4:-22}"
  local public_key

  public_key="$(get_public_key "$key_path")"
  log_info "Копирую публичный ключ на сервер ${server_user}@${server_host}:${server_port}"

  if command -v ssh-copy-id &> /dev/null; then
    if ssh-copy-id -i "${key_path}.pub" -p "$server_port" "${server_user}@${server_host}"; then
      log_info "Ключ успешно скопирован через ssh-copy-id"
      return 0
    fi
    log_warn "ssh-copy-id не смог скопировать ключ, покажу ручной fallback"
  else
    log_warn "ssh-copy-id не найден, покажу ручной fallback"
  fi

  log_info "Команды для ручного выполнения на сервере:"
  echo "  mkdir -p ~/.ssh"
  echo "  chmod 700 ~/.ssh"
  printf "  printf '%%s\\\\n' '%s' >> ~/.ssh/authorized_keys\n" "$public_key"
  echo "  chmod 600 ~/.ssh/authorized_keys"

  if ask_yes_no "Попробовать безопасный fallback через SSH?" "y"; then
    printf '%s\n' "$public_key" | ssh -p "$server_port" "${server_user}@${server_host}" 'read -r key || exit 1; mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && { grep -qxF "$key" ~/.ssh/authorized_keys || printf "%s\n" "$key" >> ~/.ssh/authorized_keys; }'
    log_info "Fallback-команда выполнена"
    return 0
  fi

  return 1
}

host_exists_in_config() {
  local ssh_config="$1"
  local host_alias="$2"

  [ -f "$ssh_config" ] && grep -Eq "^[[:space:]]*Host[[:space:]]+${host_alias}([[:space:]]|$)" "$ssh_config"
}

remove_host_from_config() {
  local ssh_config="$1"
  local host_alias="$2"
  local tmp_file

  tmp_file="$(mktemp)"
  awk -v host="$host_alias" '
    /^[[:space:]]*Host[[:space:]]+/ {
      skip = 0
      for (i = 2; i <= NF; i++) {
        if ($i == host) {
          skip = 1
          break
        }
      }
    }
    skip != 1 { print }
  ' "$ssh_config" > "$tmp_file"
  mv "$tmp_file" "$ssh_config"
  chmod 600 "$ssh_config"
}

add_ssh_config_entry() {
  local host_alias="$1"
  local host_name="$2"
  local user_name="$3"
  local port="$4"
  local identity_file="$5"
  local ssh_config="$HOME/.ssh/config"
  local backup_file

  ensure_ssh_dir
  touch "$ssh_config"
  chmod 600 "$ssh_config"

  if host_exists_in_config "$ssh_config" "$host_alias"; then
    log_warn "Host ${host_alias} уже существует в ~/.ssh/config"
    if ask_yes_no "Обновить существующую запись?" "y"; then
      backup_file="${ssh_config}.bak.$(date +%Y%m%d%H%M%S)"
      cp "$ssh_config" "$backup_file"
      chmod 600 "$backup_file"
      log_info "Создан backup: ${backup_file}"
      remove_host_from_config "$ssh_config" "$host_alias"
    else
      log_info "Запись в ~/.ssh/config не изменялась"
      return 0
    fi
  fi

  {
    echo ""
    echo "Host ${host_alias}"
    echo "    HostName ${host_name}"
    echo "    User ${user_name}"
    if [ -n "$port" ]; then
      echo "    Port ${port}"
    fi
    echo "    IdentityFile ${identity_file}"
    echo "    IdentitiesOnly yes"
  } >> "$ssh_config"

  chmod 600 "$ssh_config"
  log_info "Запись добавлена в ~/.ssh/config: Host ${host_alias}"
}

collect_key_metadata() {
  local purpose="$1"
  local default_account="$2"
  local default_device="$3"
  local account_or_server
  local device
  local email
  local key_name
  local key_path
  local comment

  account_or_server="$(ask_input "Account/server для имени ключа" "$default_account")"
  device="$(ask_input "Имя устройства для имени ключа" "$default_device")"
  email="$(ask_input "Email для комментария ключа (можно оставить пустым)" "")"

  key_name="$(generate_key_name "$purpose" "$account_or_server" "$device")"
  key_path="$HOME/.ssh/${key_name}"
  comment="$(build_key_comment "$email" "$purpose" "$account_or_server" "$device")"

  KEY_PATH="$key_path"
  KEY_COMMENT="$comment"

  log_info "Имя ключа: ${key_name}"
  log_info "Путь: ${key_path}"
}

use_existing_key() {
  local default_path="$1"
  local existing_key_path

  existing_key_path="$(ask_input "Введите путь к существующему приватному ключу" "$default_path")"
  if [ ! -f "$existing_key_path" ]; then
    log_error "Ключ не найден: ${existing_key_path}"
    return 1
  fi

  KEY_PATH="$existing_key_path"
  fix_key_permissions "$KEY_PATH"
  log_info "Используется существующий ключ: ${KEY_PATH}"
}

run_github_flow() {
  local account
  local host_alias

  log_step "GitHub SSH key"
  account="$(ask_input "GitHub account или organization" "github")"
  collect_key_metadata "github" "$account" "$(hostname)"

  if ! ask_yes_no "Использовать существующий ключ?" "n"; then
    generate_ssh_key "$KEY_PATH" "$KEY_COMMENT" "github"
  else
    use_existing_key "$KEY_PATH"
  fi

  show_public_key "$KEY_PATH"
  log_info "Добавьте этот .pub ключ в GitHub: Settings -> SSH and GPG keys -> New SSH key"

  if ask_yes_no "Сделать этот ключ основным для github.com?" "n"; then
    host_alias="github.com"
  else
    host_alias="github-$(sanitize_component "$account")"
  fi

  if ask_yes_no "Добавить запись в ~/.ssh/config для ${host_alias}?" "y"; then
    add_ssh_config_entry "$host_alias" "github.com" "git" "" "$KEY_PATH"
    log_info "Проверка GitHub: ssh -T git@${host_alias}"
  fi

  if ask_yes_no "Проверить подключение к GitHub сейчас?" "n"; then
    ssh -T "git@${host_alias}" || log_warn "GitHub мог вернуть предупреждение или отказ. Проверьте, добавлен ли .pub ключ в аккаунт."
  fi
}

run_server_flow() {
  local purpose="$1"
  local server_host
  local server_user
  local server_name
  local server_port
  local default_user="root"
  local host_alias

  log_step "SSH key для ${purpose}"

  if [ "$purpose" = "deploy" ]; then
    default_user="deploy"
  fi

  if [ "$purpose" = "backup" ] || [ "$purpose" = "rescue" ]; then
    log_warn "Резервные ключи храните отдельно и отзывайте при компрометации."
  fi

  server_host="$(ask_input "Адрес сервера (IP или доменное имя)" "")"
  if [ -z "$server_host" ]; then
    log_error "Адрес сервера обязателен"
    exit 1
  fi

  server_user="$(ask_input "Пользователь на сервере" "$default_user")"
  server_name="$(ask_input "Имя сервера для имени ключа" "$server_host")"
  server_port="$(ask_input "SSH порт сервера" "22")"

  collect_key_metadata "$purpose" "${server_name}_${server_user}" "$(hostname)"

  if ! ask_yes_no "Использовать существующий ключ?" "n"; then
    generate_ssh_key "$KEY_PATH" "$KEY_COMMENT" "$purpose"
  else
    use_existing_key "$KEY_PATH"
  fi

  show_public_key "$KEY_PATH"

  if ask_yes_no "Скопировать публичный ключ на сервер ${server_user}@${server_host}?" "y"; then
    copy_key_to_server "$KEY_PATH" "$server_user" "$server_host" "$server_port" || log_warn "Ключ не был скопирован автоматически"
  fi

  if ask_yes_no "Протестировать SSH подключение к серверу?" "y"; then
    if ssh -i "$KEY_PATH" -p "$server_port" -o ConnectTimeout=5 -o BatchMode=yes "${server_user}@${server_host}" "echo 'Подключение успешно!'" 2>/dev/null; then
      log_info "Подключение работает"
    else
      log_warn "Автоматическая проверка не прошла. Проверьте вручную:"
      echo "  ssh -i ${KEY_PATH} -p ${server_port} ${server_user}@${server_host}"
    fi
  fi

  host_alias="$(sanitize_component "${server_name}-${server_user}")"
  if ask_yes_no "Добавить запись Host ${host_alias} в ~/.ssh/config?" "y"; then
    add_ssh_config_entry "$host_alias" "$server_host" "$server_user" "$server_port" "$KEY_PATH"
    log_info "Подключение через alias: ssh ${host_alias}"
  fi
}

main() {
  local choice

  log_step "Настройка SSH-ключей"
  log_info "Скрипт выполняется на клиентской машине: $(whoami)@$(hostname)"
  warn_private_key_safety

  echo "Выберите сценарий:"
  echo "  1) GitHub key"
  echo "  2) VPS/root key"
  echo "  3) Deploy user key"
  echo "  4) Backup/rescue key"
  echo "  5) Existing key"
  choice="$(ask_choice "Сценарий" "5" "2")"

  case "$choice" in
    1) run_github_flow ;;
    2) run_server_flow "vps-root" ;;
    3) run_server_flow "deploy" ;;
    4) run_server_flow "backup" ;;
    5) use_existing_key "$HOME/.ssh/id_ed25519"; show_public_key "$KEY_PATH" ;;
  esac

  log_step "Готово"
  log_info "SSH-сценарий завершён"
}

main "$@"
