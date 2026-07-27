# You can now name every part of it

You built the pieces by hand, watched the kernel enforce them, and only then ran a container. Nothing about it should feel like magic now.

| Step | What you did | The primitive |
|---|---|---|
| 1 | Became PID 1 in a world of one process | Namespaces |
| 2 | Wrote a limit and watched a process get killed for crossing it | cgroups v2 |
| 3 | Ran a container as an unprivileged user with no daemon | User namespaces, subuid ranges |
| 4 | Made the container private and put a proxy in front | Loopback binding, reverse proxy |

## Worth carrying forward

- **A container is a process.** It appears in `ps`, it has a PID on the host, and you can read everything about it from `/proc` and `/sys/fs/cgroup`.
- **Namespaces hide, cgroups limit.** They are different mechanisms solving different problems, and confusing them makes container behaviour look arbitrary.
- **`--mount-proc` is why isolation looks real.** Without a fresh `/proc`, a process in a new PID namespace still reads the host's process list, and the boundary appears not to work when in fact you are looking through the wrong window.
- **Exit 137 means SIGKILL**, which for a container is usually the OOM killer. `memory.events` names it directly, and `oom_kill` is the line to read.
- **`--memory=64m` writes `memory.max`.** Every engine flag corresponds to kernel state you can inspect yourself, which is what makes containers debuggable rather than mysterious.
- **Root in a container is not root on the host** when user namespaces are in play. The subuid range is what makes that mapping possible, and its absence is the usual cause of rootless failing outright.
- **Publish to loopback and proxy to it.** A container bound to `0.0.0.0` is exposed to everyone who can reach the host, and no firewall rule is as reliable as never listening there.

## The habit worth keeping

When something about a container is confusing, drop a level. Find the PID, read `/proc/PID/ns/`, read its cgroup files. The engine's own output is a summary; the kernel's is the truth.

## Where this comes from

This is Module 4 of a written course that goes further: overlay filesystems and why a deleted file is still in the image, whiteouts, TLS termination with automatic certificate renewal, and running an inference server as a properly governed daemon with resource limits and a health check that exercises the actual function.

**[Linux for DevOps Engineers on devoriales.com](https://devoriales.com/quiz/25/linux-for-devops-engineers)**

The capstone brings the whole course together: LVM storage, hardened SSH, a firewall, a rootless container behind a TLS proxy, and a systemd timer checking it all.
