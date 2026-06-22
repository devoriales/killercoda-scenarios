# Drive Ansible from a Web UI with Semaphore

You already know how to run Ansible from the command line. In a team, you usually want a
shared place to run automation — with an audit trail, scheduled jobs, stored credentials,
and a button non-CLI colleagues can press. [Semaphore UI](https://semaphoreui.com/) is an
open-source web front-end for exactly that.

In this lab you will:

- **Open Semaphore in your browser** — using Killercoda's **Traffic / Ports** feature to
  reach a web app running inside the lab.
- **Log in to a pre-seeded project** that already has an SSH credential and a linked
  Ansible repository.
- **Wire up an inventory**, **build a task template**, and **run a playbook** against three
  real managed nodes (`web1`, `web2`, `db1`) — watching the output stream live, just as you
  would on the CLI.
- **Confirm the change** the playbook made on a node.

Everything runs locally inside the lab — the managed nodes are lightweight containers
reached over real SSH, and Semaphore drives them exactly the way `ansible-playbook` would.

> The lab needs a minute to pull the Semaphore image and start the nodes. The terminal
> shows the progress — grab a coffee while it finishes.
