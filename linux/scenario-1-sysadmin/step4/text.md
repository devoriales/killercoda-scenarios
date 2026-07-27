# Step 4 — Find the owner, then hold it still

A change freeze starts tonight. Before it does, two jobs: work out which package owns a binary nobody can account for, and make sure it does not move during the next upgrade.

## Which layer answers which question

Two tools are constantly mistaken for each other:

- **`dpkg`** installs and records single packages. It knows exactly what is on this machine and which file came from where. It knows nothing about repositories.
- **`apt`** works out what *could* be installed, resolves dependencies, and then calls `dpkg` to do it.

So: **questions about what IS installed go to `dpkg`, questions about what COULD be installed go to `apt`.**

## Find the owning package

```bash
which nft
```{{exec}}

That tells you where the binary is, and nothing about where it came from. For that, ask `dpkg`:

```bash
dpkg -S "$(which nft)"
```{{exec}}

This is the command to reach for when a binary turns up on a machine and nobody admits to installing it. The reverse direction is just as useful:

```bash
dpkg -L nftables | head -8
```{{exec}}

Every file that package put on disk.

## See which version apt would give you

```bash
apt-cache policy nftables
```{{exec}}

Three things to read:

- **`Installed:`** what is on the machine now
- **`Candidate:`** what you would get from `apt install`
- the numbers on the left are **priorities**. A normal repository is `500`, and the installed version itself is `100`. Highest priority wins; among equals, the highest version wins.

If `Candidate` is higher than `Installed`, the next upgrade will move this package.

## Hold it

A **hold** marks a package so no upgrade will touch it:

```bash
apt-mark hold nftables
```{{exec}}

```bash
apt-mark showhold
```{{exec}}

A held package shows up in the "kept back" list during an upgrade, which is why holds should be written down somewhere a colleague will find them. Nothing on the machine explains *why* you held it.

```bash
apt-get --simulate upgrade 2>/dev/null | grep -A3 "kept back" || echo "nothing kept back right now"
```{{exec}}

> **"Kept back" is not always a hold.** `apt upgrade` refuses to install new packages or remove existing ones. A kernel upgrade does not replace the running kernel; it installs a *new* versioned package alongside it, so the old one stays bootable. That is a new package, so plain `upgrade` skips it forever and reports it as kept back. On a fleet patched with `apt upgrade` in a cron job, the kernel is the thing that never gets patched. `full-upgrade` is what moves it, followed by a reboot.

## Your task

Two things:

1. Write the name of the package that owns the `nft` binary into `/root/answers/pkg.txt`, on its own, with nothing else in the file
2. Make sure that package is on hold

<details><summary>Hint</summary>

```
dpkg -S "$(which nft)" | cut -d: -f1 > /root/answers/pkg.txt
cat /root/answers/pkg.txt
apt-mark hold nftables
apt-mark showhold
```

`dpkg -S` prints `package: /path`, so `cut -d: -f1` keeps just the package name.

</details>

When the answer file is right and the hold is in place, click **Check**.
