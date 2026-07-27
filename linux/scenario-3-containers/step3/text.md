# Step 3 — Run a container with no root and no daemon

You have made the pieces by hand. Now let something assemble them for you, and check that it did what you expect.

The user `appops` has no sudo, no membership of any `docker` group, and no special privileges:

```bash
id appops
```{{exec}}

## Rootless needs a range of UIDs to map

```bash
grep appops /etc/subuid /etc/subgid
```{{exec}}

That range is what makes rootless work. Inside the container the process can be UID 0, and the user namespace maps that to an unprivileged host UID somewhere in the 200000 block. **Root in the container is not root on the host**, and without those ranges every rootless run fails with a mapping error.

## Start it

```bash
su - appops -c 'podman run -d --name app --memory=64m -p 8080:80 docker.io/library/nginx:alpine'
```{{exec}}

```bash
su - appops -c 'podman ps'
```{{exec}}

```bash
curl -s -o /dev/null -w "app on 8080 -> HTTP %{http_code}\n" http://127.0.0.1:8080/
```{{exec}}

No daemon was involved. `podman run` forked the container from that user's own session, which is why there is no system service to look at and why a rootless container belongs to the person who started it.

## Find it on the host

A container is a process. Prove it:

```bash
su - appops -c "podman inspect --format '{{.State.Pid}}' app"
```{{exec}}

```bash
ps -o pid,user,comm -p "$(su - appops -c "podman inspect --format '{{.State.Pid}}' app")"
```{{exec}}

Look at the `USER` column. The container believes it is running nginx as root; on the host it is an unprivileged UID from the mapped range. That is the user namespace from step 1, doing the job it exists for.

## The same primitives you built

```bash
PID=$(su - appops -c "podman inspect --format '{{.State.Pid}}' app")
readlink /proc/$PID/ns/pid; readlink /proc/self/ns/pid
```{{exec}}

Different PID namespaces, exactly as `unshare` produced in step 1.

```bash
cat /proc/$PID/cgroup
```{{exec}}

And a cgroup path, exactly as you wrote by hand in step 2. `--memory=64m` was a convenience for the `memory.max` file you already know how to set.

## Your task

Have a container named **`app`** running, owned by **`appops`**, serving on **port 8080** of the host.

It must be genuinely rootless: the host process must not be running as `root`.

<details><summary>Hint</summary>

```
su - appops -c 'podman run -d --name app --memory=64m -p 8080:80 docker.io/library/nginx:alpine'
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/
```

If a container of that name already exists from an earlier attempt:

```
su - appops -c 'podman rm -f app'
```

</details>

When it answers on 8080 and its host process is not root, click **Check**.
