#!/bin/bash
set -e

found=0
for n in lab_web1 lab_web2 lab_db1; do
  if docker exec "$n" cat /etc/acme-release 2>/dev/null | grep -q "configured by Semaphore"; then
    found=1
  fi
done

if [ "$found" -ne 1 ]; then
  echo "The /etc/acme-release marker isn't on the nodes yet."
  echo "Run the 'Configure web app' template in Semaphore (Step 5), then check with:"
  echo "  docker exec lab_web1 cat /etc/acme-release"
  exit 1
fi

echo "✅ Verified on the node — Semaphore really did configure your servers."
exit 0
