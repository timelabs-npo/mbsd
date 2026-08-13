# ADR-001: Pivot MBSD to OpenWrt Baseline

**Status:** Accepted  
**Date:** 2026-08-13  
**Effective Commit:** `627497b`

## Context and Problem Statement
The MBSD project was initially scaffolded to target a from-scratch OpenBSD arm64 port for the MediaTek MT7981 SoC (GL-MT3000 router). However, a Redteam Audit identified that OpenBSD does not support this hardware, and engineering a pristine OpenBSD GMAC and SPI-NAND driver would require 16–49 FTE-weeks. Meanwhile, the OpenWrt mainline kernel provides fully mature, production-grade drivers for the exact same hardware.

We must decide whether to continue the 6-month from-scratch OpenBSD development, or pivot our architecture to leverage the existing OpenWrt BSP.

## Considered Options
*   **Alternative A: Hard De-scope.** Limit MBSD to a "Kernel Boot PoC" on OpenBSD (serial console and 1 GbE port only, no SPI-NAND or Wi-Fi).
*   **Alternative B: Pivot to Existing Baseline.** Abandon the OpenBSD monolithic port. Re-architect MBSD as a security overlay (SquashFS immutability) atop the OpenWrt Linux kernel.
*   **Alternative C: Full Steam Ahead.** Continue writing custom OpenBSD C drivers for the MT7981.

## Decision Outcome
**Chosen option: Alternative B: Pivot to Existing Baseline.**

We will leverage the OpenWrt MT7981 baseline (which achieved mainline support in May 2023 via Daniel Golle, commit `7cbe341`). This eliminates ~99% of our low-level driver engineering risk while still perfectly achieving our ultimate goal: creating an immutable, zero-trust edge node that powers the `blueshoes` and `omnia-playbook` state engines. 

OpenWrt's native SquashFS root filesystem fulfills the immutable overlay requirement. We will eliminate the default `rootfs_data` UBIFS volume to guarantee absolute crypto-state purity.

### Approval
- **Owner/Codex Approval:** `SA/MIO`
- **Audit Gate:** Passed (Prior-Art check confirmed).
