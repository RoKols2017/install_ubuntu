#!/bin/bash

# Скрипт установки и базовой настройки Nginx
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

log_info "Начинаем установку и настройку Nginx..."

# Шаг 1: Обновление системы
log_info "Шаг 1: Обновление системы..."
apt update

# Шаг 2: Установка Nginx
log_info "Шаг 2: Установка Nginx..."
if command -v nginx &> /dev/null; then
    log_info "Nginx уже установлен. Версия:"
    nginx -v
    read -p "Продолжить настройку? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Установка отменена"
        exit 0
    fi
else
    apt install -y nginx
    log_info "Nginx установлен"
fi

# Шаг 3: Запуск и включение автозапуска
log_info "Шаг 3: Запуск Nginx..."
systemctl enable nginx
systemctl start nginx

# Проверка статуса
if systemctl is-active --quiet nginx; then
    log_info "Nginx успешно запущен"
else
    log_error "Не удалось запустить Nginx"
    exit 1
fi

# Шаг 4: Настройка firewall
log_info "Шаг 4: Настройка firewall..."
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "Status: active"; then
        log_info "Разрешаем HTTP и HTTPS в UFW..."
        ufw allow 'Nginx Full' 2>/dev/null || {
            ufw allow 80/tcp comment 'HTTP'
            ufw allow 443/tcp comment 'HTTPS'
        }
        log_info "Правила firewall добавлены"
    else
        log_warn "UFW не активен. Добавьте правила вручную:"
        log_warn "  sudo ufw allow 80/tcp"
        log_warn "  sudo ufw allow 443/tcp"
    fi
else
    log_warn "UFW не установлен. Настройте firewall вручную"
fi

# Шаг 5: Базовая оптимизация
log_info "Шаг 5: Базовая оптимизация конфигурации..."

# Резервная копия основного конфига
if [ ! -f /etc/nginx/nginx.conf.backup ]; then
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
fi

# Добавляем базовые оптимизации в nginx.conf
if ! grep -q "gzip on" /etc/nginx/nginx.conf; then
    # Находим http блок и добавляем настройки
    sed -i '/^http {/a\
    # Базовые оптимизации\
    gzip on;\
    gzip_vary on;\
    gzip_min_length 1024;\
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss;\
    \
    # Скрыть версию Nginx\
    server_tokens off;\
    \
    # Таймауты\
    keepalive_timeout 65;\
    client_max_body_size 50M;
' /etc/nginx/nginx.conf
    log_info "Базовые оптимизации добавлены"
fi

# Шаг 6: Создание директории для конфигураций
log_info "Шаг 6: Подготовка структуры конфигураций..."
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

# Шаг 7: Информация о следующих шагах
log_info "=== Установка Nginx завершена ==="
echo ""
log_info "Статус Nginx:"
systemctl status nginx --no-pager | head -5

echo ""
log_info "Проверка конфигурации:"
if nginx -t; then
    log_info "Конфигурация Nginx корректна"
else
    log_error "Ошибка в конфигурации Nginx!"
    exit 1
fi

echo ""
log_warn "Следующие шаги:"
log_warn "1. Создайте конфигурацию для ваших сервисов:"
log_warn "   sudo nano /etc/nginx/sites-available/n8n"
log_warn ""
log_warn "2. Используйте шаблон из templates/nginx.conf.example"
log_warn ""
log_warn "3. Активируйте конфигурацию:"
log_warn "   sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/"
log_warn "   sudo nginx -t"
log_warn "   sudo systemctl reload nginx"
log_warn ""
log_warn "4. Установите SSL сертификат (Let's Encrypt):"
log_warn "   sudo apt install -y certbot python3-certbot-nginx"
log_warn "   sudo certbot --nginx -d your-domain.com"
log_warn ""
log_info "Nginx доступен по адресу: http://$(hostname -I | awk '{print $1}')"

