#!/bin/bash
set -e

# The nginx vhost config must exist on both web servers
for port in 2201 2202; do
  if ! ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
       -i /root/.ssh/id_ed25519 -p "$port" ansible@localhost \
       "[ -f /etc/nginx/conf.d/app.conf ]" 2>/dev/null; then
    echo "/etc/nginx/conf.d/app.conf not found on the web server at port $port."
    echo "Run: cd /root/lab && ansible-playbook configure-nginx.yml"
    exit 1
  fi

  if ! ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
       -i /root/.ssh/id_ed25519 -p "$port" ansible@localhost \
       "grep -q 'listen' /etc/nginx/conf.d/app.conf" 2>/dev/null; then
    echo "/etc/nginx/conf.d/app.conf on port $port does not contain a 'listen' directive."
    exit 1
  fi
done

echo "nginx virtual host configuration is deployed on both web servers."
exit 0
