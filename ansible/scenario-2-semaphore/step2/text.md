# Meet the managed nodes & the project

Before automating anything, see what you're automating *against* and what's already set up.

## The managed nodes

Three lightweight containers act as your servers, each reachable over SSH on a localhost
port — exactly what the inventory points at:

```bash
docker ps --filter name=lab_ --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

| Node | Group | SSH |
|---|---|---|
| `web1` | webservers | 127.0.0.1:2201 |
| `web2` | webservers | 127.0.0.1:2202 |
| `db1`  | dbservers  | 127.0.0.1:2203 |

The repository Semaphore runs lives at `/root/lab`. Take a look at the two files that matter:

```bash
cat /root/lab/inventory/hosts.yml
cat /root/lab/playbooks/site.yml
```

The playbook pings each node and writes a marker file to `/etc/acme-release`.

## What's already in the project

Open the **Acme Automation** project in Semaphore (left sidebar) and look at:

- **Key Store** — a `nodes-ssh` SSH key (the credential that lets Semaphore log in to the
  nodes as the `ansible` user), alongside the built-in `None` key.
- **Repositories** — `acme`, linked to the lab's local git repo on the `master`/`main`
  branch.

What's **missing** — and what you'll build next — is an **Inventory** and a **Task
Template**. That's the part you wire up by hand.

Click **Check** once the three managed nodes are running.
