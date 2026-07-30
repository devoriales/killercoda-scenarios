#!/bin/bash
set -e

if ! kubectl get application waves -n argocd >/dev/null 2>&1; then
  echo "The 'waves' Application does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/01-waves/waves-application.yaml"
  exit 1
fi

SYNC=$(kubectl get application waves -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
if [ "$SYNC" = "Unknown" ]; then
  echo "Sync status is Unknown, so the controller could not compare against Git yet."
  echo "Fix it with: argocd app get waves --hard-refresh"
  exit 1
fi
if [ "$SYNC" != "Synced" ]; then
  echo "The Application is not Synced yet (currently: ${SYNC:-unknown})."
  echo "Fix it with: argocd app sync waves"
  exit 1
fi

# Every wave must have produced its resource. If a wave had blocked, the later
# ones would simply be absent, so this is the real test that the gates all opened.
for r in job/waves-migrate deploy/waves-app job/waves-smoketest; do
  if ! kubectl get "$r" -n demo >/dev/null 2>&1; then
    echo "Missing $r in the demo namespace, so not every wave completed."
    echo "Find the wave that is stuck with: kubectl get jobs -n demo"
    exit 1
  fi
done

# The migration must have actually finished, not merely been created.
if [ -z "$(kubectl get job waves-migrate -n demo -o jsonpath='{.status.completionTime}' 2>/dev/null)" ]; then
  echo "The migration Job has not completed yet. Wait a few seconds and check again."
  exit 1
fi

# And the ordering must be declared, which is what made the gate exist at all.
# Checked by annotation rather than by comparing timestamps: a fast migration can
# complete in the same second the Deployment is created, and re-syncing does not
# recreate unchanged resources, so a timestamp comparison gives false failures.
W=$(kubectl get deploy waves-app -n demo \
      -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}' 2>/dev/null)
if [ "$W" != "1" ]; then
  echo "The waves-app Deployment is not in sync-wave 1 (found: '${W:-none}')."
  echo "Without the annotation there is no gate, and it would deploy alongside the migration."
  exit 1
fi

echo "All three waves completed in order, the migration finished, and waves-app is gated in wave $W."
exit 0
