#!/bin/bash
set -e

# This step's check is the capstone's own instrument. If it passes, the host meets
# every requirement, so there is nothing further to assert here.
if [ ! -x /usr/local/bin/gateway-validate ]; then
  echo "/usr/local/bin/gateway-validate is missing, which should not happen."
  exit 1
fi

if /usr/local/bin/gateway-validate >/tmp/validate.out 2>&1; then
  tail -3 /tmp/validate.out
  echo
  echo "Every requirement verified against the running system. The gateway is complete."
  exit 0
fi

echo "gateway-validate still reports failures:"
echo
grep -E 'FAIL' /tmp/validate.out | sed 's/\x1b\[[0-9;]*m//g' | head -12
echo
tail -3 /tmp/validate.out | sed 's/\x1b\[[0-9;]*m//g'
echo
echo "Run it yourself for the full output and the suggested fix for each line:"
echo "  gateway-validate"
exit 1
