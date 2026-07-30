#!/bin/bash
set -e

if ! kubectl get appproject windowed -n argocd >/dev/null 2>&1; then
  echo "The 'windowed' AppProject does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/04-windows/windowed-project.yaml"
  exit 1
fi

if ! kubectl get application windowed-app -n argocd >/dev/null 2>&1; then
  echo "The 'windowed-app' Application does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/04-windows/windowed-application.yaml"
  exit 1
fi

# There must be a deny window on the project, which is what the whole step rests on.
KIND=$(kubectl get appproject windowed -n argocd -o jsonpath='{.spec.syncWindows[0].kind}' 2>/dev/null)
if [ "$KIND" != "deny" ]; then
  echo "Expected a deny sync window on the project, found: '${KIND:-none}'."
  echo "Re-apply: kubectl apply -f /root/manifests/04-windows/windowed-project.yaml"
  exit 1
fi

# The point of the step: manualSync flipped to true, which is the state that lets a
# human ship a fix while automation stays blocked.
MANUAL=$(kubectl get appproject windowed -n argocd -o jsonpath='{.spec.syncWindows[0].manualSync}' 2>/dev/null)
if [ "$MANUAL" != "true" ]; then
  echo "manualSync is still ${MANUAL:-false}, so the window blocks humans as well as automation."
  echo "Flip it with:"
  echo "  kubectl patch appproject windowed -n argocd --type=json -p='[{\"op\":\"replace\",\"path\":\"/spec/syncWindows/0/manualSync\",\"value\":true}]'"
  exit 1
fi

echo "A deny window is active on the project, with manualSync enabled so on-call can still sync by hand."
exit 0
