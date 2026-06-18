# Step 7: The 5-Developer Workflow — Keys & Secrets

> **The two shared secrets of a team.** Access rests on two things: each developer's
> **SSH keypair** (personal, never shared — onboarding adds a `.pub`, offboarding removes it)
> and the **vault password** (one shared secret per environment, handed out *out of band* via
> a password manager). Re-running `bootstrap.yml` is safe because it's **idempotent** — it
> only adds keys that aren't already authorized.

Onboard another developer without rebuilding anything, and learn how to rotate a shared
vault password.

```
cd /root/acme
```{{exec}}

## 7a. Add a developer's SSH key

Each dev generates their own keypair and shares only the **public** key. Simulate a second
developer:

```
ssh-keygen -t ed25519 -f /tmp/dev2_key -N "" -C "dev2@ansible-lab"
cp /tmp/dev2_key.pub .ssh/dev2.pub
```{{copy}}

Authorize **all** public keys in `.ssh/` across **all** nodes (idempotent):

```
ansible-playbook playbooks/bootstrap.yml
```{{copy}}

Verify both developers are now authorized on a node:

```
docker exec lab_web1 cat /home/ansible/.ssh/authorized_keys
```{{copy}}

**Why it matters:** per-developer keys, never a shared key. Offboarding = remove that one
`.pub` and re-run `bootstrap.yml`. Auditing = you know exactly whose key is where.

## 7b. Rotate the vault password (demo)

The vault password is a shared secret distributed **out of band** (a team password manager —
never Slack, email, or Git). When someone leaves, rotate it. The command (don't run it now —
it would change the dev password the rest of the lab relies on):

```
ansible-vault rekey --vault-id dev@.vault_pass.dev \
  --new-vault-id dev@prompt inventories/dev/group_vars/all/vault.yml
```

Because secrets live in `vault.yml` (not scattered), rotation is a single `rekey` plus a
fresh password hand-off — then commit the re-encrypted file.

Click **Check** once `dev2` is authorized.
