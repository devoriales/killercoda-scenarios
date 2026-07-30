#!/bin/bash
set -e

if ! kubectl get application canary-web -n argocd >/dev/null 2>&1; then
  echo "The canary-web Application does not exist."
  echo "Create it with: kubectl apply -f /root/manifests/04-canary/canary-application.yaml"
  exit 1
fi

if ! kubectl get rollout web -n canary-demo >/dev/null 2>&1; then
  echo "No Rollout in canary-demo, so the Application has not synced yet."
  echo "Sync it with: argocd app sync canary-web"
  exit 1
fi

PATHNOW=$(kubectl get application canary-web -n argocd -o jsonpath='{.spec.source.path}' 2>/dev/null)
if ! echo "$PATHNOW" | grep -q '/v2$'; then
  echo "The Application still points at ${PATHNOW##*/}, so no second revision has been deployed"
  echo "and no canary has run. Switch it to v2, which stands in for merging a commit:"
  echo "  kubectl patch application canary-web -n argocd --type merge -p '{\"spec\":{\"source\":{\"path\":\"module-11-progressive-delivery/03-wiring-argocd-with-rollouts/v2\"}}}'"
  echo "  argocd app sync canary-web"
  exit 1
fi

PHASE=$(kubectl get rollout web -n canary-demo -o jsonpath='{.status.phase}' 2>/dev/null)
HEALTH=$(kubectl get application canary-web -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)

if [ "$PHASE" = "Paused" ]; then
  echo "The canary is paused at 25 percent and the Application reports ${HEALTH}, which is the"
  echo "state this step exists to show. Promote it to finish:"
  echo "  kubectl argo rollouts promote web -n canary-demo"
  exit 1
fi

if [ "$PHASE" != "Healthy" ]; then
  echo "The Rollout reports phase '${PHASE:-unknown}'. Give it a few seconds, or check it with:"
  echo "  kubectl argo rollouts get rollout web -n canary-demo"
  exit 1
fi

# The promoted revision must actually be the new image.
IMG=$(kubectl get rollout web -n canary-demo -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
if ! echo "$IMG" | grep -q '1.28'; then
  echo "The Rollout completed but is running ${IMG}, not the v2 image."
  exit 1
fi

if [ "$HEALTH" != "Healthy" ]; then
  echo "The Rollout finished but the Application reports ${HEALTH}. Give it a moment to reconcile."
  exit 1
fi

echo "Canary complete: paused at 25 percent with the Application Suspended, promoted, and now Healthy on ${IMG}."
exit 0
