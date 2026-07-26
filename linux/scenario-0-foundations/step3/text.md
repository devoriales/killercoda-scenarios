# Step 3 — Read the metadata

Every file carries a record of who owns it, who may read it, how big it is, and when it last changed. Reading that record is often faster than opening the file, and on a machine you do not know it is where you start.

## The long listing, field by field

```bash
ls -l /root/course-data
```{{exec}}

Take the first ten characters of a line such as `-rw-r-----`:

| Position | Example | Meaning |
|---|---|---|
| 1 | `-` | file type: `-` regular, `d` directory, `l` symlink |
| 2 to 4 | `rw-` | what the **owner** may do |
| 5 to 7 | `r--` | what members of the **group** may do |
| 8 to 10 | `---` | what **everyone else** may do |

Each triple is read, write, execute in that order, and a `-` means not permitted. So `-rw-r-----` is a regular file the owner can read and write, the group can only read, and everyone else cannot touch at all.

Those triples are also written as three digits, where read is 4, write is 2, and execute is 1. Add them up per triple and `rw-r-----` becomes `640`.

```bash
stat -c "%a  %U:%G  %n" /root/course-data/*
```{{exec}}

`access.log` is `644`, readable by anyone on the system. `app.conf` is `640`, deliberately hidden from users outside its group, which is how you should treat anything holding a credential.

Permissions get a full treatment later in the course. For now the point is that `stat` tells you in one line what `ls -l` makes you decode.

## Useful stat formats

`stat -c` takes a format string, which makes it far more scriptable than `ls`:

| Format | Prints |
|---|---|
| `%n` | file name |
| `%s` | size in bytes |
| `%a` | permissions in octal |
| `%U` / `%G` | owner / group name |
| `%i` | inode number |
| `%h` | number of hard links |
| `%y` | last modification time |

```bash
stat -c "%n is %s bytes, last modified %y" /root/investigation/access.log
```{{exec}}

## Finding files by their properties

`find` searches by metadata rather than content, which is what you want when you know something about a file but not where it is:

```bash
find /root -type f -size +2k
```{{exec}}

```bash
find /root -type f -name "*.log"
```{{exec}}

`-type f` restricts to regular files, `-size +2k` means larger than 2 kilobytes, and `-name` matches the filename. Combine them freely.

## When the disk is full but it is not

Inodes are a finite resource, allocated when the filesystem is created. A filesystem can run out of them while still reporting free space.

```bash
df -h /
```{{exec}}

```bash
df -i /
```{{exec}}

`df -h` counts bytes. `df -i` counts inodes. Millions of tiny files will exhaust the inode table long before they fill the disk, and the kernel reports that with the same `No space left on device` error used for a genuinely full disk.

That is why, when a disk-full error does not match what `df -h` tells you, `df -i` is the next command. It is a two second check that explains an otherwise baffling failure.

## Your task

Record the permissions of the sensitive config file so the finding is written down.

Write the **octal permissions of `/root/course-data/app.conf`** into a file at `/root/investigation/metadata.txt`. The file should contain just the three digit number.

<details><summary>Hint</summary>

`stat -c %a` prints exactly the octal mode and nothing else, so you can redirect it straight into the file:

```
stat -c %a /root/course-data/app.conf > /root/investigation/metadata.txt
```

</details>

When the file holds the right number, click **Check**.
