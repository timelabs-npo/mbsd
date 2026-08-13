# MBSD Finalization Pipeline
# Protects the vanilla human-layer work artifact from deployment-stage minification.

.PHONY: all vanilla quantize release clean

# Directories
SRC_DIR = src/kernel
BUILD_DIR = build
RELEASE_DIR = release
SCRIPTS_DIR = scripts

# Targets
TARGET_KERNEL = $(BUILD_DIR)/bsd
TARGET_RAMDISK = $(BUILD_DIR)/miniroot.fs
TARGET_RELEASE = $(RELEASE_DIR)/bsd.rd.quantized

all: release

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR) $(RELEASE_DIR)

vanilla: $(BUILD_DIR)
	@echo "=== Compiling Vanilla Human-Layer Source ==="
	@echo "[*] This simulates compiling the raw, uncompressed OpenBSD kernel."
	# In a real pipeline, this would invoke `make -f Makefile.bsd` inside $(SRC_DIR)
	@touch $(TARGET_KERNEL)
	@echo "int main(){}" > $(BUILD_DIR)/dummy.c && cc $(BUILD_DIR)/dummy.c -o $(TARGET_KERNEL)
	@echo "[*] Creating raw, uncompressed RAMDISK."
	@dd if=/dev/zero of=$(TARGET_RAMDISK) bs=1m count=10 2>/dev/null
	@echo "=== Vanilla Compilation Complete ==="

quantize: vanilla
	@echo "=== Executing Deployment Finalization ==="
	@$(SCRIPTS_DIR)/quantize_firmware.sh $(TARGET_KERNEL) $(TARGET_RAMDISK) $(RELEASE_DIR)

release: quantize
	@echo "=== Release Artifacts Ready ==="
	@ls -la $(RELEASE_DIR)

clean:
	@echo "=== Cleaning Build and Release Directories ==="
	rm -rf $(BUILD_DIR)
	rm -rf $(RELEASE_DIR)
	@echo "[*] Repository restored to pristine vanilla state."
