#!/bin/bash
# background.sh — runs silently before the student arrives.
# Students never see this script or its output.
#
# Provides a bare host with the ingredients and none of the assembly: packages, a
# file-backed block device to practise LVM on, and the validation script. Everything
# the checklist looks for is left for the student to build.
#
# `set -uo pipefail` but NOT `set -e`.
set -uo pipefail

LOG=/var/log/killercoda/background.log
mkdir -p /var/log/killercoda

for pkg in lvm2 nftables nginx podman uidmap slirp4netns; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "[background] installing $pkg" >> "$LOG"
    { apt-get update -qq && apt-get install -y -qq "$pkg"; } >> "$LOG" 2>&1
  fi
done

systemctl disable --now nginx >> "$LOG" 2>&1

# A Killercoda VM has no spare disks, so LVM practises on a file-backed loop device.
# It behaves like a real block device for everything this lab does.
if [ ! -f /var/lib/gateway-disk.img ]; then
  truncate -s 1G /var/lib/gateway-disk.img
fi
losetup -j /var/lib/gateway-disk.img | grep -q loop || losetup -f /var/lib/gateway-disk.img
LOOP=$(losetup -j /var/lib/gateway-disk.img | cut -d: -f1 | head -1)
echo "[background] loop device: $LOOP" >> "$LOG"

# Recreate it on every boot so the student's LVM work survives a scenario restart.
cat > /etc/systemd/system/gateway-loop.service <<UNIT
[Unit]
Description=Attach the gateway practice disk
DefaultDependencies=no
After=local-fs-pre.target
Before=lvm2-monitor.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/losetup -f /var/lib/gateway-disk.img

[Install]
WantedBy=local-fs-pre.target
UNIT
systemctl daemon-reload >> "$LOG" 2>&1
systemctl enable gateway-loop.service >> "$LOG" 2>&1

install -m 755 /root/assets/gateway-validate /usr/local/bin/gateway-validate 2>/dev/null || \
  install -m 755 "$(dirname "$0")/assets/gateway-validate" /usr/local/bin/gateway-validate 2>/dev/null

# Clean slate: the student builds every one of these.
nft delete table inet filter 2>/dev/null
rm -f /etc/ssh/sshd_config.d/99-gateway.conf
rm -f /usr/local/bin/gateway-healthcheck
rm -f /etc/systemd/system/gateway-healthcheck.{service,timer}
rm -f /etc/nginx/sites-enabled/gateway /etc/nginx/sites-available/gateway
systemctl daemon-reload >> "$LOG" 2>&1

echo "[background] Ready. Loop device attached, nothing else built." >> "$LOG"
