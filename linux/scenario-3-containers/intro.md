# Build the thing before you use the thing

A container is not a lightweight virtual machine. It is an ordinary Linux process that has been given a restricted view of the system, and every one of those restrictions is a kernel feature that existed before containers did.

You are going to use those features directly, with no container tooling at all, and watch the kernel enforce them. Only then will you start a real container, and by that point there will be nothing surprising about it.

## What you will do

- **Create namespaces by hand** with `unshare`, and watch a process become PID 1 in a world of its own
- **Write a memory limit** into the cgroup filesystem and watch the kernel kill a process for crossing it
- **Run a container as an unprivileged user**, with no daemon and no root, and find its process on the host
- **Put a reverse proxy in front of it**, so the application binds to loopback and only the proxy is exposed

## The host you are given

| Thing | State |
|---|---|
| `appops` | An ordinary user. No sudo, no docker group, with subordinate UID ranges for rootless Podman |
| `podman` | Installed |
| `nginx` | Installed and stopped, so it is not holding port 80 |
| cgroups | v2, with nothing of yours in it yet |

You are `root` unless a step says otherwise. This is a disposable machine, so break things freely.

By the end you will be able to point at a running container and name every kernel object that makes it one.
