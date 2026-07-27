# Step 1 — Find why the endpoint is unreachable

Resist opening a packet capture. Work up the ladder and stop at the first rung that fails.

## The application team's evidence

They are not wrong:

```bash
systemctl is-active analytics-metrics.service
```{{exec}}

```bash
curl -s -o /dev/null -w "localhost -> HTTP %{http_code}\n" http://127.0.0.1:9095/
```{{exec}}

Running, and answering `200`. So the service is fine and the network must be broken. That conclusion is where a lot of time gets wasted.

## Rungs 1 to 3: the network is fine

```bash
ip -brief link show
```{{exec}}

```bash
ip -brief addr show
```{{exec}}

```bash
ip route get 1.1.1.1
```{{exec}}

Link up, address present, a default route that resolves. Nothing here is broken.

## Rung 5: ask what is actually listening

```bash
ss -tlnp 'sport = :9095'
```{{exec}}

There it is.

```
LISTEN 0  5  127.0.0.1:9095  0.0.0.0:*  users:(("python3",...))
```

The **bind address** is `127.0.0.1`, not `*` or `0.0.0.0`. The process only accepts connections arriving over the loopback interface. Compare it with `sshd`, which the load balancer can reach perfectly well:

```bash
ss -tlnp 'sport = :22'
```{{exec}}

`*:22` means every address on the machine.

## Prove it from the host's own external address

```bash
IP=$(hostname -I | awk '{print $1}'); echo "external address: $IP"
```{{exec}}

```bash
curl -s --max-time 3 -o /dev/null -w "external -> HTTP %{http_code}\n" http://$IP:9095/ || echo "external -> refused"
```{{exec}}

Same machine, same service, same instant. Over loopback it answers; over its own external address it refuses. Nothing is wrong with the network, the firewall, or DNS.

This is what "I checked with curl on the box" can fail to prove.

## Your task

Make the endpoint reachable on the host's external address, without changing what it serves.

The bind address is set in the unit file:

```bash
grep ExecStart /etc/systemd/system/analytics-metrics.service
```{{exec}}

<details><summary>Hint</summary>

Change the bind address to `0.0.0.0`, then remember that systemd caches unit files:

```
sed -i 's/--bind 127.0.0.1/--bind 0.0.0.0/' /etc/systemd/system/analytics-metrics.service
systemctl daemon-reload
systemctl restart analytics-metrics.service
ss -tlnp 'sport = :9095'
```

</details>

When `ss` shows the service listening on all addresses and the external `curl` returns `200`, click **Check**.
