# Monitoring

Мониторинг серверов и Docker-контейнеров: метрики (Prometheus + Grafana), логи (Loki + Alloy), алерты в Telegram. Плюс telemt-конфиг (не используется прямо сейчас, оставлен на будущее).

> HTTPS/reverse-proxy для Grafana и Prometheus этот репозиторий больше **не** несёт сам — nginx теперь общий на весь сервер (роль `nginx_edge` в [boriska_guard_infra](https://github.com/BoriskaGlebov/boriska_guard_infra)), а этот репозиторий кладёт туда только свой `nginx/grafana.conf` (см. ниже). Так на одном сервере может жить несколько проектов за одним nginx без взаимных правок конфигов друг друга.

## Архитектура

Стек развёрнут как обычный `docker compose` (без Docker Swarm) и состоит из двух файлов:

- **`docker-compose.monitoring-server.yml`** — централизованная часть, один экземпляр на "главном" сервере:
  - Prometheus — хранит метрики
  - Grafana — дашборды и алертинг
  - Loki — хранит логи
- **`docker-compose.monitoring-agent.yml`** — агенты, по одному набору на **каждый** мониторимый сервер:
  - cAdvisor — метрики Docker-контейнеров
  - node-exporter — метрики самого хоста (CPU/RAM/диск/сеть)
  - Alloy — собирает логи всех контейнеров хоста и шлёт их в Loki

Оба файла запускаются вместе через `docker compose -f docker-compose.monitoring-server.yml -f docker-compose.monitoring-agent.yml up -d`. Grafana и Prometheus дополнительно подключены к внешней docker-сети `edge_net` (создаёт `nginx_edge`), чтобы общий nginx мог проксировать на них по имени контейнера. Сейчас так развёрнуто на `boris-guard.space` (миграция с `vpn-boriska.ru`), остальные сервера мониторятся только в конфиге (см. `prometheus.yml`), агенты на них ещё не подняты.

Файлы `docker-compose.yaml` и `nginx_web.conf` (свой nginx, host network) — легаси прошлой схемы на `vpn-boriska.ru`, оставлены только для отката (см. закомментированный job в CI); для новых серверов не используются.

Grafana настроена полностью **как код** — датасорсы, дашборды и правила алертов лежат в `grafana/provisioning/` и подхватываются автоматически при старте/на лету, руками через UI ничего настраивать не нужно (и не стоит — правки в UI не переживут следующий деплой).

## Содержимое репозитория

| Путь | Что это |
|---|---|
| `docker-compose.monitoring-server.yml` | Prometheus, Grafana, Loki |
| `docker-compose.monitoring-agent.yml` | cAdvisor, node-exporter, Alloy |
| `nginx/grafana.conf` | свой `server{}`-конфиг для общего edge-nginx (см. `boriska_guard_infra/roles/nginx_edge`) — location'ы `/grafana/`, `/prometheus/`. CI кладёт файл в `conf.d/` общего nginx и делает reload |
| `prometheus.yml` | конфиг Prometheus (scrape-таргеты) |
| `loki-config.yml` | конфиг Loki (single-binary, filesystem storage) |
| `alloy-config.alloy` | конфиг Alloy (сбор логов контейнеров через Docker-сокет) |
| `grafana/provisioning/datasources/` | Prometheus + Loki датасорсы |
| `grafana/provisioning/dashboards/` | дашборды (host/containers/logs/alerts) как JSON |
| `grafana/provisioning/alerting/` | contact points, notification policy, правила алертов |
| `telemt-config/` | конфиг telemt (Telegram MTProto-прокси) — сейчас не используется ни одним compose-файлом, оставлено для возможного будущего применения |
| `.env.example` | шаблон переменных окружения |
| `QUICKStart.md` | настройка нового сервера с нуля (SSH-доступ + первичное обслуживание) |
| `docker-compose.yaml`, `nginx_web.conf`, `send_telegram.sh` | легаси схемы на `vpn-boriska.ru` (свой nginx вместо общего edge-nginx) — используются только закомментированным job'ом в CI, для отката |
| `send_telegram_help_blocks.sh` | не относится к этой миграции — хук для отдельного сервера help-blocks.ru |
| `grafana_dashboards/` | старые вручную экспортированные дашборды, не подключены нигде — кандидат на удаление, актуальные лежат в `grafana/provisioning/dashboards/` |

## Быстрый старт

1. Убедиться, что на сервере уже поднят общий edge-nginx (роль `nginx_edge` из `boriska_guard_infra`) и выпущен сертификат для домена Grafana — этот репозиторий сертификатами и HTTPS-терминацией не занимается.
2. Скопировать `.env.example` в `.env` и заполнить:
   ```env
   GF_ADMIN_USER=admin
   GF_ADMIN_PASSWORD=<надёжный пароль>
   TELEGRAM_BOT_TOKEN=<токен бота>
   TELEGRAM_CHAT_ID=<chat id>
   NODE_HOSTNAME=<имя этого сервера>
   GRAFANA_DOMAIN=<домен, по которому открывается Grafana, напр. grafana.boris-guard.space>
   ```
3. Запуск:
   ```bash
   docker compose \
     -f docker-compose.monitoring-server.yml \
     -f docker-compose.monitoring-agent.yml \
     up -d
   ```
4. Положить `nginx/grafana.conf` в `conf.d/` общего edge-nginx на сервере и перечитать его конфиг:
   ```bash
   cp nginx/grafana.conf /opt/nginx-edge/conf.d/grafana.conf
   docker exec nginx_edge nginx -s reload
   ```
5. Доступ:
   - Grafana: `https://<GRAFANA_DOMAIN>/grafana/`
   - Prometheus: `https://<GRAFANA_DOMAIN>/prometheus/`

### Деплой на "главный" сервер (boris-guard.space)

Настроен через GitHub Actions (`.github/workflows/linters_tests_deploy.yml`, job `develop_boris_guard`): пуш в `develop` — сервер сам подтягивает код, пересобирает `.env` из GitHub Secrets и передёргивает compose + reload edge-nginx. Секреты нужно один раз прописать в настройках репозитория на GitHub: `SSH_PRIVATE_KEY_BORIS_GUARD`, `SERVER_IP_BORIS_GUARD`, `SERVER_USER_BORIS_GUARD` (свои для этого сервера — отдельные от старых `SSH_PRIVATE_KEY`/`SERVER_IP`/`SERVER_USER`, которые остались только за закомментированным job'ом `develop_vpn_boriska`), плюс общие `GF_ADMIN_USER`, `GF_ADMIN_PASSWORD`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`.

Job `develop_vpn_boriska` закомментирован, а не удалён — оставлен на случай отката на прошлый сервер.

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
docker compose -f docker-compose.monitoring-server.yml -f docker-compose.monitoring-agent.yml logs -f grafana

# Перезапуск всего стека
docker compose -f docker-compose.monitoring-server.yml -f docker-compose.monitoring-agent.yml restart

# Проверка конфига общего edge-nginx (не входит в этот репозиторий)
docker exec nginx_edge nginx -t
```

## FAQ

- **Grafana отображается некорректно за прокси** — проверить `sub_filter`/`proxy_pass` в `nginx_web.conf` и `GF_SERVER_ROOT_URL` в compose
- **Дашборд не подхватил правки из JSON** — файловый provisioning Grafana поллит папку каждые 30 сек, но датасорсы читаются только при старте контейнера — если менялся датасорс, нужен рестарт Grafana
- **Алерт в Telegram не долетает** — проверить `docker logs grafana | grep -i telegram`, обычно проблема либо в токене/chat_id, либо в форматировании сообщения (используем `parse_mode: HTML`, а не Markdown — он куда терпимее к произвольному тексту в лейблах)

## Автор

BoriskaGlebov — https://github.com/BoriskaGlebov
