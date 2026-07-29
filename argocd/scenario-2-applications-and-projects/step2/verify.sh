#!/bin/bash
set -e

if ! kubectl get appproject course -n argocd >/dev/null 2>&1; then
  echo "The 'course' AppProject does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/02-appproject/restricted-project.yaml"
  exit 1
fi

if ! kubectl get application forbidden -n argocd >/dev/null 2>&1; then
  echo "The 'forbidden' Application does not exist yet."
  echo "Fix it with: kubectl apply -f /root/manifests/02-appproject/forbidden-app.yaml"
  exit 1
fi

# The point of the step: the project refused it, and said so in a condition.
MSG=$(kubectl get application forbidden -n argocd \
  -o jsonpath='{.status.conditions[*].message}' 2>/dev/null)

if [ -z "$MSG" ]; then
  echo "The Application exists but Argo CD has not evaluated it against the project yet."
  echo "Wait a few seconds, or run: argocd app get forbidden --hard-refresh"
  exit 1
fi

if ! echo "$MSG" | grep -q "not permitted in project"; then
  echo "Expected a 'not permitted in project' condition, but found: $MSG"
  echo "Check that forbidden-app.yaml still sets 'project: course'."
  exit 1
fi

echo "The project rejected the Application, and said exactly why:"
echo "  $MSG"
exit 0
