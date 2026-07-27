#!/bin/bash
# background.sh — runs silently before the student arrives.
# Students never see this script or its output.
#
# Prepares a host where containers can be built up from primitives: a non-root operator
# account with subordinate UID ranges for rootless Podman, nginx present but not running,
# and no cgroups or containers of the student's own yet.
#
# `set -uo pipefail` but NOT `set -e`: one failing line must never abort setup and leave
# a half-built lab. Everything below is safe to run twice.
set -uo pipefail

LOG=/var/log/killercoda/background.log
mkdir -p /var/log/killercoda

# ---------------------------------------------------------------- packages
# nginx is step 4's reverse proxy and is in the Ubuntu archive, so it installs in
# seconds. Podman is normally present on this backend; guarded in case it is not.
for pkg in nginx podman uidmap slirp4netns; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "[background] installing $pkg" >> "$LOG"
    { apt-get update -qq && apt-get install -y -qq "$pkg"; } >> "$LOG" 2>&1
  fi
done

# nginx must not hold port 80 before step 4 configures it.
systemctl disable --now nginx >> "$LOG" 2>&1

# ---------------------------------------------------------------- the operator account
# Step 3 runs a container as this user, with no sudo and no membership of any docker
# group. Rootless Podman needs subordinate UID and GID ranges: without them the user
# namespace cannot map container UIDs and every run fails with a mapping error.
if ! getent passwd appops >/dev/null; then
  useradd -m -s /bin/bash -c "Application operator" appops
fi
grep -q "^appops:" /etc/subuid || usermod --add-subuids 200000-265535 appops
grep -q "^appops:" /etc/subgid || usermod --add-subgids 200000-265535 appops

# Rootless Podman needs a user session so its files land somewhere writable.
loginctl enable-linger appops >> "$LOG" 2>&1

# ---------------------------------------------------------------- clean slate
# The student creates all of these.
rmdir /sys/fs/cgroup/practice 2>/dev/null
rm -rf /root/answers /srv/edge
mkdir -p /root/answers
rm -f /etc/nginx/sites-enabled/appdemo /etc/nginx/sites-available/appdemo

echo "[background] Ready. appops exists with subuid ranges, nginx installed and stopped." >> "$LOG"
