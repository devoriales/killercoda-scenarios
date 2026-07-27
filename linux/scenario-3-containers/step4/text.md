# Step 4 — Put a proxy in front of it

The container publishes on `0.0.0.0:8080`, which means anyone who can reach this host can reach it directly:

```bash
ss -tlnp 'sport = :8080'
```{{exec}}

That is fine for a lab and wrong for a deployment. The application should be reachable **only** through something that terminates TLS, routes by hostname, and can be the single place you configure access.

## Bind the container to loopback instead

```bash
su - appops -c 'podman rm -f app' >/dev/null 2>&1
```{{exec}}

```bash
su - appops -c 'podman run -d --name app --memory=64m -p 127.0.0.1:8080:80 docker.io/library/nginx:alpine'
```{{exec}}

```bash
ss -tlnp 'sport = :8080'
```{{exec}}

`127.0.0.1:8080` now, not `0.0.0.0:8080`. Confirm what that changed:

```bash
curl -s -o /dev/null -w "  loopback -> HTTP %{http_code}\n" http://127.0.0.1:8080/
IP=$(hostname -I | awk '{print $1}')
curl -s --max-time 3 -o /dev/null -w "  external -> HTTP %{http_code}\n" http://$IP:8080/ || echo "  external -> refused"
```{{exec}}

Reachable from the machine itself, refused from its own external address. The container is now private.

## The proxy

```bash
cat > /etc/nginx/sites-available/appdemo <<'CONF'
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
CONF
ln -sf /etc/nginx/sites-available/appdemo /etc/nginx/sites-enabled/appdemo
rm -f /etc/nginx/sites-enabled/default
```{{copy}}

Those four `proxy_set_header` lines matter more than they look. Once a proxy is in front, the application sees every request arriving from `127.0.0.1`, so its logs, its rate limiting, and any IP-based rules all see one client. The proxy has to pass the original values on.

**Validate before starting**, the same reflex as `sshd -t` and `nft -c`:

```bash
nginx -t
```{{exec}}

```bash
systemctl enable --now nginx
```{{exec}}

```bash
curl -s -o /dev/null -w "  via proxy on 80 -> HTTP %{http_code}\n" http://127.0.0.1/
```{{exec}}

```bash
IP=$(hostname -I | awk '{print $1}'); curl -s -o /dev/null -w "  externally on 80 -> HTTP %{http_code}\n" http://$IP/
```{{exec}}

Reachable from outside on port 80, through the proxy, while the container itself stays on loopback.

## Your task

Leave the host in this state:

- container `app` running as `appops`, published on **`127.0.0.1:8080` only**
- `nginx` running and enabled, proxying port 80 to it
- port 80 answering `200` on the host's external address

<details><summary>Hint</summary>

The three commands that matter, in order:

```
su - appops -c 'podman rm -f app'
su - appops -c 'podman run -d --name app --memory=64m -p 127.0.0.1:8080:80 docker.io/library/nginx:alpine'
nginx -t && systemctl enable --now nginx
```

</details>

When port 80 works from outside and 8080 does not, click **Check**.
