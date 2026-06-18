#!/bin/bash
# Verify the Acme reference repo is assembled at /root/acme.
set -e

cd /root/acme 2>/dev/null || { echo "Repo not found at /root/acme. Re-run: bash /root/setup.sh"; exit 1; }

for f in ansible.cfg \
         inventories/dev/hosts.yml inventories/prod/hosts.yml \
         inventories/dev/group_vars/all/vars.yml \
         roles/webapp/tasks/main.yml roles/webapp/templates/webapp.conf.j2 \
         playbooks/site.yml playbooks/bootstrap.yml; do
  if [ ! -f "$f" ]; then
    echo "Missing expected file: $f"
    echo "Inspect the tree with: ls -R /root/acme"
    exit 1
  fi
done

echo "Project structure looks correct — ansible.cfg, inventories, role, and playbooks are all present."
