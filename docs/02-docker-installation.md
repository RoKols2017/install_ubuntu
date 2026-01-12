# Установка Docker и Docker Compose

Это руководство описывает установку Docker Engine и Docker Compose на Ubuntu сервере.

## Предварительные требования

- Ubuntu 22.04 LTS или Ubuntu 24.04 LTS
- Права root или sudo
- Стабильное интернет-соединение

## Метод установки

Мы будем устанавливать Docker из официального репозитория Docker, что гарантирует получение последних версий и обновлений.

## Шаг 1: Удаление старых версий Docker (если есть)

Если на системе уже установлен Docker, рекомендуется удалить старые версии:

```bash
sudo apt remove -y docker docker-engine docker.io containerd runc
sudo apt purge -y docker docker-engine docker.io containerd runc
```

## Шаг 2: Установка зависимостей

```bash
sudo apt update
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
```

## Шаг 3: Добавление официального GPG ключа Docker

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

## Шаг 4: Добавление репозитория Docker

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

## Шаг 5: Установка Docker Engine и Docker Compose

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## Шаг 6: Настройка Docker для работы без sudo

По умолчанию Docker требует права root. Чтобы запускать Docker команды без sudo, добавьте пользователя в группу docker:

```bash
# Добавляем текущего пользователя в группу docker
sudo usermod -aG docker $USER

# Применяем изменения (требуется перелогиниться)
newgrp docker
```

**Важно:** После добавления пользователя в группу docker необходимо перелогиниться или перезапустить сессию, чтобы изменения вступили в силу.

## Шаг 7: Настройка автозапуска Docker

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

## Шаг 8: Проверка установки

### Проверка версии Docker

```bash
docker --version
docker compose version
```

### Тестовый запуск контейнера

```bash
docker run hello-world
```

Если контейнер успешно запустился и вывел приветственное сообщение, установка прошла успешно.

### Проверка статуса сервиса

```bash
sudo systemctl status docker
```

## Шаг 9: Настройка Docker daemon

### Конфигурация daemon.json

Создайте или отредактируйте файл `/etc/docker/daemon.json`:

```bash
sudo nano /etc/docker/daemon.json
```

Пример конфигурации:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ]
}
```

### Применение изменений

```bash
sudo systemctl restart docker
```

### Проверка конфигурации

```bash
docker info
```

## Дополнительные настройки

### Ограничение логов Docker

Docker может накапливать много логов. Настройте ротацию логов через systemd:

```bash
sudo nano /etc/systemd/system/docker.service.d/override.conf
```

Содержимое:

```ini
[Service]
LoggingMaxSize=10M
LoggingMaxFiles=3
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### Настройка DNS для контейнеров

Если у вас проблемы с DNS в контейнерах, добавьте в `daemon.json`:

```json
{
  "dns": ["8.8.8.8", "8.8.4.4"]
}
```

## Устранение неполадок

### Проблема: "Cannot connect to the Docker daemon"

**Решение:**
```bash
# Проверьте, запущен ли Docker
sudo systemctl status docker

# Если не запущен, запустите
sudo systemctl start docker

# Проверьте, что пользователь в группе docker
groups $USER

# Если нет, добавьте и перелогиньтесь
sudo usermod -aG docker $USER
newgrp docker
```

### Проблема: "Permission denied" при запуске Docker

**Решение:**
```bash
# Убедитесь, что пользователь в группе docker
sudo usermod -aG docker $USER

# Перелогиньтесь или выполните
newgrp docker
```

### Проблема: Ошибки при установке из репозитория

**Решение:**
```bash
# Очистите кэш apt
sudo apt clean
sudo apt update

# Проверьте правильность ключа
sudo apt-key list | grep Docker

# Переустановите ключ
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

## Обновление Docker

Для обновления Docker до последней версии:

```bash
sudo apt update
sudo apt upgrade docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl restart docker
```

## Удаление Docker

Если нужно полностью удалить Docker:

```bash
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/docker
```

## Автоматизация установки

Для автоматической установки используйте скрипт:

```bash
sudo bash scripts/02-install-docker.sh
```

## Полезные команды Docker

```bash
# Просмотр запущенных контейнеров
docker ps

# Просмотр всех контейнеров
docker ps -a

# Просмотр образов
docker images

# Очистка неиспользуемых ресурсов
docker system prune -a

# Просмотр использования ресурсов
docker stats

# Просмотр логов контейнера
docker logs <container_id>
```

## Источники

- [Официальная документация Docker для Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [Документация Docker Compose](https://docs.docker.com/compose/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
