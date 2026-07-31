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

# Root itself must be Healthy, because it is the thing that discovers everything else.
ROOTH=$(kubectl get application platform-root -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
if [ "$ROOTH" != "Healthy" ]; then
  echo "platform-root reports ${ROOTH:-unknown} rather than Healthy, so the tree is not established yet."
  exit 1
fi

# The children must be Synced, which proves root delivered them and the project accepted
# them. Their health is deliberately NOT required: on a busy single node the pods can take
# a while to start, and that is a property of the VM rather than of the bootstrap.
NOTSYNCED=""
for APP in platform-web-dev platform-web-staging; do
  S=$(kubectl get application "$APP" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
  [ "$S" = "Synced" ] || NOTSYNCED="$NOTSYNCED $APP($S)"
done
if [ -n "$NOTSYNCED" ]; then
  echo "These children are not Synced yet:$NOTSYNCED"
  echo "Root creates them in wave 0, just after the project. Give it a reconciliation."
  exit 1
fi

echo "Bootstrapped from one file: platform-root is Healthy, and it produced the platform project, two Applications and two namespaces."
echo "If the child workloads are still Progressing, that is this VM starting pods, not the bootstrap."
exit 0
