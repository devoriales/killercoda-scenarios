#!/bin/bash
set -e

if ! kubectl get application broken -n argocd >/dev/null 2>&1; then
  echo "The 'broken' Application does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/03-health/broken-application.yaml"
  exit 1
fi

SYNC=$(kubectl get application broken -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
HEALTH=$(kubectl get application broken -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)

if [ "$SYNC" != "Synced" ]; then
  echo "The Application is not Synced yet (currently: ${SYNC:-unknown})."
  echo "Fix it with: argocd app sync broken"
  exit 1
fi

if [ "$HEALTH" = "Progressing" ]; then
  echo "Synced already, but health is still Progressing."
  echo "The manifest sets progressDeadlineSeconds: 60, so give it a moment:"
  echo "  sleep 60 && kubectl get applications -n argocd"
  exit 1
fi

if [ "$HEALTH" != "Degraded" ]; then
  echo "Expected health to be Degraded, but it is: ${HEALTH:-unknown}"
  echo "Check the pod: kubectl get pods -n demo -l app=broken"
  exit 1
fi

# The whole point: Synced and Degraded together, on a pod that cannot pull its image.
if ! kubectl get pods -n demo -l app=broken -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null \
     | grep -qE "ImagePull|ErrImage"; then
  echo "The app is Degraded, but not for the expected image-pull reason."
  echo "Check: kubectl get pods -n demo -l app=broken"
  exit 1
fi

echo "Synced and Degraded at the same time. Argo CD did its job; the manifest is the problem."
exit 0
