# The host defends itself and reports on itself

You took a machine that was quietly unreachable and left it filtered, hardened, and monitored.

| Step | What you did | The tool |
|---|---|---|
| 1 | Found a bind address, not a network fault | `ss -tlnp`, the diagnostic ladder |
| 2 | Hardened sshd and applied it safely | `sshd -T`, `sshd -t`, drop-ins |
| 3 | Wrote a stateful default-deny firewall | `nft -c -f`, `nft -f` |
| 4 | Scheduled a check that reports its own failure | `systemd` timer, `systemctl --failed` |

## Worth carrying forward

- **Work up the ladder and stop at the first rung that fails.** Link, address, route, DNS, socket, wire. The bind address in step 1 was rung 5, and a packet capture would have shown a RST without explaining it.
- **"I checked with curl on the box" can prove very little.** Testing over loopback matches a loopback-only bind and tells you nothing about what a client elsewhere sees.
- **`sshd -T` and `nft -c` both answer "what is really in effect".** Reading the config file is guessing; asking the daemon is not.
- **`ct state established,related accept` is the rule people omit**, and omitting it breaks *outbound* traffic while inbound SSH keeps working. That asymmetry is why it gets misdiagnosed as DNS.
- **Apply a firewall as a whole file.** `nft -f` is atomic; a sequence of `nft add` leaves a window where the policy is `drop` and your accept rule has not landed.
- **A check that cannot fail is not a check.** Verify both directions before trusting it.
- **`systemctl --failed` finds every broken scheduled job on a host.** cron has no equivalent, which is why a cron job can fail nightly for months and look exactly like one that works.

## Two habits this lab could not force on you

The terminal here is disposable, so nothing you did could really lock you out. On a machine you have to keep:

1. **Keep your existing session open** while testing a new one, across every `sshd` restart and every firewall change.
2. **Arm a rollback before applying, cancel it after confirming.** Step 3 showed the mechanism with `systemd-run --on-active`. It costs one command and it is the difference between a bad afternoon and a rebuilt host.

## Where this comes from

This is Module 3 of a written course that goes considerably deeper: the full six-rung ladder with packet captures, ed25519 against RSA, what agent forwarding actually hands to a shared bastion, `ProxyJump`, the netfilter hook model, and why `set -euo pipefail` belongs at the top of every operational script.

**[Linux for DevOps Engineers on devoriales.com](https://devoriales.com/quiz/25/linux-for-devops-engineers)**

Module 4 takes containers apart from the kernel up: namespaces, cgroups v2, and overlay filesystems, before any container engine appears.
