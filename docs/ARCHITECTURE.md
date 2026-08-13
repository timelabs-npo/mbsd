# MBSD Architecture & Constraints

## Hardware: GL-MT3000 (Mediatek MT7981)

The GL-MT3000 ("Beryl AX") operates on the Mediatek Filogic 820 (MT7981B) System-on-Chip. Implementing an OpenBSD kernel on this target presents strict limitations governed by the vendor's locked boot sequence.

### 1. Flash Layout and UBI
The MT7981 utilizes SPI-NAND flash (typically 256MB). The memory is highly structured:
- **BL2 (ATF):** The immutable first-stage bootloader.
- **Factory/RF:** Proprietary partition containing Wi-Fi calibration data (EEPROM values). Overwriting this permanently damages radio performance.
- **FIP (U-Boot):** The second-stage loader. GL.iNet heavily customizes this to support their web-recovery UI and UBI container formats.
- **UBI:** The main persistent storage pool, containing the OS kernel and root filesystem.

**Constraint:** The standard OpenBSD `bsd.rd` (ELF) or `BOOTAA64.EFI` cannot be directly flashed into the UBI partition. The firmware must be packaged as a `sysupgrade.tar` with GL.iNet-specific metadata (`glinet,mt3000-snand`).

### 2. Device Tree (FDT) Dependencies
The MT7981 requires highly specific FDT declarations for:
- **Reserved Memory:** Missing or misaligned memory reservations in a handcrafted FDT will cause the kernel to overwrite secure ATF memory or Wi-Fi ring buffers, resulting in an immediate hard lockup.
- **Interrupt Routing:** GICv3 (Generic Interrupt Controller) must be perfectly mapped to the MT7981's internal bus matrix.

### 3. OpenBSD Integration Strategy
Due to the lack of native MT7981 support in OpenBSD, MBSD implements:
1.  **RAM-First Telemetry:** We boot the stock OS into RAM (via TFTP/USB and EFI) purely to capture the live FDT structure generated dynamically by U-Boot.
2.  **Kernel Minification:** `sys/arch/arm64/conf/MBSD` aggressively strips unused drivers (e.g., PCI, USB, Display) to minimize the attack surface and binary size.
3.  **FDT Stubs:** `sys/dev/fdt/if_mtg.c` and `mtspi.c` provide the minimal scaffolding required for the OpenBSD kernel to attach to the SoC's Gigabit MAC and SPI-NAND controllers.

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
