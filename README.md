# Monitoring

Мониторинг серверов и Docker-контейнеров: метрики (Prometheus + Grafana), логи (Loki + Alloy), алерты в Telegram. Плюс nginx как reverse proxy и telemt-конфиг (не используется прямо сейчас, оставлен на будущее).

## Архитектура

Стек развёрнут как обычный `docker compose` (без Docker Swarm) и состоит из трёх файлов:

- **`docker-compose.yaml`** — nginx (host network, HTTPS-терминация, reverse proxy на Grafana/Prometheus)
- **`docker-compose.monitoring-server.yml`** — централизованная часть, один экземпляр на "главном" сервере:
  - Prometheus — хранит метрики
  - Grafana — дашборды и алертинг
  - Loki — хранит логи
- **`docker-compose.monitoring-agent.yml`** — агенты, по одному набору на **каждый** мониторимый сервер:
  - cAdvisor — метрики Docker-контейнеров
  - node-exporter — метрики самого хоста (CPU/RAM/диск/сеть)
  - Alloy — собирает логи всех контейнеров хоста и шлёт их в Loki

Все три файла запускаются вместе через `docker compose -f docker-compose.yaml -f docker-compose.monitoring-server.yml -f docker-compose.monitoring-agent.yml up -d` — сейчас так развёрнуто на одном сервере (`vpn-boriska.ru`), остальные пока мониторятся только в конфиге (см. `prometheus.yml`), агенты на них ещё не подняты.

Grafana настроена полностью **как код** — датасорсы, дашборды и правила алертов лежат в `grafana/provisioning/` и подхватываются автоматически при старте/на лету, руками через UI ничего настраивать не нужно (и не стоит — правки в UI не переживут следующий деплой).

## Содержимое репозитория

| Путь | Что это |
|---|---|
| `docker-compose.yaml` | nginx |
| `docker-compose.monitoring-server.yml` | Prometheus, Grafana, Loki |
| `docker-compose.monitoring-agent.yml` | cAdvisor, node-exporter, Alloy |
| `prometheus.yml` | конфиг Prometheus (scrape-таргеты) |
| `loki-config.yml` | конфиг Loki (single-binary, filesystem storage) |
| `alloy-config.alloy` | конфиг Alloy (сбор логов контейнеров через Docker-сокет) |
| `nginx_web.conf` | reverse proxy: `/grafana/`, `/prometheus/`, ACME для certbot |
| `grafana/provisioning/datasources/` | Prometheus + Loki датасорсы |
| `grafana/provisioning/dashboards/` | дашборды (host/containers/logs/alerts) как JSON |
| `grafana/provisioning/alerting/` | contact points, notification policy, правила алертов |
| `send_telegram.sh` | cron-хук `certbot renew` на этом сервере — шлёт статус обновления сертификатов в Telegram |
| `send_telegram_help_blocks.sh` | то же самое, для сервера help-blocks.ru |
| `telemt-config/` | конфиг telemt (Telegram MTProto-прокси) — сейчас не используется ни одним compose-файлом, оставлено для возможного будущего применения |
| `grafana_dashboards/` | старые вручную экспортированные дашборды, не подключены — актуальные лежат в `grafana/provisioning/dashboards/` |
| `.env.example` | шаблон переменных окружения |
| `QUICKStart.md` | настройка нового сервера с нуля (SSH-доступ + первичное обслуживание) |

## Быстрый старт

1. Скопировать `.env.example` в `.env` и заполнить:
   ```env
   GF_ADMIN_USER=admin
   GF_ADMIN_PASSWORD=<надёжный пароль>
   TELEGRAM_BOT_TOKEN=<токен бота>
   TELEGRAM_CHAT_ID=<chat id>
   ```
2. Убедиться, что на хосте есть сертификаты Let's Encrypt (`/etc/letsencrypt`) — через certbot.
3. Запуск:
   ```bash
   docker compose \
     -f docker-compose.yaml \
     -f docker-compose.monitoring-server.yml \
     -f docker-compose.monitoring-agent.yml \
     up -d
   ```
4. Доступ:
   - Grafana: `https://<домен>/grafana/`
   - Prometheus: `https://<домен>/prometheus/`

### Деплой на "главный" сервер (vpn-boriska.ru)

Настроен через GitHub Actions (`.github/workflows/linters_tests_deploy.yml`): пуш в `develop` — сервер сам подтягивает код, пересобирает `.env` из GitHub Secrets (`GF_ADMIN_USER`, `GF_ADMIN_PASSWORD`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`) и передёргивает compose. Секреты нужно один раз прописать в настройках репозитория на GitHub.

### Добавление нового мониторимого сервера

1. Задеплоить на него `docker-compose.monitoring-agent.yml` (cAdvisor + node-exporter + Alloy)
2. Добавить его адрес в `prometheus.yml` (targets для `cadvisor`/`node-exporter`)
3. В `alloy-config.alloy` на этом сервере поменять `loki.write` endpoint на публично доступный адрес центрального Loki (сейчас там `http://loki:3100` — резолвится только пока Alloy живёт в одном docker-compose проекте с самим Loki)

## Мониторинг и алерты

- **Дашборды**: "Node Exporter Full" (состояние хоста), "Docker and system monitoring" (хост + контейнеры), "Logs" (логи через Loki), "Alerts Overview" (активные алерты)
- **Алерты** уходят в Telegram: недоступность экспортёра, диск >90%, память >90%, swap >50%, перегрузка CPU (нормализована на число ядер), падение числа контейнеров (относительно часа назад — не требует правки при изменении их количества), всплеск ERROR-логов в `api`/`vpn_bot`
- Настройка правил/каналов — только через файлы в `grafana/provisioning/alerting/`, не через UI

## Безопасность

- Секреты — только через `.env` (гитигнорится) или GitHub Secrets, не в репозитории
- Порты node-exporter (9100) и cAdvisor (8080) публикуются наружу без аутентификации — нужны для сбора метрик с других серверов, ограничивать доступ файрволом
- Prometheus/Grafana слушают только `127.0.0.1`, наружу отдаются исключительно через nginx (HTTPS)
- fail2ban / ufw — рекомендуется настраивать на уровне ОС отдельно (см. `QUICKStart.md`)

## Полезные команды

```bash
# Логи сервиса
docker compose -f docker-compose.yaml -f docker-compose.monitoring-server.yml -f docker-compose.monitoring-agent.yml logs -f grafana

# Перезапуск всего стека
docker compose -f docker-compose.yaml -f docker-compose.monitoring-server.yml -f docker-compose.monitoring-agent.yml restart

# Проверка конфига nginx
docker exec nginx nginx -t
```

## FAQ

- **Grafana отображается некорректно за прокси** — проверить `sub_filter`/`proxy_pass` в `nginx_web.conf` и `GF_SERVER_ROOT_URL` в compose
- **Дашборд не подхватил правки из JSON** — файловый provisioning Grafana поллит папку каждые 30 сек, но датасорсы читаются только при старте контейнера — если менялся датасорс, нужен рестарт Grafana
- **Алерт в Telegram не долетает** — проверить `docker logs grafana | grep -i telegram`, обычно проблема либо в токене/chat_id, либо в форматировании сообщения (используем `parse_mode: HTML`, а не Markdown — он куда терпимее к произвольному тексту в лейблах)

## Автор

BoriskaGlebov — https://github.com/BoriskaGlebov
