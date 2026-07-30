#!/bin/bash
set -e

if ! kubectl get application hooks -n argocd >/dev/null 2>&1; then
  echo "The 'hooks' Application does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/02-hooks/hooks-application.yaml"
  exit 1
fi

SYNC=$(kubectl get application hooks -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
if [ "$SYNC" != "Synced" ]; then
  echo "The Application is not Synced yet (currently: ${SYNC:-unknown})."
  echo "Fix it with: argocd app sync hooks"
  exit 1
fi

if ! kubectl get deploy hooks-app -n demo >/dev/null 2>&1; then
  echo "The hooks-app Deployment is missing, so the sync did not complete."
  echo "Fix it with: argocd app sync hooks"
  exit 1
fi

# The PreSync hook must have actually run. It is the one the step does not delete.
if ! kubectl get job hooks-presync -n demo >/dev/null 2>&1; then
  echo "The PreSync hook Job is missing. Re-run: argocd app sync hooks"
  exit 1
fi
if [ -z "$(kubectl get job hooks-presync -n demo -o jsonpath='{.status.completionTime}' 2>/dev/null)" ]; then
  echo "The PreSync hook has not completed yet. Wait a few seconds and check again."
  exit 1
fi

# The point of the step: Argo CD marks hooks as hooks, not as desired state.
IS_HOOK=$(kubectl get application hooks -n argocd -o json 2>/dev/null \
  | python3 -c "
import json,sys
rs=json.load(sys.stdin).get('status',{}).get('resources',[])
print('yes' if any(r.get('hook') and r.get('name')=='hooks-presync' for r in rs) else 'no')
" 2>/dev/null || echo unknown)

if [ "$IS_HOOK" != "yes" ]; then
  echo "Argo CD is not reporting hooks-presync as a hook in .status.resources."
  echo "Check the annotation: kubectl get job hooks-presync -n demo -o jsonpath='{.metadata.annotations}'"
  exit 1
fi

echo "PreSync and PostSync hooks ran, and Argo CD tracks hooks-presync as a hook rather than as desired state."
exit 0
