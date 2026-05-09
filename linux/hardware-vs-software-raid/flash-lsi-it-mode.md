# Flashing an LSI 9211-8i to IT Mode

This is a procedure document, not a script. Read every section before you start.
Skipping steps or using the wrong firmware image for your card revision can result
in a card that won't POST. Recovery is possible but annoying.

---

## What IT Mode Does

LSI (now Broadcom) SAS controllers ship in two firmware personalities:

- **IR mode (Integrated RAID):** The card manages RAID arrays in firmware. Drives appear
  as logical volumes to the OS. The card is in charge of parity, metadata, and rebuilds.

- **IT mode (Initiator-Target):** Pure HBA pass-through. Drives appear as raw disks to the OS.
  No firmware RAID, no metadata on the card. Your software stack (ZFS, mdadm) is in charge.

Flashing to IT mode is how you turn a "RAID controller" into an HBA. It is the recommended
configuration for ZFS, and it's strongly preferred for mdadm arrays where you want array
metadata on the drives, not the card.

---

## Supported Cards

This procedure applies to:

- LSI 9211-8i (most common, 8-port internal SAS)
- LSI 9211-8e (external SAS variant)
- LSI 9207-8i (PCIe 3.0 variant)
- LSI 9300-8i (SAS3 / 12Gb/s — different firmware family, similar process)
- OEM equivalents: Dell H200, Dell H310, IBM M1015, SuperMicro AOC-USAS2LP-H8iR

**Card revision matters.** The 9211-8i has multiple PCB revisions (A0, A1, B0). The correct
firmware depends on your revision. Check the sticker on the card — it will say something like
`LSI00194` or list a Dell/IBM OEM part number. Cross-reference with the Broadcom/LSI support
matrix before downloading firmware.

---

## Prerequisites

**Hardware:**
- The LSI card installed in a machine with a UEFI firmware (not legacy BIOS)
- A USB drive (1 GB minimum) to boot from
- No drives connected to the LSI card during the flash procedure

**Files to download (get these before you start):**
- `sas2flash.efi` — the UEFI flash utility for 9200-series cards
  - Source: Broadcom support portal → SAS 9211-8i → firmware download
  - Also mirrored widely on ServeTheHome forums (verify checksums)
- IT mode firmware: `2118it.bin` (for 9211-8i)
- SAS Address backup file from your specific card: `2118it.ROM` (SBR file)
  - The SBR (Serial Boot ROM) encodes your card's SAS address. You must use the SBR
    that matches your card's address. Mismatching this makes the card lose its identity.

**For 9300-series (SAS3 / 12Gb/s):**
- Use `sas3flash.efi` and the corresponding `Fusion-MPT SAS 3` IT firmware.
  The process is the same but the tools are different. Do not mix 9200 and 9300 utilities.

---

## Step 1: Back Up Your Current Configuration

Before touching anything, boot the machine with the LSI card installed (no drives connected)
and dump the current card info.

If you can get a Linux shell with the card accessible:

```bash frame="terminal"
# List detected LSI adapters
sas2ircu LIST

# If found, dump the configuration (replace 0 with your adapter index)
sas2ircu 0 DISPLAY > lsi_config_backup.txt
```

Save this output somewhere off the machine. It contains your card's SAS address, which you
will need if you lose it during the flash.

---

## Step 2: Create a UEFI Boot USB

1. Format the USB drive as FAT32.
2. Create a directory structure: `EFI/BOOT/` on the USB.
3. Rename `sas2flash.efi` to `BOOTX64.EFI` and place it in `EFI/BOOT/`.
4. Copy your firmware files to the root of the USB drive:
   - `2118it.bin`
   - `2118it.ROM` (SBR file matching your card's SAS address)

The USB should look like:

```text
/
├── EFI/
│   └── BOOT/
│       └── BOOTX64.EFI   ← sas2flash renamed
├── 2118it.bin
└── 2118it.ROM
```

---

## Step 3: Boot to the UEFI Shell

1. Insert the USB, power on the machine.
2. Enter the UEFI firmware settings (usually Delete, F2, or F10 at POST).
3. Set the boot order to boot from the USB drive in UEFI mode (not legacy/CSM mode).
4. The machine should boot directly into `sas2flash.efi`.

If you land in a generic UEFI shell instead of sas2flash directly:

```text
Shell> fs0:
fs0:\> EFI\BOOT\BOOTX64.EFI
```

---

## Step 4: List Adapters

Once `sas2flash` is running:

```text
sas2flash.efi -listall
```

You should see your LSI card listed with its SAS address. Note the adapter number (usually `0`).

If you don't see the card, the card may not be seated correctly, or UEFI may not have initialized
it. Power off, reseat the card, try again.

---

## Step 5: Erase the Card (the Dangerous Part)

This step erases the current firmware. After this, the card is a blank. Do not power off,
do not interrupt.

```text
sas2flash.efi -o -e 6
```

The `-e 6` flag erases all flash regions. When it completes (it takes 30–60 seconds), the
card's current firmware is gone.

---

## Step 6: Flash IT Mode Firmware

Immediately after erase completes:

```text
sas2flash.efi -o -f 2118it.bin -b 2118it.ROM
```

- `-f` specifies the firmware image
- `-b` specifies the SBR (Serial Boot ROM) that carries the SAS address

This takes 1–3 minutes. Wait for the success message. Do not interrupt.

---

## Step 7: Verify

After flashing:

```text
sas2flash.efi -listall
```

The card should reappear. The firmware version should show IT mode.

```text
sas2flash.efi -adpinfo 0
```

Check that the firmware type shows `IT` and the SAS address matches your original card address.

Reboot normally. In Linux, the card will now present raw disks instead of RAID volumes.

---

## Step 8: Verify in Linux

After rebooting into Linux:

```bash frame="terminal"
# List SAS/SATA devices — you should see raw drives now
lsblk

# Check the HBA is visible (look for mpt3sas or similar)
dmesg | grep -i mpt

# If drives are connected, each one should appear as a separate /dev/sd* device
ls /dev/sd*
```

---

## Recovery: Card Won't POST After Flash

If the card doesn't POST after flashing (you see no card in the UEFI adapter list, or the
machine hangs at POST with the card installed):

1. Remove the card from the machine.
2. Find another machine — one where the UEFI can boot to the `sas2flash.efi` environment
   even without the card fully initializing (some UEFI implementations are more tolerant).
3. Boot into the sas2flash UEFI environment with the card in a different PCIe slot.
4. Attempt the `-listall` command — some partially-flashed cards still enumerate.
5. If it lists: repeat Step 5 and Step 6 with the correct firmware files.
6. If it doesn't list: you may need to use a JTAG programmer to recover. This is rare.

The most common cause of POST failure is using the wrong SBR file (wrong SAS address) or
the wrong firmware image for the card revision. Double-check part numbers against the
Broadcom support matrix before starting.

---

## References and Further Reading

- **ServeTheHome LSI Card Cross-Flash Guide** — the canonical community reference.
  Search: "ServeTheHome 9211-8i crossflash IT mode"
- **Broadcom/LSI Support Portal** — official firmware downloads:
  https://www.broadcom.com/support/fibre-channel-networking/hbas-and-raid/
- **OpenZFS Documentation** — why ZFS requires HBA pass-through:
  https://openzfs.github.io/openzfs-docs/
- **r/homelab wiki** — LSI card recommendations and firmware links

---

## See Also

- Article: https://sumguy.com/posts/hardware-vs-software-raid/
- [SMART Monitoring](https://sumguy.com/posts/smart-monitoring-smartmontools/) — what you gain back when drives are visible to the OS
- [ZFS RAID-Z and dRAID](https://sumguy.com/posts/raid-z-and-draid-explained/) — what to run on top of your newly-IT-mode HBA
