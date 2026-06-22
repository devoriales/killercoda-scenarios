# Confirm the change on a node

A green "Success" in the UI is reassuring — but the real proof is on the node itself. The
playbook wrote `/etc/acme-release` on every host. Check it directly inside a node container:

```bash
docker exec lab_web1 cat /etc/acme-release
docker exec lab_web2 cat /etc/acme-release
docker exec lab_db1  cat /etc/acme-release
```

Each should print a line like:

```
Acme app configured by Semaphore on web1
```

That file did not exist before your run — Semaphore connected over SSH as the `ansible`
user, escalated with sudo, and created it, exactly as `ansible-playbook` would have from the
command line.

## What you built

- A web UI (reached through Killercoda's **Traffic / Ports**) driving real Ansible.
- A project wired up with an **SSH credential**, a **linked repository**, an **inventory**,
  and a **task template**.
- A **playbook run** with live output and a verifiable result on the managed nodes.

Click **Check** to confirm the marker is present on a node.
