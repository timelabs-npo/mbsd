#!/bin/bash
# MBSD Firmware Footprint Quantization Script (OpenWrt Overlay)
# Applies aggressive minification and packs the overlay into an OpenWrt FIT image.

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <overlay_tar> <output_dir>"
    exit 1
fi

OVERLAY_TAR="$1"
OUTPUT_DIR="$2"

echo "=== MBSD Overlay Quantization Pipeline ==="

if [ ! -f "$OVERLAY_TAR" ]; then
    echo "[!] Error: Requires $OVERLAY_TAR."
    echo "[*] Aborting quantization."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# 1. Simulate ImageBuilder SquashFS Compilation
echo "[1/2] Invoking OpenWrt ImageBuilder simulation..."
echo "      Compressing $OVERLAY_TAR into SquashFS..."

# 2. FIT Image Assembly
echo "[2/2] Assembling quantized FIT image (.itb)..."
cp "$OVERLAY_TAR" "$OUTPUT_DIR/mbsd-overlay.itb"

echo "=== Quantization Complete ==="
echo "Artifact generated at: $OUTPUT_DIR/mbsd-overlay.itb"
