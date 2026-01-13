#!/bin/bash

# Скрипт установки Docker и Docker Compose на Ubuntu
# Требует прав root или sudo

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

log_info "Начинаем установку Docker и Docker Compose..."

# Шаг 0: Очистка старых источников Docker (ВАЖНО: до apt update!)
log_info "Шаг 0: Очистка старых источников Docker..."
# Удаляем все файлы источников Docker в sources.list.d
rm -f /etc/apt/sources.list.d/docker*.list
rm -f /etc/apt/sources.list.d/docker*.list.save
# Находим и очищаем все файлы, содержащие упоминания Docker
find /etc/apt/sources.list.d/ -type f -name "*.list" -exec grep -l "download\.docker\.com" {} \; 2>/dev/null | xargs rm -f 2>/dev/null || true
# Удаляем записи Docker из основного файла sources.list (если есть)
sed -i '/download\.docker\.com/d' /etc/apt/sources.list 2>/dev/null || true
# Удаляем старые ключевые файлы
rm -f /etc/apt/keyrings/docker.gpg
rm -f /etc/apt/keyrings/docker.asc
rm -f /usr/share/keyrings/docker-archive-keyring.gpg
rm -f /usr/share/keyrings/docker.gpg
# Удаляем все возможные ключевые файлы Docker
find /etc/apt/keyrings /usr/share/keyrings -name "*docker*" -type f 2>/dev/null | xargs rm -f 2>/dev/null || true
# Удаляем старые ключи из apt-key (устаревший метод)
apt-key list 2>/dev/null | grep -B1 "Docker" | grep "^pub" | awk '{print $2}' | cut -d'/' -f2 | xargs -I {} apt-key del {} 2>/dev/null || true
# Очищаем кэш apt
apt clean 2>/dev/null || true
rm -rf /var/lib/apt/lists/*download.docker.com* 2>/dev/null || true
log_info "Старые источники Docker очищены"

# Шаг 1: Удаление старых версий Docker (если есть)
log_info "Шаг 1: Проверка и удаление старых версий Docker..."
if command -v docker &> /dev/null; then
    log_warn "Обнаружен установленный Docker. Удаляем старые версии..."
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    apt purge -y docker docker-engine docker.io containerd runc 2>/dev/null || true
fi

# Шаг 2: Установка зависимостей
log_info "Шаг 2: Установка зависимостей..."
apt update
apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Шаг 3: Добавление официального GPG ключа Docker
log_info "Шаг 3: Добавление официального GPG ключа Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
log_info "GPG ключ Docker добавлен"

# Шаг 4: Добавление репозитория Docker
log_info "Шаг 4: Добавление репозитория Docker..."
ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)

echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  ${CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
log_info "Репозиторий Docker добавлен"

# Шаг 5: Установка Docker Engine и Docker Compose
log_info "Шаг 5: Установка Docker Engine и Docker Compose..."
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

log_info "Docker установлен успешно"

# Шаг 6: Настройка Docker для работы без sudo
log_info "Шаг 6: Настройка Docker для работы без sudo..."
CURRENT_USER=${SUDO_USER:-$USER}
if [ "$CURRENT_USER" != "root" ]; then
    if ! groups "$CURRENT_USER" | grep -q docker; then
        usermod -aG docker "$CURRENT_USER"
        log_info "Пользователь $CURRENT_USER добавлен в группу docker"
        log_warn "Необходимо перелогиниться или выполнить 'newgrp docker' для применения изменений"
    else
        log_info "Пользователь $CURRENT_USER уже в группе docker"
    fi
else
    log_warn "Запущено от root. Добавьте пользователя в группу docker вручную:"
    log_warn "  sudo usermod -aG docker <username>"
fi

# Шаг 7: Настройка автозапуска Docker
log_info "Шаг 7: Настройка автозапуска Docker..."
systemctl enable docker
systemctl start docker
log_info "Docker настроен на автозапуск"

# Шаг 8: Проверка установки
log_info "Шаг 8: Проверка установки..."

# Проверка версии Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    log_info "Docker установлен: $DOCKER_VERSION"
else
    log_error "Docker не найден после установки!"
    exit 1
fi

# Проверка версии Docker Compose
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    log_info "Docker Compose установлен: $COMPOSE_VERSION"
else
    log_error "Docker Compose не найден после установки!"
    exit 1
fi

# Тестовый запуск контейнера
log_info "Запуск тестового контейнера hello-world..."
if docker run --rm hello-world &> /dev/null; then
    log_info "Тестовый контейнер успешно запущен"
else
    log_warn "Не удалось запустить тестовый контейнер (возможно, требуется перелогиниться)"
fi

# Шаг 9: Настройка Docker daemon
log_info "Шаг 9: Настройка Docker daemon..."

# Создаём директорию для конфигурации, если её нет
mkdir -p /etc/docker

# Настраиваем daemon.json, если файла нет
if [ ! -f /etc/docker/daemon.json ]; then
    cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
    log_info "Конфигурация Docker daemon создана"
    systemctl restart docker
    log_info "Docker перезапущен с новой конфигурацией"
else
    log_info "Конфигурация Docker daemon уже существует"
fi

# Финальная проверка
log_info "=== Финальная проверка ==="
echo ""
log_info "Версия Docker:"
docker --version

echo ""
log_info "Версия Docker Compose:"
docker compose version

echo ""
log_info "Статус Docker сервиса:"
systemctl status docker --no-pager | head -5

echo ""
log_info "Информация о Docker:"
docker info | head -10

echo ""
log_warn "ВАЖНО:"
if [ "$CURRENT_USER" != "root" ]; then
    log_warn "Если вы запускали скрипт через sudo, перелогиньтесь или выполните:"
    log_warn "  newgrp docker"
    log_warn "чтобы использовать Docker без sudo"
fi

log_info "Установка Docker завершена успешно!"

