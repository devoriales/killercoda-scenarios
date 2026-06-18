# Step 8: Git Hygiene — What to Commit, What Never To

Commit the safe things; make the dangerous things impossible to commit.

```
cd /root/acme
```{{exec}}

## The rule

**Commit the encrypted `vault.yml`. Never commit the password that decrypts it.**

| Commit ✅ | Never commit ❌ |
|---|---|
| Encrypted `vault.yml` files | `.vault_pass*` (vault passwords) |
| `vars.yml`, inventories, roles, playbooks | SSH/TLS private keys (`*.key`, `*.pem`, `id_*`) |
| `ansible.cfg`, `requirements.*` | Decrypted secret output (`*.dec`, `.env`) |
| `.gitignore`, pre-commit config | Anything under `.ssh/` |

## The two safety nets

`background.sh` already ran `git init` and committed the encrypted repo. Confirm what is and
isn't tracked:

```
git status
git check-ignore .vault_pass.dev .ssh/lab_dev_ed25519
```{{copy}}

The encrypted `vault.yml` is tracked; `.vault_pass.*` and `.ssh/` are ignored.

Make sure the pre-commit hooks are installed (idempotent — safe to run again):

```
detect-secrets scan > .secrets.baseline
pre-commit install
```{{copy}}

## Drill: try to leak a secret and watch it get blocked

**(a) A plaintext secret written into a vault file:**

```
echo "vault_db_password: leaked-in-plaintext" > inventories/dev/group_vars/all/vault.yml
git add inventories/dev/group_vars/all/vault.yml
git commit -m "oops"
```{{copy}}

Blocked by the `ansible-vault-encrypted` hook. Restore the real encrypted file:

```
git checkout -- inventories/dev/group_vars/all/vault.yml
```{{copy}}

**(b) A hardcoded credential in a normal file:**

```
echo 'aws_secret = "AKIAIOSFODNN7EXAMPLEKEYrealLookingSecret"' > leak.txt
git add leak.txt
git commit -m "oops2"
```{{copy}}

Blocked by `detect-secrets`. Clean up:

```
git reset leak.txt && rm -f leak.txt
```{{copy}}

**Why it matters:** Ansible-Vault ciphertext (AES256) is safe to store in Git — that's the
whole point; secrets travel with the code, encrypted. The decrypting password and raw
private keys live only on laptops (from a password manager) and on the nodes. Defence in
depth: `.gitignore` + pre-commit + treating any leaked password as compromised → rotate.

Click **Check** to confirm the guards are active.
