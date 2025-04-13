#!/bin/bash

BOT_TOKEN="6796421307:AAHmQ9jvbJl9kslUnPR5W5beV5ECAuesWAs"
CHAT_ID="439653349"
MESSAGE="$1"

# Проверка: если сообщение пустое — выйти
if [ -z "$MESSAGE" ]; then
  echo "❌ Ошибка: сообщение не указано"
  exit 1
fi

# Путь к curl укажем явно
/usr/bin/curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="${MESSAGE}" \
    -d parse_mode="Markdown"
