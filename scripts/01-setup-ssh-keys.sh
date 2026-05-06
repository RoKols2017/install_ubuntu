#!/bin/bash

# Интерактивный скрипт настройки SSH ключей для доступа к серверу
# Выполняется на клиентской машине (не требует root прав)

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_question() {
    echo -e "${CYAN}[?]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Функция для интерактивного ввода с проверкой
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
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                log_warn "Пожалуйста, введите 'y' или 'n'"
                ;;
        esac
    done
}

# Функция для ввода текста с проверкой
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
    
    echo "$answer"
}

# Функция для проверки существования SSH ключа
check_existing_key() {
    local key_path="$1"
    if [ -f "$key_path" ]; then
        return 0
    else
        return 1
    fi
}

# Функция для генерации имени ключа на основе сервера и клиента
generate_key_name() {
    local server_name="$1"
    local client_name="$2"
    # Убираем специальные символы и приводим к нижнему регистру
    server_name=$(echo "$server_name" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-_')
    client_name=$(echo "$client_name" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-_')
    echo "${server_name}_${client_name}"
}

# Функция для генерации SSH ключа
generate_ssh_key() {
    local key_name="$1"
    local key_path="$HOME/.ssh/${key_name}"
    local email="${2:-}"
    
    log_info "Генерирую SSH ключ: ${key_name}"
    
    # Проверяем, существует ли директория .ssh
    if [ ! -d "$HOME/.ssh" ]; then
        log_info "Создаю директорию ~/.ssh"
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
    fi
    
    # Проверяем, не существует ли уже ключ с таким именем
    if [ -f "${key_path}" ]; then
        log_warn "Ключ ${key_path} уже существует!"
        if ask_yes_no "Перезаписать существующий ключ?" "n"; then
            rm -f "${key_path}" "${key_path}.pub"
        else
            log_info "Используем существующий ключ"
            return 0
        fi
    fi
    
    # Формируем комментарий для ключа
    local comment=""
    if [ -n "$email" ]; then
        comment="-C ${email}"
    else
        comment="-C $(whoami)@$(hostname)"
    fi
    
    # Генерируем ключ
    if ssh-keygen -t ed25519 -f "${key_path}" -N "" $comment; then
        log_info "SSH ключ успешно сгенерирован: ${key_path}"
        
        # Устанавливаем правильные права доступа
        chmod 600 "${key_path}"
        chmod 644 "${key_path}.pub"
        
        return 0
    else
        log_error "Ошибка при генерации SSH ключа"
        return 1
    fi
}

# Функция для копирования ключа на сервер
copy_key_to_server() {
    local key_path="$1"
    local server_user="$2"
    local server_host="$3"
    local server_port="${4:-22}"
    
    log_info "Копирую публичный ключ на сервер ${server_user}@${server_host}:${server_port}"
    
    # Проверяем наличие ssh-copy-id
    if ! command -v ssh-copy-id &> /dev/null; then
        log_warn "ssh-copy-id не найден. Используем альтернативный метод..."
        
        # Альтернативный метод через ssh
        if [ -f "${key_path}.pub" ]; then
            log_info "Публичный ключ для копирования:"
            cat "${key_path}.pub"
            echo ""
            log_info "Выполните вручную на сервере:"
            echo "  mkdir -p ~/.ssh"
            echo "  chmod 700 ~/.ssh"
            echo "  echo '$(cat ${key_path}.pub)' >> ~/.ssh/authorized_keys"
            echo "  chmod 600 ~/.ssh/authorized_keys"
            
            if ask_yes_no "Попробовать скопировать ключ через SSH?" "y"; then
                ssh -p "$server_port" "${server_user}@${server_host}" \
                    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$(cat ${key_path}.pub)' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
                
                if [ $? -eq 0 ]; then
                    log_info "Ключ успешно скопирован на сервер"
                    return 0
                else
                    log_error "Не удалось скопировать ключ автоматически"
                    return 1
                fi
            fi
        fi
        return 1
    else
        # Используем ssh-copy-id
        if ssh-copy-id -i "${key_path}.pub" -p "$server_port" "${server_user}@${server_host}"; then
            log_info "Ключ успешно скопирован на сервер"
            return 0
        else
            log_error "Не удалось скопировать ключ на сервер"
            log_info "Попробуйте скопировать вручную. Публичный ключ:"
            cat "${key_path}.pub"
            return 1
        fi
    fi
}

# Основная функция
main() {
    log_step "Настройка SSH ключей для доступа к серверу"
    
    # Получаем информацию о клиенте
    CLIENT_NAME=$(hostname)
    CLIENT_USER=$(whoami)
    
    log_info "Информация о клиенте:"
    echo "  Пользователь: ${CLIENT_USER}"
    echo "  Хост: ${CLIENT_NAME}"
    echo ""
    
    # Запрашиваем информацию о сервере
    log_step "Информация о сервере"
    SERVER_HOST=$(ask_input "Введите адрес сервера (IP или доменное имя)" "")
    if [ -z "$SERVER_HOST" ]; then
        log_error "Адрес сервера обязателен"
        exit 1
    fi
    
    SERVER_USER=$(ask_input "Введите имя пользователя на сервере" "root")
    SERVER_NAME=$(ask_input "Введите имя сервера (для имени ключа)" "$SERVER_HOST")
    SERVER_PORT=$(ask_input "Введите SSH порт сервера" "22")
    
    # Генерируем имя ключа
    KEY_NAME=$(generate_key_name "$SERVER_NAME" "$CLIENT_NAME")
    KEY_PATH="$HOME/.ssh/${KEY_NAME}"
    
    log_info "Имя ключа будет: ${KEY_NAME}"
    echo ""
    
    # Проверяем наличие существующего ключа
    if check_existing_key "${KEY_PATH}"; then
        log_info "Найден существующий ключ: ${KEY_PATH}"
        if ask_yes_no "Использовать существующий ключ?" "y"; then
            log_info "Используем существующий ключ"
        else
            if ask_yes_no "Сгенерировать новый ключ?" "y"; then
                EMAIL=$(ask_input "Введите email для комментария в ключе (необязательно)" "")
                if ! generate_ssh_key "$KEY_NAME" "$EMAIL"; then
                    log_error "Не удалось сгенерировать ключ"
                    exit 1
                fi
            else
                log_info "Отменено пользователем"
                exit 0
            fi
        fi
    else
        # Спрашиваем, есть ли у пользователя ключ
        if ask_yes_no "Есть ли у вас SSH ключ для этого сервера?" "n"; then
            EXISTING_KEY_PATH=$(ask_input "Введите путь к существующему приватному ключу" "$HOME/.ssh/id_ed25519")
            
            if [ -f "$EXISTING_KEY_PATH" ]; then
                log_info "Используем существующий ключ: ${EXISTING_KEY_PATH}"
                KEY_PATH="$EXISTING_KEY_PATH"
            else
                log_error "Ключ не найден: ${EXISTING_KEY_PATH}"
                if ask_yes_no "Сгенерировать новый ключ?" "y"; then
                    EMAIL=$(ask_input "Введите email для комментария в ключе (необязательно)" "")
                    if ! generate_ssh_key "$KEY_NAME" "$EMAIL"; then
                        log_error "Не удалось сгенерировать ключ"
                        exit 1
                    fi
                else
                    exit 1
                fi
            fi
        else
            # Генерируем новый ключ
            log_step "Генерация нового SSH ключа"
            EMAIL=$(ask_input "Введите email для комментария в ключе (необязательно)" "")
            
            if ! generate_ssh_key "$KEY_NAME" "$EMAIL"; then
                log_error "Не удалось сгенерировать ключ"
                exit 1
            fi
        fi
    fi
    
    # Показываем информацию о ключе
    log_step "Информация о ключе"
    log_info "Приватный ключ: ${KEY_PATH}"
    if [ -f "${KEY_PATH}.pub" ]; then
        log_info "Публичный ключ: ${KEY_PATH}.pub"
        echo ""
        log_info "Содержимое публичного ключа:"
        cat "${KEY_PATH}.pub"
        echo ""
    fi
    
    # Предлагаем скопировать ключ на сервер
    log_step "Копирование ключа на сервер"
    if ask_yes_no "Скопировать публичный ключ на сервер ${SERVER_USER}@${SERVER_HOST}?" "y"; then
        if copy_key_to_server "$KEY_PATH" "$SERVER_USER" "$SERVER_HOST" "$SERVER_PORT"; then
            log_info "Ключ успешно настроен!"
            
            # Предлагаем протестировать подключение
            echo ""
            if ask_yes_no "Протестировать SSH подключение к серверу?" "y"; then
                log_info "Тестирую подключение..."
                if ssh -i "$KEY_PATH" -p "$SERVER_PORT" -o ConnectTimeout=5 -o BatchMode=yes "${SERVER_USER}@${SERVER_HOST}" "echo 'Подключение успешно!'" 2>/dev/null; then
                    log_info "Подключение работает!"
                else
                    log_warn "Не удалось подключиться автоматически. Проверьте вручную:"
                    echo "  ssh -i ${KEY_PATH} -p ${SERVER_PORT} ${SERVER_USER}@${SERVER_HOST}"
                fi
            fi
        else
            log_warn "Не удалось автоматически скопировать ключ"
            log_info "Вы можете скопировать его вручную или повторить попытку позже"
        fi
    else
        log_info "Копирование пропущено. Вы можете скопировать ключ позже командой:"
        echo "  ssh-copy-id -i ${KEY_PATH}.pub -p ${SERVER_PORT} ${SERVER_USER}@${SERVER_HOST}"
    fi
    
    # Показываем инструкции для использования
    log_step "Инструкции по использованию"
    log_info "Для подключения к серверу используйте:"
    echo "  ssh -i ${KEY_PATH} -p ${SERVER_PORT} ${SERVER_USER}@${SERVER_HOST}"
    echo ""
    
    # Предлагаем настроить SSH config
    if ask_yes_no "Добавить запись в ~/.ssh/config для удобного подключения?" "y"; then
        SSH_CONFIG="$HOME/.ssh/config"
        SSH_HOST_ALIAS="${SERVER_NAME}_${CLIENT_NAME}"
        
        # Создаём config если его нет
        if [ ! -f "$SSH_CONFIG" ]; then
            touch "$SSH_CONFIG"
            chmod 600 "$SSH_CONFIG"
        fi
        
        # Проверяем, нет ли уже такой записи
        if grep -q "Host ${SSH_HOST_ALIAS}" "$SSH_CONFIG" 2>/dev/null; then
            log_warn "Запись для ${SSH_HOST_ALIAS} уже существует в config"
            if ask_yes_no "Обновить существующую запись?" "y"; then
                # Удаляем старую запись
                sed -i "/Host ${SSH_HOST_ALIAS}/,/^$/d" "$SSH_CONFIG"
            else
                log_info "Пропускаем добавление в config"
                exit 0
            fi
        fi
        
        # Добавляем новую запись
        {
            echo ""
            echo "Host ${SSH_HOST_ALIAS}"
            echo "    HostName ${SERVER_HOST}"
            echo "    User ${SERVER_USER}"
            echo "    Port ${SERVER_PORT}"
            echo "    IdentityFile ${KEY_PATH}"
            echo "    IdentitiesOnly yes"
        } >> "$SSH_CONFIG"
        
        log_info "Запись добавлена в ~/.ssh/config"
        log_info "Теперь вы можете подключаться командой:"
        echo "  ssh ${SSH_HOST_ALIAS}"
    fi
    
    log_step "Готово!"
    log_info "SSH ключ настроен и готов к использованию"
}

# Запуск основной функции
main "$@"
