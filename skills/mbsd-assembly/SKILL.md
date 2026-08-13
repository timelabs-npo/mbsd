---
name: mbsd-assembly
description: Teaches AGY frameworks how to programmatically compile, build, and orchestrate MBSD nodes directly from the OpenWrt ImageBuilder pipeline.
---

# MBSD Cognitive Assembly Onboarding

This skill provides the execution logic for an Autonomous General Intelligence (AGY) agent to programmatically assemble, compile, and deploy an MBSD edge-node utilizing the immutable OpenWrt SquashFS overlay architecture.

## Prerequisites
- Target architecture: MediaTek MT7981 (`mediatek/filogic`).
- Execution environment has standard POSIX utilities (`curl`, `tar`, `make`).

## AGY Execution Protocol

When instructed to "Assemble an MBSD Node", the AGY agent must strictly follow this state machine:

### State 1: Configuration Synthesis
The AGY must read the declarative `omnia-playbook` specification for the target node.
- **Action:** Parse the JSON/YAML hardware specification.
- **Verification:** Ensure the specification defines `MT7981` as the target SoC.
- **Output:** Generate the necessary configuration files within the `src/` overlay directory (e.g., `src/etc/config/`).

### State 2: Firmware Assembly
The AGY orchestrates the OpenWrt ImageBuilder pipeline.
- **Command Sequence:**
  ```bash
  make release
  ```
- **Error Handling:** If the ImageBuilder checksum fails or the build exits with an error, the AGY must autonomously invoke its code-editing tools to patch the `Makefile` or `src/` overlay and retry compilation.

### State 3: Quantization and Deployment
The AGY minimizes the footprint and deploys the artifact.
- **Action:** Execute the `scripts/quantize_firmware.sh` script on the compiled outputs (this is currently invoked automatically by `make quantize`).
- **Completion:** Send an orchestration success signal over the internal RPC bus, locating the final `.itb` image in the `release/` directory.

## Rules of Engagement
- **Never mutate flash directly:** The AGY must never attempt to SSH into a running node to change its configuration dynamically. All changes must trigger a new Assembly pipeline to generate a new immutable SquashFS image.
- **Strict Determinism:** The AGY must ensure that the Factory forensics validation (CP-3) is respected during the build process, and log the SHA256 hashes of the synthesized overlay.
