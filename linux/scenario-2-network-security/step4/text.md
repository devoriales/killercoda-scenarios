# Step 4 — Schedule a check that reports its own failure

The load balancer found the step 1 fault before you did. That is the actual failure here: nothing on the host was watching.

## The script

A scheduled check does not need to send mail or write its own log. It needs to **exit 0 when healthy and non-zero when not**, and print something useful. Everything above it is built to consume exactly that.

```bash
cat > /usr/local/bin/metrics-healthcheck <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="${ENDPOINT:-http://127.0.0.1:9095/}"
TIMEOUT="${TIMEOUT:-5}"
UNIT="analytics-metrics.service"

fail() { echo "UNHEALTHY: $*" >&2; exit 1; }

# Check the unit first. If systemd already knows it is down, that is the more
# useful fact than a connection error.
systemctl is-active --quiet "$UNIT" || fail "$UNIT is $(systemctl is-active "$UNIT")"

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" "$ENDPOINT" || true)

case "$code" in
    200) ;;
    000) fail "no response from $ENDPOINT within ${TIMEOUT}s" ;;
    *)   fail "$ENDPOINT returned HTTP $code" ;;
esac

echo "HEALTHY: $ENDPOINT returned $code"
EOF
chmod 755 /usr/local/bin/metrics-healthcheck
```{{copy}}

Three details worth copying. `set -euo pipefail` catches the failures Bash otherwise swallows. `${ENDPOINT:-default}` supplies a fallback so `set -u` does not reject an unset variable. And `|| true` on the `curl` is deliberate: under `set -e` a non-zero curl would abort before the `case` could produce a useful message, so the failure is *handled* two lines later rather than suppressed.

```bash
/usr/local/bin/metrics-healthcheck; echo "exit=$?"
```{{exec}}

## Give it a schedule

Two files. The service says what to run:

```bash
cat > /etc/systemd/system/metrics-healthcheck.service <<'EOF'
[Unit]
Description=Metrics endpoint health check
After=analytics-metrics.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/metrics-healthcheck
EOF
```{{copy}}

The timer says when:

```bash
cat > /etc/systemd/system/metrics-healthcheck.timer <<'EOF'
[Unit]
Description=Run the metrics health check every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
RandomizedDelaySec=10
Persistent=true

[Install]
WantedBy=timers.target
EOF
```{{copy}}

```bash
systemctl daemon-reload && systemctl enable --now metrics-healthcheck.timer
```{{exec}}

```bash
systemctl list-timers metrics-healthcheck --no-pager
```{{exec}}

`NEXT`, `LEFT`, `LAST` and `PASSED` in one line. Getting that from a crontab means reading a schedule expression and doing arithmetic.

## Prove it reports failure

This is the part cron cannot do.

```bash
systemctl stop analytics-metrics.service
```{{exec}}

```bash
systemctl start metrics-healthcheck.service; echo "exit=$?"
```{{exec}}

```bash
systemctl is-failed metrics-healthcheck.service
```{{exec}}

```bash
journalctl -u metrics-healthcheck.service -n 5 --no-pager
```{{exec}}

The unit is marked `failed`, the exit status is in the journal, and **`systemctl --failed` now lists it**, so one command finds every broken scheduled job on the machine. A cron job failing nightly for eight months looks exactly like one that works.

Put the service back:

```bash
systemctl start analytics-metrics.service
systemctl reset-failed metrics-healthcheck.service
systemctl start metrics-healthcheck.service
```{{exec}}

## Your task

Have:

- `/usr/local/bin/metrics-healthcheck` executable, exiting 0 while the endpoint is healthy
- `metrics-healthcheck.timer` enabled and active
- `analytics-metrics.service` running again
- no units left in a failed state

<details><summary>Hint</summary>

If `systemctl --failed` still lists the health check from the deliberate failure above, clear it:

```
systemctl reset-failed metrics-healthcheck.service
```

</details>

When the timer is running and nothing is failed, click **Check**.
