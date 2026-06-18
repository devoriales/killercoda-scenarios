#!/bin/bash
# Verify the playbook passes syntax-check and ansible-lint is clean.
set -e

cd /root/acme 2>/dev/null || { echo "Repo not found at /root/acme."; exit 1; }

if ! ansible-playbook playbooks/site.yml --syntax-check >/tmp/syntax.out 2>&1; then
  echo "Syntax check failed:"
  cat /tmp/syntax.out
  exit 1
fi

if ! ansible-lint >/tmp/lint.out 2>&1; then
  echo "ansible-lint reported issues:"
  cat /tmp/lint.out
  echo "Run 'ansible-lint' to see details."
  exit 1
fi

echo "Lint is clean and the playbook passes --syntax-check. Lab complete!"
