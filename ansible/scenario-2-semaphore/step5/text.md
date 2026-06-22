# Run the playbook & watch it live

Time to actually run Ansible — from the browser.

## Run the template

1. Open **Task Templates** and find **Configure web app**.
2. Click **Run** (then confirm in the dialog).
3. Semaphore opens the **task output** view and streams the playbook log in real time —
   the same output you'd see from `ansible-playbook` on the CLI.

Watch the play execute against `web1`, `web2` and `db1`:

- the **Ping** task confirms SSH connectivity,
- the **release marker** task writes `/etc/acme-release`,
- the **debug** task prints which node it configured.

When it finishes, the task status turns **Success** and the `PLAY RECAP` shows `ok` counts
for all three hosts with `failed=0`.

> If a run fails, open the log and read the recap — the most common lab cause is a node not
> being up. You can re-run from the same template after fixing it with
> `bash /root/lab/docker/up.sh`.

Click **Check** once a run has completed successfully.
