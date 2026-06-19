# Ansible Fundamentals

## The Problem

Meridian Systems runs a busy e-commerce platform. Two web servers handle customer traffic around the clock. One database server sits behind them. Four servers today — possibly forty next year.

Until now, every change meant four open SSH terminals, the same commands typed four times by hand, and a hope that nobody made a typo. Last Tuesday, someone did. A misplaced argument to a package manager command left one web server missing a runtime dependency. The error surfaced at 2 AM in a production alert.

Your manager has one ask: **make this repeatable, safe, and auditable.**

You reach for Ansible.

---

## What you will learn

| Component | What it is |
|-----------|-----------|
| **Control node** | Where Ansible runs — the only machine that needs it installed |
| **Managed nodes** | The targets — need only Python and an SSH port |
| **Inventory** | The map from names to real machines |
| **Modules** | The units of work — idempotent, push-and-discard |
| **Playbooks** | YAML workflows composing modules into multi-step automation |
| **Variables & facts** | Making playbooks dynamic and machine-aware |
| **Handlers** | Tasks that run only when something actually changed |
| **Roles** | Self-contained, reusable automation bundles |

---

## Lab environment

The control node is this terminal. Three managed nodes — `web1`, `web2`, and `db1` — run as Docker containers on localhost, reachable over SSH:

| Node | Role | SSH port |
|------|------|----------|
| `web1` | Web server | 2201 |
| `web2` | Web server | 2202 |
| `db1` | Database server | 2203 |

Ansible is being installed. The nodes are starting. Please wait for the ready message before beginning Step 1.
