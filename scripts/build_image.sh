#!/bin/bash
# OpenWrt ImageBuilder Wrapper for MBSD
# Downloads the 23.05.4 ImageBuilder for mediatek/filogic and builds the sysupgrade FIT image.

set -e

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <build_dir> <release_dir> <src_dir>"
    exit 1
fi

BUILD_DIR=$(realpath "$1")
RELEASE_DIR=$(realpath "$2")
SRC_DIR=$(realpath "$3")

# We use OpenWrt 23.05.4 stable for MT7981 (mediatek/filogic)
OWRT_VERSION="23.05.4"
TARGET="mediatek/filogic"
PROFILE="glinet_gl-mt3000"
IB_NAME="openwrt-imagebuilder-${OWRT_VERSION}-mediatek-filogic.Linux-x86_64"
IB_URL="https://downloads.openwrt.org/releases/${OWRT_VERSION}/targets/mediatek/filogic/${IB_NAME}.tar.xz"
IB_TAR="${BUILD_DIR}/${IB_NAME}.tar.xz"
IB_DIR="${BUILD_DIR}/${IB_NAME}"

echo "=== MBSD ImageBuilder Integration ==="
echo "[*] OpenWrt Version: $OWRT_VERSION"
echo "[*] Target Profile: $PROFILE"

# Download ImageBuilder if not present
if [ ! -d "$IB_DIR" ]; then
    echo "[*] Downloading OpenWrt ImageBuilder..."
    if [ ! -f "$IB_TAR" ]; then
        curl -L -o "$IB_TAR" "$IB_URL"
    fi
    
    echo "[*] Validating ImageBuilder SHA-256 checksum (CF-1 Mitigation)..."
    EXPECTED_SHA256="1ba8bdf77664f382f994144779423a6cd0b6ad95a4fbd36de3f3c92281eb7b92"
    ACTUAL_SHA256=$(shasum -a 256 "$IB_TAR" | awk '{print $1}')
    if [ "$EXPECTED_SHA256" != "$ACTUAL_SHA256" ]; then
        echo "[!] FATAL: ImageBuilder checksum mismatch!"
        echo "Expected: $EXPECTED_SHA256"
        echo "Got:      $ACTUAL_SHA256"
        exit 1
    fi
    echo "[+] Checksum verified."

    echo "[*] Extracting ImageBuilder..."
    tar -xf "$IB_TAR" -C "$BUILD_DIR"
fi

# Prepare to build
echo "[*] Running make image..."
cd "$IB_DIR"

# Basic packages for MBSD. 
# We explicitly remove uci and standard webui since we are fully immutable and state-injected via blueshoes.
PACKAGES="kmod-mt7981-firmware kmod-mt7915e wpad-basic-mbedtls -luci -uhttpd -rpcd"

# Run ImageBuilder
make image PROFILE="$PROFILE" PACKAGES="$PACKAGES" FILES="$SRC_DIR"

# The output will be in $IB_DIR/bin/targets/mediatek/filogic/
# Look for the sysupgrade.itb or .bin file
FIRMWARE_OUT_DIR="$IB_DIR/bin/targets/mediatek/filogic"
FIRMWARE_FILE=$(find "$FIRMWARE_OUT_DIR" -type f -name "*${PROFILE}*sysupgrade.itb" -o -name "*${PROFILE}*sysupgrade.bin" | head -n 1)

if [ -z "$FIRMWARE_FILE" ]; then
    echo "[!] CRITICAL: Failed to find built firmware in $FIRMWARE_OUT_DIR"
    exit 1
fi

echo "[*] Build successful! Copying firmware to release directory..."
cp "$FIRMWARE_FILE" "$RELEASE_DIR/mbsd-overlay.itb"

echo "=== Build Complete ==="
echo "Firmware available at: $RELEASE_DIR/mbsd-overlay.itb"
