#!/bin/bash
set -e

# The metrics endpoint must be reachable, which is what the step is really about.
if ! curl -s --max-time 5 localhost:8082/metrics >/dev/null 2>&1; then
  echo "Nothing is answering on localhost:8082, so the port-forward is not running."
  echo "Start it with:"
  echo "  kubectl port-forward -n argocd svc/argocd-metrics 8082:8082 > /dev/null 2>&1 &"
  exit 1
fi

if ! curl -s --max-time 5 localhost:8082/metrics | grep -q '^argocd_app_info'; then
  echo "The endpoint responds but exposes no argocd_app_info, which means it is not the"
  echo "application controller's metrics Service. Use argocd-metrics on 8082, not argocd-server-metrics."
  exit 1
fi

if ! curl -s --max-time 5 localhost:8082/metrics | grep -q '^workqueue_depth{controller="app_reconciliation_queue"'; then
  echo "workqueue_depth for app_reconciliation_queue is missing from the endpoint."
  echo "Check you are scraping argocd-metrics on port 8082."
  exit 1
fi

if ! kubectl get application owner-a -n argocd >/dev/null 2>&1; then
  echo "The owner-a Application is gone, so there is nothing to observe. It is created in step 1."
  exit 1
fi

# End state: the drift has been corrected by syncing, not by another kubectl scale.
REPLICAS=$(kubectl get deploy web-dev -n contested -o jsonpath='{.spec.replicas}' 2>/dev/null)
SYNC=$(kubectl get application owner-a -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)

if [ "$SYNC" = "OutOfSync" ]; then
  echo "owner-a is still OutOfSync with ${REPLICAS:-?} replicas live, so the drift you created is still there."
  echo "That is the state the alert fires on. Hand control back to Git to finish:"
  echo "  argocd app sync owner-a"
  exit 1
fi

if [ "$REPLICAS" != "1" ]; then
  echo "owner-a reports $SYNC but the Deployment has ${REPLICAS:-?} replicas, which does not match Git."
  echo "Sync it: argocd app sync owner-a"
  exit 1
fi

echo "Metrics endpoint read, drift observed through argocd_app_info, and Git is back in charge at 1 replica."
exit 0
