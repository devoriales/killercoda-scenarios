# Step 7 — Roles: Reusable Automation Units

## What is a role?

A **role** is a self-contained, reusable bundle of Ansible automation. It packages tasks, handlers, variables, defaults, templates, and static files into a predictable directory layout.

A role is not a playbook. It is a component that a playbook applies. One playbook can apply multiple roles to different host groups. The same role can be applied across multiple playbooks without duplication.

Roles solve two problems:
1. **Readability.** A playbook that says `roles: [nginx, postgres, monitoring]` is immediately understandable. A flat playbook with 200 tasks is not.
2. **Reuse.** A role can be shared across projects, teams, and organisations — including through Ansible Galaxy, the community hub for published roles.

## Standard directory layout

```
roles/
└── webserver/
    ├── tasks/
    │   └── main.yml       ← entry point; Ansible loads this automatically
    ├── handlers/
    │   └── main.yml       ← handlers defined here, scoped to this role
    ├── defaults/
    │   └── main.yml       ← lowest-precedence variable defaults for this role
    ├── vars/
    │   └── main.yml       ← higher-precedence role variables (rarely changed by users)
    ├── files/             ← static files referenced by copy tasks
    ├── templates/         ← Jinja2 templates (.j2 files) for the template module
    └── meta/
        └── main.yml       ← role metadata: author, licence, and role dependencies
```

Ansible automatically loads `tasks/main.yml` when a role is applied. From there you can include additional task files with `import_tasks` or `include_tasks`. The same applies to `handlers/main.yml`, `defaults/main.yml`, and `vars/main.yml`.

## Create a role

`ansible-galaxy role init` generates the complete skeleton:

```bash
cd /root/lab && ansible-galaxy role init roles/webserver
```{{exec}}

```bash
find /root/lab/roles/webserver -type f | sort
```{{exec}}

## Populate the role

Move the work from your earlier playbooks into the role's tasks and handlers:

```bash
cat > /root/lab/roles/webserver/tasks/main.yml <<'EOF'
---
- name: Install nginx
  package:
    name: nginx
    state: present

- name: Start nginx
  command: nginx
  args:
    creates: /var/run/nginx.pid

- name: Deploy virtual host configuration
  copy:
    content: |
      server {
          listen {{ app_port }};
          server_name {{ inventory_hostname }};
          location /health {
              return 200 'OK\n';
              add_header Content-Type text/plain;
          }
      }
    dest: /etc/nginx/conf.d/app.conf
    owner: root
    group: root
    mode: '0644'
  notify: Reload nginx configuration
EOF
```{{exec}}

```bash
cat > /root/lab/roles/webserver/handlers/main.yml <<'EOF'
---
- name: Reload nginx configuration
  command: nginx -s reload
EOF
```{{exec}}

```bash
cat > /root/lab/roles/webserver/defaults/main.yml <<'EOF'
---
# Default port — overridden by group_vars/webservers.yml
app_port: 8080
EOF
```{{exec}}

## Apply the role from a playbook

```bash
cat > /root/lab/site.yml <<'EOF'
---
- name: Configure web servers
  hosts: webservers
  become: true
  roles:
    - webserver
EOF
```{{exec}}

```bash
cd /root/lab && ansible-playbook site.yml
```{{exec}}

Because nginx is already installed and the config already deployed, every task reports `ok`. The role is idempotent — applying it again converges to the same state without disruption.

## Role search path

Ansible resolves roles from multiple locations, checked in this order:

1. `./roles/` relative to the playbook file ← what you just used
2. `~/.ansible/roles/` for user-installed roles
3. `/etc/ansible/roles/` for system-wide roles
4. Directories listed in `roles_path` in `ansible.cfg`

Roles installed with `ansible-galaxy role install <name>` land in `~/.ansible/roles/`. You can pin the version and commit `requirements.yml` to source control so every team member installs the same versions.

## What comes next

With roles as the building block, the natural next topic is **collections** — namespaced bundles that can contain roles, modules, plugins, and documentation together. Collections are the distribution unit for Ansible Galaxy and Red Hat Automation Hub.
