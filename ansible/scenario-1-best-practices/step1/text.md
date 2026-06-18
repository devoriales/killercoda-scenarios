# Step 1: Understand the Project Structure

> **What is Ansible?** An **agentless** automation tool: from one control machine it
> configures many remote hosts over plain SSH — nothing to install on the targets. You
> describe the *desired state* in YAML files (**playbooks**) and Ansible makes each host
> match it. Runs are **idempotent** — re-running changes nothing once a host already matches.

Acme's Ansible repo lives at `/root/acme`. Move into it — every command in this lab runs
from here.

```
cd /root/acme
```{{exec}}

## A guided tour

```
cat README.md
```{{copy}}

List every file (skipping the volatile, never-committed directories):

```
find . -type f -not -path './.git/*' -not -path './.ssh/*' -not -name '.vault_pass*' | sort
```{{copy}}

## The layout and the rules it encodes

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
```

**Why it matters:**

- **One shared `ansible.cfg`** means every developer's Ansible behaves identically.
- **Naming discipline:** snake_case everywhere, `.yml` (not `.yaml`), no dashes in role
  names (they break collections), every task named in imperative form.
- **Separation of environments:** a dev change physically cannot touch prod, because prod
  is a different inventory directory you must select explicitly.

Click **Check** to confirm the repo is in place.
