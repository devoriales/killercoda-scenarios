# Step 8: Git Hygiene — What to Commit, What Never To

> **What is a pre-commit hook?** A check Git runs *before* a commit is recorded; if it fails,
> the commit is rejected. Here two hooks act as guardrails: **`detect-secrets`** scans for
> things that look like credentials, and an **ansible-vault** hook refuses any `vault.yml`
> that isn't encrypted. Together with `.gitignore`, they make leaking a secret hard to do by
> accident.

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

Now arm the second net — the pre-commit hooks. Two commands, run once (both are
idempotent — safe to run again):

```
detect-secrets scan > .secrets.baseline   # snapshot today's repo: only NEW secrets get flagged later
pre-commit install                          # wire the hooks into Git so they run on every commit
```{{copy}}

**What each command does:**

- **`pre-commit install`** copies a hook script into `.git/hooks/`. The
  `.pre-commit-config.yaml` in the repo only *lists* the checks; until you run this, Git
  ignores it and nothing is checked. After it, every `git commit` runs the hooks first and
  a failing check rejects the commit.
- **`detect-secrets scan > .secrets.baseline`** records every secret-looking string that
  already exists in the repo into a *baseline* file. The hook compares future commits
  against this baseline and blocks only **new** secrets — so it won't keep tripping over
  strings it has already seen.

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
