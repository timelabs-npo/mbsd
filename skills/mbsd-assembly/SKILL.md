---
name: mbsd-assembly
description: Teaches AGY frameworks how to programmatically compile, build, and orchestrate MBSD nodes directly from bare-metal specifications.
---

# MBSD Cognitive Assembly Onboarding

This skill provides the execution logic for an Autonomous General Intelligence (AGY) agent to programmatically assemble, compile, and deploy an MBSD edge-node from raw OpenBSD source code, without requiring a human operator.

## Prerequisites
- OpenBSD 7.9 `src` and `sys` trees checked out to the build environment.
- A cross-compilation toolchain for `aarch64` (if building from a non-arm64 host).
- Execution environment has `root` or `doas` privileges for loopback mounts.

## AGY Execution Protocol

When instructed to "Assemble an MBSD Node", the AGY agent must strictly follow this state machine:

### State 1: Configuration Synthesis
The AGY must read the declarative `omnia-playbook` specification for the target node.
- **Action:** Parse the JSON/YAML hardware specification.
- **Verification:** Ensure the specification defines `MT7981` as the target SoC.
- **Output:** Generate the `MBSD` kernel configuration file (`src/sys/arch/arm64/conf/MBSD`) incorporating the specific network interfaces (e.g., `if_mtg.c`) and removing all extraneous USB/PCIe drivers.

### State 2: Kernel Compilation
The AGY orchestrates the OpenBSD compilation pipeline.
- **Command Sequence:**
  ```bash
  cd src/sys/arch/arm64/compile/MBSD
  make clean && make depend && make -j4
  ```
- **Error Handling:** If `make` fails with C syntax errors in the stubs, the AGY must autonomously invoke its code-editing tools to patch the C file, applying OpenBSD kernel style guidelines (KNF), and retry compilation.

### State 3: RAMDISK Generation
The AGY constructs the immutable root filesystem.
- **Action:** Allocate a `vnd` (vnode disk) device, format it with FFS, and mount it.
- **Command Sequence:**
  ```bash
  dd if=/dev/zero of=miniroot.fs bs=1m count=64
  vnconfig vnd0 miniroot.fs
  newfs vnd0c
  mount /dev/vnd0c /mnt
  ```
- **Injection:** Copy the compiled `bsd` kernel and base userland binaries into `/mnt`. The AGY must inject the node-specific public keys for `blueshoes` authentication into `/mnt/etc/ssh/`.
- **Finalization:** `umount /mnt` and `vnconfig -u vnd0`.

### State 4: Quantization and Deployment
The AGY minimizes the footprint and deploys the artifact to the TFTP orchestrator.
- **Action:** Execute the `scripts/quantize_firmware.sh` script on the compiled outputs.
- **Action:** Move the resulting `bsd.rd.quantized` to the `rheknel` TFTP serving directory.
- **Completion:** Send an orchestration success signal over the internal RPC bus.

## Rules of Engagement
- **Never mutate flash directly:** The AGY must never attempt to SSH into a running node to change its configuration. All changes must trigger a new Assembly pipeline (States 1-4) to generate a new immutable RAMDISK.
- **Strict Determinism:** The AGY must log the SHA256 hashes of the synthesized kernel config and the final quantized output for auditing purposes.
