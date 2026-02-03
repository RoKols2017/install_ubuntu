# Безопасная настройка Ubuntu сервера

Это руководство описывает шаги по обеспечению базовой безопасности Ubuntu сервера перед развёртыванием инфраструктуры.

## ⚠️ Важные предупреждения

- Выполняйте эти шаги на **чистом сервере** или после создания резервной копии
- Некоторые изменения могут заблокировать доступ к серверу при неправильной настройке
- Рекомендуется выполнять настройку через консоль сервера (не через SSH), чтобы не потерять доступ

## Шаг 1: Обновление системы

Первым делом обновляем систему до последних версий пакетов:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo apt autoremove -y
```

## Шаг 2: Настройка Firewall (UFW)

UFW (Uncomplicated Firewall) - это простой интерфейс для iptables.

### Базовая настройка

```bash
# Включаем UFW
sudo ufw enable

# Разрешаем SSH (ВАЖНО: сделать до блокировки всех портов!)
sudo ufw allow 22/tcp

# Разрешаем HTTP и HTTPS (если планируется веб-сервер)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Проверяем статус
sudo ufw status verbose
```

### Дополнительные правила (опционально)

```bash
# Разрешить конкретный IP для SSH
sudo ufw allow from YOUR_IP_ADDRESS to any port 22

# Ограничить количество подключений
sudo ufw limit 22/tcp
```

## Шаг 3: Настройка SSH

### 3.1 Отключение входа под root

```bash
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
```

### 3.2 Изменение порта SSH (рекомендуется)

**ВНИМАНИЕ:** После изменения порта убедитесь, что firewall разрешает новый порт!

```bash
# Резервная копия конфига
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Изменяем порт (например, на 2222)
sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sudo sed -i 's/^Port 22/Port 2222/' /etc/ssh/sshd_config

# Разрешаем новый порт в firewall
sudo ufw allow 2222/tcp
```

### 3.3 Настройка аутентификации по ключам

```bash
# Отключаем парольную аутентификацию (только после настройки ключей!)
# sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
# sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Отключаем пустые пароли
sudo sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Ограничиваем количество попыток входа
sudo sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
```

### 3.4 Применение изменений SSH

```bash
# Проверяем конфигурацию на ошибки
sudo sshd -t

# Перезапускаем SSH сервис
sudo systemctl restart sshd
```

## Шаг 4: Установка и настройка fail2ban

fail2ban защищает от брутфорс атак.

```bash
# Установка
sudo apt install -y fail2ban

# Создаём локальную конфигурацию
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Редактируем настройки
sudo nano /etc/fail2ban/jail.local
```

Рекомендуемые настройки в `jail.local`:

```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22,2222
logpath = %(sshd_log)s
backend = %(sshd_backend)s
```

```bash
# Запускаем fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Проверяем статус
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

## Шаг 5: Настройка автоматических обновлений безопасности

```bash
# Установка
sudo apt install -y unattended-upgrades

# Настройка
sudo dpkg-reconfigure -plow unattended-upgrades

# Или редактируем конфиг вручную
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Рекомендуемые настройки:

```conf
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
```

```bash
# Включаем автоматические обновления
sudo systemctl enable unattended-upgrades
sudo systemctl start unattended-upgrades
```

## Шаг 6: Создание пользователя с sudo правами

```bash
# Создаём нового пользователя
sudo adduser newuser

# Добавляем в группу sudo
sudo usermod -aG sudo newuser

# Проверяем
groups newuser
```

## Шаг 7: Настройка базовых ограничений безопасности (sysctl)

```bash
# Резервная копия
sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup

# Добавляем настройки безопасности
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF

# Защита от SYN flood атак
net.ipv4.tcp_syncookies = 1

# Отключение перенаправления пакетов
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Защита от IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Отключение ICMP redirect
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Отключение ICMP ping (опционально, для дополнительной защиты)
# net.ipv4.icmp_echo_ignore_all = 1

# Защита от source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Логирование подозрительных пакетов
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
EOF

# Применяем настройки
sudo sysctl -p
```

## Шаг 8: Установка и настройка logwatch

logwatch помогает отслеживать системные события.

```bash
# Установка
sudo apt install -y logwatch

# Настройка ежедневных отчётов
sudo nano /etc/cron.daily/00logwatch
```

Содержимое файла:

```bash
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto root --detail high
```

```bash
# Делаем исполняемым
sudo chmod +x /etc/cron.daily/00logwatch
```

## Шаг 9: Настройка SSH-ключей для доступа

### На клиентской машине (ваш компьютер)

```bash
# Генерируем ключ (если ещё нет)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Копируем публичный ключ на сервер
ssh-copy-id -p 22 user@server_ip
# или если изменили порт:
ssh-copy-id -p 2222 user@server_ip
```

### На сервере

```bash
# Создаём директорию для ключей (если нет)
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Добавляем публичный ключ в authorized_keys
echo "YOUR_PUBLIC_KEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## Проверка безопасности

После выполнения всех шагов проверьте:

```bash
# Статус firewall
sudo ufw status verbose

# Статус fail2ban
sudo fail2ban-client status

# Статус автоматических обновлений
sudo systemctl status unattended-upgrades

# Проверка SSH конфигурации
sudo sshd -T | grep -E "PermitRootLogin|PasswordAuthentication|Port"
```

## Дополнительные рекомендации

1. **Регулярные обновления:** Настройте напоминания о проверке обновлений
2. **Мониторинг:** Установите систему мониторинга (Prometheus, Grafana)
3. **Аудит:** Регулярно проверяйте логи (`/var/log/auth.log`, `/var/log/syslog`)
4. **Резервное копирование:** Настройте автоматические бэкапы
5. **SSL/TLS:** Используйте Let's Encrypt для HTTPS

## Автоматизация

Для автоматизации всех этих шагов используйте скрипт:

```bash
sudo bash scripts/02-secure-server.sh
```

## Источники

- [Ubuntu Security Documentation](https://ubuntu.com/security)
- [DigitalOcean Security Best Practices](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-22-04)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)

