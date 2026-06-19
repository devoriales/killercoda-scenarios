# Step 4 — Playbooks: Orchestrating Work

## What is a playbook?

An ad hoc command runs one module once. A **playbook** chains many modules across many hosts in a defined order, with full control over privilege escalation, error handling, conditional execution, and loops.

A playbook is a YAML file containing one or more **plays**. Each play maps a set of tasks to a host group:

```
playbook
└── play  (hosts: webservers)
    ├── task: Install nginx
    ├── task: Deploy configuration
    └── task: Start nginx
```

Each **task** invokes exactly one module. The tasks within a play run sequentially on each host. Hosts within a group run in parallel (up to the configured `forks` limit, which defaults to 5).

## Write a playbook

```bash
cat > /root/lab/install-nginx.yml <<'EOF'
---
- name: Install and start nginx on web servers
  hosts: webservers
  become: true

  tasks:
    - name: Install nginx
      package:
        name: nginx
        state: present

    - name: Start nginx
      command: nginx
      args:
        creates: /var/run/nginx.pid
EOF
```{{exec}}

> **Container note.** The managed nodes run inside Docker containers with no init system — systemd is not present. The `command: nginx` task starts nginx directly. The `creates: /var/run/nginx.pid` argument makes the task idempotent: if the pid file already exists, Ansible skips the command entirely. On a real server managed by systemd you would use the `service` module instead:
> ```yaml
> - name: Ensure nginx is running and enabled
>   service:
>     name: nginx
>     state: started
>     enabled: true
> ```

## Run the playbook

```bash
cd /root/lab && ansible-playbook install-nginx.yml
```{{exec}}

Read the output:

- **TASK** lines show what ran and the result per host
- `changed` (yellow) — the module made a change to reach desired state
- `ok` (green) — desired state already existed; no change was needed
- `failed` (red) — the task failed; the play stops unless `ignore_errors: true`
- The **PLAY RECAP** at the bottom summarises totals per host

## Idempotency — run it again

```bash
cd /root/lab && ansible-playbook install-nginx.yml
```{{exec}}

Every task should now show `ok`. The playbook ran to completion and changed nothing — because the desired state already existed. Playbooks are not scripts you run once. They are **declarations of desired state** that are safe to re-run at any time, from any state.

## Check mode (dry run)

```bash
cd /root/lab && ansible-playbook install-nginx.yml --check
```{{exec}}

`--check` runs the playbook without applying any changes. Ansible evaluates each task and reports what *would* change. Use it before deploying a playbook to a sensitive system.

> Some modules do not support check mode (notably `command` and `shell`). Tasks using those modules will show `skipped` in check mode.
