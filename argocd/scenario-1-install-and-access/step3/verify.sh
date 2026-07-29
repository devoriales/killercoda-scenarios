#!/bin/bash
set -e

if ! pgrep -f "port-forward svc/argocd-server" >/dev/null 2>&1; then
  echo "No port-forward to argocd-server is running."
  echo "Fix it with: kubectl port-forward svc/argocd-server -n argocd 8080:443 > /tmp/pf.log 2>&1 &"
  exit 1
fi

# The scenario leaves argocd-server on its default self-signed TLS, so https is the
# expected answer here. Fall back to http as well, so a student who has been
# experimenting with server.insecure=true gets a useful result rather than a blank one.
body=$(curl -sk --max-time 10 https://localhost:8080/api/version 2>/dev/null || true)
if [ -z "$body" ]; then
  body=$(curl -s --max-time 10 http://localhost:8080/api/version 2>/dev/null || true)
fi

if [ -z "$body" ]; then
  echo "The port-forward is running but /api/version returned nothing over https or http."
  echo "Check /tmp/pf.log, and confirm argocd-server is Running with: kubectl get pods -n argocd"
  exit 1
fi

if ! echo "$body" | grep -q "v3.4.5"; then
  echo "Something answered on port 8080, but it did not report Argo CD v3.4.5."
  echo "Got: ${body}"
  exit 1
fi

echo "Argo CD v3.4.5 is answering on localhost:8080, confirmed from /api/version rather than a bare 200."
exit 0
