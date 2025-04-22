#!/bin/bash

#!/bin/bash

WEBHOOK_URL="https://api.telegram.org/bot6796421307:AAHmQ9jvbJl9kslUnPR5W5beV5ECAuesWAs/sendMessage"
CHAT_ID="439653349"
COMPOSE_PATH="/home/prod_server/production/monitoring/docker-compose.yaml"


# Выполняем обновление и сохраняем вывод
OUTPUT=$(certbot renew --deploy-hook "docker compose -f $COMPOSE_PATH restart nginx" 2>&1)
EXIT_CODE=$?
# Получаем имя хоста
SERVER_NAME="vpn-boriska"
# Проверка по содержимому вывода
if [[ $EXIT_CODE -ne 0 ]]; then
    MESSAGE="❌ *[$SERVER_NAME]* - ошибка при обновлении сертификатов:\n$OUTPUT"
elif echo "$OUTPUT" | grep -q "No renewals were attempted"; then
    MESSAGE="ℹ️ *[$SERVER_NAME]* - сертификаты не требуют обновления. Всё в порядке."
elif echo "$OUTPUT" | grep -q "Congratulations, all renewals succeeded"; then
    MESSAGE="✅ *[$SERVER_NAME]* -  сертификат(ы) были обновлены и nginx перезапущен."
else
    MESSAGE="⚠️ Неизвестный результат обновления:\n$OUTPUT"
fi

# Отправка сообщения
curl -s -X POST "$WEBHOOK_URL" \
  -d chat_id="$CHAT_ID" \
  -d text="$MESSAGE" \
  -d parse_mode="Markdown"