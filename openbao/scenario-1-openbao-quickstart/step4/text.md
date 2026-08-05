# Delete you can undo, destroy you cannot

K/V v2 has four ways to remove something and they are not interchangeable. The words are
similar; the consequences are not. This is the step worth remembering.

## Delete is a tombstone

`bao kv delete -versions=2 secret/production/db`{{exec}}

Now read that version back:

`bao kv get -version=2 secret/production/db`{{exec}}

```
deletion_time      2026-08-05T06:02:49Z
destroyed          false
version            2
```

The data is hidden and `deletion_time` is set, but look at `destroyed false`. The version
still exists. Nothing has actually been removed.

## So you can undo it

`bao kv undelete -versions=2 secret/production/db`{{exec}}

`bao kv get -version=2 secret/production/db`{{exec}}

`deletion_time n/a`, and the password is back. Note the API path in the success message:
`secret/undelete/production/db`. Each of these operations has its own path prefix, which
matters the moment you write code instead of typing commands.

## Destroy is not a tombstone

`bao kv destroy -versions=2 secret/production/db`{{exec}}

`bao kv get -version=2 secret/production/db`{{exec}}

```
deletion_time      n/a
destroyed          true
version            2
```

`destroyed true`, and no data. There is no `undestroy`. That version's ciphertext is gone.

Notice what remains: the version's slot in the history. That is deliberate. An auditor can
still see that a version existed and was destroyed, even though nobody can read what it
held. Removing the evidence and removing the secret are different requirements.

Look at the whole picture:

`bao kv metadata get secret/production/db`{{exec}}

Three states coexisting on one secret: live versions, and one destroyed. That history is the
thing K/V v2 buys you over K/V v1.

## And the one with no undo at all

`bao kv metadata delete` removes the secret **and every version of it**, history included.
Nothing survives. It is the only operation here with no residue and no recovery, which is
why it is worth typing deliberately rather than reaching for by habit.

Do not run it now, or the check for this step will fail. The command, for reference:

`# bao kv metadata delete secret/production/db`{{}}

## The summary worth keeping

| Operation | Reversible | What survives |
|---|---|---|
| `delete` | **yes**, via `undelete` | Everything. Data hidden, `deletion_time` set |
| `undelete` | n/a | Clears `deletion_time`, data readable again |
| `destroy` | **no** | The version's metadata, marked `destroyed: true` |
| `metadata delete` | **no** | Nothing at all |

One of the four has an undo. Recovering from the other two means going to your snapshots.
