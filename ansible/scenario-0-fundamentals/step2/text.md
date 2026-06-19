# Step 2 — Inventory: Describing Your Fleet

## What is inventory?

Before Ansible can automate anything, it needs to know what machines exist and how to reach them. The **inventory** is that list.

At its simplest, inventory is a text file you write by hand. At its most powerful, it is a dynamic plugin that queries AWS, Azure, GCP, Kubernetes, or any external API to discover machines in real time. Either way, Ansible resolves the inventory before every run.

## INI format

The default format is INI-style. Each `[section]` declares a **group**. Lines inside a section are **hosts**. `key=value` pairs on the same line as a host are **host variables** — they override default connection settings for that specific host.

```ini
[webservers]
web1 ansible_host=localhost ansible_port=2201

[dbservers]
db1 ansible_host=localhost ansible_port=2203
```

Two groups exist in every inventory regardless of whether you declare them:

| Implicit group | Contains |
|----------------|---------|
| `all` | Every host in every group |
| `ungrouped` | Hosts that belong to no named group |

You can target both with `hosts: all` in a playbook.

## Create the inventory

```bash
mkdir -p /root/lab/inventory
cat > /root/lab/inventory/hosts.ini <<'EOF'
[webservers]
web1 ansible_host=localhost ansible_port=2201
web2 ansible_host=localhost ansible_port=2202

[dbservers]
db1 ansible_host=localhost ansible_port=2203
EOF
```{{exec}}

## Inspect the resolved inventory

Use `ansible-inventory` to see exactly what Ansible resolves from the file. This is the authoritative view — it catches typos and merging surprises before you run a playbook:

```bash
cd /root/lab && ansible-inventory --graph
```{{exec}}

`--graph` shows the group hierarchy as a tree:
```
@all:
  |--@ungrouped:
  |--@webservers:
  |  |--web1
  |  |--web2
  |--@dbservers:
  |  |--db1
```

```bash
cd /root/lab && ansible-inventory --host web1
```{{exec}}

`--host` dumps every resolved variable for a single host — useful for debugging why a host variable has an unexpected value.

## Why groups matter

Playbooks target **groups**, not individual hosts. Writing `hosts: webservers` means the play runs on every current member of that group. Add a new host to the `[webservers]` section and the next playbook run includes it automatically — no playbook edits required.

Groups can also be **nested** (a group whose members are other groups) and can carry shared variables via `group_vars/` directories, which you will use in Step 5.

## YAML format

The same inventory in YAML format — both are valid, use whichever your team prefers:

```yaml
all:
  children:
    webservers:
      hosts:
        web1:
          ansible_host: localhost
          ansible_port: 2201
        web2:
          ansible_host: localhost
          ansible_port: 2202
    dbservers:
      hosts:
        db1:
          ansible_host: localhost
          ansible_port: 2203
```
