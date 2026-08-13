# MBSD Finalization Pipeline (OpenWrt Overlay Pivot)
# Protects the vanilla human-layer work artifact from deployment-stage minification.

.PHONY: all vanilla quantize release clean

# Directories
SRC_DIR = src
BUILD_DIR = build
RELEASE_DIR = release
SCRIPTS_DIR = scripts

# Targets
TARGET_OVERLAY = $(BUILD_DIR)/mbsd-overlay.tar.gz
TARGET_RELEASE = $(RELEASE_DIR)/mbsd-overlay.itb

all: release

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR) $(RELEASE_DIR)

factory-check:
	@echo "=== Verifying Factory Partition Forensics ==="
	@if [ ! -d "backups" ] || [ -z "$$(ls -A backups 2>/dev/null)" ]; then \
		echo "[!] WARNING: No Factory partition backups found in backups/ directory."; \
		echo "[!] You should run scripts/backup_mt3000.sh before flashing the hardware."; \
		echo "[!] Proceeding with build for development purposes..."; \
	else \
		echo "[*] Factory forensics verified."; \
	fi

vanilla: $(BUILD_DIR)
	@echo "=== Preparing Vanilla Overlay (src/) ==="
	@mkdir -p $(SRC_DIR)/etc/config $(SRC_DIR)/usr/sbin
	@echo "[*] Overlay scaffolding ready."

build-image: vanilla factory-check
	@echo "=== Building Image via OpenWrt ImageBuilder ==="
	@bash $(SCRIPTS_DIR)/build_image.sh $(BUILD_DIR) $(RELEASE_DIR) $(SRC_DIR)

quantize: build-image
	@echo "=== Executing Deployment Finalization ==="
	@$(SCRIPTS_DIR)/quantize_firmware.sh $(RELEASE_DIR)/mbsd-overlay.itb $(RELEASE_DIR)

sign: quantize
	@echo "=== Signing Artifacts ==="
	@if [ ! -f "mbsd-release.sec" ]; then \
		echo "[!] Error: Signing key (mbsd-release.sec) not found."; \
		echo "[!] See docs/SIGNING.md for key generation instructions."; \
		exit 1; \
	fi
	@signify -S -s mbsd-release.sec -m $(TARGET_RELEASE) -x $(TARGET_RELEASE).sig
	@echo "[*] Artifact successfully signed."

release: sign
	@echo "=== Release Artifacts Ready ==="
	@ls -la $(RELEASE_DIR)

clean:
	@echo "=== Cleaning Build and Release Directories ==="
	rm -rf $(BUILD_DIR)
	rm -rf $(RELEASE_DIR)
	@echo "[*] Repository restored to pristine vanilla state."
