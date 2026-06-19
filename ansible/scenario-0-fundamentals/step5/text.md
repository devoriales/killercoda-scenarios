# Step 5 — Variables and Facts

## Variables

Hardcoding values inside a playbook couples your automation to a specific environment. Variables let you define values once and reference them everywhere, tune behaviour per host or group, and accept input at runtime.

Ansible resolves variables from many sources. The higher the source in this list, the higher its **precedence** — a later source overrides an earlier one:

| Source | Precedence |
|--------|-----------|
| Role defaults (`defaults/main.yml`) | lowest |
| Inventory group variables | ↑ |
| Inventory host variables | ↑ |
| `group_vars/` files | ↑ |
| `host_vars/` files | ↑ |
| Play `vars:` section | ↑ |
| `vars_files:` included in a play | ↑ |
| Extra vars (`-e` on the command line) | highest |

Understanding precedence prevents confusing overrides. When a variable has an unexpected value, work through the list to find which source is winning.

## group_vars and host_vars

Ansible automatically loads variables from files named after groups and hosts. If a file (or directory) exists at `group_vars/<groupname>.yml` relative to the playbook, Ansible loads it for every host in that group before the play runs.

Create group variables for the web tier:

```bash
mkdir -p /root/lab/group_vars
cat > /root/lab/group_vars/webservers.yml <<'EOF'
app_port: 8080
app_name: meridian-web
EOF
```{{exec}}

```bash
cat > /root/lab/group_vars/dbservers.yml <<'EOF'
db_port: 5432
db_name: meridian_db
EOF
```{{exec}}

These variables are automatically in scope for any play that targets `webservers` or `dbservers`. No `import` or `include` is needed.

## Facts

**Facts** are variables Ansible discovers about managed nodes at the start of a play. They are collected by the `setup` module, which runs automatically when `gather_facts: true` (the default). Facts describe the actual state of the node:

| Fact | Example value |
|------|---------------|
| `ansible_hostname` | `web1` |
| `ansible_distribution` | `Debian` |
| `ansible_distribution_version` | `12` |
| `ansible_kernel` | `5.15.0-107-generic` |
| `ansible_memtotal_mb` | `3940` |
| `ansible_default_ipv4.address` | `172.17.0.2` |

Facts are referenced in templates and tasks just like variables — by wrapping the fact name in `{{ }}`.

## Use facts and variables in a playbook

```bash
cat > /root/lab/node-info.yml <<'EOF'
---
- name: Write node information to each host
  hosts: all
  become: true

  tasks:
    - name: Write node info file using facts and variables
      copy:
        content: |
          Hostname:     {{ ansible_hostname }}
          OS:           {{ ansible_distribution }} {{ ansible_distribution_version }}
          Kernel:       {{ ansible_kernel }}
          CPU cores:    {{ ansible_processor_vcpus }}
          App port:     {{ app_port | default('N/A') }}
          DB port:      {{ db_port | default('N/A') }}
        dest: /tmp/node_info.txt
EOF
```{{exec}}

```bash
cd /root/lab && ansible-playbook node-info.yml
```{{exec}}

Read the result from each node:

```bash
cd /root/lab && ansible all -m command -a "cat /tmp/node_info.txt"
```{{exec}}

Web servers show `App port: 8080` from `group_vars/webservers.yml`. The database server shows `DB port: 5432`. Neither shows the other group's variable. This is group variable scoping working correctly.

## register — capture task output

The `register` keyword saves a task's return value as a variable, making it available to later tasks in the same play:

```bash
cat > /root/lab/register-demo.yml <<'EOF'
---
- name: Demonstrate register
  hosts: web1

  tasks:
    - name: Get disk usage
      command: df -h /
      register: disk_result

    - name: Print the output
      debug:
        msg: "{{ disk_result.stdout_lines }}"
EOF
```{{exec}}

```bash
cd /root/lab && ansible-playbook register-demo.yml
```{{exec}}

`disk_result` is a dictionary. `.stdout_lines` is a list of strings (one per line). `.rc` is the return code. `.stdout` is the raw output string. Ansible documents the return value structure in `ansible-doc <module>`.
