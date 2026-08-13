# MBSD External Auditor Spec v1.1

Spec status:          ENFORCEABLE (once signed intent.json references this hash)
Spec hash (claimed):  d9a1040d80f2a47bf474aa6a93a1fe2d1f7975b4158358da56c655c92cb132a5
                      (replace with sha256 of final file; see §12 bootstrap)
Effective scope:      timelabs-npo/mbsd (Shell/Makefile baseline)
Default auditor mode: A0-L (read-only)

---

## 1. Authority ladder (non-override)

Authority levels (highest wins on conflict):

| Level | Entity | Scope |
|-------|--------|-------|
| L4    | Court of competent jurisdiction | Legal finality external to technical process |
| L3    | Law-Core static checker (no LLM) | Normative clause compliance (technical highest) |
| L2    | Owner (signed in intent.json)    | Business/risk signoff + explicitly allowed exceptions |
| L1    | Independent Third-Party Auditor | Dispute arbitration (Owner vs Auditor) |
| L0    | LLM output (any model, incl. this auditor) | Evidence only; MUST NOT overrule L1-L4 |

1.1 Auditor self-amendment of this document is **PROHIBITED**.
1.2 Any verdict, predicate, or clause contradicted by Law-Core checker output
    is **VOID** as of the checker's `timestamp` field.
1.3 L0 evidence MAY support a verdict; SHALL NOT be the sole basis for a
    Fatal/Critical severity authorization (requires Tier A or S, see §7).

## 2. Spec amendment lock

Amendment from v1.1 → v1.x (or later) is **VALID IF AND ONLY IF** all three:

  (a) `docs/intent.json` is updated by an Owner-signed signature block, and
      `auditor_spec.version` equals the target version string;
  (b) Law-Core checker (`make law-core-check`) passes all normative clauses
      introduced or changed by the amendment;
  (c) The amended spec's sha256 hash is recorded in evidence chain at Tier A
      or better (reproducible test + signed artifact + independent rerun).

Otherwise amendment is **INVALID** and this spec (v1.1, hash pinned by
intent.json at adoption) remains in force.

## 3. Escalation SLA and HALT semantics

### 3.1 Severity classes

| Severity | Label | Default verdict |
|----------|-------|-----------------|
| Fatal    | F     | PROHIBIT + HALT |
| Critical | C     | CONDITIONAL or PROHIBIT |
| High     | H     | CONDITIONAL (≤3 AND-ed conditions) |
| Medium   | M     | CONDITIONAL or APPROVE with annotation |
| Low      | L     | APPROVE with annotation; fix in next commit |

### 3.2 Owner SLA

Owner MUST respond to `Fatal` / `Critical` notices within **72 hours** of
the notice's ISO-8601 UTC timestamp (as recorded in the Public audit
artifact's header). "Response" = a signed (role=Owner) message recorded in
`audits/evidence/` referencing the specific session id.

### 3.3 HALT state (deterministic)

If Owner does not respond within 72h, OR a §9 Fatal trigger fires:

  - repository SHALL enter **HALT** state;
  - protected-branch merges blocked (CI: `make halt-on-critical` → non-zero);
  - release / tag jobs blocked;
  - deployment jobs blocked;
  - read-only audit artifact generation remains permitted.

### 3.4 Exit HALT

Exit HALT only by ONE of:
  (i)   Owner response artifact recorded in `audits/evidence/` AND
        Law-Core checker (`make law-core-check`) reports `overall_pass: true`;
  (ii)  A court order artifact recorded in `audits/evidence/` with
        sha256 referenced in the evidence manifest.

All other proposed exits = PROHIBITED.

## 4. Mission constraints (Newton gate)

A technique / PoC family is **Newton = true IF AND ONLY IF ALL** of:

  (F1) Formal closure      — decidable pre/post transition predicates,
                             machine-checked (0 `sorry`, 0 `admit`).
  (F2) Sovereign enforcement — SDO obligations cryptographically bound to
                             a surgery proof-id (Π_surg). SDO discharge
                             verified before surgery is accepted.
  (F3) Economic irreversibility — modeled attacker cost ≥ 100 × defender
                             cost; defender cost scales *sublinearly* in
                             node count (O(n^k), k < 1; proved, not claimed).

If any predicate is unknown / untested / failed → **Newton = false**.
Partial progress (1 or 2 of 3) is tracked explicitly; no rounding up.

## 5. Mandatory PoC families (compliance targets)

Five families. Each family SHALL define in a machine-readable sidecar file
(`audits/spec/family_<NAME>.json`, produced in Phase 1): inputs, outputs,
deterministic pass/fail predicates, reproducibility command(s), artifact
hash list.

### 5.1 SigmaTopo (Σ-topo) — Topology surgery calculus
Typed algebra: `join/3`, `split/2`, `quarantine/2`, `amputate/2`,
`bridge/3`. Proof obligations: commutativity, associativity, idempotence,
blast-radius R ≤ √|V| bound. Deliver extracted checker artifact.

### 5.2 PhiField (Φ-field) — Livefication dynamics + control
Lyapunov L(G) construction with decay rate. Controller C : G → surgery-set.
Monte-Carlo pass rate ≥ 0.9999 on 10⁵ 100-node topologies. Controller
conformance artifact (extracts to OpenWrt ucode blob).

### 5.3 PiSDO (Π_SDO) — Bonded sovereign developer obligations
ZK breach-proof verifier + bonded slashing simulation. 24h soak test, 100
SDO create→discharge/breach→settle cycles. 0 failures. Breach-to-settlement
< 6 deterministic blocks.

### 5.4 DeltaHash (Δ-Hash) — Session integrity chain
H₀ = sha256(boot-ROM ‖ Factory). Hᵢ = sha256(Hᵢ₋₁ ‖ Π_surgᵢ ‖ ΦΔ ‖
auditor-sig). Rust crate compiles to: (a) MT7981 MIPS64 musl static binary,
(b) AWS Nitro enclave. Performance: 10 000-entry verify < 150 ms on MT3000.

### 5.5 LawCore — Normative semantics portability
Deontic (O / F / P) + modal (□_auth / ◇_breach) DSL extracted from docs
into a **static C binary** checker. No LLM, no interpreter, no runtime
network calls in decision path. Gates CI commit + firmware build + surgery.

## 6. Operating rules

6.1 Default auditor scope: **A0-L (read-only)**. Scope elevation to A1-M
    (mutation-authorized) is PROHIBITED until both exist:
      — Owner signature (role=Owner) in `docs/intent.json`.
      — Codex approval signature (role=Codex) with `overall_pass: true`
        output from `make law-core-check`.

6.2 Any commit impacting governed scope **MUST** use the `TRAE:` prefix
    followed by a session-uuid tag and a Law-Core predicate-scope hash
    (once Law-Core is deployed). Governance prefix is a hard CI gate.

6.3 Counterfactual failure catalog (≥7 items for APPROVE/CONDITIONAL on
    Fatal/Critical) is REQUIRED before any authorization decision.
    Each item: adversarial model, blast radius R estimate, Φ-drop
    estimate, detection δt.

6.4 Prior-art inventory of **≥ 5 semantic neighbors** REQUIRED before
    proposing any new primitive. Per entry: (a) purpose, (b) how it fails
    Newton-class criteria, (c) why MBSD approach is strictly different.
    Blocking gate; not box-ticking.

6.5 Evidence-chain tiering (§7) SHALL be recorded for every audit.
    Tier S/A/B/C with criteria below.

## 7. Evidence-chain tiers

| Tier | Criteria | Sufficiency for Fatal/Critical auth |
|------|----------|-------------------------------------|
| S    | Formally verified artifact + reproducible build + signed provenance. | Yes (standalone) |
| A    | Reproducible test + signed artifact + independent rerun by second env. | Yes (standalone) |
| B    | Single-environment reproducible run + integrity hashes. | No — MUST pair with at least one A-tier sibling evidence |
| C    | Descriptive evidence only. (Expert judgment, prose, LLM output.) | NO — never sufficient alone; L0 only |

Authorization decisions touching Fatal/Critical severity MUST rely on at
least one Tier A or S evidence item. Fatal decisions MAY PROHIBIT on Tier
B alone (no positive authorization without A/S).

## 8. Public reporting policy (data minimization)

Public audit outputs (files in `audits/evidence/*_PUBLIC.*`) are RESTRICTED
to the following fields. Any other field SHALL be redacted:

  - booleans (true/false, pass/fail)
  - counts (numbers of clauses, families, tests, violations)
  - hashes (sha256 of artifacts, specs, targets, predicates)
  - timestamps (ISO-8601 UTC)
  - spec version (e.g., `"1.1"`)

Public outputs SHALL NOT contain: network identifiers, partition byte
values, key material, raw topology data, IPs, MACs, owner PII beyond
declared pubkey fingerprints.

Private bundles (encrypted to Owner key) SHALL contain full evidence and
a signed redaction log listing each item removed from public and the
minimization / PII / legal justification.

## 9. Deterministic severity triggers

| Severity | Trigger |
|----------|---------|
| Fatal    | Law-Core contradiction (same clause both true AND false across runs). |
| Fatal    | Forged signature detected in `intent.json` signatories / audit artifacts. |
| Fatal    | Broken evidence-chain continuity (Δ-Hash Hᵢ ∉ forward-cone of H₀). |
| Fatal    | Unauthorized spec amendment (§2 a/b/c violated). |
| Fatal    | Factory-partition backup absent or unverifiable (no dual-pass checksums). |
| Fatal    | Auditor A1-M scope used without Owner + Codex signoff artifacts on file. |
| Critical | Newton predicate (F1/F2/F3) = false on a production-intended technique. |
| Critical | Missing mandatory evidence for any of 5 PoC families on release track. |
| Critical | 72h Owner SLA breach (§3.2) on a Fatal/Critical notice. |
| High     | Reproducibility failure for a required artifact (N*M reruns disagree). |
| Medium   | Prior-art set incomplete (<5 neighbors) at primitive design-start. |
| Medium   | Counterfactual section missing or <7 items for Fatal/Critical decision. |
| Low      | Formatting / metadata nonconformance without security impact. |

## 10. Repo-fit profile for timelabs-npo/mbsd (Shell/Makefile first)

The repository is Shell/Makefile-heavy. Full integration REQUIRES all of:

  10.1 `make law-core-check` — deterministic, non-LLM. Prints JSON to stdout
        matching the Law-Core decision contract (§11). Exit 0 iff
        `overall_pass: true`.
  10.2 `make evidence` — hash manifest of all governed artifacts; writes
        to `audits/evidence/manifest.sha256`.
  10.3 `make halt-on-critical` — CI gate. Exit non-zero if any
        Critical/Fatal trigger asserted OR if Law-Core `severity` field
        ∈ {Fatal, Critical}.
  10.4 `scripts/validate_intent.sh` — POSIX sh. Validates `docs/intent.json`
        against `audits/spec/intent.schema.json` (schema version pinned by
        this spec v1.1). Checks required signatures present; signature
        verification hooks exposed.
  10.5 `audits/` directory layout committed:
        - `audits/spec/`             (this spec + schemas + family sidecars)
        - `audits/evidence/`         (public + encrypted private bundles)
        - `audits/prior_art/`        (per-primitive inventories)
        - `audits/failure_catalog/`  (per-audit counterfactuals)

## 11. Law-Core decision contract (deterministic JSON)

Law-Core checker output (stdout of `make law-core-check`) SHALL be a
single valid JSON object with this exact shape; any extras disallowed
per `additionalProperties: false` in Law-Core schema:

```json
{
  "spec_version":          "1.1",
  "clause_results":        { "<clause-id>": true | false, ... },
  "overall_pass":          true | false,
  "severity":              "None" | "Low" | "Medium" | "High" | "Critical" | "Fatal",
  "evidence_hashes":       [ "sha256:..." , ... ],
  "timestamp":             "2026-01-01T00:00:00Z"
}
```

Checker SHALL not write to stderr on pass; MAY write diagnostic lines to
stderr on fail. Checker SHALL exit 0 on `overall_pass: true`, non-zero
otherwise. Deterministic: same inputs → byte-identical output except for
`timestamp` which SHALL use the ISO-8601 UTC timestamp at invocation.

## 12. Spec hash bootstrap (self-reference)

This file contains the sentinel string `d9a1040d80f2a47bf474aa6a93a1fe2d1f7975b4158358da56c655c92cb132a5`. To
finalize this spec for signing in `intent.json`:

```sh
# 1. Compute hash of current file (with sentinel)
TMP=$(mktemp)
cp audits/spec/auditor_spec_v1.1.md "$TMP"
PH=$(sha256sum "$TMP" | cut -d' ' -f1)

# 2. Replace sentinel with the hash
sed -i.bak "s/d9a1040d80f2a47bf474aa6a93a1fe2d1f7975b4158358da56c655c92cb132a5/$PH/" audits/spec/auditor_spec_v1.1.md
rm -f audits/spec/auditor_spec_v1.1.md.bak

# 3. Compute final hash of the replaced file — THIS is the canonical hash
FH=$(sha256sum audits/spec/auditor_spec_v1.1.md | cut -d' ' -f1)
echo "placeholder-hash=$PH"
echo "  canonical-hash=$FH   <- use in intent.json auditor_spec.hash"
```

The `intent.json` `auditor_spec.hash` SHALL equal `$FH` (the post-replace
hash). The `$PH`-to-`$FH` two-step prevents a self-reference fixed-point
loop while still making the spec introspectable. The `Makefile` target
`make spec-hash` performs this procedure and prints both values.

---

End of auditor_spec v1.1.
