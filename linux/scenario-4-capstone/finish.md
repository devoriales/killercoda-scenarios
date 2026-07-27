# You built it, and something independent agreed

```
27 passed, 0 failed
Gateway meets every requirement.
```

That line is the point of the whole exercise. Not that the commands ran, but that a script which reads the running system, and which you did not get to argue with, agreed you were finished.

| Requirement | What proves it |
|---|---|
| LVM storage, mounted from fstab | `findmnt`, and an `/etc/fstab` entry |
| Locked service account owning it | `passwd -S` reporting `L`, a nologin shell |
| SSH key-only on a non-default port | `sshd -T` **and** `ss`, because they can disagree |
| Default-deny firewall with conntrack | policy `drop`, plus outbound DNS still working |
| Rootless container on loopback | `ps` showing a non-root owner, `ss` showing `127.0.0.1` |
| Limits that reach the kernel | `memory.max` in the cgroup, not the flag you typed |
| A health check that can fail | tested in both directions |
| A timer | `systemctl --failed` would surface it |

## The three things worth taking with you

**Verify against the system, not against your intent.** The `ssh.socket` trap in step 2 is the clearest example this course has: `sshd -t` passed, `sshd -T` reported port 2222, and nothing was listening on it. Every one of those outputs was truthful and the machine was still unreachable. Only `ss` told you.

**A check that cannot fail is worse than no check.** It converts silence into false confidence. Test the failure path before you trust the success path, every time.

**Keep the session open.** An established SSH connection is an already-accepted socket, so it survives a socket restart and a firewall change. That single fact is what makes SSH and firewall work recoverable, and closing the first session before proving the second is what turns a mistake into a rebuild.

## Where to go now

You have built and defended a complete host from the block device up. The written course goes deeper on every piece: inodes and hard links, fork and exec, zombies and orphans, the netfilter hook model, overlay filesystems and whiteouts, agent forwarding, and automatic certificate renewal.

**[Linux for DevOps Engineers on devoriales.com](https://devoriales.com/quiz/25/linux-for-devops-engineers)**

If you worked through all five labs in this series, you have covered the filesystem and text processing, users and permissions and systemd, networking and hardening, container primitives, and now the whole thing assembled. That is a working foundation for anything that runs on Linux.
