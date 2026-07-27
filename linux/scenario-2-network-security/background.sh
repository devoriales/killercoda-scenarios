#!/bin/bash
# background.sh — runs silently before the student arrives.
# Students never see this script or its output.
#
# Builds an analytics host with one deliberate misconfiguration (a metrics endpoint the
# load balancer cannot reach) and no firewall, no SSH hardening, and no scheduled checks.
# Those are the four things the student adds.
#
# `set -uo pipefail` but NOT `set -e`: one failing line must never abort setup and leave
# a half-built lab. Everything below is safe to run twice.
set -uo pipefail

LOG=/var/log/killercoda/background.log
mkdir -p /var/log/killercoda /root/answers /srv/analytics

# ---------------------------------------------------------------- packages
# nftables and dnsutils are the whole of steps 1 and 3. A missing binary ends the step
# in "command not found", so the install is guarded rather than assumed.
for pkg in nftables dnsutils; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "[background] installing $pkg" >> "$LOG"
    { apt-get update -qq && apt-get install -y -qq "$pkg"; } >> "$LOG" 2>&1
  fi
done

# ---------------------------------------------------------------- identity
getent group  analytics >/dev/null || groupadd --system analytics
getent passwd analytics >/dev/null || useradd --system --gid analytics \
    --home-dir /srv/analytics --shell /usr/sbin/nologin \
    --comment "Analytics collector service" analytics
chown -R analytics:analytics /srv/analytics

# ---------------------------------------------------------------- the fault for step 1
# The metrics endpoint binds to 127.0.0.1. It answers perfectly from the host itself and
# is unreachable from anywhere else, which is the single most common "the service is up
# but I cannot reach it" cause there is. Step 1 is diagnosing and fixing exactly this.
cat > /etc/systemd/system/analytics-metrics.service <<'UNIT'
[Unit]
Description=Analytics metrics endpoint
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=analytics
Group=analytics
WorkingDirectory=/srv/analytics
ExecStart=/usr/bin/python3 -m http.server 9095 --bind 127.0.0.1
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

echo "metrics endpoint" > /srv/analytics/index.html
chown analytics:analytics /srv/analytics/index.html

systemctl daemon-reload >> "$LOG" 2>&1
systemctl enable --now analytics-metrics.service >> "$LOG" 2>&1

# ---------------------------------------------------------------- clean slate elsewhere
# No firewall, no hardening drop-in, no timer. The student adds all three.
nft delete table inet filter    2>/dev/null
nft delete table inet practice  2>/dev/null
rm -f /etc/ssh/sshd_config.d/99-hardening.conf
rm -f /etc/systemd/system/metrics-healthcheck.{service,timer}
rm -f /usr/local/bin/metrics-healthcheck
systemctl daemon-reload >> "$LOG" 2>&1

echo "[background] Ready. metrics bound to loopback only, no firewall, no timer." >> "$LOG"
