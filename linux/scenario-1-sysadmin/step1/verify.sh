#!/bin/bash
set -e

LOG=/srv/analytics/logs/collector.log
REL=/srv/analytics/releases

if [ ! -e "$LOG" ]; then
  echo "$LOG is missing."
  echo "Recreate it with: touch $LOG && chown analytics:analytics $LOG && chmod 640 $LOG"
  exit 1
fi

MODE=$(stat -c %a "$LOG")
if [ "$MODE" != "640" ]; then
  echo "$LOG is mode $MODE, expected 640."
  echo "Fix it with: chmod 640 $LOG"
  exit 1
fi

OWNER=$(stat -c "%U:%G" "$LOG")
if [ "$OWNER" != "analytics:analytics" ]; then
  echo "$LOG is owned by $OWNER, expected analytics:analytics."
  echo "Fix it with: chown analytics:analytics $LOG"
  exit 1
fi

if [ ! -d "$REL" ]; then
  echo "$REL is missing or is not a directory."
  exit 1
fi

RMODE=$(stat -c %a "$REL")
# stat prints 2775 for a setgid directory. Accept any group-writable setgid mode so a
# student who chose 2770 is not failed for being stricter than the task asked.
case "$RMODE" in
  2775|2770) ;;
  *)
    echo "$REL is mode $RMODE, expected the setgid bit to be set (2775)."
    echo "Fix it with: chmod 2775 $REL"
    exit 1
    ;;
esac

RGROUP=$(stat -c %G "$REL")
if [ "$RGROUP" != "deployers" ]; then
  echo "$REL belongs to group $RGROUP, expected deployers."
  echo "Fix it with: chgrp deployers $REL"
  exit 1
fi

# Prove setgid actually works rather than trusting the mode digits: create a file as
# rjimenez and check which group it lands in.
PROBE="$REL/.verify-probe-$$"
runuser -u rjimenez -- touch "$PROBE" 2>/dev/null || {
  echo "rjimenez could not create a file in $REL. Is it still group writable?"
  exit 1
}
PGROUP=$(stat -c %G "$PROBE")
rm -f "$PROBE"

if [ "$PGROUP" != "deployers" ]; then
  echo "A file created by rjimenez in $REL landed in group $PGROUP, not deployers."
  echo "The setgid bit is what makes new files inherit the directory's group."
  echo "Fix it with: chmod 2775 $REL"
  exit 1
fi

echo "Log is 640 and still owned by analytics, and new files in releases now inherit the deployers group."
exit 0
