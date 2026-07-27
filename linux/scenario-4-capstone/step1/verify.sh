#!/bin/bash
set -e

if ! vgs vg_gateway >/dev/null 2>&1; then
  echo "Volume group vg_gateway does not exist."
  echo "  LOOP=\$(losetup -j /var/lib/gateway-disk.img | cut -d: -f1)"
  echo "  pvcreate -ff -y \"\$LOOP\" && vgcreate vg_gateway \"\$LOOP\""
  exit 1
fi

if ! findmnt -n /srv/gateway >/dev/null 2>&1; then
  echo "/srv/gateway is not mounted."
  echo "Create an LV, mkfs it, add an fstab entry, then: mount -a"
  exit 1
fi

if ! grep -qE "^[^#].*[[:space:]]/srv/gateway[[:space:]]" /etc/fstab; then
  echo "/srv/gateway is mounted but has no /etc/fstab entry, so it is gone after a reboot."
  echo "Add it, then prove it with: umount /srv/gateway && mount -a"
  exit 1
fi

if ! getent passwd appsvc >/dev/null; then
  echo "The appsvc account does not exist."
  echo "  useradd --system --gid appsvc --home-dir /srv/gateway --shell /usr/sbin/nologin appsvc"
  exit 1
fi

SH=$(getent passwd appsvc | cut -d: -f7)
case "$SH" in
  /usr/sbin/nologin|/bin/false) ;;
  *) echo "appsvc has shell '$SH'. A service account should not be loginable."
     echo "  usermod -s /usr/sbin/nologin appsvc"; exit 1 ;;
esac

if [ "$(passwd -S appsvc 2>/dev/null | awk '{print $2}')" != "L" ]; then
  echo "appsvc is not locked. Lock it with: passwd -l appsvc"
  exit 1
fi

OWNER=$(stat -c '%U:%G' /srv/gateway)
if [ "$OWNER" != "appsvc:appsvc" ]; then
  echo "/srv/gateway is owned by $OWNER, expected appsvc:appsvc."
  echo "  chown -R appsvc:appsvc /srv/gateway"
  exit 1
fi

# Step 3 needs these and will fail confusingly without them, so catch it here.
if ! grep -q '^appsvc:' /etc/subuid || ! grep -q '^appsvc:' /etc/subgid; then
  echo "appsvc has no subordinate UID/GID ranges, so rootless containers will fail in step 3."
  echo "  usermod --add-subuids 300000-365535 appsvc"
  echo "  usermod --add-subgids 300000-365535 appsvc"
  exit 1
fi

echo "vg_gateway exists, /srv/gateway is mounted from fstab and owned by a locked appsvc account with subuid ranges."
exit 0
