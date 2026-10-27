#!/bin/sh
set -eu

cd "$(dirname "$0")"
test "$(id -u)" -eq 0 || { echo 'Run with sudo' >&2; exit 1; }
test -x /usr/bin/python3
grep -qx 'server=1.1.1.1' /etc/dnsmasq.d/gateway.conf
grep -qx 'server=8.8.8.8' /etc/dnsmasq.d/gateway.conf

systemctl stop dnsmasq
install -m 0755 proxy-doh.py /usr/local/sbin/proxy-doh
cat > /etc/systemd/system/proxy-doh.service <<'EOF'
[Unit]
Description=DNS over HTTPS through host Clash proxy
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/sbin/proxy-doh
Restart=always
RestartSec=2
User=nobody
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

cp -p /etc/dnsmasq.d/gateway.conf /etc/dnsmasq.gateway.conf.pre-doh
sed -i 's/^server=1\.1\.1\.1$/server=127.0.0.1#5354/; /^server=8\.8\.8\.8$/d' /etc/dnsmasq.d/gateway.conf
dnsmasq --test
systemctl daemon-reload
systemctl enable --now proxy-doh.service
systemctl start dnsmasq
systemctl is-active proxy-doh.service dnsmasq
