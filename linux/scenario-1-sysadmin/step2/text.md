# Step 2 — Grant one person access, not a group

Tunde is on call. He needs to read the collector log while investigating an alert. He is not `analytics`, and he is not in the `analytics` group.

```bash
runuser -u tokafor -- cat /srv/analytics/logs/collector.log
```{{exec}}

`Permission denied`, and correctly so: you set that file to `640` in step 1, which gives `other` nothing.

## The three tempting shortcuts, and why each is wrong

**Add him to the `analytics` group.** He then gets access to everything that group owns, permanently, long after this incident is closed.

**Loosen `other` to `r`.** You have just published the log to every account on the machine, which is most of what you fixed in step 1.

**Change the owner.** The service breaks.

The permission triad can only describe one user, one group, and everyone else. This request does not fit, and that is exactly what **POSIX ACLs** are for.

## Grant exactly what was asked

An ACL adds a rule for one named user without touching the owner, the group, or the `other` bits:

```bash
setfacl -m u:tokafor:r /srv/analytics/logs/collector.log
```{{exec}}

```bash
runuser -u tokafor -- cat /srv/analytics/logs/collector.log
```{{exec}}

He can read it. Now look at what changed:

```bash
ls -l /srv/analytics/logs/collector.log
```{{exec}}

The mode still reads `-rw-r-----`, which says Tunde has no access. The only visible difference is the **`+`** at the end. That single character is the entire signal that extra rules exist, and it is easy to miss when you are reading `ls` output quickly.

```bash
getfacl /srv/analytics/logs/collector.log
```{{exec}}

`user::rw-` with the empty field is the owner. `user:tokafor:r--` is the rule you added.

## The mask, which quietly limits everything

```bash
chmod g-r /srv/analytics/logs/collector.log
```{{exec}}

```bash
getfacl /srv/analytics/logs/collector.log
```{{exec}}

Look at `mask::` and at Tunde's line. **`chmod` on a file with ACLs adjusts the mask**, and the mask is a ceiling on every named entry. An unrelated permission change has just disarmed the grant you made a moment ago.

```bash
runuser -u tokafor -- cat /srv/analytics/logs/collector.log
```{{exec}}

Denied again, without anyone touching his ACL entry. When an ACL "does not work", a mask narrower than the entry is nearly always the reason.

## Your task

Put it back so that:

- `tokafor` can read `/srv/analytics/logs/collector.log`
- the file is still owned by `analytics:analytics`
- `other` still has **no** access

<details><summary>Hint</summary>

Restore the group read bit, which lifts the mask again, and make sure the ACL entry is present:

```
chmod 640 /srv/analytics/logs/collector.log
setfacl -m u:tokafor:r /srv/analytics/logs/collector.log
runuser -u tokafor -- cat /srv/analytics/logs/collector.log
```

</details>

When Tunde can read the log and nobody else gained anything, click **Check**.
