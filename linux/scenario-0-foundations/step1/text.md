# Step 1 — Find your way around the filesystem

Linux has exactly one directory tree. There is no `C:` drive and no `D:` drive. A second disk does not get a letter; it gets attached to a directory somewhere in the single tree, and after that it is just a path.

The layout is standardised, which is the useful part. Configuration is in `/etc` on every distribution. Logs are in `/var/log`. Commands are in `/usr/bin`. You can be dropped onto a machine you have never seen and still know where to look.

## Look at the top of the tree

```bash
ls -1 /
```{{exec}}

| Directory | Holds |
|---|---|
| `/etc` | System configuration, all plain text |
| `/var` | Data that grows: logs, spools, databases |
| `/usr` | Programs and libraries from the distribution |
| `/home` | One directory per human user |
| `/root` | The root user's home directory, **not** the top of the tree |
| `/tmp` | Scratch space, cleared on reboot |
| `/proc` | Not on disk: the kernel answering questions as if it were files |
| `/dev` | Device nodes for disks, terminals, and random number sources |

The trap worth naming immediately: `/` is the top of the tree, `/root` is one user's home directory. Confusing them is a memorable way to ruin an afternoon.

## Where am I?

Your position in the tree is the working directory:

```bash
pwd
```{{exec}}

An **absolute** path starts at `/` and means the same thing from anywhere. A **relative** path starts from wherever you currently are. These two commands reach the same place:

```bash
cd /root/course-data && pwd
```{{exec}}

```bash
cd / && cd root/course-data && pwd
```{{exec}}

Four shorthands do most of the navigation work:

| Shorthand | Means |
|---|---|
| `.` | the current directory |
| `..` | the parent directory |
| `~` | your home directory |
| `-` | the directory you were in before this one |

```bash
cd .. && pwd
```{{exec}}

```bash
cd - && pwd
```{{exec}}

`cd -` jumps back and forth between two directories. It is the one people discover late and then use constantly, because comparing a config against a log is most of what troubleshooting looks like.

## Look at the evidence

`ls -l` is the form worth building muscle memory for:

```bash
ls -l /root/course-data
```{{exec}}

Reading a line left to right: file type and permissions, link count, owner, group, size in bytes, modification time, name. The leading character is the type, where `-` is a regular file, `d` is a directory, and `l` is a symbolic link.

Never trust a file extension. Linux does not use them to decide what a file is, and `file` inspects the actual contents:

```bash
file /root/course-data/access.log
```{{exec}}

## Your task

Set up a workspace for the investigation and bring the evidence into it.

Create a directory at `/root/investigation`, then copy the access log into it. Copying rather than moving means the original stays untouched, which is what you always want when the file is evidence.

<details><summary>Hint</summary>

You need two commands. `mkdir` creates a directory, and `cp` copies a file:

```
mkdir /root/investigation
cp /root/course-data/access.log /root/investigation/
```

</details>

When both exist, click **Check**.
