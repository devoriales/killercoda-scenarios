# Step 2 — Attach Middlewares via ExtensionRef

The Gateway API defines a `filters` field on each HTTPRoute rule. One filter type is `ExtensionRef` — the spec's intentional escape hatch for vendor-specific behaviour. You point it at any CRD by group, kind, and name.

```yaml
filters:
- type: ExtensionRef
  extensionRef:
    group: traefik.io      # Traefik's API group
    kind: Middleware        # the CRD kind
    name: rate-limit        # the object name in the same namespace
```

Multiple `ExtensionRef` filters on the same rule are applied in order — both middlewares will be active for every request that matches.

## Replace the basic HTTPRoute

The existing `bookstore-route` routes `/api` without any middleware. You'll replace it with `bookstore-with-middleware`, which attaches both middlewares to the `/api` rule and keeps a plain catch-all for `/`.

First, delete the existing route:

```
kubectl delete httproute bookstore-route -n bookstore
```

Then apply the middleware-enabled route:

```
kubectl apply -f /root/manifests/06-traefik-middlewares/httproute-with-middleware.yaml
```

Or apply inline:

```
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: bookstore-with-middleware
  namespace: bookstore
spec:
  parentRefs:
  - name: bookstore-gateway
    namespace: bookstore
    sectionName: https
  hostnames:
  - bookstore.local
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    filters:
    - type: ExtensionRef
      extensionRef:
        group: traefik.io
        kind: Middleware
        name: rate-limit
    - type: ExtensionRef
      extensionRef:
        group: traefik.io
        kind: Middleware
        name: security-headers
    backendRefs:
    - name: bookstore
      port: 80
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: bookstore
      port: 80
EOF
```

## Verify the route is accepted

```
kubectl get httproute bookstore-with-middleware -n bookstore
```

The `STATUS` column should show `Accepted`. Also confirm the app still responds:

```
curl -sk https://bookstore.local:30091/health
```

Expected: `{"status":"ok",...}`

Click **Check** when the HTTPRoute is accepted and the app responds.
