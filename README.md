## MBSD: Minimal OpenBSD Port for MediaTek Filogic MT7981

**Status:** Alpha / Conceptual Stage (WIP)  
**Target Hardware:** GL.iNet GL-MT3000 ("Beryl AX")  
**Base OS:** OpenBSD 7.9-current (arm64)  

MBSD is an experimental, minimalist OpenBSD port tailored specifically for the MediaTek Filogic MT7981 SoC. The goal of the project is to provide a security-hardened, immutable base operating system for edge nodes within the Timelabs infrastructure, moving away from traditional Linux-based router distributions.

> [!WARNING]
> **Current Project Status:** This repository is currently a work-in-progress scaffolding. The codebase consists of initial driver stubs and boot configuration scripts. Active development is temporarily blocked pending physical UART access via USB-C adapter to capture raw hardware telemetry and debug the early console initialization.

---

## 🛠 Target Architecture & Boot Flow

Unlike standard Linux/OpenWrt deployments that rely on direct U-Boot to flat-image (`uImage`) kernel handoffs, MBSD follows the standard OpenBSD/arm64 boot protocol via EFI.

```text
[Power On] → [ATF (BL2)] → [U-Boot / FIP] → [U-Boot 'bootefi'] → [Loads BOOTAA64.EFI] → [Launches bsd Kernel]
```

### 🏛 Enterprise Architectural Specification

**Storage Tiering & State Retention**  
MBSD enforces a rigorous partition between cryptographic immutability and runtime state execution. The base root filesystem (`/`) is mounted explicitly via `mount_rd(4)` as a strictly read-only RAMDISK block. All persistent state transitions are offloaded to isolated memory-backed tiers, ensuring that power-loss events result in a mathematically pure state wipe. 

**Deterministic Deployment & Threat Modeling**  
Traditional Linux edge distributions (e.g., OpenWrt) fall victim to "configuration drift" and runtime mutation, presenting an unacceptable attack surface for critical infrastructure. MBSD eliminates this threat vector through absolute determinism: configurations cannot be written to disk. The `sysctl(8)` parameters, network interface assignments, and routing daemons are injected deterministically at boot through cryptographically signed orchestration layers.

---

## 📁 Ecosystem Component Map

The project architecture relies on three primary subsystems (currently in design/stub phase):

1.  **[blueshoes](../blueshoes) (State Engine):** A hardened execution runtime for running lightweight virtualized workloads and ensuring strict state synchronization.
2.  **[omnia-playbook](../omnia-playbook) (Provisioning):** A zero-touch configuration utility designed for semantic node onboarding and automated cryptographic provisioning.
3.  **[rheknel](../rheknel) (Telemetry):** A low-level hardware telemetry daemon mapping SPI-NAND wearing metrics, GMAC counters, and MT7976 radio states directly to userland.

---

## 🚀 Next-Gen Roadmap & TODO Pipeline

*   `[ ]` **Multi-Kernel Evaluation:** Research NetBSD visualization vectors and alternative monolithic kerneling methods for resource-constrained MediaTek environments.
*   `[ ]` **Autonomous Lifecycle Execution:** Architecture design for completely deleting the "human layer" in edge-node provisioning, deployment, and failure recovery.
*   `[ ]` **Firmware Footprint Quantization:** Implement advanced static compilation and asset quantization techniques to reduce the overall memory and flash footprint of the MBSD base image.
*   `[ ]` **Cognitive Assembly Onboarding:** Teach AGY (Autonomous General Intelligence/Agents) frameworks how to programmatically compile, build, and orchestrate MBSD nodes directly from bare-metal specifications.
