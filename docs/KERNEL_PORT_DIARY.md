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
