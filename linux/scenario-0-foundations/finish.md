# Done

You started with a log file and a vague report. You finish with two concrete findings and the tools that produced them.

| Step | What you learned | Tools used |
|---|---|---|
| 1 | The filesystem has one tree with a standard layout, and paths can be absolute or relative | `ls`, `pwd`, `cd`, `file`, `cp` |
| 2 | A name is not the file. The inode is, and `rm` removes a name rather than data | `stat`, `ln`, `ln -s`, `ls -li`, `rm` |
| 3 | Metadata answers questions faster than opening a file, and inodes run out separately from disk space | `stat -c`, `find`, `df -h`, `df -i` |
| 4 | Small tools piped together turn a log into an answer | `grep`, `awk`, `sort`, `uniq` |

## What you found

- **`203.0.113.42` is a vulnerability scanner.** Twelve requests, eleven of them 404, walking a list of credential and admin paths. The one that returned **403** rather than 404 is the one that matters: `/server-status` exists and is access controlled, which tells an attacker there is something real behind it.
- **`/api/checkout` is broken.** Four of six attempts returned 500, across three unrelated clients. A failure that reproduces across independent clients is server side.

## Worth carrying forward

- **`rm` decrements a link count.** Data disappears only when the last name is gone and no process still holds the file open. This is why deleting a log sometimes fails to free any disk space at all.
- **`sort` before `uniq -c`.** `uniq` only collapses adjacent duplicates, so an unsorted pipeline fails quietly rather than loudly.
- **Anchor numeric patterns.** `grep " 404 "` and `grep 404` return very different counts, and only one of them is the answer to your question.
- **`403` and `404` are different findings.** One confirms a path exists, the other confirms it does not. Attackers read that difference, and so should you.
- **Check `df -i` when `df -h` disagrees with a disk-full error.** Inodes are exhausted separately from bytes.

## Next

This lab covers Module 1 of the full Linux course, which is free.

**[Linux for DevOps Engineers on devoriales.com](https://devoriales.com/quiz/25/linux-for-devops-engineers)**

The four written lessons behind this lab go deeper than a terminal session can: why two different Ubuntu userlands both report the very same kernel, what a system call actually is and how to watch one happen, the Filesystem Hierarchy Standard, and the three streams that make pipelines work. Each ends with a knowledge check.

After that, Module 2 covers users and permissions, process lifecycle and systemd, storage and LVM, and package management.
