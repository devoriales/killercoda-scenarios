#!/bin/bash
# Semaphore UI lab background.sh — fully self-contained (no Killercoda asset copy). It:
#   * writes a minimal Ansible repo to /root/lab and turns it into a bare git repo Semaphore
#     can clone locally (file:///repo.git),
#   * builds + starts three managed-node containers (web1/web2/db1) reached over SSH on
#     localhost 2201/2202/2203 (same pattern as the best-practices lab),
#   * runs Semaphore UI in a container on port 3000 (reachable via Killercoda Traffic/Ports),
#   * pre-seeds a project + SSH credential + linked repository via the Semaphore REST API.
#
# The install body lives in /root/setup.sh (single source of truth) and is idempotent — it
# overwrites the repo files and re-applies container/API state every run, so a half-built lab
# self-heals. We do NOT use `set -e`: one failing command must never abort the rest.
set -uo pipefail

# Progress display — written FIRST so foreground.sh can run it immediately. foreground.sh
# runs this as a subprocess so the student sees only its output, never the script source.
cat > /root/progress.sh <<'PROGRESS'
#!/bin/bash
steps=("Installing tools & writing the repo" "Building & starting managed nodes" "Starting Semaphore & seeding the project")
signals=("/tmp/kc-step1" "/tmp/kc-step2" "/tmp/kc-ready")

echo ""
echo "  Preparing your Semaphore lab, have a coffee (~2-3 minutes)..."
echo ""

for i in "${!signals[@]}"; do
  while [ ! -f "${signals[$i]}" ]; do
    printf "\r  ⏳  %s..." "${steps[$i]}"
    sleep 1
  done
  printf "\r  ✅  %-45s\n" "${steps[$i]}"
done

echo ""
echo "  Lab ready!  Open the Traffic/Ports menu (top-right) and access port 3000."
echo "  Semaphore login:  admin / ChangeMe123"
echo ""
PROGRESS
chmod +x /root/progress.sh

# Outer heredoc quoted ('SETUP') so nothing expands here; inner files use quoted delimiters
# so their contents (YAML, Jinja, JSON) stay verbatim.
cat > /root/setup.sh <<'SETUP'
#!/bin/bash
# Idempotent installer for the Semaphore UI lab. Safe to run repeatedly.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------------------
# Tunables — verified empirically against a running container during authoring.
# SQLite is the simplest embedded store that current Semaphore supports (BoltDB was removed
# by 2.18). The `-ansibleX` image flavour bundles ansible-core, which the plain image omits.
# ---------------------------------------------------------------------------------------
SEMAPHORE_IMAGE="semaphoreui/semaphore:v2.18.12-ansible2.16.5"
SEM_URL="http://127.0.0.1:3000"
SEM_USER="admin"
SEM_PASS="ChangeMe123"
PROJECT_NAME="Acme Automation"

# --- 1. Tools (docker is preinstalled on the ubuntu backend) ---------------------------
command -v git  >/dev/null 2>&1 || { apt-get update -y >/dev/null 2>&1; apt-get install -y --no-install-recommends git  >/dev/null 2>&1; }
command -v curl >/dev/null 2>&1 || apt-get install -y --no-install-recommends curl >/dev/null 2>&1
command -v jq   >/dev/null 2>&1 || apt-get install -y --no-install-recommends jq   >/dev/null 2>&1

mkdir -p /root/.lab

# --- 2. SSH keypair the nodes trust and Semaphore will use as a credential -------------
mkdir -p /root/lab/.ssh
if [ ! -f /root/lab/.ssh/lab_ed25519 ]; then
  ssh-keygen -t ed25519 -N '' -C 'semaphore-lab' -f /root/lab/.ssh/lab_ed25519 >/dev/null 2>&1
fi
chmod 600 /root/lab/.ssh/lab_ed25519

# --- 3. The Ansible repo Semaphore will run (minimal, ansible.builtin only) ------------
mkdir -p /root/lab/inventory /root/lab/playbooks /root/lab/docker

cat > /root/lab/ansible.cfg <<'EOF'
# Picked up automatically when Semaphore runs from the repo root.
[defaults]
inventory = inventory/hosts.yml
remote_user = ansible
host_key_checking = False
interpreter_python = auto_silent
retry_files_enabled = False

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
EOF

cat > /root/lab/inventory/hosts.yml <<'EOF'
---
# Three managed nodes, reached over SSH on localhost. Semaphore runs with --network host,
# so 127.0.0.1:<port> resolves to the node containers exactly as it does from the terminal.
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

cat > /root/lab/playbooks/site.yml <<'EOF'
---
# A small, observable playbook: prove connectivity and drop a marker file you can inspect
# afterwards. Uses only ansible.builtin so it needs no extra collections.
- name: Configure the Acme application
  hosts: all
  become: true
  tasks:
    - name: Check connectivity to the node
      ansible.builtin.ping:

    - name: Write the Acme release marker
      ansible.builtin.copy:
        dest: /etc/acme-release
        content: "Acme app configured by Semaphore on {{ inventory_hostname }}\n"
        owner: root
        group: root
        mode: "0644"

    - name: Report where we ran
      ansible.builtin.debug:
        msg: "Configured {{ inventory_hostname }} via {{ ansible_host }}:{{ ansible_port }}"
EOF

cat > /root/lab/README.md <<'EOF'
# Acme automation (Semaphore lab)

The repository Semaphore runs in this lab.

- `inventory/hosts.yml` — the three managed nodes (web1, web2, db1).
- `playbooks/site.yml` — pings each node and writes `/etc/acme-release`.
- `ansible.cfg` — shared config (become via sudo, key-based auth as the `ansible` user).
EOF

# --- 4. Managed-node Docker image + launcher (same pattern as the best-practices lab) ---
cat > /root/lab/docker/node.dockerfile <<'EOF'
# Managed-node image: sshd + sudo on a Python base. Key-based auth only.
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server sudo \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/sshd \
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

cat > /root/lab/docker/entrypoint.sh <<'EOF'
#!/bin/bash
# Install every mounted PUBLIC key (/keys/*.pub) into the ansible user's authorized_keys,
# then run sshd in the foreground. Private keys never enter the node.
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
chmod +x /root/lab/docker/entrypoint.sh

cat > /root/lab/docker/up.sh <<'EOF'
#!/bin/bash
# Build the node image once and start web1, web2, db1 with SSH on localhost 2201/2202/2203.
set -e
cd "$(dirname "$0")"
docker build -t acme-node -f node.dockerfile .
for spec in web1:2201 web2:2202 db1:2203; do
  name="${spec%%:*}"; port="${spec##*:}"
  docker rm -f "lab_${name}" >/dev/null 2>&1 || true
  docker run -d --name "lab_${name}" --hostname "${name}" \
    -p "${port}:22" -v "$(pwd)/../.ssh:/keys:ro" acme-node >/dev/null
done
docker ps --filter name=lab_ --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
EOF
chmod +x /root/lab/docker/up.sh

cat > /root/lab/docker/down.sh <<'EOF'
#!/bin/bash
docker rm -f lab_web1 lab_web2 lab_db1 >/dev/null 2>&1 || true
echo "lab nodes removed."
EOF
chmod +x /root/lab/docker/down.sh

touch /tmp/kc-step1

# --- 5. Git repo + bare clone Semaphore can reach at file:///repo.git ------------------
if [ ! -d /root/lab/.git ]; then
  git -C /root/lab init -q
  git -C /root/lab config user.email "dev@acme.test"
  git -C /root/lab config user.name  "Acme Dev"
fi
# .ssh holds a private key — keep it out of the repo Semaphore clones.
printf '.ssh/\n' > /root/lab/.gitignore
git -C /root/lab add -A >/dev/null 2>&1 || true
git -C /root/lab commit -q -m "Acme automation repo" >/dev/null 2>&1 || true
LAB_BRANCH="$(git -C /root/lab symbolic-ref --short HEAD 2>/dev/null || echo master)"
rm -rf /root/lab.git
git clone -q --bare /root/lab /root/lab.git >/dev/null 2>&1

# --- 6. Build & start the managed nodes ------------------------------------------------
bash /root/lab/docker/up.sh >/dev/null 2>&1 || true
touch /tmp/kc-step2

# --- 7. Start Semaphore (host networking: reaches 127.0.0.1:220x AND exposes 3000) -----
docker pull "$SEMAPHORE_IMAGE" >/dev/null 2>&1 || true
docker rm -f lab_semaphore >/dev/null 2>&1 || true
docker run -d --name lab_semaphore --network host \
  -e SEMAPHORE_DB_DIALECT=sqlite \
  -e SEMAPHORE_ADMIN="$SEM_USER" \
  -e SEMAPHORE_ADMIN_PASSWORD="$SEM_PASS" \
  -e SEMAPHORE_ADMIN_NAME="Admin" \
  -e SEMAPHORE_ADMIN_EMAIL="admin@acme.test" \
  -e SEMAPHORE_PORT="3000" \
  -v /root/lab.git:/repo.git:ro \
  "$SEMAPHORE_IMAGE" >/dev/null 2>&1 || true

# --- 8. Shared API helper (sourced by the step verify.sh scripts too) ------------------
cat > /root/.lab/api.sh <<EOF
SEM_URL="$SEM_URL"
SEM_USER="$SEM_USER"
SEM_PASS="$SEM_PASS"
PROJECT_NAME="$PROJECT_NAME"
COOKIE=/root/.lab/cookies.txt
sem_login()  { curl -s -c "\$COOKIE" -H 'Content-Type: application/json' -d "{\"auth\":\"\$SEM_USER\",\"password\":\"\$SEM_PASS\"}" "\$SEM_URL/api/auth/login" >/dev/null; }
sem_get()    { curl -s -b "\$COOKIE" "\$SEM_URL/api\$1"; }
sem_post()   { curl -s -b "\$COOKIE" -H 'Content-Type: application/json' -d "\$2" "\$SEM_URL/api\$1"; }
sem_pid()    { sem_get /projects | jq -r --arg n "\$PROJECT_NAME" '.[] | select(.name==\$n) | .id' | head -n1; }
EOF

# --- 9. Wait for Semaphore, then pre-seed project + credential + repository -------------
. /root/.lab/api.sh
for _ in $(seq 1 120); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "$SEM_URL/" 2>/dev/null)" = "200" ] && break
  sleep 1
done

# Semaphore runs git as a non-root user against a root-owned bind-mounted repo; without this
# git aborts every clone with "detected dubious ownership". --system is read regardless of
# the per-task HOME Semaphore sets.
docker exec -u 0 lab_semaphore git config --system --add safe.directory '*' >/dev/null 2>&1 || true

sem_login
PID="$(sem_pid)"
if [ -z "$PID" ] || [ "$PID" = "null" ]; then
  PID="$(sem_post /projects "$(jq -n --arg n "$PROJECT_NAME" '{name:$n,alert:false}')" | jq -r '.id')"
fi

if [ -n "$PID" ] && [ "$PID" != "null" ]; then
  # The SSH key the nodes trust. Semaphore auto-creates a built-in "None" key per project,
  # which we reuse for the repository's (unused) key slot.
  if ! sem_get "/project/$PID/keys" | jq -e '.[] | select(.name=="nodes-ssh")' >/dev/null 2>&1; then
    PK="$(cat /root/lab/.ssh/lab_ed25519)"
    sem_post "/project/$PID/keys" "$(jq -n --argjson p "$PID" --arg pk "$PK" '{name:"nodes-ssh",type:"ssh",project_id:$p,ssh:{login:"ansible",passphrase:"",private_key:$pk}}')" >/dev/null
  fi
  NONE_ID="$(sem_get "/project/$PID/keys" | jq -r '.[] | select(.type=="none") | .id' | head -n1)"
  # Repository pointing at the local bare repo.
  if ! sem_get "/project/$PID/repositories" | jq -e '.[] | select(.name=="acme")' >/dev/null 2>&1; then
    sem_post "/project/$PID/repositories" "$(jq -n --argjson p "$PID" --argjson k "$NONE_ID" --arg b "$LAB_BRANCH" '{name:"acme",project_id:$p,git_url:"file:///repo.git",git_branch:$b,ssh_key_id:$k}')" >/dev/null
  fi
  # An empty environment so the student can attach one when creating a template.
  if ! sem_get "/project/$PID/environment" | jq -e '.[] | select(.name=="empty")' >/dev/null 2>&1; then
    sem_post "/project/$PID/environment" "$(jq -n --argjson p "$PID" '{name:"empty",project_id:$p,json:"{}",env:"{}"}')" >/dev/null
  fi
fi

echo "[setup] Semaphore lab ready at $SEM_URL (login: $SEM_USER / $SEM_PASS)."
touch /tmp/kc-ready
SETUP

chmod +x /root/setup.sh
bash /root/setup.sh
echo "[background] Semaphore lab ready."
