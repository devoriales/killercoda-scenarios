#!/bin/bash
set -e

as_appops() { su - appops -c "$1" 2>/dev/null; }

STATE=$(as_appops "podman inspect --format '{{.State.Status}}' app" || true)
if [ "$STATE" != "running" ]; then
  echo "appops has no running container named 'app' (status: '${STATE:-not found}')."
  exit 1
fi

IP=$(hostname -I | awk '{print $1}')
if [ -z "$IP" ]; then
  echo "Could not determine this host's external address."
  exit 1
fi

# 1. The proxy must answer from outside.
CODE=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "http://${IP}/" || true)
if [ "$CODE" != "200" ]; then
  echo "http://${IP}/ returned '${CODE}', expected 200."
  echo "Check nginx: nginx -t && systemctl status nginx --no-pager"
  exit 1
fi

# 2. nginx must be a managed service, not something left running by hand.
if ! systemctl is-active --quiet nginx; then
  echo "nginx is not active, so whatever answered on port 80 is not the proxy."
  exit 1
fi
if ! systemctl is-enabled --quiet nginx 2>/dev/null; then
  echo "nginx is running but not enabled, so it will not come back after a reboot."
  echo "Fix it with: systemctl enable nginx"
  exit 1
fi

# 3. The container must NOT be published to the world. This is the point of the step.
if ss -tlnH 'sport = :8080' | awk '{print $4}' | grep -qE '^(0\.0\.0\.0|\*|\[::\]):8080$'; then
  echo "Port 8080 is bound to all addresses, so the container is still directly reachable."
  echo "Republish it on loopback only:"
  echo "  su - appops -c 'podman rm -f app'"
  echo "  su - appops -c 'podman run -d --name app --memory=64m -p 127.0.0.1:8080:80 docker.io/library/nginx:alpine'"
  exit 1
fi

EXT8080=$(curl -s --max-time 4 -o /dev/null -w '%{http_code}' "http://${IP}:8080/" || true)
if [ "$EXT8080" = "200" ]; then
  echo "The container answered directly on ${IP}:8080, so it is still exposed."
  echo "It should be reachable only through the proxy on port 80."
  exit 1
fi

# 4. And it must still work through loopback, or the proxy has nothing behind it.
LOCAL=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/ || true)
if [ "$LOCAL" != "200" ]; then
  echo "The container does not answer on 127.0.0.1:8080 (got '${LOCAL}')."
  echo "The proxy is forwarding there, so it needs to be listening."
  exit 1
fi

# 5. Still rootless.
PID=$(as_appops "podman inspect --format '{{.State.Pid}}' app" || true)
RUNAS=$(ps -o user= -p "$PID" 2>/dev/null | tr -d ' ')
if [ "$RUNAS" = "root" ]; then
  echo "The container's host process is running as root. It should still be rootless."
  exit 1
fi

echo "Port 80 serves through nginx from outside, the container is on loopback only, and it is still running rootless as '${RUNAS}'."
exit 0
