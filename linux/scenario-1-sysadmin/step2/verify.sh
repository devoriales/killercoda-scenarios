#!/bin/bash
set -e

LOG=/srv/analytics/logs/collector.log

if [ ! -e "$LOG" ]; then
  echo "$LOG is missing."
  exit 1
fi

# The outcome that actually matters: can he read it? Checked first, because a student
# who reached the goal another sensible way should pass.
if ! runuser -u tokafor -- test -r "$LOG"; then
  echo "tokafor still cannot read $LOG."
  echo "Grant it with: setfacl -m u:tokafor:r $LOG"
  echo "If you already did, check the mask: chmod 640 $LOG lifts it again."
  exit 1
fi

if ! runuser -u tokafor -- cat "$LOG" >/dev/null 2>&1; then
  echo "tokafor has the ACL entry but still cannot actually read $LOG."
  echo "Check the mask line in: getfacl $LOG"
  exit 1
fi

# ... but not by handing out something broader.
OWNER=$(stat -c "%U:%G" "$LOG")
if [ "$OWNER" != "analytics:analytics" ]; then
  echo "$LOG is owned by $OWNER, expected analytics:analytics."
  echo "Changing the owner is not the right way to grant one person access."
  echo "Fix it with: chown analytics:analytics $LOG"
  exit 1
fi

# `other` must still be closed. stat %a on a file with ACLs reports the mask in the
# group position, so read the other digit specifically.
MODE=$(stat -c %a "$LOG")
OTHER=${MODE: -1}
if [ "$OTHER" != "0" ]; then
  echo "$LOG is mode $MODE, so 'other' has access."
  echo "That publishes the log to every account on this machine."
  echo "Fix it with: chmod o-rwx $LOG"
  exit 1
fi

# And he must not have been quietly added to a group instead.
if id -nG tokafor | tr ' ' '\n' | grep -qx analytics; then
  echo "tokafor has been added to the analytics group."
  echo "That grants him everything the group owns, not one log file."
  echo "Undo it with: gpasswd -d tokafor analytics"
  echo "Then grant the file alone with: setfacl -m u:tokafor:r $LOG"
  exit 1
fi

if ! getfacl --absolute-names "$LOG" 2>/dev/null | grep -q "^user:tokafor:r"; then
  echo "No ACL entry for tokafor found on $LOG."
  echo "Add it with: setfacl -m u:tokafor:r $LOG"
  exit 1
fi

echo "tokafor can read the log through an ACL, the file is still owned by analytics, and other has no access."
exit 0
