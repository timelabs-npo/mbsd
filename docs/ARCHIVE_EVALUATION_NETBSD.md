*(This document is archived following the OpenWrt Pivot (ADR-001))*

# Multi-Kernel Evaluation: OpenBSD vs. NetBSD on MediaTek Filogic

This document explores the viability of alternative monolithic and virtualization kernel vectors for the MT7981 architecture, specifically contrasting the current OpenBSD port with theoretical NetBSD adaptations.

## 1. Native Support Landscape

*   **OpenBSD/arm64:** Provides a robust `GENERIC` configuration with mature EFI boot integration (`BOOTAA64.EFI`) via U-Boot. OpenBSD’s strict emphasis on cryptographic validation and security makes it the ideal base for the Timelabs infrastructure, though it lacks native MT7981 (GL-MT3000) driver support, requiring the current scaffolding efforts (`if_mtg.c`, `mtspi.c`).
*   **NetBSD/evbarm:** NetBSD targets ARM evaluation boards via the `evbarm` port. As of 2026, NetBSD contains **zero** native support for the MediaTek Filogic 820 (MT7981) System-on-Chip. Attempting a bare-metal NetBSD port would require replicating the entire OpenBSD FDT integration effort.

## 2. NetBSD Virtualization Vectors (Rump Kernels)

While bare-metal NetBSD is not currently viable, its architectural flexibility presents an intriguing vector for future edge-node isolation.

### The "Anykernel" Concept
NetBSD's Anykernel architecture allows subsystems (like the network stack or file system) to run in userspace as **Rump Kernels**. 
In a resource-constrained MT7981 environment (256MB RAM / 256MB NAND):
1.  **MBSD Base:** We retain the highly secure, immutable OpenBSD kernel as the bare-metal ring-0 hypervisor/host.
2.  **Rump Encapsulation:** If NetBSD's `rump` could be cross-compiled for ARM64 and executed on top of OpenBSD (or a microkernel), complex, stateful routing protocols could be isolated entirely in userspace without risking a kernel panic. 

### Conclusion
Currently, migrating the primary edge-node OS to NetBSD is counter-productive due to the lack of hardware enablement. However, exploring **NetBSD Rump Kernels** running *on top* of the MBSD host represents a high-value research track for isolating the Timelabs `blueshoes` State Engine from the bare-metal routing matrix.
