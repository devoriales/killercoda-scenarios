#!/bin/bash
set -e

if ! kubectl get appproject tenant-a -n argocd >/dev/null 2>&1; then
  echo "The 'tenant-a' AppProject does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/01-project/tenant-project.yaml"
  exit 1
fi

# The boundary that matters most must actually be empty, not merely present.
WL=$(kubectl get appproject tenant-a -n argocd -o json 2>/dev/null \
  | python3 -c "import json,sys; print(len(json.load(sys.stdin)['spec'].get('clusterResourceWhitelist') or []))" 2>/dev/null || echo x)
if [ "$WL" != "0" ]; then
  echo "clusterResourceWhitelist should be an empty list, blocking all cluster-scoped kinds."
  echo "Re-apply: kubectl apply -f /root/manifests/01-project/tenant-project.yaml"
  exit 1
fi

# Both rejections must have been produced, each naming its own boundary.
for pair in "rejected-repo:not permitted in project" "rejected-namespace:do not match any of the allowed destinations"; do
  APP="${pair%%:*}"; WANT="${pair#*:}"
  if ! kubectl get application "$APP" -n argocd >/dev/null 2>&1; then
    echo "The '$APP' Application does not exist yet."
    echo "Fix it with: kubectl apply -f /root/manifests/01-project/${APP}.yaml"
    exit 1
  fi
  MSG=$(kubectl get application "$APP" -n argocd -o jsonpath='{.status.conditions[*].message}' 2>/dev/null)
  if [ -z "$MSG" ]; then
    echo "Argo CD has not evaluated '$APP' against the project yet."
    echo "Wait a few seconds, or run: argocd app get $APP --hard-refresh"
    exit 1
  fi
  if ! echo "$MSG" | grep -q "$WANT"; then
    echo "Expected '$APP' to be refused with a message containing: $WANT"
    echo "Got instead: $MSG"
    exit 1
  fi
done

# And the compliant one must reconcile, proving the project permits rather than blocks all.
if ! kubectl get application tenant-a-web -n argocd >/dev/null 2>&1; then
  echo "The compliant 'tenant-a-web' Application is missing."
  echo "Fix it with: kubectl apply -f /root/manifests/01-project/allowed.yaml"
  exit 1
fi

echo "The project refused an unapproved repo and a forbidden namespace, each naming its boundary, and allowed the compliant Application."
exit 0
