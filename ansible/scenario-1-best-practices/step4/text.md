# Step 4: Write a Role the Right Way

Understand role structure, variable precedence, and the role-boundary indirection — then
run the role against the dev nodes.

```
cd /root/acme
```{{exec}}

## Look at the role

```
find roles/webapp -type f | sort
```{{copy}}

```
defaults/main.yml   # webapp_* defaults — LOW precedence, meant to be overridden
vars/main.yml       # __webapp_* internals — HIGH precedence, do not override
tasks/main.yml      # named, imperative tasks; file/template modules
handlers/main.yml   # "Restart webapp" — runs once, only if notified
templates/*.j2      # renders the config containing the secret
meta/main.yml       # role metadata (author, platforms, min ansible version)
```

See how `site.yml` maps the environment's values onto the role's interface:

```
cat playbooks/site.yml
```{{copy}}

The role never sees raw `vault_*` names — `site.yml` maps `db_password` onto
`webapp_db_password`. Clean, testable interface.

## Run the role against dev

```
ansible-playbook playbooks/site.yml
```{{copy}}

## Confirm the rendered config on a node

```
docker exec lab_web1 cat /etc/webapp/webapp.conf
```{{copy}}

Expected: `environment=dev`, `listen_port=8080`, and the **dev** database password.

**Why it matters:** prefix everything with the role name (`webapp_listen_port`) so the role
is reusable without collisions; internal-only vars get a `__` prefix. `defaults/` is the
floor (overridable by inventory); `vars/` is near the ceiling (for constants). Never use
`set_fact` to override either — facts are global and surprising.

Click **Check** once the dev config is rendered.
