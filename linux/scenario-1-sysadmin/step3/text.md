# Step 3 — Repair a service that will not start

The collector is not running. Start it and watch what happens.

```bash
systemctl start analytics-collector.service
```{{exec}}

```bash
systemctl status analytics-collector.service --no-pager
```{{exec}}

## Read the failure properly

Two lines carry the whole diagnosis.

`Active: failed` with `(Result: exit-code)` tells you the process was launched and did not survive. Underneath it:

```
Process: NNNN ExecStart=/usr/local/bin/analytics-collector (code=exited, status=203/EXEC)
```

**`203/EXEC` is worth recognising on sight.** It means systemd could not execute the thing you pointed it at. Not "the program crashed", not "the config was wrong": the `exec` never happened. There are only a few causes, and they are all about the path itself:

- the file does not exist
- it exists but is not executable
- its interpreter line names something missing

The journal says the same thing in more words:

```bash
journalctl -u analytics-collector.service -n 12 --no-pager
```{{exec}}

Because `Restart=on-failure` is set, systemd tried again, failed again, and gave up after hitting the start limit. That is why the log shows several attempts rather than one.

## Find the actual cause

Look at what the unit is asking for:

```bash
grep ExecStart /etc/systemd/system/analytics-collector.service
```{{exec}}

Now look at what is really on disk:

```bash
ls -l /usr/local/bin/analytics-collector*
```{{exec}}

The unit names `analytics-collector`. The file is `analytics-collector.sh`. A rename that never made it into the unit file, which is one of the most common causes of `203/EXEC` there is.

## Your task

Get the service running, and make sure it comes back after a reboot.

Three things are required, and one of them is easy to forget:

1. Correct the `ExecStart` path in `/etc/systemd/system/analytics-collector.service`
2. Tell systemd to re-read the unit file
3. Start it **and** enable it

<details><summary>Hint on the step people miss</summary>

systemd reads unit files once and caches them. Editing the file changes nothing until you run:

```
systemctl daemon-reload
```

Skip it and `systemctl status` will keep showing you the old behaviour, which is maddening when you are certain you fixed the file.

</details>

<details><summary>Full solution</summary>

```
sed -i 's|^ExecStart=.*|ExecStart=/usr/local/bin/analytics-collector.sh|' \
    /etc/systemd/system/analytics-collector.service
systemctl daemon-reload
systemctl enable --now analytics-collector.service
systemctl status analytics-collector.service --no-pager
```

`enable --now` does both jobs at once: it creates the boot symlink and starts the unit.

</details>

<details><summary>If systemd refuses with "start request repeated too quickly"</summary>

`Restart=on-failure` retries on a timer, and enough failures in a short window trip a start limit. systemd then refuses to try again until you clear the failure state:

```
systemctl reset-failed analytics-collector.service
systemctl start analytics-collector.service
```

You will not usually need this here, but it is worth recognising, because the message looks like the fix did not work when in fact systemd never re-attempted it.

</details>

Note that `enable` and `start` are genuinely separate. A service can be running and disabled, which works perfectly until the machine reboots.

When the unit is active and enabled, click **Check**.
