# Monitoring — контейнерная платформа мониторинга и проксирования

## Краткое описание
Проект содержит конфигурации и Docker Compose стек для запуска компонентов мониторинга и обратного проксирования:
- Nginx (SSL, обратное проксирование для Grafana/Prometheus)
- Telemt (telemetry / телеметрический сервис)
- (Опционально) экспортеры и дополнительные сервисы для Prometheus
- Grafana для визуализации метрик

Цель — собирать метрики, визуализировать их в Grafana и безопасно публиковать интерфейсы через HTTPS.

## Содержание репозитория (ключевые файлы/папки)
- `docker-compose.yaml` — основной compose-файл (nginx, telemt и т.п.)
- `docker-stack.yml` — стек для Docker Swarm (если используется)
- `nginx_web.conf` — конфигурация Nginx (HTTP->HTTPS, прокси `/grafana` и `/prometheus`, ACME)
- `telemt-config/telemt.toml` — конфигурация telemt (порт 443, TLS, API)
- `prometheus.yml` — конфигурация Prometheus (если присутствует)
- `grafana_dashboards/` — JSON-файлы/дашборды для импорта в Grafana
- `socks5_proxy/` — файлы для socks5 proxy (закомментировано в compose)
- `send_telegram.sh`, `send_telegram_help_blocks.sh` — скрипты отправки уведомлений в Telegram
- `.env` — переменные окружения (не хранить в репозитории)

## Быстрый старт
1. Подготовьте файл `.env` (если есть `.env.example`, скопируйте его и заполните):
   ```env
   DB_USER=your_user
   DB_PASSWORD=your_password
   DB_PORT=5432
   ```

2. Убедитесь, что на хосте доступны сертификаты Let's Encrypt в `/etc/letsencrypt` или настройте получение сертификатов через certbot.

3. Запуск стекa:
   ```bash
   docker compose up -d
   ```
   Или для Docker Swarm:
   ```bash
   docker stack deploy -c docker-stack.yml monitoring
   ```

4. Доступ к сервисам:
- Grafana: https://\<ваш_домен\>/grafana/
- Prometheus: https://\<ваш_домен\>/prometheus/
- Telemt: конфигурируется в `telemt-config/telemt.toml` (по умолчанию порт 443)

## Ключевые детали конфигурации
- Nginx
  - В `nginx_web.conf` настроены редиректы HTTP->HTTPS, ACME маршрут `/.well-known/acme-challenge/` и проксирование для Grafana/Prometheus.
  - Используются `limit_req_zone` для базовой защиты от массовых запросов.
  - Для корректной работы проксирования Grafana применён `sub_filter` для переписывания путей.
- Telemt
  - `telemt-config/telemt.toml` включает TLS (tls = true) и API (server.api.enabled = true).
  - В `docker-compose.yaml` telemt запускается с ограничениями безопасности (no-new-privileges, cap_drop, tmpfs) и ulimits.
- Сетевая привязка
  - В compose используются host network или привязка IP/портов. Убедитесь, что публичные IP и порты (например, 91.149.219.221 или 94.156.116.218) соответствуют настройкам хоста.

## Рекомендации по безопасности
- Не храните секреты в репозитории. Используйте `.env`, Docker secrets или менеджер секретов.
- Ограничьте доступ к административным интерфейсам (Grafana/Prometheus): включите аутентификацию и/или whitelist.
- Настройте брандмауэр (ufw/iptables):
  - Разрешить 80 и 443 для внешнего трафика.
  - Разрешить внутренние порты (например, 9090 для Prometheus) только локально.
- Установите и настройте fail2ban для защиты от повторных попыток соединений и сканирования.
- Не запускайте контейнеры от root без необходимости; вместо этого используйте capability NET_BIND_SERVICE.

## Переменные окружения (рекомендуемый минимум)
- DB_USER — пользователь БД
- DB_PASSWORD — пароль БД
- DB_PORT — порт БД
- Другие переменные зависят от конкретных сервисов и образов (проверьте docker-compose.yaml и используемые образы).

Добавьте файл `.env.example` в репозиторий для удобства развёртывания.

## Полезные команды
- Просмотр логов:
  ```bash
  docker compose logs -f nginx
  docker compose logs -f telemt
  ```
- Останов/запуск:
  ```bash
  docker compose down
  docker compose up -d
  ```
- Проверка конфигурации nginx на хосте:
  ```bash
  nginx -t -c /etc/nginx/nginx.conf
  ```

## FAQ — частые проблемы
- Ошибка привязки к порту 443: если контейнер не может привязать порт <1024, используйте capability NET_BIND_SERVICE или проброс портов через хост.
- Certbot не может верифицировать домен: проверьте, что DNS указывает на сервер и что nginx отвечает на 80 для ACME-challenge.
- Grafana некорректно отображается: проверьте `sub_filter` и `proxy_pass` в nginx, а также Base URL в Grafana.

## Лицензия
Добавьте подходящую лицензию (например, MIT) при необходи��ости.

## Автор
BoriskaGlebov — https://github.com/BoriskaGlebov

---

### Что сделано
- Сформирован README с учётом реальных конфигураций проекта (`docker-compose.yaml`, `nginx_web.conf`, `telemt-config/telemt.toml`).
- Даны рекомендации по безопасности, переменным окружения и быстрому старту.

1. Обновление системы
Что делает:
ставит последние пакеты
удаляет ненужные зависимости
чистит кэш

```shell

    sudo apt update --fix-missing && sudo apt upgrade -y
    sudo apt autoremove -y
    sudo apt clean
```

🧹 2. Очистка логов (у тебя была основная проблема)
Почему:
/var/log занял ~1.1GB
это ненормально для маленького сервера
Очистка:
```shell
    sudo journalctl --vacuum-size=50M
    sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
    sudo rm -f /var/log/*.gz /var/log/*.[0-9]
    Команда для проверки что занимает место
    df -h
```

🐳 4. Очистка Docker
Что делает:
удаляет неиспользуемые контейнеры/образы
Смотрим, что там занимает место
```shell
    docker system df
    docker system prune -a --volumes -f
```

🚨 5. Добавить SWAP (КРИТИЧНО)
Почему:
у тебя 2GB RAM
без swap система может падать
Команды:
```shell
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

```

8. Очистка RAM (временно)
```shell
    sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```
