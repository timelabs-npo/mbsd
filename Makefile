# ==============================================================================
# MBSD NORMATIVE BUILD & VERIFICATION INTERFACE
# ==============================================================================

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.PHONY: all vanilla factory-check build-image quantize sign release clean \
        validate-intent test-val-intent law-core-check evidence halt-on-critical spec-hash

SRC_DIR = src
BUILD_DIR = build
RELEASE_DIR = release
SCRIPTS_DIR = scripts
SPEC_DOC = audits/spec/auditor_spec_v1.1.md
INTENT_FILE = docs/intent.json
LAWCORE_OUT = audits/evidence/lawcore_out.json
MANIFEST = audits/evidence/manifest.sha256

all: release

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR) $(RELEASE_DIR) audits/evidence audits/spec

# Strict Factory Forensics Check (CP-3: HARD ERROR IF MISSING)
factory-check:
	@echo "=== Verifying Factory Partition Forensics (CP-3) ==="
	@if [ ! -d "backups" ] || [ -z "$$(ls -A backups 2>/dev/null)" ] || [ ! -f "backups/Factory.sha256" ]; then \
		echo "[!] FATAL (CP-3): No verified Factory backup found in backups/."; \
		echo "[!] Hardware flashing is strictly blocked until dual-pass forensics are complete."; \
		exit 1; \
	fi
	@echo "[+] Factory partition forensic baseline verified."

spec-hash:
	@mkdir -p audits/spec
	@if [ -f "$(SPEC_DOC)" ]; then \
		shasum -a 256 $(SPEC_DOC) | awk '{print $$1}' > audits/spec/spec.hash; \
		echo "[*] Pinned Auditor Spec Hash: $$(cat audits/spec/spec.hash)"; \
	else \
		echo "[!] FATAL: $(SPEC_DOC) missing." && exit 1; \
	fi

validate-intent:
	@echo "[*] Validating $(INTENT_FILE) structure and signatures..."
	@if [ ! -f "$(INTENT_FILE)" ]; then echo "[!] FATAL: Missing $(INTENT_FILE)" && exit 1; fi
	@python3 -c "import json; d=json.load(open('$(INTENT_FILE)')); \
		assert d.get('schemaVersion') == '1.1', 'Invalid schemaVersion'; \
		assert 'owner' in d and 'pubkey_fingerprint' in d['owner'], 'Missing owner pin'; \
		assert 'auditor_spec' in d and 'hash' in d['auditor_spec'], 'Missing auditor_spec'; \
		assert 'signatures' in d and len(d['signatures']) >= 1, 'Missing required signatures'; \
		assert 'updated_at' in d, 'Missing updated_at'" \
		|| (echo "[!] FATAL (CP-2): Intent validation failed." && exit 1)
	@echo "[+] Intent metadata validated."

test-val-intent:
	@echo "[*] Running developer intent validation..."
	@-python3 -c "import json; d=json.load(open('$(INTENT_FILE)')); \
		print('[+] Project:', d.get('project', 'UNKNOWN')); \
		print('[+] Signatures count:', len(d.get('signatures', [])))"

law-core-check:
	@mkdir -p audits/evidence
	@echo "[*] Executing Law-Core Static Verifier..."
	@if [ -x "bin/law-core" ]; then \
		./bin/law-core --json-out $(LAWCORE_OUT); \
	else \
		echo "[!] FATAL (CP-6): bin/law-core missing or not executable." && exit 1; \
	fi

evidence:
	@mkdir -p audits/evidence
	@echo "[*] Generating deterministic evidence manifest..."
	@find docs scripts src audits/spec -type f -exec shasum -a 256 {} + | sort -k2 > $(MANIFEST)
	@echo "[+] Manifest written to $(MANIFEST)"

halt-on-critical:
	@echo "=== CI Verification: halt-on-critical ==="
	@$(MAKE) validate-intent
	@$(MAKE) law-core-check
	@python3 -c "import json; d=json.load(open('$(LAWCORE_OUT)')); \
		assert d.get('overall_pass') in [True, 1], 'Law-Core overall_pass is false'; \
		assert d.get('severity') in ['None', 'Low', 'Medium', 'High'], 'Severity too high: ' + str(d.get('severity'))" \
		|| (echo "[!] CI HALT: Critical non-conformance detected." && exit 1)
	@echo "[+] CI Check Passed: Repository clean."

vanilla: $(BUILD_DIR)
	@mkdir -p $(SRC_DIR)/etc/config $(SRC_DIR)/usr/sbin

build-image: vanilla factory-check
	@bash $(SCRIPTS_DIR)/build_image.sh $(BUILD_DIR) $(RELEASE_DIR) $(SRC_DIR)

quantize: build-image
	@bash $(SCRIPTS_DIR)/quantize_firmware.sh $(RELEASE_DIR)/mbsd-overlay.itb $(RELEASE_DIR)

sign: quantize
	@if [ ! -f "mbsd-release.sec" ]; then \
		echo "[!] Error: Signing key mbsd-release.sec not found." && exit 1; \
	fi
	@signify -S -s mbsd-release.sec -m $(RELEASE_DIR)/mbsd-overlay.itb -x $(RELEASE_DIR)/mbsd-overlay.itb.sig

release: sign
	@echo "[+] Release artifacts successfully assembled."

clean:
	rm -rf $(BUILD_DIR) $(RELEASE_DIR) audits/evidence
