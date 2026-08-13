# Autonomous Lifecycle Execution Architecture

The ultimate goal of the MBSD project is the total deletion of the "human layer" in edge-node provisioning, deployment, and failure recovery. This document defines the zero-touch orchestration protocol designed to integrate seamlessly with the Timelabs `omnia-playbook` ecosystem.

## 1. Zero-Touch Orchestration Protocol

The autonomous lifecycle is split into three phases, replacing traditional manual SSH configuration and web UI flashing with a deterministic, programmatic pipeline.

### Phase 1: Bare-Metal Network Boot (PXE/TFTP)
Instead of shipping pre-flashed UBI containers, bare-metal MBSD nodes boot into a stateless network recovery mode.
1. U-Boot triggers a standard `dhcp` and `tftpboot` sequence over the primary Ethernet interface.
2. The orchestrator (Rheknel node) intercepts the DHCP request and serves a signed `BOOTAA64.EFI` payload along with the immutable MBSD RAMDISK (`bsd.rd`).
3. The node boots entirely in memory without touching the local SPI-NAND flash.

### Phase 2: Semantic Provisioning (Omnia-Playbook)
Once the RAMDISK initializes the networking stack, the node generates a cryptographic identity (Ed25519 node key) and broadcasts its presence.
1. The `omnia-playbook` provisioning daemon authenticates the node.
2. The exact routing tables, VLANs, and firewall rules required for this node's role are compiled into a static, read-only configuration package.
3. This package is injected into the node. MBSD does not persist this to flash; it exists only in RAM, guaranteeing absolute statelessness upon reboot.

### Phase 3: Autonomous Watchdog Recovery
Failure recovery is handled natively by hardware watchdogs, removing the need for manual "factory resets."
- If the node loses connectivity to the Omnia provisioning plane, the internal MT7981 watchdog timer triggers a hard reset.
- Upon reboot, the node falls back to Phase 1 (TFTP Network Boot), automatically pulling the latest verified image and configuration from the cluster.

## 2. Deleting the Human Layer

By strictly prohibiting SSH access and persistent configuration writes, we eliminate:
- **Configuration Drift:** No administrator can manually "tweak" a setting that survives a reboot.
- **Vulnerability Windows:** Firmware updates occur implicitly every time a node restarts and pulls from the TFTP orchestrator.
- **Deployment Delays:** New hardware is physically plugged in and becomes fully operational within 60 seconds, orchestrated entirely by the AGY framework.
