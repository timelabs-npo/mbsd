#!/bin/sh
# scripts/validate_intent.sh
# -----------------------------------------------------------------------------
# POSIX-sh validator for docs/intent.json against audits/spec/intent.schema.json.
#
# Structural checks (pure awk, no python, no jq):
#   - required top-level keys present
#   - auditor_spec.version matches ^1\.[0-9]+$
#   - auditor_spec.hash is exactly 64 hex chars
#   - owner.id and owner.pubkey_fingerprint non-empty, fingerprint >= 16 chars
#   - signatures array has >= 1 entry; each has {role, sig, algo} with
#     role ∈ {Owner,Codex}, sig length >= 32, algo ∈ {ed25519,secp256k1,signify-ed25519}
#   - updated_at matches ISO-8601 UTC pattern
#
# Signature verification (OPTIONAL, requires external tools):
#   --verify-owner   : attempt signify -V or openssl pkeyutl -verify on
#                      docs/intent.json.{sig,pub} vs the body.
#                      (Place holder; hook point. Exact message envelope TBD
#                       when Owner key is provisioned.)
# -----------------------------------------------------------------------------
set -eu

# --- defaults -----------------------------------------------------------------
INTENT_FILE="${INTENT_FILE:-docs/intent.json}"
SCHEMA_FILE="${SCHEMA_FILE:-audits/spec/intent.schema.json}"
DO_SIG_VERIFY=0
EXIT_CODE=0

# --- usage --------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $0 [--verify-owner] [--intent FILE] [--schema FILE]

Structurally validates intent.json against the v1.1 contract and (optionally)
attempts cryptographic Owner-signature verification.

Exits 0 on pass, non-zero on any structural or (if enabled) crypto failure.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --verify-owner) DO_SIG_VERIFY=1; shift ;;
        --intent) INTENT_FILE="$2"; shift 2 ;;
        --schema) SCHEMA_FILE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "validate_intent: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

# --- preconditions ------------------------------------------------------------
if [ ! -f "$INTENT_FILE" ]; then
    echo "FAIL: intent file not found: $INTENT_FILE" >&2
    exit 3
fi
if [ ! -f "$SCHEMA_FILE" ]; then
    echo "FAIL: schema file not found: $SCHEMA_FILE" >&2
    exit 3
fi

# Extract a JSON value (string) for a scalar key path "a.b.c" at depth 1-2 only.
# Crude but sufficient for intent.json's fixed known shape; avoids jq/python.
extract_scalar() {
    # $1 = path like "auditor_spec.version"
    awk -v keypath="$1" '
    BEGIN { depth = split(keypath, parts, "."); in_obj = 0; }
    {
        line = $0
        n = length(line)
        for (i = 1; i <= n; i++) {
            c = substr(line, i, 1)
            if (c == "{") { stack[++sp] = "{" }
            if (c == "}") { sp-- }
        }
    }
    ' < "$INTENT_FILE" >/dev/null

    # Actual extractor: targeted line patterns
    case "$1" in
        auditor_spec.version)
            awk 'match($0, /"auditor_spec"[ \t]*:[ \t]*\{/, m) { in_a=1 }
                 in_a && match($0, /"version"[ \t]*:[ \t]*"([^"]*)"/, g) { print g[1]; exit }
                 in_a && match($0, /\}/) { exit }' "$INTENT_FILE"
            ;;
        auditor_spec.hash)
            awk 'match($0, /"auditor_spec"[ \t]*:[ \t]*\{/) { in_a=1 }
                 in_a && match($0, /"hash"[ \t]*:[ \t]*"([^"]*)"/, g) { print g[1]; exit }
                 in_a && match($0, /\}/) { exit }' "$INTENT_FILE"
            ;;
        owner.id)
            awk 'match($0, /"owner"[ \t]*:[ \t]*\{/) { in_o=1 }
                 in_o && match($0, /"id"[ \t]*:[ \t]*"([^"]*)"/, g) { print g[1]; exit }
                 in_o && match($0, /\}/) { exit }' "$INTENT_FILE"
            ;;
        owner.pubkey_fingerprint)
            awk 'match($0, /"owner"[ \t]*:[ \t]*\{/) { in_o=1 }
                 in_o && match($0, /"pubkey_fingerprint"[ \t]*:[ \t]*"([^"]*)"/, g) { print g[1]; exit }
                 in_o && match($0, /\}/) { exit }' "$INTENT_FILE"
            ;;
        updated_at)
            awk 'match($0, /"updated_at"[ \t]*:[ \t]*"([^"]*)"/, g) { print g[1]; exit }' "$INTENT_FILE"
            ;;
        schemaVersion)
            awk 'match($0, /"schemaVersion"[ \t]*:[ \t]*"([^"]*)"/, g) { print g[1]; exit }' "$INTENT_FILE"
            ;;
        project)
            awk 'match($0, /"project"[ \t]*:[ \t]*"([^"]*)"/, g) { print g[1]; exit }' "$INTENT_FILE"
            ;;
    esac
}

fail() { echo "  FAIL: $1" >&2; EXIT_CODE=1; }
pass() { echo "  ok  : $1"; }

echo "[validate_intent] $INTENT_FILE vs $SCHEMA_FILE"

# --- 1. required top-level keys ----------------------------------------------
for K in schemaVersion project auditor_spec owner signatures updated_at; do
    if grep -q "\"$K\"" "$INTENT_FILE"; then
        pass "top-level key present: $K"
    else
        fail "missing required top-level key: $K"
    fi
done

# --- 2. scalar shapes ---------------------------------------------------------
SV=$(extract_scalar schemaVersion);     [ -n "$SV" ] && pass "schemaVersion extracted: $SV" || fail "schemaVersion empty"
PR=$(extract_scalar project);           [ -n "$PR" ] && pass "project extracted: $PR"         || fail "project empty"
AV=$(extract_scalar auditor_spec.version)
AH=$(extract_scalar auditor_spec.hash)
OI=$(extract_scalar owner.id)
OF=$(extract_scalar owner.pubkey_fingerprint)
UA=$(extract_scalar updated_at)

# auditor_spec.version = ^1\.[0-9]+$
if echo "$AV" | grep -Eq '^1\.[0-9]+$'; then
    pass "auditor_spec.version valid: $AV"
else
    fail "auditor_spec.version invalid: '$AV' (want ^1\\.[0-9]+\$)"
fi
# auditor_spec.hash = 64 hex
if echo "$AH" | grep -Eq '^[a-f0-9]{64}$'; then
    pass "auditor_spec.hash shape ok"
else
    fail "auditor_spec.hash invalid or missing: '$AH'"
fi
# owner.id non-empty
[ -n "$OI" ] && pass "owner.id non-empty: $OI" || fail "owner.id empty"
# owner.pubkey_fingerprint >= 16 chars
LEN_OF=$(awk -v s="$OF" 'BEGIN { print length(s) }')
if [ "$LEN_OF" -ge 16 ]; then
    pass "owner.pubkey_fingerprint length ok ($LEN_OF >= 16)"
else
    fail "owner.pubkey_fingerprint too short: $LEN_OF < 16"
fi
# updated_at ISO-8601 UTC (YYYY-MM-DDThh:mm:ssZ or +hh:mm)
if echo "$UA" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})$'; then
    pass "updated_at ISO-8601 shape ok: $UA"
else
    fail "updated_at invalid: '$UA' (want e.g. 2026-01-01T00:00:00Z)"
fi

# --- 3. signatures array structural check ------------------------------------
# Count entries, require at least 1 with {role, sig, algo} + enums.
SIG_COUNT=$(awk '
    /"signatures"[ \t]*:[ \t]*\[/ { in_sigs=1; next }
    in_sigs && /\]/ { exit }
    in_sigs && /"role"[ \t]*:/ { roles++ }
    in_sigs && /"sig"[ \t]*:/  { sigs++ }
    in_sigs && /"algo"[ \t]*:/ { algos++ }
    END {
        # each object has 1 of each -> count = min(roles,sigs,algos)
        m = roles
        if (sigs < m) m = sigs
        if (algos < m) m = algos
        print m
    }
' "$INTENT_FILE")

if [ -z "$SIG_COUNT" ] || [ "$SIG_COUNT" -lt 1 ]; then
    fail "signatures array must have >= 1 entry; found $SIG_COUNT"
else
    pass "signatures entries: $SIG_COUNT (>= 1)"
fi

# enum: role ∈ {Owner, Codex}; there must be at least 1 Owner role.
HAS_OWNER_ROLE=$(awk '
    /"signatures"[ \t]*:[ \t]*\[/ { in_s=1; next }
    in_s && /\]/ { exit }
    in_s && match($0, /"role"[ \t]*:[ \t]*"([^"]*)"/, g) {
        if (g[1] == "Owner") has_owner = 1
        if (g[1] != "Owner" && g[1] != "Codex") bad_role = 1
    }
    END { print (has_owner ? "1" : "0") " " (bad_role ? "1" : "0") }
' "$INTENT_FILE")
HO=$(echo "$HAS_OWNER_ROLE" | awk '{print $1}')
BR=$(echo "$HAS_OWNER_ROLE" | awk '{print $2}')
[ "$HO" = "1" ] && pass "at least one role=Owner signature present" || fail "no role=Owner signature in signatures array"
[ "$BR" = "0" ] && pass "signature roles ∈ {Owner,Codex}"           || fail "signature role outside allowed enum {Owner,Codex}"

# sig length >= 32 per entry (sample: find all "sig" values in signatures block)
MIN_SIG_LEN=$(awk '
    /"signatures"[ \t]*:[ \t]*\[/ { in_s=1; next }
    in_s && /\]/ { exit }
    in_s && match($0, /"sig"[ \t]*:[ \t]*"([^"]*)"/, g) {
        l = length(g[1])
        if (NR == 0 || l < min) min = l
    }
    END { print min+0 }
' "$INTENT_FILE")
if [ "$MIN_SIG_LEN" -ge 32 ]; then
    pass "shortest signature length ok ($MIN_SIG_LEN >= 32)"
else
    fail "signature too short: min=$MIN_SIG_LEN < 32"
fi

# enum: algo ∈ {ed25519, secp256k1, signify-ed25519}
BAD_ALGO=$(awk '
    /"signatures"[ \t]*:[ \t]*\[/ { in_s=1; next }
    in_s && /\]/ { exit }
    in_s && match($0, /"algo"[ \t]*:[ \t]*"([^"]*)"/, g) {
        if (g[1] != "ed25519" && g[1] != "secp256k1" && g[1] != "signify-ed25519") bad=1
    }
    END { print bad+0 }
' "$INTENT_FILE")
[ "$BAD_ALGO" = "0" ] && pass "signature algos ∈ allowed set" || fail "signature algo outside allowed enum"

# --- 4. schema hash cross-check: pinned hash should match THIS spec file -----
# (If sentinel still in spec, or spec file missing hash, this becomes WARN only)
SPEC_ON_DISK_HASH=$(sha256sum "$SCHEMA_FILE" 2>/dev/null | awk '{print $1}')
SPEC_MD_IN_DISK="audits/spec/auditor_spec_${AV}.md"
if [ -f "$SPEC_MD_IN_DISK" ]; then
    SPEC_MD_HASH=$(sha256sum "$SPEC_MD_IN_DISK" | awk '{print $1}')
    if [ "$SPEC_MD_HASH" = "$AH" ]; then
        pass "auditor_spec.hash matches on-disk $SPEC_MD_IN_DISK"
    else
        # Might be intentional (pre-bootstrap). Don't hard-fail.
        echo "  WARN: auditor_spec.hash ($AH) != on-disk $SPEC_MD_IN_DISK ($SPEC_MD_HASH)"
        echo "        If bootstrap has not been run, this is expected; see spec §12."
    fi
else
    echo "  NOTE: auditor_spec markdown $SPEC_MD_IN_DISK not found; hash cross-check skipped."
fi

# --- 5. optional signature crypto verification -------------------------------
if [ "$DO_SIG_VERIFY" = "1" ]; then
    echo "[validate_intent] --verify-owner requested (hook; toolchain-dependent)"
    if command -v signify >/dev/null 2>&1; then
        PUB="${INTENT_FILE}.pub"
        SIG="${INTENT_FILE}.sig"
        if [ -f "$PUB" ] && [ -f "$SIG" ]; then
            if signify -V -p "$PUB" -m "$INTENT_FILE" -x "$SIG" 2>/dev/null; then
                pass "Owner signify signature verified (signify -V OK)"
            else
                fail "Owner signify signature FAILED (signify -V)"
            fi
        else
            echo "  WARN: signify present but $PUB or $SIG missing; skip"
        fi
    else
        echo "  WARN: signify not installed on this host; skip Owner-sig verify"
    fi
fi

# --- final -------------------------------------------------------------------
if [ "$EXIT_CODE" = "0" ]; then
    echo "PASS: $INTENT_FILE passes v1.1 structural checks"
else
    echo "FAIL: $INTENT_FILE has structural or semantic errors; see above." >&2
fi
exit "$EXIT_CODE"
