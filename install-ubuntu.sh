#!/bin/sh
set -eu

cd "$(dirname "$0")"
test "$(id -u)" -eq 0 || { echo 'Run with sudo' >&2; exit 1; }
test "$(iptables -t nat -S PREROUTING | grep -c -- '--to-ports 12345')" -eq 1 || { echo 'Expected exactly one TCP REDIRECT rule' >&2; exit 1; }

systemctl disable --now redsocks
install -m 0755 check-ph-proxy /usr/local/sbin/check-ph-proxy
cat > /etc/systemd/system/ph-proxy-guard.service <<'EOF'
[Unit]
Description=Check host TUN and Philippine proxy before allowing redsocks
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/check-ph-proxy
EOF
cat > /etc/systemd/system/ph-proxy-guard.timer <<'EOF'
[Unit]
Description=Repeat Philippine proxy health check

[Timer]
OnActiveSec=0
OnUnitActiveSec=2s
AccuracySec=1s
Unit=ph-proxy-guard.service

[Install]
WantedBy=timers.target
EOF

iptables-save > /etc/iptables/rules.v4
systemctl enable netfilter-persistent
systemctl daemon-reload
systemctl start ph-proxy-guard.service
systemctl enable --now ph-proxy-guard.timer
systemctl is-enabled netfilter-persistent ph-proxy-guard.timer
systemctl is-active ph-proxy-guard.timer
