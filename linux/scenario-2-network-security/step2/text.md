# Step 2 — Harden sshd without locking yourself out

The daemon is running distribution defaults. Before changing anything, find out what it is actually enforcing.

## Read the effective configuration, not the file

```bash
sshd -T | grep -E "^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|maxauthtries|x11forwarding)"
```{{exec}}

`sshd -T` resolves every `Include` and prints what the daemon really settled on. Reading `/etc/ssh/sshd_config` alone tells you very little, because Ubuntu assembles the config from drop-ins:

```bash
grep -n "^Include" /etc/ssh/sshd_config; ls /etc/ssh/sshd_config.d/
```{{exec}}

Look closely at one value:

```
permitrootlogin without-password
```

That is **not** "no". It means root may log in with a key, just not a password. On a cloud image that is how the provisioning key works, and it is usually the first thing to tighten.

## Write a drop-in

Drop-ins are better than editing the main file: a package upgrade cannot conflict with them, and a change can be undone by deleting one file.

```bash
cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'CONF'
# Keys only. No password will ever be accepted.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password

# Reduce what an unauthenticated client can hold open.
MaxAuthTries 3
LoginGraceTime 20

# Nothing on this host needs it.
X11Forwarding no
CONF
```{{copy}}

`KbdInteractiveAuthentication no` belongs alongside `PasswordAuthentication no`. Leaving it enabled can let a password reach the daemon through PAM by a different route, so the two go together.

## Test before restarting. Always.

```bash
sshd -t; echo "exit=$?"
```{{exec}}

Exit `0` means the whole configuration parses. Now see what a typo costs:

```bash
cp /etc/ssh/sshd_config.d/99-hardening.conf /tmp/broken.conf
sed -i 's/^MaxAuthTries 3/MaxAuthTries three/' /tmp/broken.conf
sshd -t -f /tmp/broken.conf; echo "exit=$?"
```{{exec}}

The file, the line, and the reason. `sshd` refuses to start on a config it cannot parse, so pushing that to a fleet and restarting would take every daemon down at once.

```bash
rm -f /tmp/broken.conf
```{{exec}}

## Apply it

On a remote machine the rule is: **keep your current session open**, restart, then open a *second* connection to confirm before closing the first. An established SSH session survives a daemon restart, so a config that locks everyone out is still repairable as long as you have not disconnected.

```bash
systemctl restart ssh
```{{exec}}

```bash
sshd -T | grep -E "^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|maxauthtries)"
```{{exec}}

## Your task

Have the daemon actually enforcing:

- `passwordauthentication no`
- `kbdinteractiveauthentication no`
- `maxauthtries 3`
- `permitrootlogin` set to anything other than `yes`

The commands above will get you there. The one that is easy to skip is restarting the service: writing the file changes nothing until the daemon re-reads it.

When `sshd -T` reports those values, click **Check**.
