#!/bin/bash
# Verify at least one VPA has recommendations (PROVIDED=True)
set -e

# Wait up to 90 seconds for at least one recommendation
for i in $(seq 1 18); do
  PROVIDED=$(kubectl get vpa -n metrics-app --no-headers 2>/dev/null | grep -c "True" || echo 0)
  if [ "$PROVIDED" -ge 1 ]; then
    echo "VPA recommendations available: $PROVIDED VPA(s) with PROVIDED=True"
    exit 0
  fi
  sleep 5
done

echo "FAIL: No VPA recommendations appeared within 90 seconds. Check that metrics-server is running: kubectl get pods -n kube-system | grep metrics-server"
exit 1
