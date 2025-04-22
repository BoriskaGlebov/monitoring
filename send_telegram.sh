#!/bin/bash

#!/bin/bash

WEBHOOK_URL="https://api.telegram.org/bot6796421307:AAHmQ9jvbJl9kslUnPR5W5beV5ECAuesWAs/sendMessage"
CHAT_ID="439653349"
COMPOSE_PATH="/home/prod_server/production/monitoring/docker-compose.yaml"

# Выполняем обновление
OUTPUT=$(certbot renew --quiet --deploy-hook "docker compose -f $COMPOSE_PATH restart nginx" 2>&1)
EXIT_CODE=$?

# Проверка результата
if [[ $EXIT_CODE -eq 0 ]]; then
    if echo "$OUTPUT" | grep -q "No renewals were attempted"; then
        MESSAGE="ℹ️ Сертификаты не требуют обновления. Всё в порядке."
    else
        MESSAGE="✅ Сертификат(ы) были обновлены и nginx перезапущен."
    fi
else
    MESSAGE="❌ Ошибка при обновлении сертификатов:\n$OUTPUT"
fi

# Отправка сообщения
curl -s -X POST "$WEBHOOK_URL" -d chat_id="$CHAT_ID" -d text="$MESSAGE" -d parse_mode="Markdown"

