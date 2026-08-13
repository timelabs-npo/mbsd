# OpenBSD 7.9 RAM-boot runbook for GL-MT3000

**Current status: READY FOR THE LIVE U-BOOT CHECKPOINT.** The user has confirmed
that this GL-MT3000 previously exposed its recovery/U-Boot console to PuTTY on
the Windows 11 host through the ordinary USB-C cable and that the same path was
used to load vanilla OpenWrt. Reuse that proven USB-C/COM path. A separate TTL
adapter is not a prerequisite unless this device no longer enumerates.

This runbook is intentionally non-persistent. Do not run `erase`, `nand write`,
`ubi write`, `mtd write`, `sysupgrade`, `saveenv`, `env save`, or
`env default -a`. Do not use the handcrafted minimal DTB in `../dts`; it omits
reserved-memory regions present in the live GL-MT3000 device tree.

## Verified input artifacts

The two payloads are unmodified OpenBSD 7.9/arm64 release files. Verify them on
the machine that will prepare the USB drive:

```text
ca9da7ec817f5a51dd75dd72a107022bc00290a42e968e205fb37765c1b0c55a  bsd.rd
741a760c3d3cd97b576146f84787a3f2cfb2e37d896372114b08a4f26e059d3d  BOOTAA64.EFI
```

The stock kernel is not a GL-MT3000 port. A boot prompt or kernel banner is a
smoke-test result, not proof of Ethernet or Wi-Fi support.

## Phase 1: read-only console discovery

Connect the previously proven USB-C cable to the Windows 11 host. In PuTTY open
the resulting COM port as Serial, initially using the previously successful
settings (normally 115200 8N1, flow control None), enable logging of all session
output, power on, interrupt autoboot, and capture the complete transcript. At
the U-Boot prompt run:

```text
version
bdinfo
printenv
help usb
help fatls
help fatload
help bootefi
help fdt
fdt addr ${fdtcontroladdr}
fdt print /memory
fdt print /reserved-memory
```

Stop if `bootefi` is unavailable, `${fdtcontroladdr}` is undefined or invalid,
the live memory/reservation output is incomplete, or no safe EFI load address
can be established from `bdinfo` and `printenv`. Do not guess an address.

## Phase 2: prepare the preferred USB EFI path

Use a spare USB mass-storage device with a GPT EFI System Partition formatted
FAT32. Copy the files with this exact layout:

```text
/efi/boot/bootaa64.efi   (copy of BOOTAA64.EFI)
/bsd                     (copy of bsd.rd)
```

The prepared `usb-esp` directory in this staging bundle already has that
layout. The EFI loader, not U-Boot, must open `/bsd` from the USB filesystem.
Do **not** raw-load `bsd.rd` into a second RAM address; `bootefi` would not pass
that buffer to OpenBSD.

At the U-Boot prompt, enumerate before loading:

```text
usb start
usb storage
part list usb 0
fatls usb 0:1 /
fatls usb 0:1 /efi/boot
```

If the EFI partition is not `usb 0:1`, use the partition number actually shown
by `part list`. After confirming the two files, load only the EFI application
using the existing, validated U-Boot load-address variable:

```text
fatload usb 0:1 ${kernel_addr_r} /efi/boot/bootaa64.efi
bootefi ${kernel_addr_r} ${fdtcontroladdr}
```

If `${kernel_addr_r}` is absent or conflicts with the live memory map, stop.
Do not substitute a hard-coded address.

At the OpenBSD `boot>` prompt, let the default `esp0a:/bsd` load proceed. If it
does not, first record the output of `machine diskinfo`, then try only when the
USB ESP is shown:

```text
boot esp0a:/bsd
```

Capture every console byte from `bootefi` through the final result. Stop after
the first fault, hang, reboot, or installer prompt; do not start installation.

## Conditional TFTP/PXE path

TFTP is not currently approved as a substitute for the USB ESP. U-Boot
`tftpboot` can place `BOOTAA64.EFI` in RAM, but a separately loaded `bsd.rd`
buffer is not an EFI boot argument. The OpenBSD EFI loader can fetch a kernel
from `tftp0a:` only when U-Boot exposes a working EFI network/PXE protocol to
the launched application.

Use this path only after a live transcript demonstrates that capability. The
preferred network form is EFI PXE/DHCP boot of `BOOTAA64.EFI`; at `boot>`,
`machine diskinfo` must show `tftp0` before attempting:

```text
boot tftp0a:/bsd.rd
```

If `tftp0` is absent, stop and use the USB ESP path. Historical Windows address
`192.168.1.174` is not proof of the current adapter state and must not be
hard-coded without a fresh read-only adapter/route check.

## Result classification

- `EFI_LOADER_REACHED`: `>> OpenBSD/arm64 BOOTAA64` and `boot>` are captured.
- `KERNEL_STARTED`: an OpenBSD kernel banner and early device attachment are
  captured.
- `RAMDISK_REACHED`: the installer shell/menu is reached, but no install or
  disk-write command is run.
- `BLOCKED`: any prerequisite or stop condition fails.

Ethernet and Wi-Fi must be reported from actual attachment output and interface
inventory; they must not be inferred from reaching `boot>`. The inspected stock
source contains no MT7981 NETSYS/GMAC or MT7976/mt76 Wi-Fi implementation.

## Rollback

Because this procedure performs no flash or saved-environment writes, power
cycling returns to the existing OpenWrt boot path. Before testing, record a
normal OpenWrt boot transcript and confirm the recovery/autoboot path. If a
power cycle does not restore OpenWrt, stop; do not attempt flash repair from
this runbook.
