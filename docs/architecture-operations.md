[← Architecture](architecture.md) · [Back to README](../README.md) · [Supabase →](03-supabase.md)

# Architecture Operations

Операционные детали архитектуры: масштабирование, мониторинг, резервное копирование, производительность и дальнейшее развитие.

## Масштабирование

### Горизонтальное масштабирование

| Component | Option |
|-----------|--------|
| n8n Workers | добавление worker-контейнеров через `N8N_WORKERS_COUNT` |
| Redis | репликация или Redis Cluster для больших нагрузок |
| PostgreSQL | read replicas и connection pooling через PgBouncer |

### Вертикальное масштабирование

- Увеличение RAM сервера.
- Увеличение CPU cores.
- SSD/NVMe для PostgreSQL volumes.

## Security Layers

| Layer | Controls |
|-------|----------|
| Network | UFW, закрытые внутренние порты, optional IP allowlist |
| Application | n8n auth, Redis/PostgreSQL passwords, HTTPS через Nginx |
| Data | backups, секреты в `.env`, регулярные обновления |

## Monitoring Scope

Рекомендуемые метрики:

- CPU, RAM, disk usage, network traffic.
- Docker container status and resource usage.
- n8n workflow execution volume and failures.
- Redis operations, memory usage and queue behavior.
- PostgreSQL query volume, DB size and connection pool state.

Инструменты:

- Prometheus + Grafana.
- `docker stats`.
- Service logs via `docker compose logs`.

## Backup Scope

| Data | Backup method |
|------|---------------|
| PostgreSQL | `pg_dump` or scripted backup |
| Redis | RDB/AOF copy where needed |
| n8n workflows | stored in PostgreSQL |
| Compose config | git-tracked files and protected `.env` backup |

Базовая стратегия:

- Daily database backups.
- Weekly full backup where applicable.
- Store backups away from the host.
- Test restore on a clean machine before production use.

## Performance Notes

| Component | Optimization |
|-----------|--------------|
| PostgreSQL/pgvector | HNSW indexes, connection pooling, query tuning |
| Redis | memory limit, eviction policy, batch operations |
| n8n | workflow optimization, queue mode, worker scaling |
| Host | enough RAM, SSD/NVMe, monitoring before scaling |

## Deployment Order

1. Server security.
2. Docker installation.
3. Secret generation.
4. Supabase/PostgreSQL.
5. Redis.
6. pgvector setup.
7. n8n main/worker.
8. Optional Nginx.
9. Monitoring, backups and ready checks.

## Future Options

- Nginx load balancing and rate limiting.
- Alerting in Grafana/Prometheus.
- CI/CD for deployment checks.
- Docker Swarm or Kubernetes for high availability.

## See Also

- [Architecture](architecture.md) — high-level component map.
- [Backups](10-backup-restore.md) — concrete backup flow.
- [Quality Checks](12-quality-checks.md) — readiness validation.
