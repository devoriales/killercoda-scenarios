# Step 2 — A name is not the file

Here is the idea that makes the rest of the filesystem make sense.

When you create a file, the kernel allocates an **inode**: a record holding the file's size, permissions, owner, timestamps, and the addresses of its data blocks. The inode holds everything about the file **except its name**.

The name lives in the directory, which is nothing more than a table mapping names to inode numbers. That indirection is why two names can refer to one file, and why deleting a name does not necessarily delete anything.

## Look at an inode

```bash
cd /root/investigation
```{{exec}}

```bash
stat access.log
```{{exec}}

Two fields matter here:

- **`Inode:`** is this file's real identity. Your number will differ from anyone else's; it is assigned when the file is created.
- **`Links:`** counts how many names point at this inode. Right now it is `1`.

## Two kinds of link

A **hard link** is another name for the same inode:

```bash
ln access.log evidence-copy.log
```{{exec}}

A **symbolic link** is its own separate file whose contents are a path:

```bash
ln -s access.log latest.log
```{{exec}}

Now look at all three together. The `-i` flag prints inode numbers in the first column:

```bash
ls -li
```{{exec}}

Three things to notice, in order of importance:

1. **`access.log` and `evidence-copy.log` show the same inode number.** They are not copies. They are two names for one file, and neither is the "original" as far as the filesystem is concerned.
2. **The link count on both is now `2`** (the third column).
3. **`latest.log` has a different inode and a size of 10 bytes.** The string `access.log` is exactly 10 characters. The symlink's content *is* that path.

Confirm it in one line:

```bash
stat -c "%n  inode=%i  links=%h  size=%s" access.log evidence-copy.log latest.log
```{{exec}}

## What happens when you delete

This is where the distinction earns its keep.

```bash
rm access.log
```{{exec}}

```bash
cat latest.log
```{{exec}}

The symbolic link is broken. It stored the text `access.log`, and that name no longer resolves to anything.

```bash
wc -l evidence-copy.log
```{{exec}}

The hard link is untouched, and all 45 lines are still there. The data was never "inside" the name `access.log` to begin with.

**`rm` does not delete files.** It removes a name and decrements the link count. The inode and its data are freed only when that count reaches zero.

> **The log that would not go away.** A service is writing to `/var/log/app.log`, the disk fills, and you `rm` the log. `df` still reports the disk full, because the running process holds the file open. The link count has not reached zero, so the blocks stay allocated even though no name points at them. `du` cannot see it, because `du` walks names. Until the service reopens its logs or restarts, that space is not coming back.

## Your task

Restore the situation so the investigation can continue.

You need `access.log` to exist again in `/root/investigation`, and you need the broken `latest.log` symlink cleaned up. The data is still available through the hard link.

<details><summary>Hint</summary>

The hard link `evidence-copy.log` still holds the data. Make a new name for it, and remove the dangling symlink:

```
cd /root/investigation
ln evidence-copy.log access.log
rm latest.log
```

</details>

When `access.log` is back and `latest.log` is gone, click **Check**.
