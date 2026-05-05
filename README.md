# Руководства по установке инфраструктуры Ubuntu

Универсальные руководства и скрипты для безопасной настройки Ubuntu сервера, установки Docker и развертывания инфраструктуры для мультиагентных ассистентов на базе n8n с Supabase, Redis и pgvector.

## Какую задачу решает

Когда нужно быстро подготовить VPS или bare-metal сервер под AI-сервисы, команда обычно тратит время на разрозненные чеклисты: безопасность, Docker, база данных, очередь задач, векторный поиск и reverse proxy настраиваются отдельно и часто вручную.

Этот проект нужен, чтобы:

- последовательно поднять Ubuntu-сервер с базовой безопасностью;
- установить Docker и контейнерный runtime;
- развернуть self-hosted стек для AI automation и multi-agent workflow;
- получить единый набор документов, скриптов и compose-конфигураций вместо ручной сборки по частям.

## Что получает команда на выходе

- сервер с UFW, SSH hardening, fail2ban и автообновлениями безопасности;
- Docker-based инфраструктуру с Supabase, Redis, pgvector и n8n;
- понятный порядок установки по этапам и отдельным компонентам;
- основу для RAG, очередей задач, automation workflow и self-hosted AI сервисов.

## Proof: infrastructure flow

```text
Ubuntu server
  -> security hardening
  -> Docker install
  -> Supabase + pgvector
  -> Redis
  -> n8n main + worker
  -> optional Nginx reverse proxy
```

## Proof: what is actually included

- В репозитории есть отдельные этапы для security, Docker, Supabase, n8n, Redis, pgvector и Nginx.
- Для быстрой установки предусмотрены shell scripts `02-secure-server.sh` ... `08-setup-nginx.sh`.
- Архитектура явно описывает runtime-компоненты: `Redis`, `PgBouncer`, `PostgreSQL/Supabase`, `n8n Main`, `n8n Worker` и `Nginx`.
- Документация фиксирует как пошаговую установку компонентов, так и объединенную установку через Docker Compose.

## 📋 Содержание

### Этап 1: Безопасная настройка сервера
- [Документация](docs/01-server-security.md) - Полное руководство по безопасности Ubuntu
- [Скрипт настройки SSH ключей](scripts/01-setup-ssh-keys.sh) - Подготовка доступа (клиентская машина)
- [Скрипт установки](scripts/02-secure-server.sh) - Автоматизация настройки безопасности

**Что включает:**
- Обновление системы
- Настройка firewall (UFW)
- Настройка SSH
- Установка fail2ban
- Автоматические обновления безопасности
- Базовые ограничения безопасности

### Этап 2: Установка Docker
- [Документация](docs/02-docker-installation.md) - Руководство по установке Docker и Docker Compose
- [Скрипт установки](scripts/03-install-docker.sh) - Автоматическая установка Docker

**Что включает:**
- Установка Docker Engine
- Установка Docker Compose
- Настройка для работы без sudo
- Настройка автозапуска
- Конфигурация Docker daemon

### Этап 3: Инфраструктура для мультиагентных ассистентов
- [Обзор инфраструктуры](docs/03-infrastructure-setup.md) - Общее руководство и порядок установки
- [Архитектура решения](docs/architecture.md) - Диаграмма и описание архитектуры

#### 3.1 Supabase (Self-hosted)
- [Документация](docs/03-supabase.md) - Полное руководство по установке Supabase
- [Скрипт установки](scripts/04-setup-supabase.sh)
- [Конфигурация](docker-compose/supabase/config.toml)

#### 3.2 n8n с воркером
- [Документация](docs/04-n8n.md) - Полное руководство по установке n8n
- [Скрипт установки](scripts/05-setup-n8n.sh)
- [Конфигурация](docker-compose/n8n/env.example)

#### 3.3 Redis
- [Документация](docs/05-redis.md) - Полное руководство по установке Redis
- [Скрипт установки](scripts/06-setup-redis.sh)

#### 3.4 Векторная БД (pgvector)
- [Документация](docs/06-vector-db.md) - Полное руководство по настройке pgvector
- [Скрипт установки](scripts/07-setup-vector-db.sh)

### Этап 4: Nginx Reverse Proxy (опционально)
- [Документация](docs/07-nginx.md) - Установка и настройка Nginx с SSL
- [Скрипт установки](scripts/08-setup-nginx.sh) - Автоматическая установка Nginx

**Что включает:**
- Установка Nginx
- Настройка reverse proxy для сервисов
- Установка SSL сертификатов (Let's Encrypt)
- Оптимизация производительности
- Настройка безопасности

### Дополнительные материалы
- [Системные требования](requirements/system-requirements.md)
- [Драйверы и совместимость железа](docs/08-hardware-drivers.md)
- [Мониторинг](docs/09-monitoring.md)
- [Бэкапы и восстановление](docs/10-backup-restore.md)
- [Устранение неполадок](docs/11-troubleshooting.md)
- [Контроль качества](docs/12-quality-checks.md)
- [Управление секретами](docs/13-secrets.md)
- [Правила готовности](docs/14-ready-rules.md)
- [Последовательность скриптов](docs/15-scripts-order.md)
- [Docker Compose конфигурация](docker-compose/docker-compose.yml) - Объединённая конфигурация всех сервисов
- [Шаблоны конфигураций](templates/) - Nginx, firewall и другие

## 🚀 Быстрый старт

**Для быстрого начала работы см. [QUICKSTART.md](QUICKSTART.md)**

1. **Проверьте системные требования:**
   ```bash
   cat requirements/system-requirements.md
   ```

2. **Выполните настройку безопасности (Этап 1):**
   ```bash
   sudo bash scripts/02-secure-server.sh
   ```

3. **Установите Docker (Этап 2):**
   ```bash
   sudo bash scripts/03-install-docker.sh
   ```

4. **Разверните инфраструктуру (Этап 3):**
   ```bash
   # Supabase
   sudo bash scripts/04-setup-supabase.sh
   
   # Redis
   sudo bash scripts/06-setup-redis.sh
   
   # pgvector
   sudo bash scripts/07-setup-vector-db.sh

   # n8n
   sudo bash scripts/05-setup-n8n.sh
   ```

5. **Установите Nginx (опционально, для production):**
   ```bash
   sudo bash scripts/08-setup-nginx.sh
   ```

6. **Или используйте единый Docker Compose:**
   ```bash
   cd docker-compose
   docker compose up -d
   ```

## 📁 Структура проекта

```
install_ubuntu/
├── README.md                          # Этот файл
├── .cursorrules                       # Правила проекта для Cursor
├── docs/                              # Документация по этапам
│   ├── 01-server-security.md
│   ├── 02-docker-installation.md
│   ├── 03-infrastructure-setup.md
│   ├── 03-supabase.md
│   ├── 04-n8n.md
│   ├── 05-redis.md
│   ├── 06-vector-db.md
│   ├── 07-nginx.md
│   ├── 08-hardware-drivers.md
│   ├── 09-monitoring.md
│   ├── 10-backup-restore.md
│   ├── 11-troubleshooting.md
│   ├── 12-quality-checks.md
│   ├── 13-secrets.md
│   ├── 14-ready-rules.md
│   ├── 15-scripts-order.md
│   └── architecture.md
├── scripts/                           # Скрипты установки
│   ├── 00-preflight-check.sh
│   ├── 01-setup-ssh-keys.sh
│   ├── 02-secure-server.sh
│   ├── 03-install-docker.sh
│   ├── 04-setup-supabase.sh
│   ├── 05-setup-n8n.sh
│   ├── 06-setup-redis.sh
│   ├── 07-setup-vector-db.sh
│   ├── 08-setup-nginx.sh
│   ├── 09-install-nvidia-drivers.sh
│   ├── 10-backup-postgres.sh
│   ├── 11-setup-backup-cron.sh
│   ├── 12-generate-secrets.sh
│   └── 99-ready-checks.sh
├── docker-compose/                    # Docker Compose конфигурации
│   ├── docker-compose.yml
│   ├── supabase/
│   └── n8n/
├── templates/                         # Шаблоны конфигураций
│   ├── nginx.conf.example
│   └── firewall-rules.example
└── requirements/                      # Дополнительные требования
    └── system-requirements.md
```

## ⚠️ Важные замечания

- Все скрипты требуют прав root или sudo
- Перед выполнением скриптов рекомендуется прочитать соответствующую документацию
- Измените все дефолтные пароли и ключи
- Настройте резервное копирование перед использованием в production

## 🔗 Полезные ссылки

- [Официальная документация Ubuntu Security](https://ubuntu.com/security)
- [Документация Docker](https://docs.docker.com/)
- [Документация Supabase Self-hosting](https://supabase.com/docs/guides/self-hosting)
- [Документация n8n](https://docs.n8n.io/)
- [Документация pgvector](https://github.com/pgvector/pgvector)

## 📝 Лицензия

Этот проект предоставляется "как есть" для использования в образовательных и коммерческих целях.
