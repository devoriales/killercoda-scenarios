# The load balancer says the host is down

The analytics host serves a metrics endpoint on port 9095. The service is running. The application team has checked it themselves, on the box, with `curl`, and it returns `200`.

The load balancer disagrees and has pulled the host out of rotation.

Both of them are right, and by the end of the first step you will be able to say exactly why without guessing.

## What you will do

- **Diagnose** the unreachable endpoint by working up the ladder rather than starting with a packet capture
- **Harden** the SSH daemon, using the test-before-restart discipline that keeps a remote machine reachable
- **Filter** with a stateful `nftables` ruleset, including the one rule whose absence breaks outbound traffic while leaving inbound SSH working perfectly
- **Schedule** a health check as a systemd timer, so the next failure announces itself instead of being discovered by a load balancer

## The host you are given

| Thing | State |
|---|---|
| `analytics-metrics.service` | Running, and misconfigured in exactly one way |
| `sshd` | Running with distribution defaults, nothing tightened |
| Firewall | None. `nft list ruleset` is empty |
| Scheduled checks | None |

You are `root`. This is a disposable virtual machine, so you can be bolder here than you would be on a machine you have to keep, which is precisely why it is worth practising the careful habits now.

Let's find out why the load balancer cannot see a service that is definitely running.
