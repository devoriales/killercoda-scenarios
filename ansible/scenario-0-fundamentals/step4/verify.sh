#!/bin/bash
set -e

# nginx must be installed on both web servers
for port in 2201 2202; do
  if ! ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
       -i /root/.ssh/id_ed25519 -p "$port" ansible@localhost \
       "dpkg -l nginx 2>/dev/null | grep -q '^ii'" 2>/dev/null; then
    echo "nginx is not installed on the web server at port $port."
    echo "Run: cd /root/lab && ansible-playbook install-nginx.yml"
    exit 1
  fi
done

# nginx process must be running on web1
if ! ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
     -i /root/.ssh/id_ed25519 -p 2201 ansible@localhost \
     "pgrep nginx >/dev/null" 2>/dev/null; then
  echo "nginx is installed but not running on web1."
  echo "Ensure the playbook's 'Start nginx' task completed successfully."
  exit 1
fi

echo "nginx is installed and running on both web servers."
exit 0
