# Быстрый старт

Краткое руководство по развёртыванию инфраструктуры.

## Предварительные требования

- Ubuntu 22.04 LTS или 24.04 LTS
- Минимум 4 GB RAM (рекомендуется 8 GB+)
- 50 GB свободного места
- Права root или sudo
- Для локальных серверов с новым железом: см. [драйверы и совместимость](docs/08-hardware-drivers.md)

## Шаг 1: Клонирование/копирование проекта

```bash
# Если проект в git
git clone <repository-url>
cd install_ubuntu

# Или скопируйте файлы на сервер
```

## Шаг 1.1: Preflight проверка

```bash
sudo bash scripts/00-preflight-check.sh
```

## Шаг 1.2: Настройка SSH ключей (клиентская машина)

```bash
bash scripts/01-setup-ssh-keys.sh
```

## Шаг 2: Безопасная настройка сервера

```bash
# Выполните скрипт настройки безопасности
sudo bash scripts/02-secure-server.sh

# ВАЖНО: Убедитесь, что у вас настроен доступ по SSH ключам
# перед выполнением этого скрипта!
```

## Шаг 3: Установка Docker

```bash
# Установите Docker и Docker Compose
sudo bash scripts/03-install-docker.sh

# Перелогиньтесь или выполните для применения изменений группы docker
newgrp docker
```

## Шаг 4: Настройка переменных окружения

```bash
# Перейдите в директорию docker-compose
cd docker-compose

# Скопируйте пример файла переменных окружения
cp env.example .env

# Отредактируйте .env и измените все пароли!
nano .env
```

**Обязательно измените:**
- `REDIS_PASSWORD` - пароль для Redis
- `SUPABASE_DB_PASSWORD` - пароль для PostgreSQL
- `N8N_BASIC_AUTH_PASSWORD` - пароль для n8n
- `N8N_ENCRYPTION_KEY` - ключ шифрования n8n
- `N8N_USER_MANAGEMENT_JWT_SECRET` - JWT секрет n8n
- `GRAFANA_PASSWORD` - пароль Grafana

## Шаг 5: Запуск инфраструктуры

### Вариант A: Использование единого docker-compose.yml

```bash
cd docker-compose

# Запуск всех сервисов
docker compose --env-file .env up -d

# Проверка статуса
docker compose ps

# Просмотр логов
docker compose logs -f
```

Примечание:
- Порты PostgreSQL/Redis/Studio доступны только на `127.0.0.1`.
- Для внешнего доступа используйте SSH‑туннель или reverse proxy.

### Вариант B: Поэтапная установка

```bash
# 1. Установка Supabase
sudo bash scripts/04-setup-supabase.sh

# 2. Установка Redis
sudo bash scripts/06-setup-redis.sh

# 3. Настройка векторной БД
sudo bash scripts/07-setup-vector-db.sh

# 4. Установка n8n
sudo bash scripts/05-setup-n8n.sh
```

## Шаг 6: Проверка работы

### Проверка сервисов

```bash
# Статус всех контейнеров
docker ps

# Проверка Redis
docker exec redis redis-cli -a YOUR_REDIS_PASSWORD ping

# Проверка PostgreSQL
docker exec supabase_db psql -U postgres -c "SELECT version();"

# Проверка n8n
curl http://localhost:5678/healthz
```

### Ready‑проверка
```bash
sudo bash scripts/99-ready-checks.sh
```

### Доступ к веб-интерфейсам

- **n8n:** http://localhost:5678
  - Логин: из файла `.env` (N8N_BASIC_AUTH_USER)
  - Пароль: из файла `.env` (N8N_BASIC_AUTH_PASSWORD)

- **Supabase Studio:** http://localhost:54323 (если включён)

Примечание:
- По умолчанию n8n и Studio доступны только на `127.0.0.1`.
- Для внешнего доступа используйте:
  ```bash
  cd docker-compose
  docker compose -f docker-compose.yml -f docker-compose.override.public.yml up -d
  ```

## Шаг 7: Настройка векторной БД

```bash
# Выполните скрипт настройки pgvector
sudo bash scripts/07-setup-vector-db.sh

# Скрипт запросит параметры подключения к БД
# Используйте данные из Supabase:
# - Хост: localhost
# - Порт: 54322
# - Пользователь: postgres
# - Пароль: из .env (SUPABASE_DB_PASSWORD)
```

## Шаг 8: Настройка n8n

1. Откройте http://localhost:5678 в браузере
2. Войдите с учётными данными из `.env`
3. Настройте credentials:
   - OpenAI API (для ChatGPT и embeddings)
   - PostgreSQL (для векторного поиска)
   - Redis (для очередей)

## Следующие шаги

1. **Настройка резервного копирования:**
   ```bash
   # Бэкап PostgreSQL
   sudo bash scripts/10-backup-postgres.sh
   ```
   См. [10-backup-restore.md](docs/10-backup-restore.md)
   Для расписания: `sudo bash scripts/11-setup-backup-cron.sh`

2. **Настройка мониторинга:**
   - Запустите Prometheus + Grafana через compose
   - См. [09-monitoring.md](docs/09-monitoring.md)

3. **Настройка Nginx reverse proxy:**
   ```bash
   # Установите Nginx
   sudo bash scripts/08-setup-nginx.sh
   
   # Создайте конфигурацию (используйте шаблон из templates/nginx.conf.example)
   sudo nano /etc/nginx/sites-available/n8n
   
   # Активируйте конфигурацию
   sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   
   # Установите SSL сертификат
   sudo apt install -y certbot python3-certbot-nginx
   sudo certbot --nginx -d your-domain.com
   ```
   
   См. [07-nginx.md](docs/07-nginx.md) для подробностей

4. **Создание workflow в n8n:**
   - Создайте базовый RAG workflow
   - Настройте мультиагентную архитектуру

## Устранение неполадок

### Проблема: Контейнеры не запускаются

```bash
# Проверьте логи
docker compose logs

# Проверьте использование ресурсов
docker stats

# Проверьте сеть
docker network ls
docker network inspect infrastructure-network
```

### Проблема: Не могу подключиться к n8n

```bash
# Проверьте, запущен ли контейнер
docker ps | grep n8n

# Проверьте логи
docker logs n8n

# Проверьте порт
sudo netstat -tlnp | grep 5678
```

### Проблема: Ошибки подключения к БД

```bash
# Проверьте, запущен ли PostgreSQL
docker ps | grep supabase

# Проверьте логи
docker logs supabase_db

# Проверьте подключение
docker exec supabase_db psql -U postgres -c "SELECT 1;"
```

Подробнее см. [11-troubleshooting.md](docs/11-troubleshooting.md)

## Полезные команды

```bash
# Остановка всех сервисов
docker compose down

# Остановка с удалением volumes (ОСТОРОЖНО: удалит данные!)
docker compose down -v

# Перезапуск сервиса
docker compose restart n8n

# Просмотр логов конкретного сервиса
docker compose logs -f n8n

# Обновление образов
docker compose pull
docker compose up -d
```

## Дополнительная документация

- [Полная документация](README.md)
- [Безопасность сервера](docs/01-server-security.md)
- [Установка Docker](docs/02-docker-installation.md)
- [Настройка инфраструктуры](docs/03-infrastructure-setup.md)
- [Архитектура решения](docs/architecture.md)

## Поддержка

При возникновении проблем:
1. Проверьте логи сервисов
2. Изучите соответствующую документацию
3. Проверьте системные требования

