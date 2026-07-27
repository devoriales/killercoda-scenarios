# Step 1 — Close the permissions you inherited

Two faults, both created by someone trying to make an error message go away.

## Fault one: the log anyone can rewrite

```bash
ls -l /srv/analytics/logs/collector.log
```{{exec}}

Mode `777`. Read that as three sets of `rwx`: the owner, the group, and **everyone else on the machine**.

The file is still owned by `analytics`, and that is what makes this worse than it looks. Watch what an unrelated account can do:

```bash
runuser -u tokafor -- bash -c 'echo "ts=2026-03-14T08:13:11Z level=info queue_depth=12" > /srv/analytics/logs/collector.log'
```{{exec}}

```bash
cat /srv/analytics/logs/collector.log
```{{exec}}

```bash
stat -c "%U:%G" /srv/analytics/logs/collector.log
```{{exec}}

The warning about a queue depth of 8412 is gone, replaced by a line claiming everything is fine. The file **still reports `analytics:analytics` as its owner**, so anyone reading this log later, including an incident review, attributes that line to the service.

That is the real cost of `777`. It does not just grant too much access; on anything read as a record, it destroys the meaning of the record.

## Fault two: the shared directory that loses its group

```bash
ls -ld /srv/analytics/releases
```{{exec}}

Owned by group `deployers`, mode `775`, which looks correct. Now watch what happens when a deploy engineer actually uses it:

```bash
runuser -u rjimenez -- touch /srv/analytics/releases/build-4471.tar.gz
```{{exec}}

```bash
ls -l /srv/analytics/releases
```{{exec}}

The file belongs to group `rjimenez`, not `deployers`. New files take the creator's **primary** group, so every artefact in this shared directory is readable only by the person who happened to build it. The shared access someone configured applies to nothing.

The fix is the **setgid** bit on the directory. With it set, new files inherit the directory's group instead of the creator's.

## Your task

Two things:

1. Restore `/srv/analytics/logs/collector.log` to mode **`640`**, so the owner can write, the group can read, and nobody else has any access.
2. Set the **setgid** bit on `/srv/analytics/releases`, keeping it group writable, so new files inherit the `deployers` group.

<details><summary>Hint</summary>

`chmod` takes a leading digit for the special bits, where `2` is setgid:

```
chmod 640 /srv/analytics/logs/collector.log
chmod 2775 /srv/analytics/releases
```

Confirm with `ls -ld /srv/analytics/releases`. You are looking for an `s` where the group's `x` normally sits: `drwxrwsr-x`.

</details>

When both are done, click **Check**.
