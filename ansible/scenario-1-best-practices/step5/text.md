# Step 5: Introduce Ansible Vault

> **What is Ansible Vault?** Built-in **encryption for secrets** (AES256). It turns a
> variables file into ciphertext you can safely commit to Git; at runtime Ansible decrypts it
> in memory using a password you supply, so playbooks read the secret values transparently.
> No separate secrets store — the encrypted file travels with the code.

This is the heart of the lab — encrypt secrets, keep them usable, and understand the
indirection pattern.

```
cd /root/acme
```{{exec}}

## The indirection pattern

Open the two dev files side by side conceptually:

- `inventories/dev/group_vars/all/vault.yml` — encrypted ciphertext (a flat list of
  `vault_*` secrets).
- `inventories/dev/group_vars/all/vars.yml` — plain, maps friendly names onto those
  `vault_*` values.

```
# vault.yml (ENCRYPTED) — flat list, each secret named vault_*
vault_db_password: dev-Sup3rSecret-DB-pw
vault_api_token:   dev-tok-abc123xyz

# vars.yml (PLAIN) — maps friendly names onto the vault_ values
db_password: "{{ vault_db_password }}"
api_token:   "{{ vault_api_token }}"
```

Roles and templates only ever reference `db_password` — never `vault_db_password`.

## The dev vault password is already in place

`background.sh` wrote it for you (gitignored). Re-create it any time — it's idempotent:

```
printf 'dev-lab-password' > .vault_pass.dev && chmod 600 .vault_pass.dev
```{{copy}}

## Confirm the file really is encrypted

```
head -n1 inventories/dev/group_vars/all/vault.yml
```{{copy}}

Expected: a header like `$ANSIBLE_VAULT;1.2;AES256;dev` — note the `dev` label at the end.

## View it (decrypts to your screen, not to disk)

```
ansible-vault view inventories/dev/group_vars/all/vault.yml
```{{copy}}

## Other everyday commands

```
# Edit in place (decrypts to a temp file, re-encrypts on save)
ansible-vault edit inventories/dev/group_vars/all/vault.yml

# Encrypt a single value to paste into a vars file
ansible-vault encrypt_string --encrypt-vault-id dev 's3cr3t' --name 'vault_some_token'
```{{copy}}

> **Note:** This repo has TWO vault-ids (dev, prod — next step). Any command that **writes**
> ciphertext (`create`, `encrypt`, `encrypt_string`, `rekey`) must name the id with
> `--encrypt-vault-id dev`. Read-only commands (`view`, `edit`, `decrypt`) don't — they try
> each known password until one works.

**Why it matters:** the `vault_` prefix + indirection keeps every secret greppable
(`grep -r api_token`), keeps `vault.yml` a tidy flat list, and makes it obvious which
variables are sensitive.

Click **Check** to confirm the dev vault is encrypted and decryptable.
