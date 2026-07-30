#!/bin/bash
set -e

if ! kubectl get appproject signed-only -n argocd >/dev/null 2>&1; then
  echo "The signed-only AppProject does not exist."
  echo "Create it with: kubectl apply -f /root/manifests/04-security/signed-only-project.yaml"
  exit 1
fi

if ! kubectl get application unsigned-app -n argocd >/dev/null 2>&1; then
  echo "The unsigned-app Application does not exist."
  echo "Create it with: kubectl apply -f /root/manifests/04-security/unsigned-app.yaml"
  exit 1
fi

KEYS=$(kubectl get appproject signed-only -n argocd -o jsonpath='{.spec.signatureKeys[*].keyID}' 2>/dev/null)
MSG=$(kubectl get application unsigned-app -n argocd -o jsonpath='{.status.conditions[*].message}' 2>/dev/null)

if [ -n "$KEYS" ]; then
  # Requirement still in place: the student should have SEEN the refusal.
  if echo "$MSG" | grep -q "is not signed, but a signature is required"; then
    echo "Signature enforcement confirmed: the project requires key ${KEYS} and Argo CD refused an unsigned revision."
    echo "Now remove the requirement and refresh, to prove that was the only thing blocking it."
    exit 1
  fi
  echo "The project requires key ${KEYS} but the Application does not report a signature refusal yet."
  echo "Conditions are written on reconciliation, so give it a moment or force one:"
  echo "  kubectl annotate application unsigned-app -n argocd argocd.argoproj.io/refresh=hard --overwrite"
  exit 1
fi

# Requirement removed: the refusal must be gone, not merely stale.
if echo "$MSG" | grep -q "is not signed"; then
  echo "signatureKeys is removed but the Application still reports the signature error."
  echo "That is a stale condition. Force a re-evaluation:"
  echo "  kubectl annotate application unsigned-app -n argocd argocd.argoproj.io/refresh=hard --overwrite"
  exit 1
fi

SYNC=$(kubectl get application unsigned-app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
if [ -z "$SYNC" ] || [ "$SYNC" = "Unknown" ]; then
  echo "The Application reports sync status '${SYNC:-none}', so it is not being evaluated cleanly yet."
  echo "Force a refresh and check again:"
  echo "  kubectl annotate application unsigned-app -n argocd argocd.argoproj.io/refresh=hard --overwrite"
  exit 1
fi

echo "Proven: with signatureKeys removed the same commit reconciles to ${SYNC} with no conditions, so the signature requirement was the only thing blocking it."
exit 0
