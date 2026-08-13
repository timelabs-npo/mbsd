# Autonomous Lifecycle Execution (MBSD)

The ultimate goal of the MBSD architecture is to completely delete the "human layer" in edge-node provisioning, deployment, and failure recovery.

This document outlines the authoritative state model (Model B) for zero-touch hardware orchestration.

## The Authoritative Boot Model: Local SquashFS NAND Boot

MBSD enforces **Model B** (Local SquashFS NAND boot via FIT `bootm`).

### Specifications
- **Boot Protocol:** UBI volume `kernel` → `bootm` FIT image (`.itb`) on NAND.
- **Local Flash Touched:** Yes. The SquashFS `rootfs` is written to a UBI volume.
- **Offline Bootable:** Yes. Boots without network connectivity (immutable root + RAM state).
- **Failure Domain:** Single node only; network partition tolerated.
- **Immutability Mechanism:** SquashFS (read-only block device) — enforced by FS driver. We explicitly eliminate the `rootfs_data` UBI volume.
- **Firmware Update Path:** In-band upgrade flow (`sysupgrade`).
- **Recovery:** Requires UART / TFTP recovery procedure in case of critical failure.
- **Operational Cost:** Zero after initial flash. No TFTP orchestrator required.

## Autonomous Provisioning Flow (Omnia-Playbook)

1. **Bare-Metal Boot:** The router powers on and U-Boot initiates the boot sequence.
2. **FIT Image Execution:** U-Boot loads the signed MBSD `mbsd-overlay.itb` FIT image from the NAND flash.
3. **SquashFS Mount:** The OpenWrt kernel boots and mounts the immutable SquashFS root filesystem.
4. **State Engine Initialization:** The `blueshoes` state engine initializes in RAM.
5. **Node Authentication:** The node reaches out to the central `omnia-playbook` orchestrator, authenticating via cryptographically signed `signify` challenges.
6. **State Injection:** `omnia-playbook` injects the authorized network configuration, routing tables, and cryptographic keys directly into the node's RAM.
7. **Execution:** The node enters active duty. Any power cycle immediately wipes all injected state, returning the node to its mathematically pure, pristine baseline.
