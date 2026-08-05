# Deploy OpenBao, and meet a pod that is not Ready

OpenBao ships as a Helm chart. You are deploying it **standalone**: a single replica on file
storage, no clustering. High availability means Raft, and Raft means quorum and leader
election, which is a lot to take on before you have seen the thing run at all.

The values file is already on disk. Have a look at what it asks for:

`cat /root/manifests/values-quickstart.yaml`{{exec}}

Two lines are worth noticing before you apply it. The readiness probe is enabled and the
liveness probe is not. That is deliberate, and step 2 will show you why.

Create the namespace and install:

`kubectl create namespace openbao`{{exec}}

`helm install openbao openbao/openbao --namespace openbao --version 0.28.6 --values /root/manifests/values-quickstart.yaml`{{exec}}

Now watch the pod:

`kubectl get pods -n openbao`{{exec}}

Give it a few seconds and run that again. You are looking for this:

```
NAME        READY   STATUS    RESTARTS   AGE
openbao-0   0/1     Running   0          25s
```

## Read that carefully

`0/1`, but `Running`, and zero restarts.

That is not a broken deployment. The container started, the process is up, and it is
answering requests. It is reporting itself **not ready**, which is honest: an OpenBao that
has never been initialized holds no keys and can decrypt nothing, so routing traffic to it
would be pointless.

The readiness probe in that values file runs `bao status` inside the container, and that
command's exit code *is* the seal status: `0` unsealed, `2` sealed. Kubernetes is reading
the seal state directly.

Ask the instance yourself:

`bao status`{{exec}}

```
Initialized     false
Sealed          true
Total Shares    0
Threshold       0
```

`Initialized false` means no keys have ever been generated for this instance. `Sealed true`
follows from that: there is nothing to unseal with yet.

Both of those are about to change.

<details><summary>Why is the liveness probe disabled?</summary>

A liveness probe answers "is this process wedged, restart it". No HTTP health check on
OpenBao can answer that, because the states you would key on are legitimate: sealed answers
`503` and uninitialized answers `501`, and both are correct conditions rather than faults.

Enable liveness naively and Kubernetes restarts the pod every few seconds during exactly
the window where you are trying to initialize and unseal it, re-sealing the instance each
time. You can watch the restart counter climb while you work. It is a memorable way to
learn this and a slow one.

</details>
