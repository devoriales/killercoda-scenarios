# Ansible Best-Practices Lab

You've just joined **Acme**, a 5-developer platform team. Acme runs a web application across
two environments — **dev** and **prod** — each made of a web tier (two servers) and a
database tier (one server). The team uses Ansible to deploy it, and the automation code
lives in a shared Git repository everyone clones. To render its config the app needs two
secrets — a **database password** and an **API token** — different values in dev and prod.
Every developer runs playbooks against dev all day; only a couple of senior people deploy
prod.

This lab recreates exactly that. Docker containers stand in for Acme's servers, and
`/root/acme` is Acme's Ansible repo:

| Acme's world | In this lab |
|---|---|
| Web-tier servers | containers `web1`, `web2` (group `webservers`) |
| Database server | container `db1` (group `dbservers`) |
| Dev vs prod | `inventories/dev/` and `inventories/prod/` |
| The app's secrets | `db_password`, `api_token` (in encrypted `vault.yml`) |
| The 5 developers | per-person SSH keys in `.ssh/`, authorized via `bootstrap.yml` |
| The shared repo | `/root/acme` + its `.gitignore` / pre-commit guards |

By the end you'll have a runnable, multi-environment Ansible project with per-developer SSH
access, vault-encrypted per-environment secrets, and Git guards that make leaking a secret
hard to do by accident — and you'll understand **why** each choice is the recommended
practice.

**The environment is preparing itself in the background** (installing Ansible, assembling
the repo, encrypting the vaults, building the node image). This takes a few minutes — the
terminal shows progress and Step 1 only opens once everything is ready.

> **Throwaway lab passwords** (safe to write down — they protect nothing real):
> dev vault password `dev-lab-password`, prod vault password `prod-lab-password`.
