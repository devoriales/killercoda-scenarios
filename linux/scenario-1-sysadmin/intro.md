# You now own the analytics host

The engineer who built this box left last month. It runs one thing: a collector that ingests batches and writes to a log. It has been limping, nobody has touched the permissions since it was set up in a hurry, and this morning the service is not running at all.

You have root. Nothing here is exotic, and that is the point: every fault on this machine is one you will meet on real systems, usually created by someone in a rush who meant to come back and tidy up.

## What you will deal with

- A log file at mode `777`, which means anyone with a shell can rewrite the record while it still shows the service as its owner
- A shared release directory that keeps producing files the rest of the team cannot read
- An on-call engineer who needs to read one log, and a tempting shortcut that would give them far more than that
- A `systemd` unit that fails instantly with an error code worth recognising on sight
- A package that must not move during the next upgrade window

## The people involved

| Account | What they are |
|---|---|
| `analytics` | System account. No password, no login shell. It exists to own a process. |
| `rjimenez` | Deploy engineer, member of `deployers` |
| `tokafor` | On call this week, member of `oncall`. Not in `deployers` or `analytics`. |

Everything lives under `/srv/analytics`. Work as `root` throughout.

Let's get it back into a state you would be willing to hand to someone else.
