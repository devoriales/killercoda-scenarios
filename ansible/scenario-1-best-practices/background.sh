#!/bin/bash
# Ansible lab background.sh — fully self-contained: it writes the entire Acme reference
# repo to /root/acme inline (no dependency on Killercoda asset copying), installs the
# toolchain, encrypts the per-environment vaults, warms the managed-node image, and
# initialises Git with the pre-commit safety nets.
#
# The install body is written to /root/setup.sh (single source of truth) and run from
# there. foreground.sh re-runs /root/setup.sh if it detects an incomplete environment, so
# a transient failure is recoverable. We do NOT use `set -e`: one failing command must
# never abort the rest of the setup. setup.sh is idempotent — it overwrites the repo files
# every run, so a half-built /root/acme always self-heals.
set -uo pipefail

# Write the tiny readiness waiter FIRST. foreground.sh just clears the screen and runs this
# file, so the student never sees the script source or a wait loop being typed into their
# terminal — only its short progress output.
cat > /root/wait-ready.sh <<'WAIT'
#!/bin/bash
set -uo pipefail
encrypted() { head -n1 "$1" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; }
ready() {
  command -v ansible       >/dev/null 2>&1 || return 1
  command -v ansible-vault >/dev/null 2>&1 || return 1
  [ -f /root/acme/playbooks/site.yml ] || return 1
  [ -d /root/acme/.git ] || return 1
  encrypted /root/acme/inventories/dev/group_vars/all/vault.yml  || return 1
  encrypted /root/acme/inventories/prod/group_vars/all/vault.yml || return 1
}
echo "Preparing the lab environment (installing Ansible, building the node image)..."
echo "This takes ~2-3 minutes — please wait."
ELAPSED=0; TIMEOUT=480; GRACE=90
while ! ready; do
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo; echo "Still finishing up. If Step 1 looks empty, run:  bash /root/setup.sh"
    exit 0
  fi
  # Self-heal: re-run the idempotent installer every ~30s past the grace period.
  if [ "$ELAPSED" -ge "$GRACE" ] && [ $((ELAPSED % 30)) -eq 0 ] && [ -f /root/setup.sh ]; then
    bash /root/setup.sh >/dev/null 2>&1
  fi
  printf '.'; sleep 5; ELAPSED=$((ELAPSED + 5))
done
echo; echo "Ready! The Acme Ansible repo is at /root/acme — start Step 1."
WAIT
chmod +x /root/wait-ready.sh

# Outer heredoc is quoted ('SETUP') so nothing expands here. Every file written inside also
# uses a quoted delimiter so contents (Jinja {{ }}, $ANSIBLE_VAULT, $vars) stay verbatim.
cat > /root/setup.sh <<'SETUP'
#!/bin/bash
# Idempotent installer for the Ansible best-practices lab. Safe to run repeatedly.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- 1. Toolchain (ansible is preinstalled on the ubuntu image; ensure the rest) -------
command -v ansible >/dev/null 2>&1 || { apt-get update -y >/dev/null 2>&1; apt-get install -y --no-install-recommends ansible >/dev/null 2>&1; }
command -v git     >/dev/null 2>&1 || apt-get install -y --no-install-recommends git >/dev/null 2>&1
command -v pip3    >/dev/null 2>&1 || apt-get install -y --no-install-recommends python3-pip >/dev/null 2>&1
# NOTE: the ubuntu backend has the docker engine but NOT the compose v2 plugin, so the lab
# uses plain `docker build` / `docker run` (docker/up.sh) — no docker-compose dependency.
# pre-commit + detect-secrets + ansible-lint: pip first, apt fallback for pre-commit.
pip3 install --break-system-packages -q pre-commit detect-secrets ansible-lint >/dev/null 2>&1 \
  || apt-get install -y --no-install-recommends pre-commit >/dev/null 2>&1 || true

# --- 2. Lay down the repo tree --------------------------------------------------------
mkdir -p /root/acme
cd /root/acme || exit 1
mkdir -p inventories/dev/group_vars/all inventories/dev/group_vars/webservers \
         inventories/prod/group_vars/all inventories/prod/group_vars/webservers \
         roles/webapp/defaults roles/webapp/vars roles/webapp/tasks roles/webapp/handlers \
         roles/webapp/templates roles/webapp/meta playbooks docker scripts

cat > README.md <<'EOF'
# Acme Ansible repo

Automation for Acme's web application across two environments (`dev`, `prod`), each with a
web tier (`web1`, `web2`) and a database tier (`db1`).

```
ansible.cfg                 # ONE shared config -> identical for all devs
inventories/
  dev/  prod/               # one directory PER ENVIRONMENT; never mix dev & prod
    hosts.yml               # which machines exist, grouped by role
    group_vars/
      all/vars.yml          # plain variables (committed readable)
      all/vault.yml         # secrets (committed ENCRYPTED)
      webservers/vars.yml   # variables for one group only
roles/
  webapp/                   # reusable unit: defaults, vars, tasks, handlers, templates, meta
playbooks/
  bootstrap.yml  site.yml   # orchestration: which roles run on which hosts
docker/                     # the fake servers (web1, web2, db1) for this lab
```

Throwaway lab vault passwords (they protect nothing real):

- dev vault password: `dev-lab-password`
- prod vault password: `prod-lab-password`
EOF

cat > ansible.cfg <<'EOF'
# ONE shared config in the repo root -> identical for all developers.
[defaults]
inventory = inventories/dev/hosts.yml
roles_path = roles
private_key_file = ./.ssh/lab_dev_ed25519
remote_user = ansible
host_key_checking = False
interpreter_python = auto_silent
retry_files_enabled = False

# Two vault-ids: each encrypted file is matched to the password file with the same label.
vault_identity_list = dev@.vault_pass.dev, prod@.vault_pass.prod

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
EOF

cat > requirements.txt <<'EOF'
# Pinned Python toolchain — every developer shares the exact same versions.
ansible-core==2.20.5
ansible-lint==24.12.2
pre-commit==4.0.1
detect-secrets==1.5.0
EOF

cat > requirements.yml <<'EOF'
---
# Pinned Ansible collections. Installed with:
#   ansible-galaxy collection install -r requirements.yml
collections:
  - name: ansible.posix
    version: "2.0.0"
  - name: community.general
    version: "10.1.0"
  - name: community.docker
    version: "4.4.0"
EOF

cat > .gitignore <<'EOF'
# Net 1 of the Git safety nets: the dangerous things can't even be tracked.

# Vault passwords — NEVER commit
.vault_pass*

# Private keys / certs
*.key
*.pem
id_*
*.ppk

# SSH material — only *.pub is shareable, and we keep even that out of Git
.ssh/

# Decrypted secret output / local env
*.dec
secrets.yml
.env

# Python / tooling noise
.venv/
__pycache__/
*.retry
EOF

cat > .pre-commit-config.yaml <<'EOF'
---
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: detect-private-key
      - id: end-of-file-fixer
      - id: trailing-whitespace

  - repo: local
    hooks:
      - id: ansible-vault-encrypted
        name: Ensure vault.yml files are encrypted
        entry: scripts/check-vault-encrypted.sh
        language: script
        files: 'group_vars/.*/vault\.yml$'
EOF

cat > scripts/check-vault-encrypted.sh <<'EOF'
#!/bin/bash
# pre-commit guard: fail if any matched group_vars vault.yml is not Ansible-Vault encrypted.
set -e
status=0
for f in "$@"; do
  if ! head -n1 "$f" | grep -q '^\$ANSIBLE_VAULT'; then
    echo "ERROR: $f is NOT vault-encrypted — refusing to commit a plaintext secret."
    status=1
  fi
done
exit "$status"
EOF
chmod +x scripts/check-vault-encrypted.sh

cat > inventories/dev/hosts.yml <<'EOF'
---
all:
  children:
    webservers:
      hosts:
        web1:
          ansible_host: 127.0.0.1
          ansible_port: 2201
        web2:
          ansible_host: 127.0.0.1
          ansible_port: 2202
    dbservers:
      hosts:
        db1:
          ansible_host: 127.0.0.1
          ansible_port: 2203
EOF

cat > inventories/prod/hosts.yml <<'EOF'
---
# Same node topology as dev in this lab, but a SEPARATE directory you must select with
# `-i inventories/prod/hosts.yml`.
all:
  children:
    webservers:
      hosts:
        web1:
          ansible_host: 127.0.0.1
          ansible_port: 2201
        web2:
          ansible_host: 127.0.0.1
          ansible_port: 2202
    dbservers:
      hosts:
        db1:
          ansible_host: 127.0.0.1
          ansible_port: 2203
EOF

cat > inventories/dev/group_vars/all/vars.yml <<'EOF'
---
# Plain variables — committed readable. They map friendly names onto the vault_* values.
environment_name: dev
db_host: db1
db_name: acme_app

db_password: "{{ vault_db_password }}"
api_token: "{{ vault_api_token }}"
EOF

cat > inventories/prod/group_vars/all/vars.yml <<'EOF'
---
environment_name: prod
db_host: db1
db_name: acme_app

db_password: "{{ vault_db_password }}"
api_token: "{{ vault_api_token }}"
EOF

cat > inventories/dev/group_vars/webservers/vars.yml <<'EOF'
---
# Variables for the webservers group only, in the DEV environment.
webapp_listen_port: 8080
EOF

cat > inventories/prod/group_vars/webservers/vars.yml <<'EOF'
---
# Same variable, different value in PROD — no playbook change required.
webapp_listen_port: 80
EOF

cat > roles/webapp/defaults/main.yml <<'EOF'
---
# LOW-precedence defaults — meant to be overridden by inventory or the play.
webapp_environment: unknown
webapp_listen_port: 8080
webapp_config_dir: /etc/webapp
webapp_config_file: "{{ webapp_config_dir }}/webapp.conf"
webapp_db_host: localhost
webapp_db_name: app
webapp_db_password: "CHANGEME"
webapp_api_token: "CHANGEME"
EOF

cat > roles/webapp/vars/main.yml <<'EOF'
---
# HIGH-precedence internals — do NOT override these from inventory.
__webapp_owner: root
__webapp_group: root
__webapp_config_mode: "0640"
EOF

cat > roles/webapp/tasks/main.yml <<'EOF'
---
- name: Ensure the webapp config directory exists
  ansible.builtin.file:
    path: "{{ webapp_config_dir }}"
    state: directory
    owner: "{{ __webapp_owner }}"
    group: "{{ __webapp_group }}"
    mode: "0755"

- name: Render the webapp configuration
  ansible.builtin.template:
    src: webapp.conf.j2
    dest: "{{ webapp_config_file }}"
    owner: "{{ __webapp_owner }}"
    group: "{{ __webapp_group }}"
    mode: "{{ __webapp_config_mode }}"
  notify: Restart webapp
EOF

cat > roles/webapp/handlers/main.yml <<'EOF'
---
- name: Restart webapp
  ansible.builtin.debug:
    msg: "webapp would be restarted now (lab placeholder — no real service to bounce)"
EOF

cat > roles/webapp/templates/webapp.conf.j2 <<'EOF'
# Managed by Ansible — do not edit by hand.
environment={{ webapp_environment }}
listen_port={{ webapp_listen_port }}
db_host={{ webapp_db_host }}
db_name={{ webapp_db_name }}
db_password={{ webapp_db_password }}
api_token={{ webapp_api_token }}
EOF

cat > roles/webapp/meta/main.yml <<'EOF'
---
galaxy_info:
  role_name: webapp
  author: Acme Platform Team
  description: Render the Acme web application configuration from inventory + vault values.
  company: Acme
  license: MIT
  min_ansible_version: "2.15"
  platforms:
    - name: Ubuntu
      versions:
        - jammy
        - noble
  galaxy_tags:
    - acme
    - webapp
dependencies: []
EOF

cat > playbooks/site.yml <<'EOF'
---
# Deploy the web application config. The INDIRECTION at the role boundary lives here: the
# environment's friendly db_password / api_token are mapped onto the role's webapp_*
# interface, so the role never sees raw vault_* names.
- name: Configure the Acme web application
  hosts: webservers
  become: true
  roles:
    - role: webapp
      vars:
        webapp_environment: "{{ environment_name }}"
        webapp_db_host: "{{ db_host }}"
        webapp_db_name: "{{ db_name }}"
        webapp_db_password: "{{ db_password }}"
        webapp_api_token: "{{ api_token }}"
        # webapp_listen_port is intentionally NOT mapped here: the webservers group_var of
        # the same name already overrides the role default (group_vars > role defaults).
EOF

cat > playbooks/bootstrap.yml <<'EOF'
---
# Authorize every developer's PUBLIC key (.ssh/*.pub) for the `ansible` user on all nodes.
# Idempotent and uses only ansible.builtin modules (no external collection needed).
- name: Authorize all developer SSH public keys on all nodes
  hosts: all
  become: true
  tasks:
    - name: Find local public keys
      ansible.builtin.find:
        paths: "{{ playbook_dir }}/../.ssh"
        patterns: "*.pub"
      delegate_to: localhost
      become: false
      run_once: true
      register: dev_pubkeys

    - name: Ensure the ansible user's .ssh directory exists
      ansible.builtin.file:
        path: /home/ansible/.ssh
        state: directory
        owner: ansible
        group: ansible
        mode: "0700"

    - name: Read each public key from the control node
      ansible.builtin.slurp:
        src: "{{ item.path }}"
      delegate_to: localhost
      become: false
      run_once: true
      loop: "{{ dev_pubkeys.files }}"
      loop_control:
        label: "{{ item.path | basename }}"
      register: dev_pubkey_contents

    - name: Authorize each developer key for the ansible user
      ansible.builtin.lineinfile:
        path: /home/ansible/.ssh/authorized_keys
        line: "{{ item.content | b64decode | trim }}"
        create: true
        owner: ansible
        group: ansible
        mode: "0600"
      loop: "{{ dev_pubkey_contents.results }}"
      loop_control:
        label: "{{ item.item.path | basename }}"
EOF

cat > docker/node.dockerfile <<'EOF'
# Managed-node image: an SSH server + sudo on top of a Python base (Ansible needs Python
# on the target). Key-based auth only — no passwords, no root login.
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server sudo \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /var/run/sshd \
 && useradd -m -s /bin/bash ansible \
 && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
 && chmod 0440 /etc/sudoers.d/ansible \
 && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EOF

cat > docker/entrypoint.sh <<'EOF'
#!/bin/bash
# Install every mounted PUBLIC key (.ssh/*.pub -> /keys) into the ansible user's
# authorized_keys, then run sshd in the foreground. Private keys never enter the node.
set -e

install -d -m 0700 -o ansible -g ansible /home/ansible/.ssh

if compgen -G "/keys/*.pub" > /dev/null 2>&1; then
  cat /keys/*.pub > /home/ansible/.ssh/authorized_keys
  chown ansible:ansible /home/ansible/.ssh/authorized_keys
  chmod 0600 /home/ansible/.ssh/authorized_keys
fi

ssh-keygen -A

exec /usr/sbin/sshd -D -e
EOF
chmod +x docker/entrypoint.sh

cat > docker/up.sh <<'EOF'
#!/bin/bash
# Build the node image once and start the three fake servers: web1, web2 (group
# webservers) and db1 (group dbservers). Each publishes SSH on a distinct localhost port
# matching ansible_port in the inventory. Uses plain docker (no compose plugin needed).
set -e
cd "$(dirname "$0")"                       # the docker/ directory
docker build -t acme-node -f node.dockerfile .
for spec in web1:2201 web2:2202 db1:2203; do
  name="${spec%%:*}"; port="${spec##*:}"
  docker rm -f "lab_${name}" >/dev/null 2>&1 || true
  docker run -d --name "lab_${name}" --hostname "${name}" \
    -p "${port}:22" -v "$(pwd)/../.ssh:/keys:ro" acme-node >/dev/null
done
docker ps --filter name=lab_ --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
EOF
chmod +x docker/up.sh

cat > docker/down.sh <<'EOF'
#!/bin/bash
# Stop and remove the three lab nodes.
docker rm -f lab_web1 lab_web2 lab_db1 >/dev/null 2>&1 || true
echo "lab nodes removed."
EOF
chmod +x docker/down.sh

cat > .ansible-lint <<'EOF'
---
profile: min
offline: true
EOF

# --- 3. Vault passwords (throwaway lab values) ----------------------------------------
[ -f .vault_pass.dev ]  || printf 'dev-lab-password'  > .vault_pass.dev
[ -f .vault_pass.prod ] || printf 'prod-lab-password' > .vault_pass.prod
chmod 600 .vault_pass.dev .vault_pass.prod

# --- 4. Encrypt the per-environment vaults (idempotent; never leave plaintext) --------
printf -- '---\nvault_db_password: dev-Sup3rSecret-DB-pw\nvault_api_token: dev-tok-abc123xyz\n'   > /tmp/vault_dev.yml
printf -- '---\nvault_db_password: prod-DB-pw-9z8y7x\nvault_api_token: prod-tok-zzz999\n'          > /tmp/vault_prod.yml
for env in dev prod; do
  dst="inventories/$env/group_vars/all/vault.yml"
  if ! head -n1 "$dst" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
    cp "/tmp/vault_${env}.yml" "$dst"
    ansible-vault encrypt --encrypt-vault-id "$env" "$dst" >/dev/null 2>&1 || true
  fi
done
rm -f /tmp/vault_dev.yml /tmp/vault_prod.yml

# --- 5. Collections (best-effort) + warm the managed-node image -----------------------
ansible-galaxy collection install -r requirements.yml >/dev/null 2>&1 || true
docker build -t acme-node -f docker/node.dockerfile docker/ >/dev/null 2>&1 || true

# --- 6. Git repo + pre-commit safety nets (clean baseline) ----------------------------
if [ ! -d .git ]; then
  git init -q
  git config user.email "dev@acme.test"
  git config user.name  "Acme Dev"
  detect-secrets scan > .secrets.baseline 2>/dev/null || echo '{}' > .secrets.baseline
  pre-commit install       >/dev/null 2>&1 || true
  pre-commit install-hooks >/dev/null 2>&1 || true
  git add -A >/dev/null 2>&1 || true
  git commit -q --no-verify -m "Initial Acme Ansible repo (encrypted vaults)" >/dev/null 2>&1 || true
fi

echo "[setup] Ansible lab repo ready at /root/acme."
SETUP

chmod +x /root/setup.sh
bash /root/setup.sh
echo "[background] Ansible lab ready."
