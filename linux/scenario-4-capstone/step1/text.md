# Step 1 — Storage and the account that owns it

Run the checklist first, so you know what "done" looks like:

```bash
gateway-validate
```{{exec}}

Lots of red. Work up from the bottom of the list.

## The volume

Find the loop device that was attached for you:

```bash
losetup -j /var/lib/gateway-disk.img
```{{exec}}

Build the stack on it: physical volume, volume group, logical volume, filesystem.

```bash
LOOP=$(losetup -j /var/lib/gateway-disk.img | cut -d: -f1)
pvcreate -ff -y "$LOOP"
vgcreate vg_gateway "$LOOP"
lvcreate -L 700M -n lv_appdata vg_gateway
mkfs.xfs -q -L appdata /dev/vg_gateway/lv_appdata
```{{copy}}

Note the 700M out of roughly 1 GB. **Do not allocate the whole volume group.** Unallocated space is what lets you grow whichever volume turns out to need it, and space you have not committed costs nothing.

## Mount it so it survives a reboot

```bash
mkdir -p /srv/gateway
printf '/dev/vg_gateway/lv_appdata  /srv/gateway  xfs  defaults,nofail  0  2\n' >> /etc/fstab
mount -a
findmnt -no SOURCE,FSTYPE,TARGET /srv/gateway
```{{exec}}

`mount -a` rather than a bare `mount`: it exercises the `fstab` entry, so a mistake surfaces now instead of at the next reboot. `nofail` means a missing data disk does not hold the boot.

## The account that owns it

```bash
groupadd --system appsvc
useradd --system --gid appsvc --home-dir /srv/gateway \
        --shell /usr/sbin/nologin --comment "Gateway application service" appsvc
passwd -l appsvc
usermod --add-subuids 300000-365535 appsvc
usermod --add-subgids 300000-365535 appsvc
loginctl enable-linger appsvc
chown -R appsvc:appsvc /srv/gateway
```{{copy}}

Three of those lines are easy to skip and cost you later. `passwd -l` locks the password so the account cannot be logged into at all. The **subuid and subgid ranges** are what rootless Podman needs in step 3, and nothing complains until a container fails with a mapping error. `enable-linger` lets that user's containers keep running when nobody is logged in.

```bash
getent passwd appsvc; stat -c '%U:%G %a %n' /srv/gateway
```{{exec}}

## Your task

Requirements 1 and 2 passing:

```bash
gateway-validate
```{{exec}}

The first two sections should be green. When they are, click **Check**.
