# Step 1 — Create Traefik Middleware CRDs

The Gateway API spec defines a clean extension point for vendor-specific behaviour: the `ExtensionRef` filter. But before you can reference a Middleware in an HTTPRoute, you need to create the Middleware objects themselves.

Traefik ships its own CRDs — `Middleware` is one of them. It lives in the `traefik.io/v1alpha1` API group and is **not part of the Gateway API spec**. This is the trade-off: you gain powerful Traefik-native features, but the Middleware objects are non-portable.

## Create a Rate Limiting Middleware

The rate limiter uses a **token bucket** algorithm:
- `average` — sustained rate (tokens refilled per second)
- `burst` — maximum tokens available at once (absorbs short spikes)

Apply from the manifest delivered to your VM:

```
kubectl apply -f /root/manifests/06-traefik-middlewares/rate-limit.yaml
```{{copy}}

Or apply inline:

```
kubectl apply -f - <<'EOF'
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
  namespace: bookstore
spec:
  rateLimit:
    average: 10
    burst: 20
EOF

```{{copy}}

## Create a Security Headers Middleware

This middleware injects HTTP response headers that protect against common web vulnerabilities:

| Header | Protects against |
|---|---|
| `X-Frame-Options: DENY` | Clickjacking (blocks iframes) |
| `X-Content-Type-Options: nosniff` | MIME-type sniffing |
| `Referrer-Policy` | Referrer data leakage |
| `Content-Security-Policy` | Inline script injection |

```
kubectl apply -f /root/manifests/06-traefik-middlewares/security-headers.yaml
```{{copy}}

Or apply inline:

```
kubectl apply -f - <<'EOF'
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: bookstore
spec:
  headers:
    customResponseHeaders:
      X-Frame-Options: "DENY"
      X-Content-Type-Options: "nosniff"
      Referrer-Policy: "strict-origin-when-cross-origin"
      Content-Security-Policy: "default-src 'self'"
EOF
```{{copy}}

## Verify

Check that both Middleware objects exist in the `bookstore` namespace:

```
kubectl get middleware -n bookstore
```{{copy}}

Expected output:
```
NAME               AGE
rate-limit         10s
security-headers   8s
```

Click **Check** when both middlewares are listed.
