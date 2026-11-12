# fstrim vs discard: a measured TRIM demo

Companion kit for [fstrim vs discard: Keeping SSDs Fast](https://sumguy.com/fstrim-vs-discard/).

`demo.sh` shows what TRIM does by watching a sparse disk image shrink. It creates a
2 GiB sparse file, attaches it as a loop device, formats it ext4, and then:

1. **Periodic TRIM:** mounts without `discard`, writes 1 GiB, deletes it, and shows the
   image stays at 1.1G until `fstrim` runs. It then runs `fstrim` a second time (0 B)
   and again after a remount (all free space again).
2. **Continuous discard:** mounts with `-o discard`, writes 1 GiB, deletes it, and shows
   the image shrinks right after `rm` and `sync`.

A sparse file reclaims space on discard the same way a thin-provisioned VM disk does
(qcow2, LVM thin, ZFS zvol). A physical SSD does not shrink visibly; its controller just
learns the blocks are free.

## Prerequisites

- Docker on a Linux host (tested with Docker 29.8.0, host kernel 6.8.0)
- About 1.2 GiB of free space in the kit directory while the demo runs

The container runs `--privileged` because it needs a loop device and permission to
mount it. Nothing is installed on the host. The script detaches the loop device and
deletes the image on exit.

## Run it

```bash
cd linux/fstrim-and-discard
docker run --rm --privileged -v "$PWD":/work debian:trixie /work/demo.sh
```

Expected output from our run (2026-11-12) is in `results.txt`. Your loop device
number will differ.

## Tested versions

- Image: `debian:trixie` (e2fsprogs and util-linux installed by the script)
- Host kernel: 6.8.0-138-generic
