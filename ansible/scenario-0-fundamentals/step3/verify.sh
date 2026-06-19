#!/bin/bash
set -e

# curl must be installed on both web servers
for port in 2201 2202; do
  if ! ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
       -i /root/.ssh/id_ed25519 -p "$port" ansible@localhost \
       "dpkg -l curl 2>/dev/null | grep -q '^ii'" 2>/dev/null; then
    echo "curl is not installed on the web server at port $port."
    echo "Run: cd /root/lab && ansible webservers -m package -a \"name=curl state=present\" --become"
    exit 1
  fi
done

echo "curl is installed on web1 and web2."
exit 0
