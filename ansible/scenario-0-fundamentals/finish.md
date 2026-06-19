# Lab Complete

You have built a working Ansible setup from scratch and exercised every core component:

| Component | What you did |
|-----------|-------------|
| **Control node** | Installed Ansible, created `ansible.cfg` |
| **Managed nodes** | Reached three Docker containers over SSH — no agents installed |
| **Inventory** | Declared groups and per-host connection variables in INI format |
| **Modules** | Used `ping`, `setup`, `package`, `command`, `copy`, `debug` |
| **Ad hoc commands** | Ran modules directly from the CLI against host patterns |
| **Playbooks** | Wrote YAML plays with ordered task lists; observed `changed` vs `ok` |
| **Idempotency** | Ran the same playbook twice and confirmed the second run changed nothing |
| **Variables** | Defined group variables in `group_vars/`; referenced them with `{{ }}` |
| **Facts** | Used `ansible_hostname`, `ansible_distribution`, and others gathered by `setup` |
| **Handlers** | Wrote a `notify`/`handlers` pair; confirmed the handler ran only on change |
| **Roles** | Scaffolded a role with `ansible-galaxy role init`; applied it from `site.yml` |

---

## Key facts to carry forward

**Ansible is push-based and agentless.** The control node pushes module code, executes it remotely, reads the result, and discards the temporary files. Nothing persists on managed nodes between runs.

**Idempotency is a contract, not magic.** A module is idempotent because its author wrote it that way. `command` and `shell` are not idempotent by default — you must add `creates:`, `removes:`, or `changed_when: false` explicitly.

**Variable precedence is ordered.** When a variable has an unexpected value, trace it through the precedence chain — role defaults → inventory → group_vars → host_vars → play vars → extra vars. The highest source always wins.

**Handlers deduplicate.** Ten notifying tasks fire the handler once, at the end of the play.

---

## Continue learning

The natural next topics after these fundamentals:

- **Ansible Vault** — encrypting secrets so plaintext passwords never reach version control
- **Jinja2 templates** — generating configuration files dynamically from variables and facts
- **Conditionals and loops** — `when:` for conditional tasks, `loop:` for repeated tasks
- **Error handling** — `block/rescue/always`, `ignore_errors`, `failed_when`
- **Collections** — namespaced bundles of roles, modules, and plugins from Ansible Galaxy

Continue with the **Ansible Best Practices** scenario to apply these fundamentals on a team-grade project with Vault-encrypted secrets, per-environment inventories, and Git safety nets.
