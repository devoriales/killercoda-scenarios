# "Get it online, and don't let it wake us up"

A four person team has been running their analytics dashboard on a laptop under someone's desk. It has outgrown that.

You have been handed a fresh VM, an application that serves HTTP on port 8080, and one sentence of requirements: **get it online, and don't let it be the thing that wakes us up.**

That is the whole brief, and it is the brief you will actually receive in a job. Nobody hands you a checklist. They hand you a machine and an expectation.

## What is behind that sentence

- **The dashboard holds customer data.** Not a lot, but enough that "somebody got in through the analytics box" would be a bad week.
- **It faces the internet.** People will open it on their phones.
- **It will grow.** More data sources are coming, and the volume it writes to has to get bigger without downtime.
- **Nobody is watching it.** There is no ops team. If it breaks at 2am on a Sunday it stays broken until somebody happens to look.
- **You will not be maintaining it.** In six months this is someone else's problem, and they will have to understand what you did from the machine alone.

## What goes wrong if you cut a corner

Every requirement here exists because of an ordinary failure, not a theoretical one:

| Skip this | And this happens |
|---|---|
| LVM and an `fstab` entry | The disk fills in month three, or the volume is not mounted after a reboot and the app quietly writes into the root filesystem |
| A locked service account | The application runs as root, and one bug in it is one bug away from the whole machine |
| SSH hardening | The box sits on the internet accepting passwords, and the logs fill with login attempts within hours |
| A firewall | Every port anything opens is reachable by everyone, including things you did not know were listening |
| A container on loopback | The application is directly exposed and the proxy in front of it is decoration |
| A reverse proxy | You have no single place to terminate TLS, route by name, or control access |
| Resource limits | One runaway query takes the machine down, and takes SSH with it, so you cannot get in to fix it |
| A health check that really works | The dashboard is broken for a week and a customer notices first |
| A timer | The health check you wrote is never run |

The last two are the ones people skip, and they are the ones that turn a small problem into a long one.

## How you will know you are finished

Not by running the commands. By running this:

```
gateway-validate
```

It inspects the **running system** and reports pass or fail on all nine requirements. It does not read your notes and it does not care what you meant to do.

That is the real subject of this lab: proving your own work instead of believing it.

## Two practical notes

There is no new material here. Every technique came from an earlier module. What is new is that nothing is done for you, and the requirements depend on each other in an order that only becomes obvious when you get it wrong. **Build them in the order the steps give you.**

This VM has no spare disks, so a 1 GB file has been attached as a loop device for you to practise LVM on. It behaves like a real block device for everything you will do here.

```bash
losetup -a
```{{exec}}

Now find out what you are up against.

```bash
gateway-validate
```{{exec}}
