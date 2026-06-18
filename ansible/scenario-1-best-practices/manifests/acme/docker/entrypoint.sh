#!/bin/bash
# Install every mounted PUBLIC key (.ssh/*.pub -> /keys) into the ansible user's
# authorized_keys, then run sshd in the foreground. Private keys never enter the node.
set -e

install -d -m 0700 -o ansible -g ansible /home/ansible/.ssh

if compgen -G "/keys/*.pub" > /dev/null 2>&1; then
  cat /keys/*.pub > /home/ansible/.ssh/authorized_keys
  chown ansible:ansible /home/ansible/.ssh/authorized_keys
  chmod 0600 /home/ansible/.ssh/authorized_keys
fi

# Generate host keys on first boot if missing.
ssh-keygen -A

exec /usr/sbin/sshd -D -e
