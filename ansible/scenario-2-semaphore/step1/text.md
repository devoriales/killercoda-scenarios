# Open Semaphore in your browser

Semaphore is already running inside the lab on **port 3000**. Killercoda can expose any port
running in the environment to your browser through the **Traffic / Ports** feature.

## Open the Traffic/Ports menu

1. Look at the **top-right of the terminal panel** for the menu icon (☰ / three lines, or a
   tab labelled **Traffic / Ports**).
2. Click it and choose **Traffic / Ports**.
3. In **Custom ports**, type `3000` and click **Access**.

A new browser tab opens, served over HTTP, pointing at Semaphore.

> If the page shows an error the very first time, give it a few seconds and refresh — the
> Semaphore container may still be finishing its first start-up.

## Log in

Use the lab administrator account:

| Field | Value |
|---|---|
| Username | `admin` |
| Password | `ChangeMe123` |

You land on the **Acme Automation** project, which was pre-seeded for you. Have a quick look
around — you'll wire it up over the next steps.

You can confirm Semaphore is up from the terminal too:

```bash
docker ps --filter name=lab_semaphore
curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://127.0.0.1:3000/
```

Click **Check** when Semaphore is reachable.
