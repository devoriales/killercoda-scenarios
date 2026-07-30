# Progressive syncs, and the flag nobody mentions

An ApplicationSet that generates dev, staging and prod will sync all three **at the same
time**. A bad commit reaches production at the same moment it reaches dev, which removes the
entire point of having environments.

`RollingSync` updates them in ordered steps instead, waiting for each step to become Healthy
before starting the next.

`cat /root/manifests/04-rolling/appset-rolling.yaml`{{exec}}

Note that steps match on **labels of the generated Applications**, not on generator
parameters, which is why the template sets `envLabel` explicitly. Miss that label and the
Application matches no step, and an Application in no step is never synced by the strategy at
all. That is not an error.

## Apply it and watch nothing happen

`kubectl apply -f /root/manifests/04-rolling/appset-rolling.yaml`{{exec}}

`sleep 30 && kubectl get applications -n argocd | grep roll-`{{exec}}

All three arrive and sync **together**. No stagger, no waiting, no error about your strategy.

Confirm the controller is ignoring it:

`kubectl exec -n argocd deploy/argocd-applicationset-controller -c argocd-applicationset-controller -- sh -c 'echo "[$ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_PROGRESSIVE_SYNCS]"'`{{exec}}

```
[]
```

**Empty.** Progressive syncs are gated behind a ConfigMap key that is absent on a stock
install, and the controller accepts a `RollingSync` strategy without complaining when the
feature is off. The only symptom is that everything syncs at once, which looks like your steps
are wrong rather than like the feature is disabled.

## Turn it on

`kubectl patch cm argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"applicationsetcontroller.enable.progressive.syncs":"true"}}'`{{exec}}

`kubectl rollout restart deploy argocd-applicationset-controller -n argocd`{{exec}}

`kubectl rollout status deploy argocd-applicationset-controller -n argocd --timeout=180s`{{exec}}

Now verify the controller can see it:

`kubectl exec -n argocd deploy/argocd-applicationset-controller -c argocd-applicationset-controller -- sh -c 'echo "[$ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_PROGRESSIVE_SYNCS]"'`{{exec}}

```
[true]
```

## Watch the gate hold

The strategy only has visible work to do when there is something to change. Delete the
workloads and let it rebuild them in order:

`kubectl delete deploy --all -n rolling-demo`{{exec}}

`for i in $(seq 1 15); do kubectl get applicationset rolling-demo -n argocd -o json | python3 -c "import json,sys; print(' '.join(f\"{a['application'].replace('roll-','')}:s{a.get('step')}={a.get('status')}\" for a in json.load(sys.stdin).get('status',{}).get('applicationStatus',[])))"; sleep 2; done`{{exec}}

```
dev:s1=Pending  prod:s3=Waiting  staging:s2=Waiting
dev:s1=Healthy  prod:s3=Healthy  staging:s2=Healthy
```

**`Waiting` is the whole feature.** Steps 2 and 3 are not merely slower; they are held until
step 1 reports Healthy. The statuses run `Waiting`, then `Pending`, then `Progressing`, then
`Healthy`.

> **You may not catch `Waiting` at all, and that is expected.** These workloads are a single
> nginx pod whose image is already cached, so all three steps can finish inside a few seconds
> and every line you see reads `Healthy`. The loop above samples every two seconds to improve
> your odds. Seeing only `Healthy` does not mean the strategy was ignored: the step numbers in
> the output are the proof it is active, because an ignored strategy assigns no steps at all.

On a real rollout each step takes as long as its deployment does, which is when the gate
becomes visible and useful rather than a blink.

## What it protects you from, and what it does not

`RollingSync` gates on Argo CD's **health status**, and health for a Deployment means the
rollout completed and replicas are available. That is a real signal and a shallow one: a
Deployment can be perfectly Healthy while returning 500 to every request.

To gate on something meaningful, add a `PostSync` hook per environment that actually tests the
service, exactly as scenario 4 did. A failing hook makes the Application unhealthy, which
stops the next step. **Progressive steps plus a real smoke test** is what makes an automated
promotion pipeline trustworthy.

And do not confuse this with Argo Rollouts. `RollingSync` orders **whole Applications** against
each other. Canary and blue-green within a single service are a different tool.

<details><summary>A step that never finishes?</summary>

If staging never reaches Healthy, prod stays `Waiting` indefinitely and there is no error,
because nothing failed. Read the step assignment before assuming the controller is broken:

`kubectl get applicationset rolling-demo -n argocd -o jsonpath='{.status.applicationStatus}'`{{copy}}
</details>
