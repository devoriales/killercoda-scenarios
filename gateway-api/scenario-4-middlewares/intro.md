# Lab 4/4 — Traefik Middlewares via ExtensionRef

> This scenario is part of the **[Gateway API Learning Lab: From Zero to Hero](https://devoriales.com/quiz/20/gateway-api-learning-lab-from-zero-to-hero)** course on [devoriales.com](https://devoriales.com).
> **Scenarios:** [1 — Baseline](https://killercoda.com/devoriales/course/gateway-api/scenario-1-baseline) · [2 — Migration](https://killercoda.com/devoriales/course/gateway-api/scenario-2-migration) · [3 — Advanced](https://killercoda.com/devoriales/course/gateway-api/scenario-3-advanced)· [4 — Middlewares](https://killercoda.com/devoriales/course/gateway-api/scenario-4-middlewares)

In the previous labs you migrated from ingress-nginx to Traefik, configured TLS, and explored canary and header-based routing — all using portable Gateway API resources.

This lab introduces **vendor-specific extensions**: Traefik Middleware CRDs attached to HTTPRoute rules via the Gateway API `ExtensionRef` filter.

## What's already running

| Resource | State |
|---|---|
| Traefik v3 | NodePort 30090 (HTTP) / 30091 (HTTPS) |
| GatewayClass `traefik` | Programmed |
| Gateway `bookstore-gateway` | HTTP + HTTPS listeners |
| HTTPRoute `bookstore-route` | Routes `/api` and `/` to bookstore v1 |
| TLS secret `bookstore-tls` | mkcert cert for `bookstore.local` |
| App `bookstore` (v1) | 2 replicas, port 8000 |

## What you'll do

1. **Create Traefik Middleware CRDs** — a rate limiter and a security headers injector
2. **Wire them into an HTTPRoute** via `ExtensionRef` — the Gateway API extension point for vendor features
3. **Verify the behavior** — security headers in every response, 429 errors when the rate limit fires

## Check environment readiness

Wait until the Gateway is programmed and Traefik is running:

```
kubectl wait --for=condition=Programmed gateway/bookstore-gateway -n bookstore --timeout=120s
kubectl get pods -n traefik
```

Once both are ready, proceed to Step 1.
