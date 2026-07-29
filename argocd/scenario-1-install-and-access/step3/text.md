# Reach the API server

Nothing outside the cluster can reach Argo CD yet. Look at what the install created:

`kubectl get svc -n argocd -o custom-columns='NAME:.metadata.name,TYPE:.spec.type,PORTS:.spec.ports[*].port'`{{exec}}

Every service is `ClusterIP`. That is deliberate, not an oversight: Argo CD holds
credentials for every cluster and repository it manages, so it does not expose itself
until you decide how.

The one you want is `argocd-server`, on ports 80 and 443.

## Port-forward

`kubectl port-forward svc/argocd-server -n argocd 8080:443 > /tmp/pf.log 2>&1 &`{{exec}}

Give it a second to establish:

`sleep 3 && echo "forward running with PID $(pgrep -f 'port-forward svc/argocd-server' | head -1)"`{{exec}}

## Confirm what is answering

A `200` proves *something* is on that port. This proves it is Argo CD, and which build:

`curl -sk https://localhost:8080/api/version`{{exec}}

```
{"Version":"v3.4.5"}
```

`-k` is required because Argo CD generates a self-signed certificate at install time, so
your browser and `curl` are both right to object. That is expected here, and it is the
reason real deployments put an ingress with a proper certificate in front.

Check the UI itself responds too:

`curl -sk -o /dev/null -w "UI: HTTP %{http_code}\n" https://localhost:8080/`{{exec}}

## What the three access routes actually are

| Route | Reach it at | Needs | Use for |
| --- | --- | --- | --- |
| port-forward | `https://localhost:8080` | nothing | local work, debugging |
| LoadBalancer | the service's external address | a cloud load balancer | quick shared access |
| Ingress | your own hostname | `server.insecure=true` | anything real |

The Ingress row has a trap worth knowing before you meet it. `argocd-server` serves HTTPS
and refuses plain HTTP, answering with a `307` redirect to `https://`. An ingress that has
already terminated TLS then forwards plain HTTP again, so either the request loops until
the browser gives up, or it redirects somewhere unreachable. Two components both
insisting on owning TLS.

The fix is to let exactly one of them own it, by turning off the server's own TLS with
`server.insecure=true`. The name is alarming and the change is narrow: it does not
disable authentication, it stops `argocd-server` terminating TLS on the assumption that
something in front of it does.

Port-forward is a tunnel through your kubeconfig. It dies with your terminal and serves
exactly one person, which is perfect here and wrong for anything shared.
