# Step 3 — Firewall, and the application behind it

## The ruleset

```bash
cat > /root/firewall.nft <<'NFT'
#!/usr/sbin/nft -f

# Replace only OUR table. flush ruleset would also destroy the NAT tables podman
# installs, and container networking would break in a way that looks unrelated.
table inet filter
delete table inet filter

table inet filter {
  chain input {
    type filter hook input priority filter; policy drop;

    # Return traffic for connections this host started. Without this, outbound breaks
    # while inbound ssh keeps working, which is how it gets misdiagnosed as DNS.
    ct state established,related accept
    ct state invalid drop
    iif lo accept

    ip protocol icmp icmp type echo-request limit rate 5/second accept
    ip6 nexthdr icmpv6 accept

    tcp dport { 22, 2222 } ct state new limit rate 10/minute accept comment "ssh"
    tcp dport { 80, 443 } accept comment "public edge, 80 also for ACME"

    counter comment "dropped by default policy"
  }
  chain forward { type filter hook forward priority filter; policy drop; }
  chain output  { type filter hook output priority filter; policy accept; }
}
NFT
```{{copy}}

Check it, arm a rollback, then apply the whole file atomically:

```bash
nft -c -f /root/firewall.nft && echo "parsed OK"
```{{exec}}

```bash
systemd-run --on-active=120 --unit=fw-rollback /usr/sbin/nft delete table inet filter
```{{exec}}

```bash
nft -f /root/firewall.nft && echo applied
```{{exec}}

Confirm outbound still works, which is what proves the connection tracking rule is doing its job:

```bash
getent hosts archive.ubuntu.com >/dev/null && echo "outbound DNS still works"
```{{exec}}

```bash
systemctl stop fw-rollback.timer 2>/dev/null; echo "rollback cancelled"
```{{exec}}

Never build a firewall with a sequence of `nft add`. Setting `policy drop` first and adding the SSH rule second leaves a window in which your own connection can be reset. A file is applied atomically, so that window does not exist.

## The application

Rootless, memory limited, and bound to loopback so only the proxy can reach it:

```bash
su - appsvc -s /bin/bash -c 'podman run -d --name gateway-app --memory=64m -p 127.0.0.1:8080:80 docker.io/library/nginx:alpine'
```{{exec}}

```bash
PID=$(su - appsvc -s /bin/bash -c "podman inspect --format '{{.State.Pid}}' gateway-app")
ps -o pid,user,comm -p "$PID"; ss -tlnH 'sport = :8080' | awk '{print "bound:", $4}'
```{{exec}}

Root inside the container, `appsvc` on the host, and reachable only from the machine itself. Check the limit reached the kernel rather than trusting the flag:

```bash
cat /sys/fs/cgroup$(cut -d: -f3 /proc/$PID/cgroup)/memory.max
```{{exec}}

`67108864` is the 64 MiB you asked for.

## Your task

```bash
gateway-validate
```{{exec}}

Sections 4, 5 and 7 green. When they are, click **Check**.
