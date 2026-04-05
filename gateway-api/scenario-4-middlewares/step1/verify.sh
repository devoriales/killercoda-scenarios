#!/bin/bash
set -e

if ! kubectl get middleware rate-limit -n bookstore &>/dev/null; then
  echo "Middleware 'rate-limit' not found in namespace bookstore."
  echo "Run: kubectl apply -f /root/manifests/06-traefik-middlewares/rate-limit.yaml"
  exit 1
fi

if ! kubectl get middleware security-headers -n bookstore &>/dev/null; then
  echo "Middleware 'security-headers' not found in namespace bookstore."
  echo "Run: kubectl apply -f /root/manifests/06-traefik-middlewares/security-headers.yaml"
  exit 1
fi

echo "Both Traefik Middleware CRDs are present. Ready to attach them via ExtensionRef."
exit 0
