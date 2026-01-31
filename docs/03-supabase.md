# Установка Supabase (Self-hosted)

Supabase предоставляет PostgreSQL базу данных с дополнительными функциями: аутентификация, хранилище, real-time подписки.

## Предварительные требования

- Docker и Docker Compose установлены ([Этап 2](02-docker-installation.md))
- Минимум 2 GB RAM для Supabase
- Порты: 54321 (API), 54322 (DB), 54323 (Studio)

## Шаг 1: Установка Supabase CLI

```bash
# Установка через npm (требуется Node.js)
npm install -g supabase

# Или через Docker (рекомендуется)
docker pull supabase/cli:latest
```

## Шаг 2: Инициализация проекта

```bash
# Создаём директорию для проекта
mkdir -p ~/supabase
cd ~/supabase

# Инициализируем проект
supabase init
```

## Шаг 3: Настройка конфигурации

Редактируем `supabase/config.toml`:

```toml
[project]
# Имя проекта
name = "my-project"

[auth]
# Настройки аутентификации
site_url = "http://localhost:3000"
additional_redirect_urls = ["https://yourdomain.com"]

[api]
# Порт API Gateway
port = 54321
schemas = ["public", "storage", "graphql_public"]
extra_search_path = ["public", "extensions"]

[db]
# Порт PostgreSQL
port = 54322
# Пароль для postgres пользователя (ИЗМЕНИТЕ!)
password = "your-super-secret-password"
```

Или используйте готовый файл конфигурации: `docker-compose/supabase/config.toml`

## Шаг 4: Запуск Supabase

```bash
# Запуск через Docker Compose
supabase start

# Или используя наш скрипт
sudo bash scripts/03-setup-supabase.sh
```

## Шаг 5: Получение API ключей

После запуска Supabase выведет информацию о подключении:

```bash
supabase status
```

Сохраните:
- **API URL**: `http://localhost:54321`
- **anon key**: публичный ключ для клиентских приложений
- **service_role key**: секретный ключ для серверных операций
- **DB URL**: строка подключения к PostgreSQL

## Шаг 6: Настройка pgvector расширения

pgvector уже включён в Supabase. Проверяем:

```bash
# Подключаемся к базе данных
psql postgresql://postgres:your-password@localhost:54322/postgres

# В psql выполняем:
CREATE EXTENSION IF NOT EXISTS vector;
\dx  # Проверяем установленные расширения
\q
```

Или используйте скрипт настройки векторной БД: [см. установку pgvector](06-vector-db.md)

## Шаг 7: Создание начальной схемы БД

Пример SQL для создания таблицы с векторами (уже включён в `docker-compose/supabase/init.sql`):

```sql
-- Создаём таблицу для хранения документов с эмбеддингами
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT NOT NULL,
  embedding vector(1536),  -- Размерность для OpenAI embeddings
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Создаём индекс для векторного поиска (HNSW)
CREATE INDEX ON documents 
USING hnsw (embedding vector_cosine_ops);

-- Функция для поиска похожих документов
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding vector(1536),
  match_threshold float DEFAULT 0.7,
  match_count int DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  similarity float,
  metadata JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    documents.id,
    documents.content,
    1 - (documents.embedding <=> query_embedding) as similarity,
    documents.metadata
  FROM documents
  WHERE 1 - (documents.embedding <=> query_embedding) > match_threshold
  ORDER BY documents.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
```

## Проверка работы

```bash
# Проверка статуса
supabase status

# Проверка подключения к БД
docker exec supabase_db psql -U postgres -c "SELECT version();"

# Доступ к Studio (если включён)
# http://localhost:54323
```

## Устранение неполадок

### Проблема: Не удаётся запустить Supabase

```bash
# Проверьте логи
docker logs supabase_db

# Проверьте порты
sudo netstat -tlnp | grep 5432
```

### Проблема: Ошибки подключения к БД

```bash
# Проверьте пароль в config.toml
# Проверьте, что контейнер запущен
docker ps | grep supabase
```

## Следующие шаги

После установки Supabase:
1. Настройте векторную БД: [06-vector-db.md](06-vector-db.md)
2. Установите Redis: [05-redis.md](05-redis.md)
3. Установите n8n: [04-n8n.md](04-n8n.md)

## Источники

- [Официальная документация Supabase Self-hosting](https://supabase.com/docs/guides/self-hosting)
- [Документация pgvector](https://github.com/pgvector/pgvector)

