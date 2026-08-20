# MBSD Kernel Port Diary (GL-MT3000 / Beryl MT7981)

## Token Economy Strategy & Directives
*   **Context Conservation:** Context tokens are strictly reserved for OpenBSD kernel architecture (C/ASM), Makefiles, and Device Tree logic.
*   **Delegation:** Trivial file manipulation, build logging, and UART output parsing are delegated to bash/python scripts running either locally or on the target proxy "WD".
*   **No Heavy Reads:** Never dump full kernel logs into the LLM context window. Filter using `grep` or specific `awk` patterns to extract registers/panics.
*   **Zero Cost Mistakes:** Expect panics. Iterate fast. Commits act as checkpoints.

## Entry 001: 2026-08-20 - Project Inception
**Objective:** Establish OpenBSD `sys` tree and orchestrate cross-compilation push to "WD" (WinPro11).
**Actions:**
1. Initialized KERNEL_PORT_DIARY.md.
2. Formulated Token Economy Strategy.
3. Preparing to fetch OpenBSD 7.6 `sys.tar.gz` to `src/sys`.
4. Designing push mechanism (`scp`/`rsync`) to transfer compiled `bsd` kernel and artifacts to WD for U-Boot execution.

## Entry 002: 2026-08-20 - GMAC Scaffolding
**Objective:** Initialized `if_mtgmac.c` driver in OpenBSD kernel tree.
**Actions:**
1. Created `src/sys/dev/fdt/if_mtgmac.c`.
2. Implemented `mtgmac_match` mapping to DTS `mediatek,mt7981-gmac`.
3. Registered driver in `src/sys/dev/fdt/files.fdt`.
4. Bypassed all prompts. Full throttle execution.

## Entry 003: 2026-08-20 - DMA Bruteforce Initialization
**Objective:** Write the hardware register map and initialization sequence.
**Reasoning:** Hardware datasheets are incomplete. We use direct `bus_space_write_4` macros to force the PDMA engine to stop, reset its indexes, and start again. Zero hesitation.
