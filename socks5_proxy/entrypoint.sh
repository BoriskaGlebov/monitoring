#!/bin/sh

echo "Starting 3proxy..."

# Создаём файл пользователей
cat <<EOF > /usr/local/3proxy/conf/users.txt
$SOCKS5_LOGIN:CL:$SOCKS5_PASSWORD
EOF

# Создаём конфиг
cat <<EOF > /usr/local/3proxy/conf/3proxy.cfg
#!/bin/3proxy

timeouts 1 5 30 60 180 1800 15 60

users \$/usr/local/3proxy/conf/users.txt

log /usr/local/3proxy/logs/3proxy.log
logformat "-\""+_G{""time_unix"":%t, ""proxy"":{""type:"":""%N"", ""port"":%p}, ""error"":{""code"":""%E""}, ""auth"":{""user"":""%U""}, ""client"":{""ip"":""%C"", ""port"":%c}, ""server"":{""ip"":""%R"", ""port"":%r}, ""bytes"":{""sent"":%O, ""received"":%I}, ""request"":{""hostname"":""%n""}, ""message"":""%T""}"

auth strong
socks -p$SOCKS5_PORT
EOF

echo "Container startup"

/bin/3proxy /usr/local/3proxy/conf/3proxy.cfg