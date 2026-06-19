#!/bin/bash
set -e

ROLE=/root/lab/roles/webserver

if [ ! -d "$ROLE" ]; then
  echo "Role directory not found at $ROLE"
  echo "Run: cd /root/lab && ansible-galaxy role init roles/webserver"
  exit 1
fi

if [ ! -f "$ROLE/tasks/main.yml" ]; then
  echo "tasks/main.yml not found in the webserver role."
  echo "Create it at $ROLE/tasks/main.yml with the nginx tasks."
  exit 1
fi

if ! grep -q 'nginx' "$ROLE/tasks/main.yml"; then
  echo "tasks/main.yml does not contain nginx tasks."
  exit 1
fi

if [ ! -f "$ROLE/handlers/main.yml" ]; then
  echo "handlers/main.yml not found in the webserver role."
  echo "Create it at $ROLE/handlers/main.yml with the nginx reload handler."
  exit 1
fi

if [ ! -f /root/lab/site.yml ]; then
  echo "site.yml not found at /root/lab/site.yml"
  echo "Create it referencing the webserver role."
  exit 1
fi

if ! grep -q 'webserver' /root/lab/site.yml; then
  echo "site.yml does not reference the webserver role."
  exit 1
fi

echo "webserver role is correctly structured and referenced in site.yml."
exit 0
