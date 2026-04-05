# Lab Complete — Traefik Middlewares via ExtensionRef

You've extended the Gateway API with vendor-specific behaviour using Traefik Middleware CRDs.

## What you did

| Step | Outcome |
|---|---|
| Created `rate-limit` Middleware | Token bucket: 10 req/s sustained, burst 20 |
| Created `security-headers` Middleware | Injects 4 protective HTTP response headers |
| Applied `ExtensionRef` filters in HTTPRoute | Both middlewares active on every `/api` request |
| Verified security headers | Present on `/api`, absent on `/` (scoped per rule) |
| Tested rate limiting | 429 responses under concurrent load |

## The full learning path

| Lab | Topic |
|---|---|
| Lab 1 | Deploy bookstore + expose via ingress-nginx |
| Lab 2 | Install Gateway API + Traefik, migrate to HTTPRoute, add TLS |
| Lab 3 | Canary traffic splitting, header-based routing, decommission ingress-nginx |
| **Lab 4** | **Traefik Middlewares via ExtensionRef (this lab)** |

## Key concepts

**GatewayClass** — cluster-scoped, identifies the controller (`traefik.io/gateway-controller`)

**Gateway** — declares listeners; owned by the platform team

**HTTPRoute** — routes requests to backends; owned by the application team

**ExtensionRef** — the Gateway API extension point for vendor-specific filters; keeps routing logic portable, confines vendor coupling to the `filters` block

**Traefik Middleware** — vendor CRD (`traefik.io/v1alpha1`); powerful but non-portable; attach via `ExtensionRef` to HTTPRoute rules

## Continue learning

- [Kubernetes Gateway API documentation](https://gateway-api.sigs.k8s.io/)
- [Traefik Middleware reference](https://doc.traefik.io/traefik/middlewares/http/overview/)
- Full course at [devoriales.com](https://devoriales.com)
