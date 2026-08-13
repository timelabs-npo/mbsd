*(This document is archived following the OpenWrt Pivot (ADR-001). References to OpenBSD as the MBSD base are historical; MBSD now uses OpenWrt 23.05.4 as the production baseline.)*

# Multi-Kernel Evaluation: OpenBSD vs. NetBSD on MediaTek Filogic

This document explores the viability of alternative monolithic and virtualization kernel vectors for the MT7981 architecture. Following ADR-001, OpenBSD was abandoned as the MBSD base due to lack of MT7981 driver support. This evaluation is retained for prior-art documentation purposes.

## 1. Native Support Landscape

*   **OpenBSD/arm64:** Provides a robust `GENERIC` configuration with mature EFI boot integration (`BOOTAA64.EFI`) via U-Boot. However, OpenBSD lacks native MT7981 (GL-MT3000) driver support, and the estimated 16–49 FTE-weeks of driver development rendered it non-viable. **Status: Superseded by OpenWrt (ADR-001).**
*   **NetBSD/evbarm:** NetBSD targets ARM evaluation boards via the `evbarm` port. As of 2026, NetBSD contains **zero** native support for the MediaTek Filogic 820 (MT7981) System-on-Chip. Attempting a bare-metal NetBSD port would require replicating the entire driver integration effort.

## 2. NetBSD Virtualization Vectors (Rump Kernels)

While bare-metal NetBSD is not currently viable, its architectural flexibility presents an intriguing vector for future edge-node isolation.

### The "Anykernel" Concept
NetBSD's Anykernel architecture allows subsystems (like the network stack or file system) to run in userspace as **Rump Kernels**. 
In a resource-constrained MT7981 environment (256MB RAM / 256MB NAND):
1.  **MBSD Base:** The production base is OpenWrt Linux (per ADR-001), providing mature MT7981 hardware support.
2.  **Rump Encapsulation:** If NetBSD's `rump` could be cross-compiled for ARM64 and executed on top of OpenWrt's Linux kernel, complex, stateful routing protocols could be isolated entirely in userspace without risking a kernel panic.

### Conclusion
Migrating the primary edge-node OS to NetBSD is not viable due to the lack of hardware enablement. The **NetBSD Rump Kernels** concept remains a theoretical research track for isolating the Timelabs `blueshoes` State Engine from the bare-metal routing matrix.
