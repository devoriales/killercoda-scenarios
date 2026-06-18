# Step 3: Inventories, Groups, and Variables

> **What is an inventory?** The list of hosts Ansible manages, sorted into **groups** by
> role (`webservers`, `dbservers`). Groups let you target many hosts at once and attach
> config to them through **`group_vars/<group>/`** — variables that automatically apply to
> every host in that group. One inventory directory per environment keeps dev and prod apart.

See how host grouping and `group_vars` drive configuration.

```
cd /root/acme
```{{exec}}

## Show the dev inventory as Ansible sees it

```
ansible-inventory --graph
```{{copy}}

Expected — a tree grouping hosts by role:

```
@all:
  |--@dbservers:
  |  |--db1
  |--@webservers:
  |  |--web1
  |  |--web2
  |--@ungrouped:
```

## Inspect the variables that resolve for one host

```
ansible-inventory --host web1
```{{copy}}

You'll see the merged variable set for `web1` — the connection details plus
`webapp_listen_port: 8080` (from `group_vars/webservers/`) and the env/db values.

## dev vs prod — same variable, different value

```
grep -r webapp_listen_port inventories/
```{{copy}}

`webapp_listen_port` is **8080** in dev and **80** in prod — without changing a single
playbook. The role's default is overridden by the group's value, and which group file wins
is decided by *which inventory directory you select*.

**Why it matters:** group by role (`webservers`, `dbservers`), then attach config via
`group_vars/<group>/`. Values in `group_vars/all/` apply everywhere; group-specific files
apply only to that tier. Ansible matches these automatically by group name.

Click **Check** to confirm the inventory groups resolve.
