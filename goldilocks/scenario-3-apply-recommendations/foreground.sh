#!/bin/bash
# Scenario 3 foreground.sh — readiness gate.
#
# Killercoda runs this automatically in the student's terminal and blocks Step 1 until
# it finishes. It waits for the background install to bring up the full stack, label the
# namespace, and produce VPA recommendations, and self-heals by re-running the idempotent
# /root/setup.sh if the background run aborted or is missing pieces. The student never has
# to copy/paste a wait loop.
set -uo pipefail

TIMEOUT=480   # hard ceiling — VPA needs a few minutes of metrics before it recommends
GRACE=120     # how long to wait before attempting a self-heal re-run
ELAPSED=0

rec_cpu() {
  kubectl get vpa "$1" -n metrics-app \
    -o jsonpath='{.status.recommendation.containerRecommendations[0].target.cpu}' 2>/dev/null
}

# Stack installed and namespace labeled — the part a re-run of setup.sh can fix.
installed() {
  kubectl get deploy frontend -n metrics-app >/dev/null 2>&1 \
    && [ "$(kubectl get ns metrics-app -o jsonpath='{.metadata.labels.goldilocks\.fairwinds\.com/enabled}' 2>/dev/null)" = "true" ]
}

ready() {
  kubectl get deploy frontend api -n metrics-app >/dev/null 2>&1 || return 1
  [ "$(kubectl get pods -n metrics-app --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)" -ge 2 ] || return 1
  kubectl get pods -n goldilocks --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -q . || return 1
  kubectl get pods -n vpa --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -q . || return 1
  [ -n "$(rec_cpu goldilocks-frontend)" ] || return 1
  [ -n "$(rec_cpu goldilocks-api)" ] || return 1
  return 0
}

echo "Preparing the lab environment and waiting for VPA recommendations (a few minutes)..."

# Wait for background.sh to write the installer before we consider self-healing.
while [ ! -f /root/setup.sh ] && [ "$ELAPSED" -lt 60 ]; do
  sleep 2; ELAPSED=$((ELAPSED + 2))
done

while ! ready; do
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "Environment not fully ready after ${TIMEOUT}s."
    echo "Inspect with: kubectl get pods -A   and   kubectl get vpa -n metrics-app"
    break
  fi
  # Self-heal: past the grace period without the stack installed and namespace labeled
  # means the background run likely aborted — re-run the idempotent installer. Once
  # installed, we just keep waiting; recommendations only need time, not a re-run.
  if [ "$ELAPSED" -ge "$GRACE" ] && ! installed; then
    echo "Setup looks incomplete — reconciling..."
    [ -f /root/setup.sh ] && bash /root/setup.sh
  fi
  echo "Waiting for VPA recommendations... (${ELAPSED}s)"
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

if ready; then
  echo "Recommendations ready!"
fi
