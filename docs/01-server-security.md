[Back to README](../README.md) · [Security Hardening Details →](01-server-security-hardening.md)

# Безопасная настройка Ubuntu сервера

Базовый hardening перед развёртыванием Docker-инфраструктуры: обновления, firewall, SSH, fail2ban и автоматические security updates.

## Важные предупреждения

- Выполняйте hardening на чистом сервере или после резервной копии.
- Сначала проверьте SSH-доступ по ключу, затем меняйте SSH-настройки.
- Если работаете по SSH, держите вторую активную сессию до проверки нового доступа.
- Генерируйте ключи на клиентской машине; на сервер и в GitHub добавляйте только `.pub`.

## Pre-hardening checklist

- SSH-ключ создан или выбран на клиентской машине.
- Публичный ключ добавлен в `~/.ssh/authorized_keys` нужного пользователя на сервере.
- Вход по ключу проверен во второй SSH-сессии.
- Root/password hardening включается только после подтверждения ключевого доступа.
- Подробный guide по GitHub, VPS/root, deploy и backup ключам: [SSH Keys](ssh-keys.md).

## Быстрый путь

```bash
sudo bash scripts/02-secure-server.sh
```

Скрипт автоматизирует основные шаги: обновление системы, UFW, SSH hardening, fail2ban и unattended upgrades.

## Что настраивается

| Блок | Назначение | Проверка |
|------|------------|----------|
| System updates | обновление пакетов и cleanup | `sudo apt update` |
| UFW | разрешить SSH/HTTP/HTTPS и закрыть остальное | `sudo ufw status verbose` |
| SSH | запрет root-login, пустых паролей, ограничение попыток | `sudo sshd -t` |
| fail2ban | защита SSH от brute force | `sudo fail2ban-client status sshd` |
| unattended upgrades | автоматические security updates | `systemctl status unattended-upgrades` |

## Ручной порядок

### 1. Обновите систему

```bash
sudo apt update
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo apt autoremove -y
```

### 2. Включите UFW

```bash
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw --force enable
sudo ufw status verbose
```

### 3. Проверьте SSH hardening

Минимальные настройки:

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/^PermitEmptyPasswords yes/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sudo sshd -t
sudo systemctl restart sshd
```

Отключайте password auth только после подтверждения доступа по SSH-ключу.

### 4. Установите fail2ban

```bash
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo fail2ban-client status
```

### 5. Включите security updates

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
sudo systemctl enable unattended-upgrades
sudo systemctl start unattended-upgrades
```

## Проверка после hardening

```bash
sudo ufw status verbose
sudo sshd -T | grep -E "permitrootlogin|passwordauthentication|maxauthtries|port"
sudo fail2ban-client status sshd
systemctl status unattended-upgrades --no-pager
```

## Advanced details

Расширенные настройки SSH-порта, `sysctl`, logwatch и дополнительные рекомендации вынесены в [Security Hardening Details](01-server-security-hardening.md). Подробные SSH-key сценарии описаны в [SSH Keys](ssh-keys.md).

## Источники

- [Ubuntu Security Documentation](https://ubuntu.com/security)
- [DigitalOcean Security Best Practices](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-22-04)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)

## See Also

- [Security Hardening Details](01-server-security-hardening.md) — расширенные настройки безопасности.
- [SSH Keys](ssh-keys.md) — генерация и настройка ключей для GitHub, VPS/root, deploy и backup доступа.
- [Docker Installation](02-docker-installation.md) — следующий этап после hardening.
- [Quality Checks](12-quality-checks.md) — проверка готовности после установки.
