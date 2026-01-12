#!/bin/bash

# Скрипт безопасной настройки Ubuntu сервера
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

log_info "Начинаем настройку безопасности Ubuntu сервера..."

# Шаг 1: Обновление системы
log_info "Шаг 1: Обновление системы..."
apt update
apt upgrade -y
apt dist-upgrade -y
apt autoremove -y
log_info "Система обновлена"

# Шаг 2: Настройка Firewall
log_info "Шаг 2: Настройка UFW..."
# Проверяем, установлен ли UFW
if ! command -v ufw &> /dev/null; then
    apt install -y ufw
fi

# Включаем UFW
ufw --force enable

# Разрешаем SSH (ВАЖНО!)
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

log_info "Firewall настроен. Статус:"
ufw status verbose

# Шаг 3: Настройка SSH
log_info "Шаг 3: Настройка SSH..."

# Резервная копия конфига SSH
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

# Отключаем вход под root
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Отключаем пустые пароли
sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^PermitEmptyPasswords yes/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Ограничиваем количество попыток входа
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config

# Проверяем конфигурацию SSH
if sshd -t; then
    log_info "Конфигурация SSH проверена успешно"
    systemctl restart sshd
    log_info "SSH сервис перезапущен"
else
    log_error "Ошибка в конфигурации SSH! Восстанавливаем резервную копию..."
    cp /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S) /etc/ssh/sshd_config
    exit 1
fi

# Шаг 4: Установка fail2ban
log_info "Шаг 4: Установка и настройка fail2ban..."
apt install -y fail2ban

# Создаём локальную конфигурацию, если её нет
if [ ! -f /etc/fail2ban/jail.local ]; then
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
fi

# Настраиваем базовые параметры
cat >> /etc/fail2ban/jail.local <<EOF

[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

systemctl enable fail2ban
systemctl restart fail2ban
log_info "fail2ban установлен и запущен"

# Шаг 5: Настройка автоматических обновлений
log_info "Шаг 5: Настройка автоматических обновлений безопасности..."
apt install -y unattended-upgrades

# Настраиваем автоматические обновления
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
EOF

systemctl enable unattended-upgrades
systemctl start unattended-upgrades
log_info "Автоматические обновления настроены"

# Шаг 6: Настройка sysctl
log_info "Шаг 6: Настройка базовых ограничений безопасности (sysctl)..."

# Резервная копия
cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S)

# Добавляем настройки безопасности
cat >> /etc/sysctl.conf <<EOF

# Настройки безопасности
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
EOF

sysctl -p
log_info "Настройки sysctl применены"

# Шаг 7: Установка logwatch
log_info "Шаг 7: Установка logwatch..."
apt install -y logwatch

# Настраиваем ежедневные отчёты
cat > /etc/cron.daily/00logwatch <<'EOF'
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto root --detail high
EOF

chmod +x /etc/cron.daily/00logwatch
log_info "logwatch установлен и настроен"

# Финальная проверка
log_info "Проверка настроек безопасности..."

echo ""
log_info "=== Статус Firewall ==="
ufw status verbose

echo ""
log_info "=== Статус fail2ban ==="
fail2ban-client status

echo ""
log_info "=== Статус автоматических обновлений ==="
systemctl status unattended-upgrades --no-pager | head -5

echo ""
log_info "=== Конфигурация SSH ==="
sshd -T | grep -E "PermitRootLogin|PasswordAuthentication|Port|MaxAuthTries" || true

echo ""
log_warn "ВАЖНО:"
log_warn "1. Убедитесь, что у вас настроен доступ по SSH ключам"
log_warn "2. Проверьте, что вы можете подключиться к серверу"
log_warn "3. Рекомендуется изменить порт SSH (см. документацию)"
log_warn "4. Измените все дефолтные пароли"

log_info "Настройка безопасности завершена!"
