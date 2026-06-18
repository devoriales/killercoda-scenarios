# Step 6: Per-Environment Vault Passwords (vault-ids)

Give dev and prod **different** vault passwords, so dev access can't unlock prod secrets —
and have Ansible pick the right one automatically.

```
cd /root/acme
```{{exec}}

## How it's wired — `ansible.cfg`

```
vault_identity_list = dev@.vault_pass.dev, prod@.vault_pass.prod
```

Each encrypted file carries a label in its header. Ansible matches each blob to the
password file with the same label. You hold whichever password files you're authorized for.

```
head -n1 inventories/dev/group_vars/all/vault.yml    # ...;dev
head -n1 inventories/prod/group_vars/all/vault.yml   # ...;prod
```{{copy}}

## Deploy to each environment — secrets auto-decrypt with the matching id

```
ansible-playbook playbooks/site.yml                                  # dev (default)
ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml    # prod (explicit)
```{{copy}}

Confirm prod rendered on the node:

```
docker exec lab_web1 grep -E 'environment|db_password' /etc/webapp/webapp.conf
```{{copy}}

Expected: `environment=prod` and the **prod** database password.

## Prove isolation: the dev password CANNOT open the prod vault

```
ANSIBLE_VAULT_IDENTITY_LIST="dev@.vault_pass.dev" \
  ansible-vault view inventories/prod/group_vars/all/vault.yml
```{{copy}}

Expected: `ERROR! Decryption failed` — the dev password is useless against prod ciphertext.

**Why it matters:** this is the practical answer to *"how do 5 devs share environments
safely?"* Give the team the dev vault password for day-to-day work; restrict the prod vault
password to the few who deploy prod. Same repo, same playbooks, graduated access —
enforced by which `.vault_pass.*` file a person holds.

Click **Check** to confirm the prod deploy and the isolation.
