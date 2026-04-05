#!/bin/bash
set -e

if ! kubectl get httproute bookstore-with-middleware -n bookstore &>/dev/null; then
  echo "HTTPRoute 'bookstore-with-middleware' not found in namespace bookstore."
  echo "Run: kubectl apply -f /root/manifests/06-traefik-middlewares/httproute-with-middleware.yaml"
  exit 1
fi

# Confirm the app is reachable through the new route
STATUS=$(curl -sk -o /dev/null -w "%{http_code}" https://bookstore.local:30091/health)
if [ "$STATUS" != "200" ]; then
  echo "App is not responding via Traefik (got HTTP $STATUS, expected 200)."
  echo "Check: kubectl describe httproute bookstore-with-middleware -n bookstore"
  exit 1
fi

echo "HTTPRoute with ExtensionRef filters is active and app is reachable. Ready to test middleware behaviour."
exit 0
