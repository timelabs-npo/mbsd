#!/bin/bash
set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <build_dir> <release_dir> <src_dir>"
    exit 1
fi

BUILD_DIR=$(realpath "$1")
RELEASE_DIR=$(realpath "$2")
SRC_DIR=$(realpath "$3")

OWRT_VERSION="23.05.4"
TARGET="mediatek/filogic"
PROFILE="glinet_gl-mt3000"
IB_NAME="openwrt-imagebuilder-${OWRT_VERSION}-mediatek-filogic.Linux-x86_64"
IB_URL="https://downloads.openwrt.org/releases/${OWRT_VERSION}/targets/mediatek/filogic/${IB_NAME}.tar.xz"
IB_TAR="${BUILD_DIR}/${IB_NAME}.tar.xz"
IB_DIR="${BUILD_DIR}/${IB_NAME}"

# NORMATIVE PIN: Pinned OpenWrt 23.05.4 ImageBuilder SHA-256 Checksum
# Note: Using the actual sha256sum from the OpenWrt download server to prevent curl failure.
EXPECTED_SHA256="1ba8bdf77664f382f994144779423a6cd0b6ad95a4fbd36de3f3c92281eb7b92"

mkdir -p "$BUILD_DIR" "$RELEASE_DIR"

if [ ! -d "$IB_DIR" ]; then
    if [ ! -f "$IB_TAR" ]; then
        echo "[*] Downloading OpenWrt ImageBuilder..."
        curl -sSL -o "$IB_TAR" "$IB_URL"
    fi
    
    echo "[*] Verifying ImageBuilder integrity..."
    ACTUAL_SHA256=$(shasum -a 256 "$IB_TAR" | awk '{print $1}')
    if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "[!] FATAL: SHA-256 mismatch on ImageBuilder tarball!"
        echo "[!] Expected: $EXPECTED_SHA256"
        echo "[!] Actual:   $ACTUAL_SHA256"
        rm -f "$IB_TAR"
        exit 1
    fi
    echo "[+] ImageBuilder integrity verified."
    
    echo "[*] Extracting ImageBuilder..."
    tar -xf "$IB_TAR" -C "$BUILD_DIR"
fi

echo "[*] Building immutable SquashFS image..."
cd "$IB_DIR"
PACKAGES="kmod-mt7981-firmware kmod-mt7915e wpad-basic-mbedtls -luci -uhttpd -rpcd"
make image PROFILE="$PROFILE" PACKAGES="$PACKAGES" FILES="$SRC_DIR"

FIRMWARE_FILE=$(find "$IB_DIR/bin/targets/mediatek/filogic" -type f \( -name "*${PROFILE}*sysupgrade.itb" -o -name "*${PROFILE}*sysupgrade.bin" \) | head -n 1)

if [ -z "$FIRMWARE_FILE" ] || [ ! -f "$FIRMWARE_FILE" ]; then
    echo "[!] FATAL: Build failed to produce sysupgrade artifact."
    exit 1
fi

cp "$FIRMWARE_FILE" "$RELEASE_DIR/mbsd-overlay.itb"
echo "[+] Immutable release artifact generated at: $RELEASE_DIR/mbsd-overlay.itb"
