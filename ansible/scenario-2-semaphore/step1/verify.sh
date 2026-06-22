#!/bin/bash
set -e

if ! docker ps --filter name=lab_semaphore --filter status=running --format '{{.Names}}' | grep -q lab_semaphore; then
  echo "Semaphore container is not running. Wait a moment, or check it with:"
  echo "  docker ps -a --filter name=lab_semaphore"
  exit 1
fi

if [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/ 2>/dev/null)" != "200" ]; then
  echo "Semaphore is not answering on port 3000 yet. Give it a few seconds, then:"
  echo "  curl -s -o /dev/null -w '%{http_code}\\n' http://127.0.0.1:3000/"
  exit 1
fi

echo "✅ Semaphore is up. Open it via Traffic/Ports on port 3000 and log in as admin / ChangeMe123."
exit 0
