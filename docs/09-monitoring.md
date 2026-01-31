# Мониторинг (Prometheus + Grafana)

Это руководство описывает базовую настройку мониторинга для инфраструктуры.

## Предварительные требования
1. Запущена основная инфраструктура (`docker-compose.yml`).
2. В `.env` задан пароль Grafana: `GRAFANA_PASSWORD`.

## 1. Подготовка .env
```bash
cd docker-compose
cp env.example .env
nano .env
```

Добавьте или обновите:
```bash
GRAFANA_PASSWORD=your-secure-grafana-password
```

## 2. Запуск мониторинга
```bash
cd docker-compose
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml ps
```

## 3. Доступ к интерфейсам
- **Prometheus:** http://localhost:9090
- **Grafana:** http://localhost:3000  
  Логин: `admin`  
  Пароль: `GRAFANA_PASSWORD`

Примечание:
- Порты мониторинга привязаны к `127.0.0.1`.
- Для внешнего доступа используйте SSH‑туннель или reverse proxy.

## 4. Источники метрик
В базовой конфигурации Prometheus собирает метрики n8n по `/metrics`:

```yaml
scrape_configs:
  - job_name: n8n
    metrics_path: /metrics
    static_configs:
      - targets: ["n8n:5678"]
```

## Источники
- https://prometheus.io/docs/introduction/overview/
- https://grafana.com/docs/grafana/latest/
