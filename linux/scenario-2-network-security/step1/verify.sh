#!/bin/bash
set -e

UNIT=analytics-metrics.service

if ! systemctl is-active --quiet "$UNIT"; then
  echo "$UNIT is $(systemctl is-active "$UNIT"), expected active."
  echo "Start it with: systemctl start $UNIT"
  exit 1
fi

# The outcome that matters: reachable on the host's real address, not just loopback.
IP=$(hostname -I | awk '{print $1}')
if [ -z "$IP" ]; then
  echo "Could not determine this host's external address."
  exit 1
fi

CODE=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' "http://${IP}:9095/" || true)
if [ "$CODE" != "200" ]; then
  echo "http://${IP}:9095/ returned '${CODE}', expected 200."
  echo "Check the bind address with: ss -tlnp 'sport = :9095'"
  echo "A listener on 127.0.0.1 only accepts connections over loopback."
  exit 1
fi

# And confirm the fix was the bind address rather than something incidental.
if ss -tlnH 'sport = :9095' | awk '{print $4}' | grep -q '^127\.0\.0\.1:'; then
  echo "Port 9095 is still bound to 127.0.0.1 only."
  echo "Fix ExecStart in /etc/systemd/system/${UNIT}, then run:"
  echo "  systemctl daemon-reload && systemctl restart $UNIT"
  exit 1
fi

# Loopback must keep working too; binding to the external address alone would break
# anything on the host that talks to 127.0.0.1.
LOCAL=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:9095/ || true)
if [ "$LOCAL" != "200" ]; then
  echo "The endpoint answers on ${IP} but no longer on 127.0.0.1 (got '${LOCAL}')."
  echo "Bind to 0.0.0.0 rather than to one specific address."
  exit 1
fi

echo "Reachable on ${IP}:9095 and on 127.0.0.1:9095. The bind address was the cause."
exit 0
