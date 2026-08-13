## MBSD: Immutable Security Overlay for MediaTek Filogic MT7981

**Status:** Alpha / Conceptual Stage (WIP)  
**Target Hardware:** GL.iNet GL-MT3000 ("Beryl AX")  
**Base BSP:** OpenWrt (Kernel 5.4+ / MT7981 Mainline)

MBSD is an experimental, security-hardened overlay designed to run on top of the battle-tested OpenWrt MediaTek BSP. The goal of the project is to provide a strictly immutable, zero-trust execution environment for edge nodes within the Timelabs infrastructure, without sacrificing mainline driver stability for 2.5GbE, Wi-Fi 6, and SPI-NAND flash.

> [!WARNING]
> **Current Project Status:** This repository is currently a work-in-progress scaffolding. The architecture relies on pivoting the OpenWrt rootfs into a strictly immutable SquashFS deployment. Active development is temporarily blocked pending physical UART access via 3.3V internal header to verify U-Boot environments and FIT image paths.

---

## 🛠 Target Architecture & Boot Flow

Unlike experimental OpenBSD ports that lack driver support and `bootefi` implementation on stock U-Boot, MBSD leverages the native hardware boot path using Flattened Image Trees (FIT, `.itb`).

```text
[Power On] → [BootROM] → [BL2 (DDR Init)] → [ATF (BL31)] → [U-Boot (BL33)] → [bootm FIT Image] → [OpenWrt Kernel + Immutable SquashFS]
```

### 🏛 Enterprise Architectural Specification

**Immutable Overlay (SquashFS)**  
MBSD enforces a rigorous partition between cryptographic immutability and runtime state execution. By discarding OpenWrt's default JFFS2 overlay (`overlayfs`), the base root filesystem (`/`) is mounted explicitly as a strictly read-only SquashFS block. All persistent state transitions are offloaded to isolated memory-backed tiers, ensuring that power-loss events result in a mathematically pure state wipe. 

**Deterministic Deployment & Threat Modeling**  
Traditional Linux edge distributions fall victim to "configuration drift" and runtime mutation, presenting an unacceptable attack surface for critical infrastructure. MBSD eliminates this threat vector through absolute determinism: configurations cannot be written to disk. The `sysctl` parameters, network interface assignments, and routing daemons are injected deterministically at boot through cryptographically signed orchestration layers.

---

## 📁 Ecosystem Component Map

The project architecture relies on three primary subsystems (currently in design/stub phase):

1.  **[blueshoes](../blueshoes) (State Engine):** A hardened execution runtime for running lightweight virtualized workloads and ensuring strict state synchronization.
2.  **[omnia-playbook](../omnia-playbook) (Provisioning):** A zero-touch configuration utility designed for semantic node onboarding and automated cryptographic provisioning.
3.  **[rheknel](../rheknel) (Telemetry):** A low-level hardware telemetry daemon mapping SPI-NAND wearing metrics, GMAC counters, and MT7976 radio states directly to userland.

---

## ⚙️ Build System & Finalization (Deployment Pipeline)

**This repository is protected as a strictly "Vanilla-Compatible" human work artifact.** The raw source code and configuration definitions are fully readable and editable. All firmware quantization (ImageBuilder invocation, artifact stripping, and SquashFS compression) is handled as a separate deployment stage via the top-level `Makefile`.

*   `make vanilla`: Generates the raw OpenWrt config artifacts and overlay structures inside `build/`.
*   `make quantize`: Invokes the OpenWrt ImageBuilder to strip the artifacts and compress them into the immutable SquashFS payload.
*   `make release`: Executes the full end-to-end pipeline, outputting the immutable deployment FIT payload to `release/mbsd-overlay.itb`.
*   `make clean`: Purges the `build/` and `release/` directories, restoring the pristine vanilla state.

---

## 🚀 Next-Gen Roadmap & TODO Pipeline

*   `[ ]` **OpenWrt ImageBuilder Integration:** Automate the pulling of the MT7981 SDK to wrap the MBSD overlay around the stock kernel.
*   `[ ]` **Autonomous Lifecycle Execution:** Architecture design for completely deleting the "human layer" in edge-node provisioning, deployment, and failure recovery.
*   `[ ]` **Firmware Footprint Quantization:** Implement advanced package stripping and asset quantization techniques to reduce the overall memory and flash footprint of the MBSD SquashFS image.
*   `[ ]` **Cognitive Assembly Onboarding:** Teach AGY (Autonomous General Intelligence/Agents) frameworks how to programmatically compile, build, and orchestrate MBSD nodes directly from ImageBuilder specifications.
