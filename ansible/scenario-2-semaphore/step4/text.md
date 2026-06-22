# Build a task template

A **task template** is a reusable, runnable job. It ties together *what* to run (a playbook),
*where* (an inventory), *from* (a repository), and *with* (an environment). Once it exists,
anyone with access can run it with one click.

## In the Semaphore UI

1. In the **Acme Automation** project, open **Task Templates** in the left sidebar.
2. Click **New Template** → **Ansible Playbook**.
3. Fill in the **Common options** (left column):

   | Field | Value |
   |---|---|
   | **Name** | `Configure web app` |
   | **Path to playbook file** | `playbooks/site.yml` |
   | **Inventory** | `acme-nodes` |
   | **Repository** | `acme` |
   | **Variable Groups** | `empty` |

4. Click **Create**. (You can ignore the Advanced and Ansible options for now.)

> The **Variable Groups** entry (`empty`) was pre-seeded for you — it's where you'd attach
> extra variables to inject into a run. We don't need any here.

That's the whole template model: a named, version-controlled job built from the pieces you've
assembled. Change the playbook in Git, and the next run picks it up automatically.

Click **Check** once the template exists.
