# Установка и настройка Nginx

Nginx используется как reverse proxy для сервисов инфраструктуры, обеспечивая SSL/TLS шифрование и единую точку входа.

## Предварительные требования

- Ubuntu сервер с настроенной безопасностью ([Этап 1](01-server-security.md))
- Docker установлен ([Этап 2](02-docker-installation.md))
- Доменное имя, указывающее на IP сервера (для SSL сертификатов)
- Порты: 80 (HTTP), 443 (HTTPS)

## Шаг 1: Установка Nginx

```bash
# Используя скрипт (рекомендуется)
sudo bash scripts/07-setup-nginx.sh

# Или вручную
sudo apt update
sudo apt install -y nginx
```

## Шаг 2: Базовая проверка

После установки проверьте статус:

```bash
sudo systemctl status nginx
```

Nginx должен быть доступен по адресу `http://your-server-ip`

## Шаг 3: Настройка reverse proxy для n8n

Создаём конфигурацию для n8n:

```bash
sudo nano /etc/nginx/sites-available/n8n
```

Используйте шаблон из `templates/nginx.conf.example` или создайте базовую конфигурацию:

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
        
        # Таймауты для long-running запросов
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
```

Активируем конфигурацию:

```bash
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
sudo nginx -t  # Проверка конфигурации
sudo systemctl reload nginx
```

## Шаг 4: Установка SSL сертификата (Let's Encrypt)

### Установка Certbot

```bash
sudo apt install -y certbot python3-certbot-nginx
```

### Получение сертификата

```bash
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

Certbot автоматически:
- Получит SSL сертификат
- Настроит Nginx для использования HTTPS
- Настроит автоматическое обновление сертификата

### Автоматическое обновление

Certbot автоматически настраивает cron для обновления сертификатов. Проверьте:

```bash
sudo certbot renew --dry-run
```

## Шаг 5: Настройка для нескольких сервисов

Если нужно проксировать несколько сервисов, используйте поддомены:

```nginx
# n8n
server {
    listen 443 ssl http2;
    server_name n8n.your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:5678;
        # ... остальные настройки proxy
    }
}

# Supabase Studio (опционально)
server {
    listen 443 ssl http2;
    server_name studio.your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:54323;
        # ... остальные настройки proxy
    }
}
```

## Шаг 6: Безопасность

### Ограничение доступа по IP (опционально)

```nginx
location / {
    allow 192.168.1.0/24;  # Разрешить локальную сеть
    allow 1.2.3.4;          # Разрешить конкретный IP
    deny all;               # Запретить все остальное
    
    proxy_pass http://localhost:5678;
}
```

### Rate limiting

```nginx
# В http блоке
limit_req_zone $binary_remote_addr zone=n8n_limit:10m rate=10r/s;

# В server блоке
location / {
    limit_req zone=n8n_limit burst=20 nodelay;
    proxy_pass http://localhost:5678;
}
```

### Безопасные заголовки

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

## Шаг 7: Оптимизация производительности

### Кэширование статических файлов

```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### Сжатие

```nginx
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss;
```

### Увеличение буферов для больших запросов

```nginx
client_max_body_size 50M;
client_body_buffer_size 128k;
proxy_buffering on;
proxy_buffer_size 4k;
proxy_buffers 8 4k;
```

## Мониторинг и логи

### Просмотр логов

```bash
# Логи доступа
sudo tail -f /var/log/nginx/access.log

# Логи ошибок
sudo tail -f /var/log/nginx/error.log

# Логи конкретного сайта
sudo tail -f /var/log/nginx/n8n_access.log
```

### Статистика

```bash
# Проверка конфигурации
sudo nginx -t

# Проверка статуса
sudo systemctl status nginx

# Проверка активных соединений
sudo netstat -an | grep :443
```

## Устранение неполадок

### Проблема: Nginx не запускается

```bash
# Проверьте конфигурацию на ошибки
sudo nginx -t

# Проверьте логи
sudo tail -50 /var/log/nginx/error.log

# Проверьте, не заняты ли порты
sudo netstat -tlnp | grep -E ':(80|443)'
```

### Проблема: 502 Bad Gateway

```bash
# Проверьте, запущен ли backend сервис
docker ps | grep n8n
curl http://localhost:5678/healthz

# Проверьте настройки proxy_pass в конфигурации
# Убедитесь, что используется правильный порт
```

### Проблема: SSL сертификат не работает

```bash
# Проверьте сертификат
sudo certbot certificates

# Обновите сертификат вручную
sudo certbot renew

# Проверьте права доступа к файлам сертификата
sudo ls -la /etc/letsencrypt/live/your-domain.com/
```

### Проблема: Слишком много открытых файлов

```bash
# Увеличьте лимит
sudo nano /etc/security/limits.conf
# Добавьте:
# * soft nofile 65535
# * hard nofile 65535

# Или в /etc/nginx/nginx.conf:
worker_rlimit_nofile 65535;
```

## Обновление Nginx

```bash
sudo apt update
sudo apt upgrade nginx
sudo systemctl restart nginx
```

## Удаление Nginx

```bash
sudo systemctl stop nginx
sudo apt remove --purge nginx nginx-common
sudo apt autoremove
sudo rm -rf /etc/nginx
sudo rm -rf /var/log/nginx
```

## Дополнительные настройки

### Настройка для production

1. **Отключите версию Nginx в заголовках:**
   ```nginx
   server_tokens off;
   ```

2. **Настройте таймауты:**
   ```nginx
   keepalive_timeout 65;
   client_header_timeout 20;
   client_body_timeout 20;
   send_timeout 20;
   ```

3. **Ограничьте размер запросов:**
   ```nginx
   client_max_body_size 50M;
   client_body_buffer_size 128k;
   ```

## Интеграция с firewall

Убедитесь, что порты открыты:

```bash
sudo ufw allow 'Nginx Full'
# или отдельно:
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## Источники

- [Официальная документация Nginx](https://nginx.org/en/docs/)
- [Nginx Beginner's Guide](https://nginx.org/en/docs/beginners_guide.html)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)
