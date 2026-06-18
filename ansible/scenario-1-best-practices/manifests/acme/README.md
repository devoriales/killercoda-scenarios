# Acme Ansible repo

Automation for Acme's web application across two environments (`dev`, `prod`), each with a
web tier (`web1`, `web2`) and a database tier (`db1`).

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
docker/                     # the fake servers (web1, web2, db1) for this lab
```

Throwaway lab vault passwords (they protect nothing real):

- dev vault password: `dev-lab-password`
- prod vault password: `prod-lab-password`
