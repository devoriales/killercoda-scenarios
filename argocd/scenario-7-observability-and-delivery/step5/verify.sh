#!/bin/bash
set -e

if ! kubectl get application platform-root -n argocd >/dev/null 2>&1; then
  echo "The platform-root Application does not exist."
  echo "Apply the one file with:"
  echo "  kubectl apply -f /root/manifests/05-bootstrap/root-application.yaml"
  exit 1
fi

if ! kubectl get appproject platform -n argocd >/dev/null 2>&1; then
  echo "Root exists but the platform AppProject has not appeared yet."
  echo "It is in sync wave -1 and takes a few seconds. Check root with:"
  echo "  kubectl get application platform-root -n argocd -o jsonpath='{.status.sync.status}'"
  exit 1
fi

for APP in platform-web-dev platform-web-staging; do
  if ! kubectl get application "$APP" -n argocd >/dev/null 2>&1; then
    echo "$APP was not created by root."
    echo "If you deleted it, root recreates it within a reconciliation. Give it 40 seconds."
    echo "If it never returns, check root: kubectl get application platform-root -n argocd"
    exit 1
  fi
done

# Both children must have actually deployed, which proves the project permitted the Namespace.
for NS in platform-dev platform-staging; do
  if ! kubectl get ns "$NS" >/dev/null 2>&1; then
    echo "Namespace $NS does not exist, so a child Application has not synced."
    echo "Look one level deeper than status.conditions, which stays empty for project denials:"
    echo "  kubectl get application platform-web-${NS#platform-} -n argocd -o jsonpath='{range .status.operationState.syncResult.resources[*]}{.kind}/{.name} status={.status} msg={.message}{\"\\n\"}{end}'"
    exit 1
  fi
done

UNHEALTHY=""
for APP in platform-root platform-web-dev platform-web-staging; do
  H=$(kubectl get application "$APP" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
  [ "$H" = "Healthy" ] || UNHEALTHY="$UNHEALTHY $APP($H)"
done
if [ -n "$UNHEALTHY" ]; then
  echo "Not everything is Healthy yet:$UNHEALTHY"
  echo "Give the tree a reconciliation, then check again."
  exit 1
fi

echo "Bootstrapped from one file: the platform project, two Applications and two namespaces all exist and are Healthy, and root recreated a deleted child."
exit 0
