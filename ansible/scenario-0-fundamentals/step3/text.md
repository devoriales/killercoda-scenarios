# Step 3 — Modules and Ad Hoc Commands

## What is a module?

A **module** is the fundamental unit of work in Ansible. Every action Ansible performs — install a package, copy a file, create a user, restart a service, make an API call — is implemented as a module.

Modules have three defining properties:

**Idempotent.** Running the same module with the same arguments twice produces the same end state. Installing a package that is already installed does nothing — no error, no re-download. This makes automation safe to re-run at any time.

**Push-and-discard.** The control node compiles the module code and its arguments, copies the bundle to a temporary directory on the managed node via the SSH channel, executes it, reads the JSON result back, and then deletes the temporary file. Nothing persists on the managed node between runs.

**JSON contract.** Every module receives its arguments as JSON and must write a JSON object to stdout as its result. This contract is the reason modules can be written in any language — Python, Bash, PowerShell, Go — as long as they honour the JSON I/O.

## Ad hoc commands

An **ad hoc command** invokes a single module against a host pattern, outside of any playbook. The syntax is:

```
ansible <host-pattern> -m <module-name> -a "<module-arguments>"
```

Ad hoc commands are useful for quick checks, one-off tasks, and testing module arguments before committing them to a playbook.

### ping — verify the full connection path

`ping` is not ICMP. It is an Ansible module that verifies SSH connectivity, Python availability on the remote side, and basic module execution end-to-end:

```bash
cd /root/lab && ansible all -m ping
```{{exec}}

A green `pong` response means every layer works: SSH, Python on the remote, and the module execution loop.

### setup — gather facts

The `setup` module collects **facts**: structured data about the managed node — OS distribution, kernel version, CPU count, total RAM, network interfaces, IP addresses, and more. This module runs automatically at the start of every play (unless you disable it with `gather_facts: false`).

Filter to see only what you need:

```bash
cd /root/lab && ansible web1 -m setup -a "filter=ansible_distribution*"
```{{exec}}

```bash
cd /root/lab && ansible db1 -m setup -a "filter=ansible_memtotal_mb"
```{{exec}}

Facts are accessible inside playbooks as variables, which you will use in Step 5.

### package — install software

```bash
cd /root/lab && ansible webservers -m package -a "name=curl state=present" --become
```{{exec}}

`--become` elevates privileges to root (equivalent to `sudo`). The `ansible` user on each node has passwordless sudo configured in this lab.

Run it a second time:

```bash
cd /root/lab && ansible webservers -m package -a "name=curl state=present" --become
```{{exec}}

The first run shows `changed` (yellow): the module made a change. The second shows `ok` (green): the desired state already exists, nothing happened. This is **idempotency** — the same module, the same arguments, the same idempotent outcome.

### command vs shell

```bash
cd /root/lab && ansible all -m command -a "hostname"
```{{exec}}

```bash
cd /root/lab && ansible all -m shell -a "echo The OS is $(uname -s)"
```{{exec}}

`command` does not invoke a shell — it passes the arguments directly to the OS `execve()` system call. This means shell features like pipes (`|`), redirects (`>`), and variable expansion (`$VAR`) are **not available**, but it is also not susceptible to shell injection.

`shell` invokes `/bin/sh -c` on the remote side. Use it only when you genuinely need shell features. `command` is the safer default.

### ansible-doc — offline module documentation

```bash
ansible-doc package
```{{exec}}

`ansible-doc` prints the full module documentation without needing internet access. Use it to look up argument names, accepted values, and return data before writing a task.
