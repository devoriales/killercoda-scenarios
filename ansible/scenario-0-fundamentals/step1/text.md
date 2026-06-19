# Step 1 — The Control Node

## What is the control node?

The **control node** is the machine where Ansible is installed and from which all automation is driven. It is the only machine that requires Ansible. Managed nodes need no Ansible installation at all — just Python and an open SSH port.

This is what makes Ansible **agentless**. There is no daemon running on your servers waiting for instructions. There is no agent binary to install, upgrade, or secure. Ansible connects over the protocols that are already present — SSH on Linux/macOS, WinRM on Windows — does its work, and disconnects.

```
Control node  (this terminal)
     │
     ├── SSH ──▶  web1  (port 2201)
     ├── SSH ──▶  web2  (port 2202)
     └── SSH ──▶  db1   (port 2203)
```

The control node reads your playbooks, resolves your inventory, pushes module code to managed nodes, executes it there, collects the JSON results, and decides what to do next. Every decision happens here; managed nodes are passive targets.

## Explore what is installed

```bash
ansible --version
```{{exec}}

The output shows: the Ansible version, the Python interpreter in use, the config file that was loaded (or `None`), the module library path, and the executable path.

Ansible ships several CLI tools:

```bash
ls /usr/bin/ansible*
```{{exec}}

| Tool | Purpose |
|------|---------|
| `ansible` | Run a single module against hosts ad hoc |
| `ansible-playbook` | Execute a YAML playbook |
| `ansible-config` | Inspect and validate configuration |
| `ansible-inventory` | Dump and inspect the resolved inventory |
| `ansible-galaxy` | Install roles and collections |
| `ansible-doc` | Browse module documentation offline |
| `ansible-vault` | Encrypt and decrypt secrets |

## Create ansible.cfg

Ansible looks for configuration in this order, using the first match:

1. `$ANSIBLE_CONFIG` environment variable (path to a file)
2. `./ansible.cfg` in the current working directory
3. `~/.ansible.cfg` in the user's home directory
4. `/etc/ansible/ansible.cfg` system-wide fallback

You will work from `/root/lab/`. Create a config file there:

```bash
mkdir -p /root/lab
cat > /root/lab/ansible.cfg <<'EOF'
[defaults]
inventory        = ./inventory/hosts.ini
remote_user      = ansible
private_key_file = /root/.ssh/id_ed25519
host_key_checking = False

[privilege_escalation]
become      = False
become_method = sudo
EOF
```{{exec}}

`host_key_checking = False` skips SSH host-key verification. This is acceptable in a short-lived lab where nodes are rebuilt frequently. In production, leave it `True` and pre-populate known hosts.

Confirm Ansible picks up the new config:

```bash
cd /root/lab && ansible --version | grep 'config file'
```{{exec}}

You should see `config file = /root/lab/ansible.cfg`.
