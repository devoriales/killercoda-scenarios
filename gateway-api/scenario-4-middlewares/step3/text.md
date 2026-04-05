# Step 3 — Verify Security Headers and Test Rate Limiting

Both middlewares are now active on every `/api` request. Let's confirm they work.

## Verify security headers

The `security-headers` middleware injects response headers on every matched request. Check them with:

```
curl -sk https://bookstore.local:30091/api/v1/books -I | grep -iE "x-frame|x-content|referrer|content-security"
```

Expected output (order may vary):

```
content-security-policy: default-src 'self'
referrer-policy: strict-origin-when-cross-origin
x-content-type-options: nosniff
x-frame-options: DENY
```

If you hit `/health` instead (which matches the `/` rule, not `/api`), you will **not** see these headers — the middleware is scoped to the `/api` rule only. Try it:

```
curl -sk https://bookstore.local:30091/health -I | grep -iE "x-frame|x-content"
```

No output is expected. This is `ExtensionRef` working as intended: precise, per-rule attachment.

## Test rate limiting

The `rate-limit` middleware allows 10 requests/second sustained with a burst of 20. Fire 30 **concurrent** requests to trigger the limit:

```
seq 30 | xargs -P 30 -I{} curl -sk -o /dev/null -w "%{http_code}\n" \
  https://bookstore.local:30091/api/v1/books | sort | uniq -c
```

Expected output (approximate):

```
 20 200
 10 429
```

The `429 Too Many Requests` responses are Traefik enforcing the token bucket limit. Sequential requests (one at a time) won't trigger it — the burst of 20 absorbs them. You need concurrent load to exhaust the bucket.

## Inspect the route configuration

You can also confirm the filters are recorded on the HTTPRoute object:

```
kubectl get httproute bookstore-with-middleware -n bookstore -o yaml | grep -A5 extensionRef
```

Click **Check** when you can see the security headers in the response.
