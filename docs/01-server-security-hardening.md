[← Server Security](01-server-security.md) · [Back to README](../README.md) · [Docker Installation →](02-docker-installation.md)

# Security Hardening Details

Дополнительные настройки безопасности Ubuntu сервера. Используйте после базового hardening из [Server Security](01-server-security.md).

## Изменение SSH-порта

После изменения порта сначала разрешите новый порт в firewall и только потом перезапускайте SSH.

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sudo sed -i 's/^Port 22/Port 2222/' /etc/ssh/sshd_config
sudo ufw allow 2222/tcp
sudo sshd -t
sudo systemctl restart sshd
```

## SSH-ключи

Основной guide по именованию, passphrase, GitHub, VPS/root, deploy и backup ключам: [SSH Keys](ssh-keys.md).

Минимальный сценарий на клиентской машине:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/vps-fi-01_root_ubuntu_pc -C "email@example.com | vps-root | vps-fi-01/root | ubuntu-pc | 2026-05-16"
ssh-copy-id -i ~/.ssh/vps-fi-01_root_ubuntu_pc.pub -p 22 root@server_ip
```

Если порт изменён:

```bash
ssh-copy-id -i ~/.ssh/vps-fi-01_root_ubuntu_pc.pub -p 2222 root@server_ip
```

На сервере при ручной настройке добавляйте только публичный ключ:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
printf '%s\n' 'YOUR_PUBLIC_KEY' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Не вставляйте приватный ключ в `authorized_keys`, GitHub, чаты, тикеты или репозитории.

## fail2ban jail.local

```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
```

Рекомендуемый минимум:

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

## sysctl hardening

```bash
sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup
sudo tee -a /etc/sysctl.conf > /dev/null <<'EOF'
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
sudo sysctl -p
```

Не включайте `net.ipv4.icmp_echo_ignore_all = 1` без необходимости: ping часто нужен для диагностики.

## Пользователь с sudo

```bash
sudo adduser newuser
sudo usermod -aG sudo newuser
groups newuser
```

## logwatch

```bash
sudo apt install -y logwatch
sudo nano /etc/cron.daily/00logwatch
```

Пример содержимого:

```bash
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto root --detail high
```

```bash
sudo chmod +x /etc/cron.daily/00logwatch
```

## Дополнительные рекомендации

- Регулярно проверяйте `/var/log/auth.log` и `/var/log/syslog`.
- Настройте мониторинг после запуска Docker-стека.
- Настройте резервное копирование до production-данных.
- Используйте HTTPS через Nginx/Let's Encrypt для публичных сервисов.

## See Also

- [Server Security](01-server-security.md) — базовый hardening flow.
- [SSH Keys](ssh-keys.md) — подробные сценарии SSH-ключей.
- [Nginx](07-nginx.md) — HTTPS и reverse proxy.
- [Monitoring](09-monitoring.md) — наблюдение за runtime-сервисами.
