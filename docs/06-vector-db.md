# Настройка векторной БД (pgvector)

pgvector уже установлен в Supabase. Настраиваем таблицы и функции для векторного поиска.

## Предварительные требования

- Supabase установлен и запущен - [см. установку Supabase](03-supabase.md)
- Файл `.env` с параметрами подключения (создаётся автоматически скриптом установки Supabase)

## Шаг 1: Автоматическая настройка (рекомендуется)

Скрипт автоматически читает параметры подключения из файла `docker-compose/.env`:

```bash
sudo bash scripts/06-setup-vector-db.sh
```

Скрипт автоматически:
- Читает параметры подключения из `.env` файла (переменная `SUPABASE_DB_PASSWORD`)
- Подключается к базе данных
- Проверяет и устанавливает расширение pgvector (если нужно)
- Создаёт таблицы, индексы и функции для векторного поиска

**Примечание:** Если файл `.env` не найден, скрипт запросит параметры подключения вручную.

## Шаг 2: Ручная настройка (опционально)

Если нужно выполнить настройку вручную:

```bash
# Подключение к базе данных
psql postgresql://postgres:your-password@localhost:54322/postgres
```

Пароль можно найти в файле `docker-compose/.env` (переменная `SUPABASE_DB_PASSWORD`).

## Шаг 3: Ручное выполнение SQL (опционально)

Если нужно выполнить SQL вручную без скрипта:

```sql
-- Создаём таблицу для хранения документов с эмбеддингами
CREATE TABLE IF NOT EXISTS documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT NOT NULL,
  embedding vector(1536),  -- Размерность для OpenAI embeddings
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Создаём таблицу для хранения сессий чата (опционально)
CREATE TABLE IF NOT EXISTS chat_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT,
  messages JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Шаг 4: Настройка индексов

```sql
-- HNSW индекс (быстрый, но занимает больше места)
CREATE INDEX IF NOT EXISTS documents_embedding_idx ON documents 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 24, ef_construction = 128);

-- IVFFlat индекс (медленнее, но меньше места)
-- CREATE INDEX documents_embedding_idx ON documents 
-- USING ivfflat (embedding vector_cosine_ops)
-- WITH (lists = 100);

-- Индекс для поиска сессий по пользователю
CREATE INDEX IF NOT EXISTS chat_sessions_user_id_idx ON chat_sessions(user_id);
```

Примечания по тюнингу HNSW:
- `m` и `ef_construction` увеличивают точность, но требуют больше памяти.
- Для изменения параметров индекса нужно пересоздать индекс.

Пример пересоздания индекса:
```sql
DROP INDEX IF EXISTS documents_embedding_idx;
CREATE INDEX documents_embedding_idx ON documents
USING hnsw (embedding vector_cosine_ops)
WITH (m = 24, ef_construction = 128);
```

Пример настройки точности поиска:
```sql
SET hnsw.ef_search = 100;
```

## Шаг 5: Создание функций для поиска

```sql
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
  metadata JSONB,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    documents.id,
    documents.content,
    1 - (documents.embedding <=> query_embedding) as similarity,
    documents.metadata,
    documents.created_at
  FROM documents
  WHERE documents.embedding IS NOT NULL
    AND 1 - (documents.embedding <=> query_embedding) > match_threshold
  ORDER BY documents.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- Функция для обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Триггеры для автоматического обновления updated_at
DROP TRIGGER IF EXISTS update_documents_updated_at ON documents;
CREATE TRIGGER update_documents_updated_at
    BEFORE UPDATE ON documents
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_chat_sessions_updated_at ON chat_sessions;
CREATE TRIGGER update_chat_sessions_updated_at
    BEFORE UPDATE ON chat_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

## Шаг 6: Интеграция с n8n

В n8n используйте узел "Postgres" для выполнения SQL запросов:

```sql
SELECT * FROM match_documents(
  $1::vector(1536),  -- query_embedding
  0.7,               -- match_threshold
  10                  -- match_count
);
```

## Поддержка и обслуживание

Рекомендуется периодически выполнять:
```sql
VACUUM (ANALYZE) documents;
VACUUM (ANALYZE) chat_sessions;
```

Проверка работы autovacuum:
```sql
SELECT relname, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

Пример использования в n8n Function узле:

```javascript
const queryEmbedding = $input.item.json.embedding;

const similarDocs = await $executeQuery(`
  SELECT * FROM match_documents(
    $1::vector(1536),
    0.7,
    5
  )
`, [queryEmbedding]);

return similarDocs;
```

## Шаг 7: Тестирование векторного поиска

```sql
-- Создаём тестовый документ
INSERT INTO documents (content, embedding, metadata)
VALUES (
  'Это тестовый документ',
  '[0.1, 0.2, 0.3, ...]'::vector(1536),  -- Замените на реальный embedding
  '{"source": "test"}'::jsonb
);

-- Тестируем поиск
SELECT * FROM match_documents(
  '[0.1, 0.2, 0.3, ...]'::vector(1536),
  0.5,
  5
);
```

## Оптимизация для больших объемов данных

### Настройка параметров индекса HNSW

```sql
-- Для больших датасетов увеличьте параметры
CREATE INDEX documents_embedding_idx ON documents 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 32, ef_construction = 128);
```

### Партиционирование таблиц

Для очень больших объёмов данных рассмотрите партиционирование:

```sql
-- Пример партиционирования по дате
CREATE TABLE documents_2024 PARTITION OF documents
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
```

## Мониторинг производительности

```sql
-- Проверка размера индекса
SELECT pg_size_pretty(pg_relation_size('documents_embedding_idx'));

-- Проверка количества документов
SELECT COUNT(*) FROM documents;

-- Анализ использования индекса
EXPLAIN ANALYZE SELECT * FROM match_documents(
  '[0.1, 0.2, ...]'::vector(1536),
  0.7,
  10
);
```

## Устранение неполадок

### Проблема: Ошибка при создании расширения

```bash
# Убедитесь, что Supabase запущен
docker ps | grep supabase

# Проверьте логи
docker logs supabase_db
```

### Проблема: Медленный поиск

```sql
-- Проверьте, используется ли индекс
EXPLAIN ANALYZE SELECT * FROM match_documents(...);

-- Пересоздайте индекс с другими параметрами
DROP INDEX documents_embedding_idx;
CREATE INDEX documents_embedding_idx ON documents 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 32, ef_construction = 128);
```

## Следующие шаги

После настройки векторной БД:
1. Установите n8n: [04-n8n.md](04-n8n.md)
2. Настройте интеграцию с ChatGPT API в n8n

## Источники

- [Официальная документация pgvector](https://github.com/pgvector/pgvector)
- [Supabase Vector Search документация](https://supabase.com/docs/guides/ai/vector-columns)

