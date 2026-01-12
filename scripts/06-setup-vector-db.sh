#!/bin/bash

# Скрипт настройки векторной БД (pgvector)
# Требует работающий Supabase или PostgreSQL с pgvector

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

log_info "Начинаем настройку векторной БД (pgvector)..."

# Запрашиваем параметры подключения
read -p "Хост PostgreSQL [localhost]: " DB_HOST
DB_HOST=${DB_HOST:-localhost}

read -p "Порт PostgreSQL [54322]: " DB_PORT
DB_PORT=${DB_PORT:-54322}

read -p "Имя базы данных [postgres]: " DB_NAME
DB_NAME=${DB_NAME:-postgres}

read -p "Пользователь [postgres]: " DB_USER
DB_USER=${DB_USER:-postgres}

read -sp "Пароль: " DB_PASSWORD
echo ""

# Проверяем подключение
log_info "Проверка подключения к базе данных..."
export PGPASSWORD="$DB_PASSWORD"

if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
    log_error "Не удалось подключиться к базе данных. Проверьте параметры подключения."
    exit 1
fi

log_info "Подключение успешно!"

# Проверяем наличие расширения pgvector
log_info "Проверка расширения pgvector..."
if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "\dx vector" | grep -q vector; then
    log_info "Расширение pgvector уже установлено"
else
    log_info "Установка расширения pgvector..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS vector;"
    log_info "Расширение pgvector установлено"
fi

# Создаём SQL скрипт для инициализации
SQL_SCRIPT=$(mktemp)
cat > "$SQL_SCRIPT" <<'SQL'
-- Создаём таблицу для хранения документов с эмбеддингами
CREATE TABLE IF NOT EXISTS documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT NOT NULL,
  embedding vector(1536),  -- Размерность для OpenAI embeddings
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Создаём индекс для векторного поиска (HNSW)
CREATE INDEX IF NOT EXISTS documents_embedding_idx ON documents 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

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

-- Триггер для автоматического обновления updated_at
DROP TRIGGER IF EXISTS update_documents_updated_at ON documents;
CREATE TRIGGER update_documents_updated_at
    BEFORE UPDATE ON documents
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Создаём таблицу для хранения сессий чата (опционально)
CREATE TABLE IF NOT EXISTS chat_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT,
  messages JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индекс для поиска сессий по пользователю
CREATE INDEX IF NOT EXISTS chat_sessions_user_id_idx ON chat_sessions(user_id);

-- Триггер для обновления updated_at в chat_sessions
DROP TRIGGER IF EXISTS update_chat_sessions_updated_at ON chat_sessions;
CREATE TRIGGER update_chat_sessions_updated_at
    BEFORE UPDATE ON chat_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
SQL

# Выполняем SQL скрипт
log_info "Создание таблиц и функций..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SQL_SCRIPT"

# Удаляем временный файл
rm "$SQL_SCRIPT"

# Проверяем созданные объекты
log_info "Проверка созданных объектов..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
\dt documents
\df match_documents
EOF

log_info "=== Настройка завершена ==="
log_info "Созданы следующие объекты:"
log_info "  - Таблица documents (для хранения документов с эмбеддингами)"
log_info "  - Таблица chat_sessions (для хранения сессий чата)"
log_info "  - Функция match_documents (для векторного поиска)"
log_info "  - Индексы для оптимизации поиска"

log_warn "Пример использования функции match_documents:"
log_warn "  SELECT * FROM match_documents("
log_warn "    '[0.1, 0.2, ...]'::vector(1536),  -- ваш embedding"
log_warn "    0.7,                              -- порог схожести"
log_warn "    10                                 -- количество результатов"
log_warn "  );"

log_info "Настройка векторной БД завершена!"
