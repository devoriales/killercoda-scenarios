#!/bin/bash
# background.sh — Ansible fundamentals lab.
# Writes setup.sh (the idempotent installer) then runs it in the background.
# foreground.sh clears the screen and runs /root/progress.sh (written below).
# progress.sh watches /tmp/kc-step1..3 and /tmp/kc-ready sentinel files
# written by setup.sh to display named progress stages to the student.
# Uses `set -uo pipefail` but NOT `set -e`: one failing step must never abort setup.
set -uo pipefail

# Write the progress display script FIRST so foreground.sh can run it immediately.
cat > /root/progress.sh <<'PROGRESS'
#!/bin/bash
steps=("Installing Ansible" "Building managed-node image" "Starting web1, web2, db1" "Configuring SSH access")
signals=("/tmp/kc-step1" "/tmp/kc-step2" "/tmp/kc-step3" "/tmp/kc-ready")

echo ""
echo "  Preparing your Ansible lab (~3 minutes)..."
echo ""

for i in "${!signals[@]}"; do
  while [ ! -f "${signals[$i]}" ]; do
    printf "\r  ⏳  %s..." "${steps[$i]}"
    sleep 1
  done
  printf "\r  ✅  %-45s\n" "${steps[$i]}"
done

echo ""
echo "  Lab ready!  Your workspace is at /root/lab"
echo ""
PROGRESS
chmod +x /root/progress.sh

# --- idempotent installer ---------------------------------------------------------------
# The outer heredoc uses a quoted delimiter ('SETUP') so nothing inside is expanded here.
# Files written inside SETUP also use quoted delimiters so Jinja {{ }}, $vars, etc.
# reach disk verbatim.
cat > /root/setup.sh <<'SETUP'
#!/bin/bash
# Idempotent: safe to run multiple times. Re-running always converges to a correct state.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. Ansible ─────────────────────────────────────────────────────────────────────────────
command -v ansible >/dev/null 2>&1 || {
  apt-get update -y -qq >/dev/null 2>&1
  apt-get install -y -qq --no-install-recommends ansible >/dev/null 2>&1
}
touch /tmp/kc-step1

# 2. SSH key for root (the control node) ─────────────────────────────────────────────────
mkdir -p /root/.ssh && chmod 700 /root/.ssh
if [ ! -f /root/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
fi

# 3. Managed-node Docker image ────────────────────────────────────────────────────────────
IMGDIR=/opt/ansible-fundamentals-node
mkdir -p "$IMGDIR"
cp /root/.ssh/id_ed25519.pub "$IMGDIR/authorized_keys"

cat > "$IMGDIR/Dockerfile" <<'DOCKERFILE'
FROM python:3.12-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-server sudo && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /run/sshd && \
    useradd -m -s /bin/bash ansible && \
    echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible && \
    chmod 440 /etc/sudoers.d/ansible && \
    mkdir -p /home/ansible/.ssh && chmod 700 /home/ansible/.ssh && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
COPY authorized_keys /home/ansible/.ssh/authorized_keys
RUN chown -R ansible:ansible /home/ansible/.ssh && \
    chmod 600 /home/ansible/.ssh/authorized_keys
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
DOCKERFILE

# Only rebuild if the Dockerfile or key changed
CURRENT_HASH=""
STORED_HASH=""
CURRENT_HASH=$(md5sum "$IMGDIR/Dockerfile" "$IMGDIR/authorized_keys" 2>/dev/null | md5sum | cut -d' ' -f1)
STORED_HASH=$(cat "$IMGDIR/.build_hash" 2>/dev/null || true)
if [ "$CURRENT_HASH" != "$STORED_HASH" ] || ! docker image inspect ansible-node:fundamentals >/dev/null 2>&1; then
  docker build -t ansible-node:fundamentals "$IMGDIR" -q >/dev/null 2>&1
  echo "$CURRENT_HASH" > "$IMGDIR/.build_hash"
fi
touch /tmp/kc-step2

# 4. Start managed nodes ──────────────────────────────────────────────────────────────────
_start_node() {
  local name=$1 port=$2
  # If already running, nothing to do
  docker ps --format '{{.Names}}' | grep -qx "$name" && return 0
  # Remove a stopped container with the same name, if any
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker run -d --name "$name" --hostname "$name" -p "${port}:22" ansible-node:fundamentals >/dev/null 2>&1
}
_start_node web1 2201
_start_node web2 2202
_start_node db1  2203
touch /tmp/kc-step3

# 5. Wait for SSH on all nodes ────────────────────────────────────────────────────────────
_wait_ssh() {
  local port=$1
  for i in $(seq 1 30); do
    ssh -o StrictHostKeyChecking=no \
        -o ConnectTimeout=2 \
        -o BatchMode=yes \
        -i /root/.ssh/id_ed25519 \
        -p "$port" ansible@localhost exit 2>/dev/null && return 0
    sleep 3
  done
  echo "WARNING: SSH on port $port did not become ready in time." >&2
  return 1
}
_wait_ssh 2201 || true
_wait_ssh 2202 || true
_wait_ssh 2203 || true

# 6. Populate known_hosts ─────────────────────────────────────────────────────────────────
> /root/.ssh/known_hosts
ssh-keyscan -p 2201 -H localhost >> /root/.ssh/known_hosts 2>/dev/null || true
ssh-keyscan -p 2202 -H localhost >> /root/.ssh/known_hosts 2>/dev/null || true
ssh-keyscan -p 2203 -H localhost >> /root/.ssh/known_hosts 2>/dev/null || true

# 7. Pre-warm apt cache on managed nodes (parallel) ───────────────────────────────────────
for port in 2201 2202 2203; do
  ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
      -i /root/.ssh/id_ed25519 -p "$port" ansible@localhost \
      "sudo apt-get update -qq" >/dev/null 2>&1 &
done
wait

# 8. Create the student workspace ─────────────────────────────────────────────────────────
mkdir -p /root/lab

# Signal that setup is complete
touch /root/lab/.ready
touch /tmp/kc-ready
SETUP
chmod +x /root/setup.sh

# Run the installer in the background; foreground.sh polls /root/lab/.ready
bash /root/setup.sh >/var/log/ansible-lab-setup.log 2>&1 &
