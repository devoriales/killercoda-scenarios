# Step 3 — Write a firewall that does not break outbound traffic

There is no firewall at all:

```bash
nft list ruleset
```{{exec}}

Before writing rules, ask what needs one:

```bash
ss -tulpnH | awk '{print $1, $5, $7}' | grep -vE '127\.0\.0\.[0-9]+|\[::1\]'
```{{exec}}

That is the entire attack surface. Anything bound to `0.0.0.0` or `*` is reachable from outside and needs a reason to exist.

## The rule everyone leaves out

A default-deny firewall has to recognise **return traffic**. When this host makes an outbound DNS query, the reply arrives as an *inbound* packet on a high port that no allow rule mentions. Without connection tracking, the policy drops it.

The symptom is distinctive and misleading: DNS hangs, `apt` stalls, outbound calls time out, and **inbound SSH keeps working perfectly**, which sends people to look at the resolver for an hour.

## Write the whole ruleset as a file

Never build a firewall with a sequence of `nft add` commands. Setting `policy drop` first and adding the SSH rule second leaves a window in which your own connection can be reset. A file is applied atomically, so that window does not exist.

```bash
cat > /root/firewall.nft <<'NFT'
#!/usr/sbin/nft -f

# Replace only OUR table, and leave every other one alone. `flush ruleset` would be
# shorter and would also destroy the tables Docker, Podman and the platform itself
# rely on. Declaring the table before deleting it makes this safe to run twice.
table inet filter
delete table inet filter

table inet filter {
  chain input {
    type filter hook input priority filter; policy drop;

    # Return traffic for connections this host started. Without this, outbound breaks.
    ct state established,related accept
    ct state invalid drop

    # The host talks to itself constantly, including the resolver stub.
    iif lo accept

    # Ping stays usable for diagnosis, rate limited rather than blocked.
    ip protocol icmp icmp type echo-request limit rate 5/second accept
    ip6 nexthdr icmpv6 accept

    # The only ports this host offers.
    tcp dport 22 ct state new limit rate 10/minute accept comment "ssh"
    tcp dport 9095 accept comment "metrics endpoint"

    # Count what the policy refuses, so the ruleset can be reasoned about later.
    counter comment "dropped by default policy"
  }

  chain forward {
    type filter hook forward priority filter; policy drop;
  }

  chain output {
    type filter hook output priority filter; policy accept;
  }
}
NFT
```{{copy}}

## Check it before loading it

```bash
nft -c -f /root/firewall.nft; echo "exit=$?"
```{{exec}}

`-c` parses and validates without touching the running configuration. This is the `sshd -t` of firewalls, and it belongs in the same reflex.

## Arm a rollback, then apply

On a machine you cannot afford to lose, arm an automatic undo first and cancel it once you have confirmed access:

```bash
systemd-run --on-active=120 --unit=fw-rollback /usr/sbin/nft delete table inet filter
```{{exec}}

```bash
nft -f /root/firewall.nft && echo "applied"
```{{exec}}

Confirm you still have everything you need:

```bash
curl -s -o /dev/null -w "metrics -> HTTP %{http_code}\n" http://127.0.0.1:9095/
```{{exec}}

```bash
getent hosts archive.ubuntu.com >/dev/null && echo "outbound DNS still works"
```{{exec}}

That second command is the one that proves the `ct state established` rule is doing its job. If it hangs, the rule is missing.

Now cancel the rollback:

```bash
systemctl stop fw-rollback.timer 2>/dev/null; echo "rollback cancelled"
```{{exec}}

## Your task

Have a loaded ruleset with:

- an `input` chain whose policy is `drop`
- a `ct state established,related accept` rule
- `iif lo accept`
- port `22` and port `9095` accepted
- outbound DNS still working

<details><summary>If you lock yourself out</summary>

You will not, from this terminal, but the habit matters. The rollback timer deletes the table after two minutes, which restores the open state without touching any other table. Rules also live only in kernel memory, so a reboot clears them. To persist a ruleset you are happy with, write it to `/etc/nftables.conf` and `systemctl enable --now nftables`.

</details>

When the ruleset is loaded and DNS still resolves, click **Check**.
