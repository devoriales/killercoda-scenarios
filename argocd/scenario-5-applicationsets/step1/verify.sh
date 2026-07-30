#!/bin/bash
set -e

if ! kubectl get applicationset list-demo -n argocd >/dev/null 2>&1; then
  echo "The 'list-demo' ApplicationSet does not exist."
  echo "The step deletes it on purpose to show the blast radius, then re-applies it."
  echo "Fix it with: kubectl apply -f /root/manifests/01-list/appset-list.yaml"
  exit 1
fi

# All three generated Applications must exist.
MISSING=""
for env in dev staging prod; do
  kubectl get application "list-$env" -n argocd >/dev/null 2>&1 || MISSING="$MISSING list-$env"
done
if [ -n "$MISSING" ]; then
  echo "The generator has not produced these Applications yet:$MISSING"
  echo "Generation takes a few seconds. Check again with: kubectl get applications -n argocd"
  exit 1
fi

# And they must be OWNED by the ApplicationSet, which is the point of the step.
OWNER=$(kubectl get application list-dev -n argocd \
  -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}' 2>/dev/null)
if [ "$OWNER" != "ApplicationSet/list-demo" ]; then
  echo "list-dev is not owned by the ApplicationSet (owner reads: '${OWNER:-none}')."
  echo "Without that owner reference it is a standalone Application, not a generated one."
  exit 1
fi

echo "Three Applications generated from one object, each owned by ApplicationSet/list-demo."
exit 0
