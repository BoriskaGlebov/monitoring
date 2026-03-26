#!/bin/sh

echo "Starting 3proxy..."

cat <<EOF > /usr/local/3proxy/conf/3proxy.cfg
#!/bin/3proxy

nscache 65536
timeouts 1 5 30 60 180 1800 15 60

users $SOCKS5_LOGIN:CL:$SOCKS5_PASSWORD
log /usr/local/3proxy/logs/3proxy.log
logformat "-\""+_G{""time_unix"":%t, ""proxy"":{""type:"":""%N"", ""port"":%p}, ""error"":{""code"":""%E""}, ""auth"":{""user"":""%U""}, ""client"":{""ip"":""%C"", ""port"":%c}, ""server"":{""ip"":""%R"", ""port"":%r}, ""bytes"":{""sent"":%O, ""received"":%I}, ""request"":{""hostname"":""%n""}, ""message"":""%T""}"
auth strong
allow $SOCKS5_LOGIN
deny *

socks -p$SOCKS5_PORT
EOF

exec /bin/3proxy /usr/local/3proxy/conf/3proxy.cfg