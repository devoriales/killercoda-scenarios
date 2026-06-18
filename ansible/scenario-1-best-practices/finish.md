# Lab Complete!

You've built Acme's Ansible setup from the ground up and answered the questions that
separate a tidy repo from a security incident.

## What you accomplished

| Area | What you did |
|---|---|
| Structure | Toured the standard layout: one shared `ansible.cfg`, per-environment inventories, a reusable role |
| SSH access | Generated a personal key, booted the nodes, reached them as the unprivileged `ansible` user |
| Inventories | Grouped hosts by role and saw `group_vars` resolve per host and per environment |
| Roles | Read a role done right — `webapp_` prefixes, `defaults` vs `vars` precedence, role-boundary indirection |
| Vault | Encrypted secrets with the `vault_` + indirection pattern, kept them usable |
| Vault-ids | Gave dev and prod different passwords and proved dev access can't unlock prod |
| Team workflow | Authorized a second developer's key with `bootstrap.yml`; saw how to rotate a vault password |
| Git hygiene | Committed the encrypted vault, made committing a plaintext secret impossible |
| Verify | Ran `ansible-lint`, `--syntax-check`, and a `--check --diff` dry run |

## Key takeaways

1. **Per-developer keys, never a shared key.** Offboarding = delete one `.pub` and re-run `bootstrap.yml`.
2. **Encrypted vault files belong in Git; the password that decrypts them never does.**
3. **Per-environment vault-ids** give graduated access from the same repo: everyone gets dev, a few get prod.
4. **The `vault_` + indirection pattern** keeps every secret greppable and the vault file a tidy flat list.
5. **Defence in depth:** `.gitignore` + pre-commit (`detect-secrets`, `detect-private-key`, the vault-encryption guard) + rotate-on-leak.

## Where to go next (beyond this lab)

- **SOPS** (file-level encryption with KMS/age backends) and **HashiCorp Vault** (dynamic,
  short-lived credentials via the `community.hashi_vault` lookup) for larger orgs.
- **Molecule** for role testing, plus a CI pipeline running the same `pre-commit` +
  `ansible-lint` + `--check` on every PR.
- **Execution Environments** (containerized Ansible) to make the pinned toolchain identical
  across laptops and CI.
