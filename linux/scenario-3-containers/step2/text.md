# Step 2 — Make the kernel enforce a limit

Namespaces hide things. They limit nothing. A process alone in a PID namespace can still take every byte of memory on the machine.

Limits are **control groups**, and in v2 they are a filesystem.

```bash
stat -fc %T /sys/fs/cgroup
```{{exec}}

`cgroup2fs`. Creating a group is `mkdir`:

```bash
mkdir -p /sys/fs/cgroup/practice && ls /sys/fs/cgroup/practice/
```{{exec}}

The kernel populated it. Those files are the interface: you read state from them and write limits into them.

## Delegation

A parent must explicitly hand down each controller it will let children use:

```bash
cat /sys/fs/cgroup/cgroup.controllers
```{{exec}}

```bash
echo "+memory +pids" > /sys/fs/cgroup/cgroup.subtree_control
cat /sys/fs/cgroup/cgroup.subtree_control
```{{exec}}

Without that, `memory.max` will not even exist in your group. This delegation model is also why rootless containers need a slice handed to them before they can set any limits at all.

## Write a limit and watch it bite

```bash
echo 33554432 > /sys/fs/cgroup/practice/memory.max
cat /sys/fs/cgroup/practice/memory.max
```{{exec}}

32 MiB. Now join the group and ask for far more:

```bash
bash -c 'echo $BASHPID > /sys/fs/cgroup/practice/cgroup.procs
         exec python3 -c "b = bytearray(200 * 1024 * 1024); print(\"allocated 200M\")"'
echo "exit=$?"
```{{exec}}

No output and **exit 137**, which is 128 + 9: killed by `SIGKILL`. Writing a PID into `cgroup.procs` is how a process joins a group, and the ceiling applied from that moment.

The kernel kept the receipt:

```bash
cat /sys/fs/cgroup/practice/memory.events
```{{exec}}

`oom_kill 1` is the process that did not survive. `max` counts how often the limit was reached and reclaim attempted.

**When a container dies at exit 137 and nobody admits to stopping it, this file is the answer.**

## A process limit too

```bash
echo 5 > /sys/fs/cgroup/practice/pids.max
```{{exec}}

```bash
bash -c 'echo $BASHPID > /sys/fs/cgroup/practice/cgroup.procs
         for i in $(seq 1 12); do sleep 5 & done
         wait' 2>&1 | grep -c "fork" || true
```{{exec}}

```bash
cat /sys/fs/cgroup/practice/pids.events
```{{exec}}

Forks refused. This is what stops a runaway process from taking the host down with it.

## Your task

Leave `/sys/fs/cgroup/practice` in place with:

- `memory.max` set to exactly **33554432** (32 MiB)
- at least one recorded `oom_kill` in `memory.events`

The commands above do both. The second requires actually running something that gets killed.

<details><summary>Hint</summary>

```
echo "+memory" > /sys/fs/cgroup/cgroup.subtree_control
mkdir -p /sys/fs/cgroup/practice
echo 33554432 > /sys/fs/cgroup/practice/memory.max
bash -c 'echo $BASHPID > /sys/fs/cgroup/practice/cgroup.procs
         exec python3 -c "b = bytearray(200 * 1024 * 1024)"'
cat /sys/fs/cgroup/practice/memory.events
```

</details>

When the limit is set and the kernel has recorded a kill, click **Check**.
