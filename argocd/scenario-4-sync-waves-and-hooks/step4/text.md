# Sync windows: when a sync is allowed at all

Every `argocd app get` you have run has printed a line nobody explained:

```
SyncWindow:         Sync Allowed
```

It has said `Sync Allowed` every time because no window was configured. This step makes it say
something else.

## Scheduling, not permission

An `AppProject` answers *what* an Application may do: which repos, which namespaces, which
kinds. A **sync window** answers a different question: **may a sync happen right now.**

The two are unrelated. An Application can be perfectly entitled to deploy and still be refused
because it is 2 a.m. on a Sunday during a change freeze.

`cat /root/manifests/04-windows/windowed-project.yaml`{{exec}}

| Field | Means |
| --- | --- |
| `kind` | `allow` or `deny` |
| `schedule` | cron expression for when the window **opens** |
| `duration` | how long it stays open |
| `applications` | glob patterns matching Application names |
| `manualSync` | may a human still sync by hand while this applies |

The window in that file is always active, which makes the demo deterministic instead of
depending on what time you run it. A realistic one is `schedule: '0 9 * * 1-5'` with
`duration: 8h`, meaning weekday office hours.

**Windows live on the project, not the Application.** That is what makes them a fleet-wide
control rather than something each team sets for itself.

## Watch a sync get refused

`kubectl apply -f /root/manifests/04-windows/windowed-project.yaml`{{exec}}

`kubectl apply -f /root/manifests/04-windows/windowed-application.yaml`{{exec}}

`argocd proj windows list windowed`{{exec}}

```
ID  STATUS  KIND  SCHEDULE   DURATION  APPLICATIONS  MANUALSYNC
0   Active  deny  * * * * *  24h       *             Disabled
```

`Active` means it applies right now. Look at the Application:

`argocd app get windowed-app`{{exec}}

```
SyncWindow:         Sync Denied
Sync Status:        OutOfSync
```

**`Sync Denied`**, and the app is knowingly `OutOfSync`. Argo CD can see the difference and is
choosing not to act. Try anyway:

`argocd app sync windowed-app`{{exec}}

```
FATA rpc error: code = PermissionDenied desc = cannot sync: blocked by sync window
```

Not a warning, not a queued operation. Refused.

## Letting humans through

A change freeze that also blocks the person fixing the outage is a bad change freeze. That is
what `manualSync` is for:

`kubectl patch appproject windowed -n argocd --type=json -p='[{"op":"replace","path":"/spec/syncWindows/0/manualSync","value":true}]'`{{exec}}

`argocd app get windowed-app`{{exec}}

```
SyncWindow:         Manual Allowed
```

A third state, distinct from both. **Automation stays blocked, a human may proceed.** And it
works:

`argocd app sync windowed-app`{{exec}}

That combination, a deny window with `manualSync: true`, is the one most teams actually want:
auto-sync stops during the freeze, on-call can still ship a fix.

## How overlapping windows resolve

Short and worth memorising, because it is the opposite of what people assume: **deny wins.**

- No windows: everything allowed. That is the default you have had all along.
- Any active `allow` window: sync permitted during it.
- Any active `deny` window: blocked, **even if an `allow` window is active at the same time**.

So you cannot punch a hole in a deny window by layering an allow window over it. To create an
exception you narrow the deny window's `applications` glob, or you use `manualSync`.

<details><summary>A window that never seems to open?</summary>

`schedule` is evaluated in the controller's timezone, UTC unless you set `timeZone`. A team
writes `0 9 * * 1-5` meaning their 9 a.m., and it opens at 9 UTC.

Check what Argo CD believes rather than what you intended:

`argocd proj windows list windowed`{{copy}}

The `TIMEZONE` column is empty when none was set, which means UTC.

Also beware that adding a single `allow` window **denies syncs at every other time**, which is
how teams accidentally stop auto-sync overnight.
</details>
