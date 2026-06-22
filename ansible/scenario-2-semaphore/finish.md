# Nicely done

You stood up **Semaphore UI** in the browser and used it to run Ansible end to end against
real managed nodes.

## What you learned

- **Browser access in Killercoda** — the **Traffic / Ports** menu exposes any port running in
  the lab (here, Semaphore on `3000`) as a clickable URL.
- **Semaphore's building blocks** — a **project** holds **Key Store** credentials, a linked
  **repository**, **inventories**, and **task templates**. A template ties a playbook to an
  inventory, repo, and environment into a one-click job.
- **The same Ansible, a shared front door** — Semaphore runs `ansible-playbook` for you, but
  adds stored credentials, live + retained logs, access control, and scheduling — the things
  a team needs that the bare CLI doesn't give you.

## Take it further

- Add a **schedule** to the template to run it on a cron.
- Add **survey variables** so a run can be parameterised from the UI.
- Create a second **environment** with real variables and bind it to the template.
- Explore **Build / Deploy** template types to model a promotion pipeline.

Docs: [semaphoreui.com/docs](https://semaphoreui.com/docs)

If you came from the **Ansible Best-Practices** lab, you've now seen both ends of the
spectrum: disciplined CLI project structure, and a shared web UI that runs it for the team.
