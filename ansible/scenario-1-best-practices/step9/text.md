# Step 9: Verify — Linting & Dry Runs

> **Linting vs. check mode.** **`ansible-lint`** reads your files *statically* — it flags
> bad naming, deprecated syntax, and risky patterns without contacting any host. **Check mode**
> (`--check`) does the opposite: it actually connects but runs every task in "what would
> change?" mode, applying nothing. Add `--diff` and it prints the exact lines a real run would
> alter — a safe rehearsal before touching prod.

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

> **Reading the output.** A clean run ends with `Passed: 0 failure(s)` — that's success
> (exit code `0`). Two lines look like problems but aren't: `Skipped installing collection
> dependencies due to running in offline mode` comes from `offline: true` in
> `.ansible-lint` (the lab has no internet), and `Profile 'min' was required, but only
> 'production' profile passed` just means the repo is *cleaner* than the `min` profile
> demands. Both are harmless.

## Syntax check (parses playbooks without running them)

```
ansible-playbook playbooks/site.yml --syntax-check
```{{copy}}

## Dry run: show what WOULD change, change nothing

```
ansible-playbook playbooks/site.yml --check --diff
```{{copy}}

`--check` reports prospective changes without touching the nodes; `--diff` shows the exact
lines that would change in the rendered config. A healthy dry run **prints the diff for
`webapp.conf` and ends with a green `PLAY RECAP`** — it should not error. This is your safe
rehearsal — **always run it against prod before a real apply.**

**Why it matters:** linting + a `--check --diff` dry run are the cheap, fast feedback loop
that keeps a 5-person team from breaking shared environments. Wire the same `pre-commit` and
`ansible-lint` into CI so the rules apply to everyone, not just whoever installed the local
hooks.

Click **Check** to confirm lint and syntax-check pass — and finish the lab.
