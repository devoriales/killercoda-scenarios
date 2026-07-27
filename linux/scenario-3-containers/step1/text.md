# Step 1 — Make a namespace by hand

Every process is already in a full set of namespaces. Yours are the host's:

```bash
ls -l /proc/self/ns/
```{{exec}}

Those numbers are inode identifiers for kernel objects. Two processes with the same number share that namespace. **"Being in a container" means having different numbers here**, and nothing more mysterious than that.

## A world with one process in it

```bash
unshare --pid --fork --mount-proc ps -ef
```{{exec}}

One process, and it is PID 1. Now compare:

```bash
ps -e --no-headers | wc -l
```{{exec}}

Every one of those is still running. The isolated process simply cannot see them.

`--mount-proc` is doing real work there. `ps` reads `/proc`, so without a fresh `/proc` for the new namespace you would look through the host's and see everything. Try it:

```bash
unshare --pid --fork ps -ef | head -5
```{{exec}}

Same PID namespace, no fresh `/proc`, and the isolation looks like it failed. It did not; you are just reading the wrong window. That distinction is the sort of thing a container engine handles so you never notice it.

## Its own hostname

```bash
unshare --uts sh -c 'hostname isolated-demo; echo "inside: $(hostname)"'
```{{exec}}

```bash
hostname
```{{exec}}

The host is untouched. That is the whole mechanism behind a container having its own hostname.

## Its own network

```bash
ip -brief link show
```{{exec}}

```bash
unshare --net ip -brief link show
```{{exec}}

The host has real interfaces. The new namespace has a loopback device and nothing else: no addresses, no routes, no connectivity at all. **Everything a container can reach on the network was deliberately plumbed in afterwards.**

Prove they are genuinely different objects:

```bash
readlink /proc/self/ns/net; unshare --net readlink /proc/self/ns/net
```{{exec}}

## Your task

Record what you have just seen, so the check can confirm you ran it rather than read it.

Write **the number of processes visible inside a new PID namespace** into `/root/answers/pidns.txt`, as a bare number on its own.

<details><summary>Hint</summary>

Count the processes rather than the lines of output, so the `ps` header does not confuse the answer:

```
unshare --pid --fork --mount-proc ps -e --no-headers | wc -l > /root/answers/pidns.txt
cat /root/answers/pidns.txt
```

</details>

When the file holds the right number, click **Check**.
