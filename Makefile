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

vanilla: $(BUILD_DIR)
	@echo "=== Compiling Vanilla Human-Layer Source ==="
	@echo "[*] This simulates compiling the raw MBSD overlay structures."
	@touch $(TARGET_OVERLAY)
	@echo "fake-tar-payload" > $(TARGET_OVERLAY)
	@echo "=== Vanilla Compilation Complete ==="

quantize: vanilla
	@echo "=== Executing Deployment Finalization ==="
	@$(SCRIPTS_DIR)/quantize_firmware.sh $(TARGET_OVERLAY) $(RELEASE_DIR)

release: quantize
	@echo "=== Release Artifacts Ready ==="
	@ls -la $(RELEASE_DIR)

clean:
	@echo "=== Cleaning Build and Release Directories ==="
	rm -rf $(BUILD_DIR)
	rm -rf $(RELEASE_DIR)
	@echo "[*] Repository restored to pristine vanilla state."
