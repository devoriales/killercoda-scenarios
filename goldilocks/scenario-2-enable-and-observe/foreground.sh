#!/bin/bash
# Scenario 2 foreground.sh — readiness gate.
#
# Killercoda runs this automatically in the student's terminal and blocks Step 1 until
# it finishes. It waits for the background install to bring up the full stack, and
# self-heals by re-running the idempotent /root/setup.sh if the background run aborted
# or is missing pieces. The student never has to copy/paste a wait loop.
set -uo pipefail

TIMEOUT=360   # hard ceiling before we stop waiting and print a diagnostic
GRACE=90      # how long to wait before attempting a self-heal re-run
ELAPSED=0

ready() {
  kubectl get deploy frontend api -n metrics-app >/dev/null 2>&1 || return 1
  [ "$(kubectl get pods -n metrics-app --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)" -ge 2 ] || return 1
  kubectl get pods -n goldilocks --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -q . || return 1
  kubectl get pods -n vpa --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -q . || return 1
  return 0
}

echo "Preparing the lab environment (this can take a few minutes)..."

# Wait for background.sh to write the installer before we consider self-healing.
while [ ! -f /root/setup.sh ] && [ "$ELAPSED" -lt 60 ]; do
  sleep 2; ELAPSED=$((ELAPSED + 2))
done

while ! ready; do
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "Environment not fully ready after ${TIMEOUT}s."
    echo "Inspect with: kubectl get pods -A"
    break
  fi
  # Self-heal: past the grace period with the sample app still missing means the
  # background run likely aborted — re-run the idempotent installer in the foreground.
  if [ "$ELAPSED" -ge "$GRACE" ] && ! kubectl get deploy frontend -n metrics-app >/dev/null 2>&1; then
    echo "Setup looks incomplete — reconciling..."
    [ -f /root/setup.sh ] && bash /root/setup.sh
  fi
  echo "Waiting for environment... (${ELAPSED}s)"
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

if ready; then
  echo "Ready!"
fi
