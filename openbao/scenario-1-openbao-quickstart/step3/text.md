# Write a secret, then rotate it and read the old one back

OpenBao is a broker, not a database with an API on top. Paths map to plugins, and each
plugin decides what "read this path" means. Look at what a fresh instance actually has:

`bao secrets list`{{exec}}

```
Path          Type         Description
----          ----         -----------
cubbyhole/    cubbyhole    per-token private secret storage
identity/     identity     identity store
sys/          system       system endpoints used for control, policy and debugging
```

**No `secret/` mount.** A lot of writing assumes one exists, because Vault's `-dev` mode
creates it for convenience. Yours is a real instance. Mount a K/V version 2 store:

`bao secrets enable -path=secret -version=2 kv`{{exec}}

## Write something

`bao kv put secret/production/db username=dbadmin password=initial-secret`{{exec}}

Read the output carefully:

```
====== Secret Path ======
secret/data/production/db
```

You typed `secret/production/db`. The engine used `secret/data/production/db`.

The CLI hides a path segment that the API requires, and this is the single most common
source of confusion with K/V v2. A `curl` to `secret/production/db` returns 404 and looks
like a permissions problem. That `Secret Path` line exists precisely because people trip on
this, and it is telling you the path your code will need.

## Rotate it

`bao kv put secret/production/db username=dbadmin password=rotated-once`{{exec}}

`bao kv put secret/production/db username=dbadmin password=rotated-twice`{{exec}}

Read it back:

`bao kv get secret/production/db`{{exec}}

Version 3, password `rotated-twice`. Now ask for the first one:

`bao kv get -version=1 secret/production/db`{{exec}}

```
password    initial-secret
```

Still there. Still readable.

## Sit with that for a second

**Rotating a secret in K/V v2 does not invalidate the old one.** It records a new version.

If `initial-secret` still works against your actual database, K/V v2 has not protected you
from anything. It has documented what happened. That is useful for audit and rollback, and
it is not revocation.

Credentials that genuinely stop working when you rotate them are **dynamic secrets**: OpenBao
generates them on demand, hands them out with a lease, and revokes them at the source when
the lease ends. Different engine, covered in the full course.

See the whole history:

`bao kv metadata get secret/production/db`{{exec}}

Note `max_versions 0`, meaning unlimited. A secret rotated hourly by automation accumulates
versions forever. Fine here, worth setting on a busy path.
