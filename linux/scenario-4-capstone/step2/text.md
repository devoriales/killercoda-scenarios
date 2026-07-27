# Step 2 — SSH on a port of your choosing

This step contains the trap that catches almost everyone on Ubuntu 24.04. Read the whole thing before you close any sessions.

## The drop-in

```bash
cat > /etc/ssh/sshd_config.d/99-gateway.conf <<'CONF'
Port 22
Port 2222
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 20
X11Forwarding no
CONF
```{{copy}}

**Keep 22.** Remove it only once you have opened a session on 2222 and confirmed it works. Moving SSH is the single most effective way to lose a remote machine, and the whole point of keeping both is that a mistake stays recoverable.

Validate before applying anything:

```bash
sshd -t; echo "exit=$?"
```{{exec}}

```bash
systemctl restart ssh
```{{exec}}

## Now check your work, and do not trust the daemon

```bash
sshd -T | awk '$1=="port"{print $2}'
```{{exec}}

It says 22 and 2222. Now ask the kernel what is genuinely listening:

```bash
ss -tlnH | awk '$4 ~ /:(22|2222)$/ {print $4}'
```{{exec}}

**Only 22.** The daemon's own report of its configuration is correct and completely ineffective.

## Why

```bash
systemctl is-enabled ssh.socket; systemctl cat ssh.socket | grep -A3 sshd-socket-generator
```{{exec}}

`ssh` is **socket activated**. systemd owns the listening socket and starts `sshd` on demand, so the port belongs to `ssh.socket`, not to `sshd`. A generator reads your `Port` directives and writes them into the socket unit, but `systemctl restart ssh` restarts the *service* and never touches the socket that is actually listening.

```bash
systemctl daemon-reload && systemctl restart ssh.socket
```{{exec}}

```bash
ss -tlnH | awk '$4 ~ /:(22|2222)$/ {print $4}'
```{{exec}}

Both, at last.

> **Restarting the socket does not drop your session.** An established SSH connection is an already-accepted socket owned by a running `sshd`. Replacing the listener only affects *new* connections. That is the mechanism behind "keep your session open while you test", and it holds for the firewall in step 3 too.

## Your task

```bash
gateway-validate
```{{exec}}

Section 3 green: key-only authentication, and something genuinely listening on 2222.

When it is, click **Check**.
