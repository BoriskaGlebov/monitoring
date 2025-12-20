#!/bin/bash

#!/bin/bash

WEBHOOK_URL="https://api.telegram.org/bot6796421307:AAHmQ9jvbJl9kslUnPR5W5beV5ECAuesWAs/sendMessage"
CHAT_ID="439653349"
COMMON_FILE="/home/vpn_user/test_zone/vpn_bot/docker-compose.common.yml"
COMPOSE_PATH="/home/vpn_user/test_zone/vpn_bot/docker-compose.develop.yml"


# Выполняем обновление и сохраняем вывод
OUTPUT=$(certbot renew --deploy-hook "docker compose -f $COMMON_FILE -f $COMPOSE_PATH restart nginx_vpn_bot" 2>&1)
EXIT_CODE=$?
# Получаем имя хоста
SERVER_NAME="help-blocks"
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