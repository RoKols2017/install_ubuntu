[← Nginx](07-nginx.md) · [Back to README](../README.md) · [Hardware Drivers →](08-hardware-drivers.md)

# Nginx Operations

Расширенные настройки Nginx для нескольких сервисов, security controls, performance, logs and troubleshooting.

## Несколько сервисов

Используйте поддомены для разных web-интерфейсов:

```nginx
server {
    listen 443 ssl http2;
    server_name n8n.your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:5678;
    }
}

server {
    listen 443 ssl http2;
    server_name studio.your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:54323;
    }
}
```

## Ограничение доступа по IP

```nginx
location / {
    allow 192.168.1.0/24;
    allow 1.2.3.4;
    deny all;
    proxy_pass http://localhost:5678;
}
```

## Rate Limiting

```nginx
limit_req_zone $binary_remote_addr zone=n8n_limit:10m rate=10r/s;

location / {
    limit_req zone=n8n_limit burst=20 nodelay;
    proxy_pass http://localhost:5678;
}
```

## Secure Headers

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

## Performance

Static cache:

```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

Compression:

```nginx
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss;
```

Large requests:

```nginx
client_max_body_size 50M;
client_body_buffer_size 128k;
proxy_buffering on;
proxy_buffer_size 4k;
proxy_buffers 8 4k;
```

## Logs And Status

```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
sudo nginx -t
sudo systemctl status nginx
sudo netstat -an | grep :443
```

## Troubleshooting

### Nginx не запускается

```bash
sudo nginx -t
sudo tail -50 /var/log/nginx/error.log
sudo netstat -tlnp | grep -E ':(80|443)'
```

### 502 Bad Gateway

```bash
docker ps | grep n8n
curl http://localhost:5678/healthz
```

Проверьте `proxy_pass` и порт backend-сервиса.

### SSL не работает

```bash
sudo certbot certificates
sudo certbot renew
sudo ls -la /etc/letsencrypt/live/your-domain.com/
```

### Too Many Open Files

В `/etc/security/limits.conf`:

```text
* soft nofile 65535
* hard nofile 65535
```

Или в `/etc/nginx/nginx.conf`:

```nginx
worker_rlimit_nofile 65535;
```

## Maintenance

Update:

```bash
sudo apt update
sudo apt upgrade nginx
sudo systemctl restart nginx
```

Remove:

```bash
sudo systemctl stop nginx
sudo apt remove --purge nginx nginx-common
sudo apt autoremove
sudo rm -rf /etc/nginx /var/log/nginx
```

## See Also

- [Nginx](07-nginx.md) — базовая установка и SSL path.
- [Troubleshooting](11-troubleshooting.md) — общая диагностика Docker-стека.
- [Monitoring](09-monitoring.md) — runtime-наблюдение после публикации сервисов.
