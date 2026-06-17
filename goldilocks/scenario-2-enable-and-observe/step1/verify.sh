#!/bin/bash
# Verify sample app is deployed (the background setup may still be finishing, so poll)
set -e

# Poll for up to 120s (24 x 5s) in case background.sh is still installing the stack.
for i in $(seq 1 24); do
  DEPS=$(kubectl get deployments -n metrics-app --no-headers 2>/dev/null | wc -l | tr -d ' ')
  RUNNING=$(kubectl get pods -n metrics-app --no-headers 2>/dev/null | grep -c "Running" || true)

  if [ "$DEPS" -ge 2 ] && [ "$RUNNING" -ge 2 ]; then
    echo "Sample app ready: $DEPS deployments, $RUNNING pods Running."
    exit 0
  fi
  sleep 5
done

echo "FAIL: Sample app not ready (found $DEPS deployments, $RUNNING Running pods in metrics-app)."
echo "The background setup can take a few minutes. Wait for Step 1's readiness check to print 'Ready!', then try again."
exit 1
