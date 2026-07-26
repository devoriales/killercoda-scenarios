#!/bin/bash
set -e

WORKDIR=/root/investigation
SCANNER="$WORKDIR/scanner.txt"
ENDPOINT="$WORKDIR/broken-endpoint.txt"

if [ ! -f "$SCANNER" ]; then
  echo "$SCANNER does not exist yet."
  echo "Find the address with: grep \" 404 \" $WORKDIR/access.log | awk '{ print \$1 }' | sort -u"
  exit 1
fi

if [ ! -f "$ENDPOINT" ]; then
  echo "$ENDPOINT does not exist yet."
  echo "Find the path with: awk '\$9 == 500 { print \$7 }' $WORKDIR/access.log | sort -u"
  exit 1
fi

FOUND_IP=$(tr -d '[:space:]' < "$SCANNER")
FOUND_PATH=$(tr -d '[:space:]' < "$ENDPOINT")

if [ "$FOUND_IP" != "203.0.113.42" ]; then
  echo "$SCANNER contains '$FOUND_IP', which is not the scanner."
  echo "Every 404 came from one address. Find it with:"
  echo "  grep \" 404 \" $WORKDIR/access.log | awk '{ print \$1 }' | sort | uniq -c | sort -rn"
  exit 1
fi

if [ "$FOUND_PATH" != "/api/checkout" ]; then
  echo "$ENDPOINT contains '$FOUND_PATH', which is not the failing endpoint."
  echo "Three different clients hit 500 on one path. Find it with:"
  echo "  awk '\$9 == 500 { print \$7 }' $WORKDIR/access.log | sort -u"
  exit 1
fi

echo "Both findings correct: 203.0.113.42 was scanning for credentials, and /api/checkout is failing for multiple clients."
exit 0
