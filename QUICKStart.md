# 🚀 Быстрая настройка нового сервера (SSH + безопасность)

Этот гайд описывает первичную настройку арендованного сервера: подключение по root, создание пользователя, настройка SSH-ключей и отключение паролей.

---

## 🔑 1. Подключение к серверу по паролю root
```shell
    ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@IP_ADDRESS
```


---

## 👤 2. Создание нового пользователя
```shell
    sudo adduser username
```


---

## 🛡 3. Добавление пользователя в sudo

```shell
    Ubuntu / Debian:
    sudo usermod -aG sudo username
```

---

## 🔐 4. Создание SSH-ключа на локальной машине

```shell
    ssh-keygen -t ed25519 -C "key for server" -f ~/.ssh/xray_host
```

---

## 📤 5. Добавление ключа на сервер

```shell
    ssh-copy-id -i ~/.ssh/xray_host.pub \ -o IdentitiesOnly=yes \ -o IdentityFile=~/.ssh/xray_host \ xray@132.243.246.145
```
---

## ⚙️ 6. Настройка SSH-конфига (локально)

```shell
    nano ~/.ssh/config

    Host xray-host
        HostName IP_ADDRESS
        User xray
        IdentityFile ~/.ssh/xray_host
        IdentitiesOnly yes
    
    #Подключение:
    ssh xray-host
```

---

## 🔎 7. Проверка подключения по ключу

```shell
    ssh -i ~/.ssh/xray_host -o IdentitiesOnly=yes xray@IP_ADDRESS
```

---

## 🔍 8. Проверка конфигов на сервере

ls -la /etc/ssh/sshd_config.d/

---

## 🔒 9. Отключение пароля и root-доступа

Открыть конфиг:
sudo nano /etc/ssh/sshd_config

или:
sudo nano /etc/ssh/sshd_config.d/99-hardening.conf

Добавить:
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin no
PubkeyAuthentication yes

Опционально:
AllowUsers xray

---

## 🔄 10. Перезапуск SSH

```shell
    sudo systemctl restart ssh
```

---

## 🚨 11. Проверка (ОБЯЗАТЕЛЬНО)

```shell
    ssh xray-host

    ssh root@IP_ADDRESS

    ssh -o PreferredAuthentications=password xray@IP_ADDRESS
```

---

## 🧠 Итог

- root вход по SSH отключён
- парольная аутентификация отключена
- доступ только по SSH-ключу
- отдельный пользователь с sudo