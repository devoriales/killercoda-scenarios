#!/bin/bash
# background.sh — runs silently before the student arrives.
# Students never see this script or its output.
#
# It builds a small but realistic analytics host: a service account, a deploy group,
# an on-call engineer, and a systemd unit with one deliberate fault for step 3.
#
# `set -uo pipefail` but NOT `set -e`: one failing line must never abort setup and
# leave the student with a half-built lab. Everything below is safe to run twice.
set -uo pipefail

LOG=/var/log/killercoda/background.log
mkdir -p /var/log/killercoda /root/answers

# ---------------------------------------------------------------- packages
# setfacl/getfacl are the whole of step 2 and are NOT in every minimal Ubuntu image.
# A missing binary there ends the step in "command not found", so it is worth the
# guarded install. Costs nothing when already present.
if ! command -v setfacl >/dev/null 2>&1; then
  echo "[background] acl missing, installing." >> "$LOG"
  { apt-get update -qq && apt-get install -y -qq acl; } >> "$LOG" 2>&1
fi

# ---------------------------------------------------------------- identities
# Service account: no password, no login shell. It exists only to own a process.
getent group  analytics >/dev/null || groupadd --system analytics
getent passwd analytics >/dev/null || useradd --system --gid analytics \
    --home-dir /srv/analytics --shell /usr/sbin/nologin \
    --comment "Analytics collector service" analytics

# Humans.
getent group deployers >/dev/null || groupadd deployers
getent group oncall    >/dev/null || groupadd oncall
getent passwd rjimenez >/dev/null || useradd -m -s /bin/bash -G deployers -c "Rosa Jimenez" rjimenez
getent passwd tokafor  >/dev/null || useradd -m -s /bin/bash -G oncall    -c "Tunde Okafor" tokafor

# ---------------------------------------------------------------- directories
mkdir -p /srv/analytics/logs /srv/analytics/releases /srv/analytics/incoming
chown -R analytics:analytics /srv/analytics/logs /srv/analytics/incoming

# Step 1 fault A: the log is world writable. Anyone on the box can rewrite the record
# while it still appears to be owned by the service. The student fixes this.
cat > /srv/analytics/logs/collector.log <<'COLLECTORLOG'
ts=2026-03-14T08:12:03Z level=info msg="collector started"
ts=2026-03-14T08:12:08Z level=info queue_depth=41
ts=2026-03-14T08:13:11Z level=warn queue_depth=8412 msg="ingest backlog growing"
ts=2026-03-14T08:14:02Z level=info queue_depth=77
COLLECTORLOG
chown analytics:analytics /srv/analytics/logs/collector.log
chmod 0777 /srv/analytics/logs/collector.log

# Step 1 fault B: a shared release directory with no setgid bit, so files created by
# one member of deployers are unreadable by the rest of the team.
#
# `chmod g-s` is required and `chmod 0775` is not enough. GNU chmod deliberately
# PRESERVES the setuid and setgid bits on a directory when given an octal mode, so on a
# re-run of this script a directory that already had setgid would keep it and step 1
# would be solved before the student arrived. Clearing it symbolically is unambiguous.
chown root:deployers /srv/analytics/releases
chmod 0775 /srv/analytics/releases
chmod g-s  /srv/analytics/releases
find /srv/analytics/releases -mindepth 1 -delete 2>/dev/null || true

# ---------------------------------------------------------------- the service
# The collector itself. Traps SIGTERM so students can see a clean shutdown.
cat > /usr/local/bin/analytics-collector.sh <<'COLLECTOR'
#!/usr/bin/env bash
set -euo pipefail
LOGFILE=/srv/analytics/logs/collector.log

shutdown() {
    echo "ts=$(date -u +%FT%TZ) level=info msg=\"shutting down cleanly on SIGTERM\"" >> "$LOGFILE"
    exit 0
}
trap shutdown TERM INT

echo "ts=$(date -u +%FT%TZ) level=info msg=\"collector started\" pid=$$" >> "$LOGFILE"
while true; do
    echo "ts=$(date -u +%FT%TZ) level=info queue_depth=$((RANDOM % 200))" >> "$LOGFILE"
    sleep 5 &
    wait $!
done
COLLECTOR
chmod 0755 /usr/local/bin/analytics-collector.sh

# Guarantee the step 3 fault rather than assuming a clean image. If anything ever leaves
# a binary at the un-suffixed path, the broken ExecStart below would resolve, the service
# would start cleanly, and the whole step would evaporate with no sign anything was wrong.
rm -f /usr/local/bin/analytics-collector

# Step 3 fault: ExecStart names /usr/local/bin/analytics-collector, but the script that
# exists is analytics-collector.sh. systemd will fail the unit with 203/EXEC, which is
# the error this step teaches students to read. Do NOT "fix" this here.
cat > /etc/systemd/system/analytics-collector.service <<'UNIT'
[Unit]
Description=Analytics collector
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=analytics
Group=analytics
ExecStart=/usr/local/bin/analytics-collector
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload >> "$LOG" 2>&1

# Deliberately left stopped and disabled. Step 3 is where the student starts it.
systemctl disable analytics-collector.service >> "$LOG" 2>&1 || true
systemctl stop    analytics-collector.service >> "$LOG" 2>&1 || true

echo "[background] Ready. analytics/rjimenez/tokafor exist, unit staged with a 203/EXEC fault." >> "$LOG"
