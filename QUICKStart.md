# 🚀 Настройка сервера с нуля

Два независимых сценария: (1) первичная настройка только что арендованного сервера — доступ и безопасность SSH, (2) периодическое обслуживание уже работающего сервера.

---

# Часть 1. Первичная настройка (SSH + безопасность)

Подключение по root, создание пользователя, настройка SSH-ключей и отключение паролей.

## 🔑 1. Подключение к серверу по паролю root
```shell
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@IP_ADDRESS
```

## 👤 2. Создание нового пользователя
```shell
sudo adduser username
```

## 🛡 3. Добавление пользователя в sudo
```shell
# Ubuntu / Debian:
sudo usermod -aG sudo username
```

## 🔐 4. Создание SSH-ключа на локальной машине
```shell
ssh-keygen -t ed25519 -C "key for server" -f ~/.ssh/xray_host
```

## 📤 5. Добавление ключа на сервер
```shell
ssh-copy-id -i ~/.ssh/xray_host.pub \
  -o IdentitiesOnly=yes \
  -o IdentityFile=~/.ssh/xray_host \
  xray@132.243.246.145
```

## ⚙️ 6. Настройка SSH-конфига (локально)
```shell
nano ~/.ssh/config
```
```
Host xray-host
    HostName IP_ADDRESS
    User xray
    IdentityFile ~/.ssh/xray_host
    IdentitiesOnly yes
```
Подключение: `ssh xray-host`

## 🔎 7. Проверка подключения по ключу
```shell
ssh -i ~/.ssh/xray_host -o IdentitiesOnly=yes xray@IP_ADDRESS
```

## 🔍 8. Проверка конфигов на сервере
```shell
ls -la /etc/ssh/sshd_config.d/
```

## 🔒 9. Отключение пароля и root-доступа
Открыть конфиг:
```shell
sudo nano /etc/ssh/sshd_config
# или
sudo nano /etc/ssh/sshd_config.d/99-hardening.conf
```
Добавить:
```
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
```
Опционально: `AllowUsers xray`

## 🔄 10. Перезапуск SSH
```shell
sudo systemctl restart ssh
```

## 🚨 11. Проверка (ОБЯЗАТЕЛЬНО)
```shell
ssh xray-host
ssh root@IP_ADDRESS
ssh -o PreferredAuthentications=password xray@IP_ADDRESS
```

**Итог:** root вход по SSH отключён, парольная аутентификация отключена, доступ только по SSH-ключу, отдельный пользователь с sudo.

---

# Часть 2. Обслуживание сервера

Периодические задачи для уже работающего сервера — актуально, когда заканчивается место на диске или память.

## 1. Обновление системы
Ставит последние пакеты, удаляет ненужные зависимости, чистит кэш.
```shell
sudo apt update --fix-missing && sudo apt upgrade -y
sudo apt autoremove -y
sudo apt clean
```

## 2. Очистка логов
`/var/log` разрастается со временем — на маленьком сервере это заметная часть диска.
```shell
sudo journalctl --vacuum-size=50M
sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
sudo rm -f /var/log/*.gz /var/log/*.[0-9]

# Проверить, что реально занимает место:
df -h
```

## 3. Очистка Docker
Удаляет неиспользуемые контейнеры/образы/volume'ы.
```shell
# Посмотреть, что занимает место:
docker system df

# Почистить:
docker system prune -a --volumes -f
```

## 4. Добавить SWAP (критично при малом объёме RAM)
Без свопа система может падать при пиковой нагрузке, если RAM немного (например, 2GB).
```shell
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## 5. Очистка RAM (временная мера)
```shell
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```
