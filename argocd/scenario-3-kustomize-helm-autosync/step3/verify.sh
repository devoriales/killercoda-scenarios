#!/bin/bash
set -e

if ! kubectl get application helm-demo -n argocd >/dev/null 2>&1; then
  echo "The 'helm-demo' Application does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/03-helm/helm-demo-application.yaml"
  exit 1
fi

SYNC=$(kubectl get application helm-demo -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
if [ "$SYNC" != "Synced" ]; then
  echo "'helm-demo' is not Synced yet (currently: ${SYNC:-unknown})."
  echo "Fix it with: argocd app sync helm-demo"
  exit 1
fi

REPLICAS=$(kubectl get deploy helm-demo -n demo -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")
if [ "$REPLICAS" != "2" ]; then
  echo "Expected the chart to render 2 replicas (valuesObject sets replicaCount: 2), found: ${REPLICAS:-none}"
  echo "Check: argocd app manifests helm-demo"
  exit 1
fi

# The point of the step: the workload runs, and Helm has no record of it.
if command -v helm >/dev/null 2>&1; then
  if helm list -n demo 2>/dev/null | grep -q helm-demo; then
    echo "A Helm release named helm-demo exists in the demo namespace."
    echo "Argo CD templates charts rather than installing releases, so there should be none."
    echo "Did you run 'helm install' by hand? Remove it with: helm uninstall helm-demo -n demo"
    exit 1
  fi
fi

TRACK=$(kubectl get deploy helm-demo -n demo \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' 2>/dev/null)
if [ -z "$TRACK" ]; then
  echo "The Deployment exists but Argo CD does not track it."
  echo "Re-run: argocd app sync helm-demo"
  exit 1
fi

echo "The chart is deployed with $REPLICAS replicas, Helm has no release for it, and Argo CD owns it: $TRACK"
exit 0
