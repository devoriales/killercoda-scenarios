# One host, everything you have learned

This is the machine every lesson in this course was a piece of.

You are going to build a gateway: an application serving over a proxy, its data on a volume you can grow, its service account unable to log in, its ports closed except the ones you name, and something checking all of it on a schedule.

There is no new material here. What is new is that nothing is done for you, and that at the end a script decides whether you are finished.

## The nine requirements

| # | Requirement |
|---|---|
| 1 | Data on an LVM volume, mounted through `/etc/fstab` |
| 2 | A locked service account owning it |
| 3 | SSH key-only, listening on a non-default port |
| 4 | Default-deny firewall with connection tracking |
| 5 | The application in a rootless container, on loopback |
| 6 | A reverse proxy in front, managed by systemd |
| 7 | Resource limits that actually reach the kernel |
| 8 | A health check that exercises the real path |
| 9 | A timer, so a failure announces itself |

**Build them in that order.** Each depends on the ones before it, and taking them out of order is how people lock themselves out.

## Your instrument

```
gateway-validate
```

Run it now and it will tell you how far you are from done. Run it after every step. It reads the running system, never a file you wrote, which means it will catch things you were certain you had configured.

## The one difference from a real host

This VM has no spare disks, so a 1 GB file has been attached as a loop device for you to practise LVM on. It behaves like a real block device for everything here.

```bash
losetup -a
```{{exec}}

Nothing else has been built. Start with `gateway-validate` and see what you are up against.
