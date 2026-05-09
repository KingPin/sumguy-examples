# ZFS vdev Layout Reference

Capacity math and design rationale for common RAID-Z and dRAID configurations.

All examples assume equal-sized drives. Usable capacity = (data drives / total drives) × raw capacity.

---

## RAID-Z2 Layouts

### 6-Drive RAID-Z2 (recommended home lab starting point)

```
vdev: raidz2
drives: 6
parity: 2
data: 4
efficiency: 4/6 = 66.7%
```

**Capacity math (6 × 4TB drives):**
- Raw: 24TB
- Usable: ~16TB
- Survives: any 2 simultaneous drive failures

**Create:**
```bash
zpool create mypool raidz2 /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf
```

**Characteristics:**
- Rebuild time on 4TB drives: ~6–12 hours depending on data and I/O load
- Random IOPS: limited to single vdev (add more vdevs for more IOPS)
- Good general-purpose layout for 4–8 bay NAS boxes

---

### 8-Drive RAID-Z2

```
vdev: raidz2
drives: 8
parity: 2
data: 6
efficiency: 6/8 = 75%
```

**Capacity math (8 × 4TB drives):**
- Raw: 32TB
- Usable: ~24TB
- Survives: any 2 simultaneous drive failures

**Create:**
```bash
zpool create mypool raidz2 \
  /dev/sda /dev/sdb /dev/sdc /dev/sdd \
  /dev/sde /dev/sdf /dev/sdg /dev/sdh
```

**Characteristics:**
- Rebuild time on 4TB drives: ~10–18 hours
- At 8TB drives, rebuild approaches 24+ hours — consider splitting into two 4-drive vdevs
- Better capacity efficiency than 6-drive layout; slightly longer rebuild window

---

### 12-Drive: Two 6-Drive RAID-Z2 vdevs (recommended over single 12-drive vdev)

```
pool: 2 vdevs
each vdev: raidz2, 6 drives
total drives: 12
efficiency per vdev: 4/6 = 66.7%
pool efficiency: same ~66.7%
```

**Capacity math (12 × 4TB drives):**
- Raw: 48TB
- Usable: ~32TB (16TB per vdev × 2)
- Survives: 2 simultaneous failures *per vdev* (independent fault domains)

**Create:**
```bash
zpool create mypool \
  raidz2 /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf \
  raidz2 /dev/sdg /dev/sdh /dev/sdi /dev/sdj /dev/sdk /dev/sdl
```

**Why two vdevs instead of one 12-drive vdev:**
- **~2x random IOPS** — ZFS stripes across vdevs, so pool IOPS = sum of vdev IOPS
- Shorter rebuild window: 6-drive vdev rebuilds faster than 12-drive vdev
- Failure isolation: a drive failure in vdev1 doesn't touch vdev2's data
- Same usable capacity as single 12-drive vdev

This is the ZFS equivalent of RAID 60 — two independent parity groups striped into a single pool.

---

### 4-Drive RAID-Z2 (tight but valid)

```
vdev: raidz2
drives: 4
parity: 2
data: 2
efficiency: 2/4 = 50%
```

**Capacity math (4 × 4TB drives):**
- Raw: 16TB
- Usable: ~8TB
- Survives: any 2 simultaneous drive failures

**Create:**
```bash
zpool create mypool raidz2 /dev/sda /dev/sdb /dev/sdc /dev/sdd
```

**Characteristics:**
- Only 50% efficiency — same as RAID 1 mirroring but with parity math overhead
- Better used as a 4-drive mirror (2×2) if IOPS matter
- Reasonable for small capacity requirements where Z2 protection is needed

---

## dRAID Layouts

### 11-Drive dRAID2:8d:1s (smallest practical dRAID2 with 1 spare)

```
type: dRAID2
parity: 2
data per stripe: 8
distributed spares: 1
total drives: 11 (8 data + 2 parity + 1 spare)
efficiency: ~72% (accounting for distributed spare capacity)
```

**Capacity math (11 × 4TB drives):**
- Raw: 44TB
- Usable: ~32TB (~72%)
- Survives: any 2 simultaneous drive failures
- Spare: 1 distributed spare (activates on failure, not a separate physical drive)

**Create:**
```bash
zpool create mypool draid2:8d:1s \
  /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde \
  /dev/sdf /dev/sdg /dev/sdh /dev/sdi /dev/sdj /dev/sdk
```

**Characteristics:**
- Rebuild: all 10 surviving drives contribute in parallel (vs 9 drives writing to 1 spare in RAID-Z)
- Best suited for 16+ drive pools where rebuild time is the primary concern
- At 11 drives it works, but the complexity vs RAID-Z2 isn't justified at this scale

---

### 24-Drive dRAID2:20d:2s (large array sweet spot)

```
type: dRAID2
parity: 2
data per stripe: 20
distributed spares: 2
total drives: 24 (20 data + 2 parity + 2 spare)
efficiency: ~83%
```

**Capacity math (24 × 16TB drives):**
- Raw: 384TB
- Usable: ~320TB (~83%)
- Survives: any 2 simultaneous drive failures
- Spares: 2 distributed (2 independent failures can both trigger parallel rebuilds simultaneously)

**Create:**
```bash
zpool create mypool draid2:20d:2s \
  /dev/sda  /dev/sdb  /dev/sdc  /dev/sdd  /dev/sde  \
  /dev/sdf  /dev/sdg  /dev/sdh  /dev/sdi  /dev/sdj  \
  /dev/sdk  /dev/sdl  /dev/sdm  /dev/sdn  /dev/sdo  \
  /dev/sdp  /dev/sdq  /dev/sdr  /dev/sds  /dev/sdt  \
  /dev/sdu  /dev/sdv  /dev/sdw  /dev/sdx
```

**Why dRAID shines here:**
- Traditional RAID-Z2 resilver on 24 × 16TB drives: 48–96+ hours (degraded window)
- dRAID resilver on same array: 6–12 hours (all 23 surviving drives rebuilding simultaneously)
- Two distributed spares means two simultaneous failures can both begin rebuilding immediately
- This is where dRAID stops being theoretical and starts being genuinely important for data safety

---

## Layout Selection Summary

| Drives | Layout | Recommendation |
|---|---|---|
| 4 | RAID-Z2 | Works, but 50% efficiency is tight |
| 6 | RAID-Z2 | Sweet spot — use this |
| 8 | RAID-Z2 | Good; watch rebuild times on large drives |
| 12 | 2× RAID-Z2 (6+6) | Better IOPS than single 12-drive vdev |
| 16 | 2× RAID-Z2 (8+8) | Consider dRAID at this scale |
| 24+ | dRAID2 | Distributed spares, parallel resilver wins |

**General rule:** IOPS scales with vdev count, not drive count. More smaller vdevs = more pool IOPS. Size your vdevs around rebuild time comfort and fault isolation, then add vdevs for throughput.
