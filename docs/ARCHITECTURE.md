# MBSD Architecture & Constraints

## Hardware: GL-MT3000 (Mediatek MT7981)

The GL-MT3000 ("Beryl AX") operates on the Mediatek Filogic 820 (MT7981B) System-on-Chip. Implementing an OpenBSD kernel on this target presents strict limitations governed by the vendor's locked boot sequence.

### 1. Flash Layout and UBI
The MT7981 utilizes SPI-NAND flash (typically 256MB). The memory is highly structured:
- **BL2 (ATF):** The immutable first-stage bootloader.
- **Factory/RF:** Proprietary partition containing Wi-Fi calibration data (EEPROM values). Overwriting this permanently damages radio performance.
- **FIP (U-Boot):** The second-stage loader. GL.iNet heavily customizes this to support their web-recovery UI and UBI container formats.
- **UBI:** The main persistent storage pool, containing the OS kernel and root filesystem.

- **Immutable Root:** The base root filesystem is mounted explicitly as a strictly read-only SquashFS block. We explicitly eliminate the OpenWrt `rootfs_data` UBIFS volume to guarantee absolute crypto-state purity. `sysupgrade.tar` with GL.iNet-specific metadata (`glinet,mt3000-snand`).

### 2. Device Tree (FDT) Dependencies
The MT7981 requires highly specific FDT declarations for:
- **Reserved Memory:** Missing or misaligned memory reservations in a handcrafted FDT will cause the kernel to overwrite secure ATF memory or Wi-Fi ring buffers, resulting in an immediate hard lockup.
- **Interrupt Routing:** GICv3 (Generic Interrupt Controller) must be perfectly mapped to the MT7981's internal bus matrix.

### 3. OpenWrt Integration Strategy
Rather than compiling an unsupported OpenBSD kernel from scratch, MBSD leverages the **OpenWrt ImageBuilder**. 
The orchestrator dynamically injects the `blueshoes` state engine binaries and network configurations into the OpenWrt rootfs during the build process. The final `mbsd-overlay.itb` FIT image contains the mainline Linux kernel, the SquashFS overlay, and the Device Tree in a single, signed package ready for `bootm` execution.

---

## Timelabs Ecosystem Integration

### The MBSD Namespace
MBSD operates as the physical root of trust. It is designed to be completely read-only in production, enforcing physical state security.

### Rheknel Orchestration
Rheknel acts as the bridge between the MBSD kernel and higher-order logic. When MBSD initializes the networking stack, Rheknel securely extracts routing tables and interface metrics, passing them up without violating the immutable root filesystem constraint.

### Omnia-Playbook semantic adherence
MBSD's boot and network initialization sequences are semantically mapped. Failures (e.g., "PHY link down") are translated into Omnia concepts, triggering predefined semantic fallbacks rather than generic shell scripts.

### Blueshoes State Representation
Once MBSD is alive and Rheknel establishes telemetry, Blueshoes projects its "Representations" onto the node. MBSD strictly guarantees that no external force can mutate the edge node without passing through the Blueshoes contradiction register.
