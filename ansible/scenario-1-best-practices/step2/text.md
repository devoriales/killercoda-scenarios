# Step 2: Stand Up the Nodes & Connect with an SSH Key

You'll create your own SSH key, boot the three fake servers, and reach them with Ansible.

```
cd /root/acme
```{{exec}}

## 1. Generate YOUR personal keypair

No passphrase here for lab convenience; in real life use a passphrase + `ssh-agent`.

```
mkdir -p .ssh
ssh-keygen -t ed25519 -f .ssh/lab_dev_ed25519 -N "" -C "$(whoami)@ansible-lab"
```{{copy}}

## 2. Publish your PUBLIC key into the repo's key directory

Only the `.pub` goes here. **The private key never leaves your laptop.**

```
cp .ssh/lab_dev_ed25519.pub .ssh/$(whoami).pub
```{{copy}}

## 3. Boot the three nodes

The container entrypoint installs every `.ssh/*.pub` into the `ansible` user's
`authorized_keys` at start-up.

```
docker compose -f docker/docker-compose.yml up -d --build
```{{copy}}

Give them a few seconds to start their SSH daemons:

```
sleep 5 && docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```{{exec}}

## 4. Talk to them

```
ansible all -m ping
```{{copy}}

Expected: each node replies `SUCCESS` with `"ping": "pong"`.

```
web1 | SUCCESS => { "ping": "pong" }
web2 | SUCCESS => { "ping": "pong" }
db1  | SUCCESS => { "ping": "pong" }
```

**Why it matters:** key-based auth only — the nodes have `PasswordAuthentication no` and
`PermitRootLogin no`. You log in as the unprivileged `ansible` user and escalate with
`become`. `ansible.cfg` ties it together: `private_key_file = ./.ssh/lab_dev_ed25519` plus
the per-host `ansible_port` route you to the right container.

Click **Check** once all three nodes answer.
