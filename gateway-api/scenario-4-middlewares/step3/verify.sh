#!/bin/bash
set -e

# Check security headers are present on /api requests
HEADERS=$(curl -sk https://bookstore.local:30091/api/v1/books -I)

if ! echo "$HEADERS" | grep -qi "x-frame-options"; then
  echo "Security header X-Frame-Options is missing from /api/v1/books response."
  echo "Check that 'security-headers' Middleware is attached to the /api rule in bookstore-with-middleware HTTPRoute."
  exit 1
fi

if ! echo "$HEADERS" | grep -qi "x-content-type-options"; then
  echo "Security header X-Content-Type-Options is missing from /api/v1/books response."
  echo "Check that 'security-headers' Middleware is attached to the /api rule in bookstore-with-middleware HTTPRoute."
  exit 1
fi

echo "Security headers confirmed. Traefik Middleware via ExtensionRef is working correctly."
exit 0
