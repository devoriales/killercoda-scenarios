#!/bin/bash
set -e

UNIT=analytics-collector.service

if ! systemctl is-active --quiet "$UNIT"; then
  STATE=$(systemctl is-active "$UNIT" 2>/dev/null || true)
  echo "$UNIT is '$STATE', expected 'active'."
  echo "Check why with: systemctl status $UNIT --no-pager"
  echo "A status=203/EXEC means the ExecStart path does not point at an executable file."
  exit 1
fi

if ! systemctl is-enabled --quiet "$UNIT"; then
  echo "$UNIT is running but not enabled, so it will not come back after a reboot."
  echo "Fix it with: systemctl enable $UNIT"
  exit 1
fi

# The fix must be a corrected path, not a unit rewritten to dodge the problem by
# running as root or pointing somewhere unrelated.
EXECSTART=$(systemctl show -p ExecStart --value "$UNIT" 2>/dev/null || true)
case "$EXECSTART" in
  *analytics-collector.sh*) ;;
  *)
    echo "ExecStart does not point at /usr/local/bin/analytics-collector.sh."
    echo "systemd currently has: $EXECSTART"
    echo "If you edited the file already, you still need: systemctl daemon-reload"
    exit 1
    ;;
esac

USERPROP=$(systemctl show -p User --value "$UNIT" 2>/dev/null || true)
if [ "$USERPROP" != "analytics" ]; then
  echo "The unit runs as '${USERPROP:-root}', expected analytics."
  echo "Running a collector as root is not the fix for a path error."
  exit 1
fi

# Prove it is genuinely running as the service account rather than merely claiming to.
MAINPID=$(systemctl show -p MainPID --value "$UNIT")
if [ -z "$MAINPID" ] || [ "$MAINPID" = "0" ]; then
  echo "$UNIT reports no main PID, so nothing is actually running."
  exit 1
fi

RUNAS=$(ps -o user= -p "$MAINPID" 2>/dev/null | tr -d ' ')
if [ "$RUNAS" != "analytics" ]; then
  echo "The collector process is running as '$RUNAS', expected analytics."
  exit 1
fi

echo "analytics-collector is active, enabled, and running as the analytics account (PID $MAINPID)."
exit 0
