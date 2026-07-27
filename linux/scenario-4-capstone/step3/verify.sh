#!/bin/bash
set -e

if ! nft list table inet filter >/dev/null 2>&1; then
  echo "No 'inet filter' table is loaded."
  echo "  nft -c -f /root/firewall.nft && nft -f /root/firewall.nft"
  exit 1
fi

RS=$(nft list table inet filter)

if ! sed -n '/chain input/,/}/p' <<<"$RS" | grep -q 'policy drop'; then
  echo "The input chain policy is not 'drop'."
  exit 1
fi

if ! grep -qE 'ct state.*established' <<<"$RS"; then
  echo "No 'ct state established,related accept' rule."
  echo "Without it, replies to this host's own outbound connections are dropped."
  exit 1
fi

for p in 22 2222 80; do
  if ! grep -qE "tcp dport ($p|\{[^}]*\b$p\b[^}]*\})" <<<"$RS"; then
    echo "Port $p is not accepted by the ruleset."
    exit 1
  fi
done

if ! timeout 8 getent hosts archive.ubuntu.com >/dev/null 2>&1; then
  echo "Outbound DNS is not working with this ruleset loaded."
  echo "That is the signature of a missing connection tracking rule."
  exit 1
fi

CNAME=$(su - appsvc -s /bin/bash -c 'podman ps --format "{{.Names}}"' 2>/dev/null | head -1)
if [ -z "$CNAME" ]; then
  echo "No running container for appsvc."
  echo "  su - appsvc -s /bin/bash -c 'podman run -d --name gateway-app --memory=64m -p 127.0.0.1:8080:80 docker.io/library/nginx:alpine'"
  exit 1
fi

PID=$(su - appsvc -s /bin/bash -c "podman inspect --format '{{.State.Pid}}' $CNAME" 2>/dev/null)
RUNAS=$(ps -o user= -p "$PID" 2>/dev/null | tr -d ' ')
if [ "$RUNAS" = "root" ] || [ -z "$RUNAS" ]; then
  echo "The container's host process runs as '${RUNAS:-unknown}', expected an unprivileged user."
  echo "Start it as appsvc, not root."
  exit 1
fi

BIND=$(ss -tlnH 'sport = :8080' | awk '{print $4}' | head -1)
case "$BIND" in
  127.0.0.1:*) ;;
  *) echo "Port 8080 is bound to '${BIND:-nothing}', expected 127.0.0.1 only."
     echo "Publish with -p 127.0.0.1:8080:80 so only the proxy can reach it."; exit 1 ;;
esac

CG=$(cut -d: -f3 "/proc/$PID/cgroup" 2>/dev/null)
MEM=$(cat "/sys/fs/cgroup${CG}/memory.max" 2>/dev/null || echo max)
if [ "$MEM" = "max" ] || [ -z "$MEM" ]; then
  echo "The container has no memory ceiling in the kernel (memory.max = $MEM)."
  echo "Start it with --memory=64m and check /sys/fs/cgroup<path>/memory.max."
  exit 1
fi

echo "Default-deny firewall with conntrack, outbound working, and '$CNAME' rootless as $RUNAS on loopback with memory.max=$MEM."
exit 0
