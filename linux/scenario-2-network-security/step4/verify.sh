#!/bin/bash
set -e

SCRIPT=/usr/local/bin/metrics-healthcheck

if [ ! -x "$SCRIPT" ]; then
  echo "$SCRIPT is missing or not executable."
  echo "Create it, then: chmod 755 $SCRIPT"
  exit 1
fi

if ! systemctl is-active --quiet analytics-metrics.service; then
  echo "analytics-metrics.service is not running, so the health check cannot pass."
  echo "Start it with: systemctl start analytics-metrics.service"
  exit 1
fi

# The script must actually work, not merely exist.
if ! "$SCRIPT" >/tmp/hc.out 2>&1; then
  echo "$SCRIPT exited non-zero against a healthy endpoint:"
  sed 's/^/  /' /tmp/hc.out
  exit 1
fi

# ... and it must report failure too, or it is worthless as a check. Prove it by
# pointing it at a port nothing is listening on, rather than by stopping the service.
if ENDPOINT="http://127.0.0.1:9/" TIMEOUT=2 "$SCRIPT" >/dev/null 2>&1; then
  echo "$SCRIPT exited 0 against an endpoint that cannot possibly answer."
  echo "A check that always passes is worse than no check at all."
  echo "It should exit non-zero when the endpoint does not return 200."
  exit 1
fi

if ! systemctl is-enabled --quiet metrics-healthcheck.timer 2>/dev/null; then
  echo "metrics-healthcheck.timer is not enabled, so it will not survive a reboot."
  echo "Enable it with: systemctl enable --now metrics-healthcheck.timer"
  exit 1
fi

if ! systemctl is-active --quiet metrics-healthcheck.timer; then
  echo "metrics-healthcheck.timer is not active."
  echo "Start it with: systemctl start metrics-healthcheck.timer"
  exit 1
fi

if ! systemctl list-timers metrics-healthcheck --no-pager 2>/dev/null | grep -q metrics-healthcheck; then
  echo "The timer is enabled but systemd is not scheduling it."
  echo "Check the [Timer] section, then: systemctl daemon-reload"
  exit 1
fi

FAILED=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | tr '\n' ' ' | sed 's/ $//')
if [ -n "$FAILED" ]; then
  echo "These units are still in a failed state: $FAILED"
  echo "The deliberate failure in this step needs clearing:"
  echo "  systemctl reset-failed metrics-healthcheck.service"
  exit 1
fi

echo "Health check works in both directions, the timer is enabled and scheduled, and nothing is left failed."
exit 0
