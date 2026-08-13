#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

WEBHOOK_URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
CHAT_ID="$TELEGRAM_CHAT_ID"

# Выполняем обновление и сохраняем вывод
OUTPUT=$(certbot renew --deploy-hook "docker restart nginx" 2>&1)
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
