# Step 4 — Proxy, health check, and proof

## The proxy

```bash
cat > /etc/nginx/sites-available/gateway <<'CONF'
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
CONF
ln -sf /etc/nginx/sites-available/gateway /etc/nginx/sites-enabled/gateway
rm -f /etc/nginx/sites-enabled/default
```{{copy}}

The four `proxy_set_header` lines are not decoration. Once a proxy is in front, the application sees every request arriving from `127.0.0.1`, so its logs, its rate limiting, and any IP-based rule see one client. The proxy has to pass the original values, and on a real deployment the application must be told to trust them **only** from the proxy, because any client can set `X-Forwarded-For` itself.

```bash
nginx -t && systemctl enable --now nginx
```{{exec}}

```bash
IP=$(hostname -I | awk '{print $1}'); curl -s -o /dev/null -w "via proxy -> HTTP %{http_code}\n" http://$IP/
```{{exec}}

## The health check

It follows the path a user takes, rather than testing components in isolation:

```bash
cat > /usr/local/bin/gateway-healthcheck <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="${ENDPOINT:-http://127.0.0.1/}"
TIMEOUT="${TIMEOUT:-10}"
APP_USER="${APP_USER:-appsvc}"
MOUNT="${MOUNT:-/srv/gateway}"

fail() { echo "UNHEALTHY: $*" >&2; exit 1; }

findmnt -n "$MOUNT" >/dev/null 2>&1 || fail "$MOUNT is not mounted"
systemctl is-active --quiet nginx || fail "nginx is $(systemctl is-active nginx)"

running=$(su - "$APP_USER" -s /bin/bash -c 'podman ps --format "{{.Names}}"' 2>/dev/null || true)
[ -n "$running" ] || fail "no container running for $APP_USER"

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" "$ENDPOINT" || true)
case "$code" in
    200) ;;
    000) fail "no response from $ENDPOINT within ${TIMEOUT}s" ;;
    *)   fail "$ENDPOINT returned HTTP $code" ;;
esac

echo "HEALTHY: $ENDPOINT returned $code, $MOUNT mounted, container '$running' running as $APP_USER"
EOF2
chmod 755 /usr/local/bin/gateway-healthcheck
```{{copy}}

Test it **in both directions**. A check that cannot fail is worse than no check, because it produces a week of green while requests are dropped:

```bash
/usr/local/bin/gateway-healthcheck; echo "exit=$?"
```{{exec}}

```bash
ENDPOINT="http://127.0.0.1:9/" TIMEOUT=3 /usr/local/bin/gateway-healthcheck; echo "exit=$?"
```{{exec}}

## The timer

```bash
cat > /etc/systemd/system/gateway-healthcheck.service <<'CONF'
[Unit]
Description=Gateway end to end health check
After=nginx.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gateway-healthcheck
CONF

cat > /etc/systemd/system/gateway-healthcheck.timer <<'CONF'
[Unit]
Description=Run the gateway health check every 2 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=2min
RandomizedDelaySec=20
Persistent=true

[Install]
WantedBy=timers.target
CONF

systemctl daemon-reload
systemctl enable --now gateway-healthcheck.timer
```{{copy}}

```bash
systemctl list-timers gateway-healthcheck --no-pager
```{{exec}}

## The proof

```bash
gateway-validate
```{{exec}}

Every section green, and a final line telling you so. If anything is red, the message says what to do about it.

If units are left in a failed state from earlier experiments, clear them once you have understood why:

```bash
systemctl --failed --no-pager; systemctl reset-failed
```{{exec}}

## Your task

Get `gateway-validate` to exit 0 with everything passing, then click **Check**.
