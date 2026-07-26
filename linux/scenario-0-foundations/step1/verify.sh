#!/bin/bash
set -e

WORKDIR=/root/investigation
LOG="$WORKDIR/access.log"
SOURCE=/root/course-data/access.log

if [ ! -d "$WORKDIR" ]; then
  echo "Directory $WORKDIR does not exist yet."
  echo "Run: mkdir /root/investigation"
  exit 1
fi

if [ ! -f "$LOG" ]; then
  echo "The access log has not been copied into $WORKDIR."
  echo "Run: cp /root/course-data/access.log /root/investigation/"
  exit 1
fi

# The original must survive: this is evidence, so it is copied and never moved.
if [ ! -f "$SOURCE" ]; then
  echo "The original at $SOURCE is missing, so the log was moved instead of copied."
  echo "Restore it with: cp $LOG $SOURCE"
  exit 1
fi

LINES=$(wc -l < "$LOG")
if [ "$LINES" -ne 45 ]; then
  echo "$LOG has $LINES lines, expected 45. It looks truncated or modified."
  echo "Copy it again with: cp $SOURCE $WORKDIR/"
  exit 1
fi

echo "Workspace ready: $WORKDIR contains all 45 log lines, and the original is intact."
exit 0
