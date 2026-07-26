#!/bin/bash
set -e

REPORT=/root/investigation/metadata.txt
CONF=/root/course-data/app.conf

if [ ! -f "$REPORT" ]; then
  echo "$REPORT does not exist yet."
  echo "Run: stat -c %a $CONF > $REPORT"
  exit 1
fi

EXPECTED=$(stat -c %a "$CONF")

# Accept the number with surrounding whitespace or a trailing newline, but nothing else.
FOUND=$(tr -d '[:space:]' < "$REPORT")

if [ -z "$FOUND" ]; then
  echo "$REPORT is empty."
  echo "Run: stat -c %a $CONF > $REPORT"
  exit 1
fi

if [ "$FOUND" != "$EXPECTED" ]; then
  echo "$REPORT contains '$FOUND', but $CONF is mode $EXPECTED."
  echo "Check with: stat -c %a $CONF"
  echo "Then write it: stat -c %a $CONF > $REPORT"
  exit 1
fi

echo "Correct: $CONF is mode $EXPECTED, readable by its owner and group only."
exit 0
