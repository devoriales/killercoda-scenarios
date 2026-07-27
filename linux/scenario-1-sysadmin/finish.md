# The host is yours now

You took over a machine nobody had maintained and left it in a state you could hand to someone else.

| Step | What you fixed | The tool |
|---|---|---|
| 1 | A world writable log and a shared directory losing its group | `chmod`, the setgid bit |
| 2 | One engineer granted read access, and nothing more | `setfacl`, `getfacl`, the mask |
| 3 | A unit failing with `203/EXEC`, started and made persistent | `systemctl`, `journalctl`, `daemon-reload` |
| 4 | The package owning an unexplained binary, then frozen | `dpkg -S`, `apt-mark hold` |

## Worth carrying forward

- **`777` does not just over-grant. It destroys the meaning of a record.** The log still named `analytics` as its owner after an unrelated account rewrote it, so the audit trail lied about who wrote that line.
- **A `+` on the end of `ls -l` output is the only sign an ACL exists.** The mode column will happily show you permissions that are not the whole story.
- **`chmod` on a file with ACLs moves the mask**, which can silently disarm a grant you made earlier. If an ACL "stops working", check the mask first.
- **`203/EXEC` always means the path, never the program.** The file is missing, not executable, or names a missing interpreter.
- **`daemon-reload` after every unit edit.** systemd caches unit files, and without it you are debugging the old version of your own change.
- **`enable` and `start` are independent.** Running and disabled is a service that works until the next reboot.
- **"Kept back" usually means your kernel is not being patched**, not that something is broken.

## Where this comes from

This lab is Module 2 of a longer written course. The lessons behind it go considerably deeper: `/etc/passwd` and `/etc/shadow` field by field, setuid and the sticky bit, `sudo` delegation through `/etc/sudoers.d`, fork and exec, zombies and orphans, SIGTERM against SIGKILL, reading a process through `/proc`, and the storage stack from block device to LVM.

**[Linux for DevOps Engineers on devoriales.com](https://devoriales.com/quiz/25/linux-for-devops-engineers)**

Each lesson ends with a knowledge check built around interpreting real output rather than recalling syntax.

Module 3 covers networking and diagnostics, SSH hardening, firewalls with nftables, and automation with Bash and systemd timers.
