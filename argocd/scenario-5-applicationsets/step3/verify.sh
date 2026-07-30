#!/bin/bash
set -e

# The step ends by deleting the three ApplicationSets, so a pass means either the
# matrix produced its four Applications, or the student has already cleaned up.
# Accept both, but require that the cleanup was genuine rather than a failed apply.

if kubectl get applicationset matrix-demo -n argocd >/dev/null 2>&1; then
  # Still present: the cross product must be complete.
  FOUND=0
  for n in mx-dev-eu mx-dev-us mx-staging-eu mx-staging-us; do
    kubectl get application "$n" -n argocd >/dev/null 2>&1 && FOUND=$((FOUND+1))
  done
  if [ "$FOUND" -ne 4 ]; then
    echo "The matrix generator has produced $FOUND of the expected 4 Applications."
    echo "Two environments times two regions is four. Give it a few seconds and check again:"
    echo "  kubectl get applications -n argocd -o name | grep mx-"
    exit 1
  fi
  echo "Matrix produced all 4 Applications (2 environments x 2 regions). You can now run the cleanup command."
  exit 0
fi

# Deleted: the generated Applications must be gone with it, which is the blast
# radius lesson from step 1 seen at scale.
LEFT=$(kubectl get applications -n argocd --no-headers 2>/dev/null | grep -c '^mx-' || true)
if [ "$LEFT" -ne 0 ]; then
  echo "The matrix ApplicationSet is gone but $LEFT of its Applications remain."
  echo "Deleting an ApplicationSet should remove everything it generated. Wait a moment and check again."
  exit 1
fi

echo "Matrix cross product demonstrated, and deleting the ApplicationSets removed everything they generated."
exit 0
