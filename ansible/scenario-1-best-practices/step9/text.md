# Step 9: Verify — Linting & Dry Runs

Catch mistakes before they hit a host.

```
cd /root/acme
```{{exec}}

## Static best-practice + correctness linting

```
ansible-lint
```{{copy}}

`ansible-lint` encodes much of the best-practice checklist automatically — naming,
deprecated syntax, risky patterns. This repo ships an `.ansible-lint` profile so it runs
clean.

## Syntax check (parses playbooks without running them)

```
ansible-playbook playbooks/site.yml --syntax-check
```{{copy}}

## Dry run: show what WOULD change, change nothing

```
ansible-playbook playbooks/site.yml --check --diff
```{{copy}}

`--check` reports prospective changes without touching the nodes; `--diff` shows the exact
lines that would change in the rendered config. This is your safe rehearsal — **always run
it against prod before a real apply.**

**Why it matters:** linting + a `--check --diff` dry run are the cheap, fast feedback loop
that keeps a 5-person team from breaking shared environments. Wire the same `pre-commit` and
`ansible-lint` into CI so the rules apply to everyone, not just whoever installed the local
hooks.

Click **Check** to confirm lint and syntax-check pass — and finish the lab.
