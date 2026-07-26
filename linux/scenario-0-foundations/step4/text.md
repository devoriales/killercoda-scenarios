# Step 4 — Catch the scanner

Now the investigation. You have 45 requests and a report that checkout is failing. Two questions to answer: what is broken, and is anyone attacking the site?

## The log format

```bash
cd /root/investigation
```{{exec}}

```bash
head -2 access.log
```{{exec}}

This is nginx **combined format**. Split on spaces, the fields you need are:

| Field | Contents |
|---|---|
| `$1` | client IP address |
| `$7` | requested path |
| `$9` | HTTP status code |

## grep finds the lines

`grep` prints lines matching a pattern. Three flags cover almost everything:

```bash
grep -c " 404 " access.log
```{{exec}}

`-c` counts instead of printing. Eleven "not found" responses on a working shop is worth a look.

```bash
grep -n " 500 " access.log
```{{exec}}

`-n` adds line numbers. Every server error is on the same endpoint.

Note the spaces in `" 404 "`. Without them the pattern would also match a response size of `4040` or a path like `/product/404`. Anchoring a numeric field with the characters around it is the difference between a count you can trust and one that quietly overstates.

## awk works with fields

`grep` selects lines; `awk` takes them apart. It splits each line on whitespace and numbers the pieces `$1`, `$2`, and so on.

```bash
awk '{ print $1, $9 }' access.log | head -5
```{{exec}}

`awk` also has associative arrays, which turns it into a report generator. The shape is `pattern { action }` plus an `END` block that runs once at the finish:

```bash
awk '{ tally[$9]++ } END { for (s in tally) print tally[s], s }' access.log | sort -rn
```{{exec}}

The whole day classified in one pass.

## Who generated the 404s?

```bash
grep " 404 " access.log | awk '{ print $1 }' | sort | uniq -c | sort -rn
```{{exec}}

Read that pipeline stage by stage, because this shape recurs constantly:

1. `grep " 404 "` keeps only the not-found lines
2. `awk '{print $1}'` reduces each to its client address
3. `sort` groups identical addresses together
4. `uniq -c` collapses each run and prefixes the count
5. `sort -rn` puts the largest first

`uniq` only removes **adjacent** duplicates, which is why `sort` has to come first. Forget it and the pipeline fails quietly by reporting counts of 1.

Every 404 came from one address. Ask what it requested:

```bash
grep "^203.0.113.42" access.log | awk '{ print $9, $7 }'
```{{exec}}

WordPress admin pages, `/.env`, `/.git/config`, database backups, AWS credentials, an SSH private key. That is not a customer, it is a vulnerability scanner working through a list.

One response differs. `/server-status` returned **403**, not 404. A `403` means the path exists and is access controlled; a `404` means it does not exist at all. The scanner just learned that path is real, and that is the finding worth acting on.

## What is actually broken

The scan is noise. The 500 errors are the incident:

```bash
awk '$9 == 500 { print $1, $7 }' access.log | sort | uniq -c
```{{exec}}

Three different clients, one endpoint. When one client fails, suspect the client. When three unrelated clients fail identically on the same endpoint, the endpoint is broken.

```bash
awk '$7 == "/api/checkout" { print $9 }' access.log | sort | uniq -c
```{{exec}}

Six checkout attempts, four of them failed. Two thirds of your customers could not complete a purchase, and it was sitting in the log the whole time.

## Your task

Write up both findings.

1. Put the scanner's IP address into `/root/investigation/scanner.txt`
2. Put the broken endpoint's path into `/root/investigation/broken-endpoint.txt`

Each file should contain just the one value.

<details><summary>Hint</summary>

You already ran the commands that produce both answers. Write them out:

```
echo "203.0.113.42" > /root/investigation/scanner.txt
echo "/api/checkout" > /root/investigation/broken-endpoint.txt
```

Or derive the scanner address directly rather than typing it:

```
grep " 404 " access.log | awk '{ print $1 }' | sort -u > /root/investigation/scanner.txt
```

</details>

When both files are written, click **Check**.
