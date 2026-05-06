[← pgvector](06-vector-db.md) · [Back to README](../README.md) · [Nginx Operations →](07-nginx-operations.md)

# Установка и настройка Nginx

Nginx используется как optional reverse proxy для публичного HTTPS-доступа к n8n и другим web-интерфейсам. По умолчанию сервисы стека привязаны к `127.0.0.1`; открывайте их наружу только осознанно.

## Предварительные требования

- Ubuntu server уже прошёл [Server Security](01-server-security.md).
- Docker stack запущен и n8n отвечает на `http://localhost:5678/healthz`.
- Домен указывает на IP сервера.
- Порты `80/tcp` и `443/tcp` разрешены в UFW.

## Быстрая установка

```bash
sudo bash scripts/08-setup-nginx.sh
```

Ручной вариант:

```bash
sudo apt update
sudo apt install -y nginx
sudo systemctl status nginx
```

## Reverse Proxy Для n8n

Создайте конфигурацию:

```bash
sudo nano /etc/nginx/sites-available/n8n
```

Базовый пример:

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
```

Активируйте сайт:

```bash
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## SSL Через Let's Encrypt

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
sudo certbot renew --dry-run
```

Certbot получит сертификат, обновит Nginx-конфигурацию и настроит renewal.

## Firewall

```bash
sudo ufw allow 'Nginx Full'
sudo ufw status verbose
```

## Проверка

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
curl -I http://your-domain.com
curl -I https://your-domain.com
```

## Advanced Operations

Настройки для нескольких сервисов, IP allowlist, rate limiting, secure headers, gzip, buffers, logs and troubleshooting вынесены в [Nginx Operations](07-nginx-operations.md).

## Источники

- [Официальная документация Nginx](https://nginx.org/en/docs/)
- [Nginx Beginner's Guide](https://nginx.org/en/docs/beginners_guide.html)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)

## See Also

- [Nginx Operations](07-nginx-operations.md) — advanced proxy, security and troubleshooting.
- [Server Security](01-server-security.md) — firewall и SSH hardening перед публичным доступом.
- [Secrets](13-secrets.md) — секреты и `.env` перед production-доступом.
