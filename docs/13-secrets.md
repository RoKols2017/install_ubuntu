# Управление секретами

Это руководство описывает базовые практики хранения секретов для production.

## 1. Защищённый `.env` (базовый вариант)
```bash
cd docker-compose
cp env.example .env
nano .env
```

Ограничьте доступ:
```bash
chmod 600 .env
```

Рекомендации:
- Не коммитьте `.env` в git.
- Храните резервную копию секретов в менеджере паролей.

## 2. Генерация секретов
```bash
openssl rand -base64 24 | tr -d "=+/" | cut -c1-32
```

Или используйте скрипт:
```bash
sudo bash scripts/12-generate-secrets.sh
```

## 3. Ротация секретов
1. Сгенерируйте новые значения.
2. Обновите `.env`.
3. Перезапустите сервисы:
   ```bash
   docker compose up -d
   ```

## 4. Docker secrets (опционально)
Docker secrets удобны в Swarm и при использовании сервисов,
которые поддерживают переменные вида `*_FILE`.

В этом проекте основной путь — защищённый `.env`.

## Источники
- https://docs.docker.com/engine/swarm/secrets/
- https://docs.docker.com/compose/environment-variables/
