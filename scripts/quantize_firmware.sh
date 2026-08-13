#!/bin/bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <firmware_file> <release_dir>"
    exit 1
fi

FIRMWARE_FILE=$(realpath "$1")
RELEASE_DIR=$(realpath "$2")

if [ ! -f "$FIRMWARE_FILE" ]; then
    echo "[!] FATAL: Firmware file $FIRMWARE_FILE not found for quantization."
    exit 1
fi

REPORT_FILE="$RELEASE_DIR/minification_report.txt"

echo "======================================" > "$REPORT_FILE"
echo " MBSD FIRMWARE QUANTIZATION REPORT" >> "$REPORT_FILE"
echo "======================================" >> "$REPORT_FILE"
echo "Date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')" >> "$REPORT_FILE"
echo "Target: $FIRMWARE_FILE" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Cross-platform file size (macOS uses -f%z, GNU/Linux uses -c%s)
if stat -f%z "$FIRMWARE_FILE" >/dev/null 2>&1; then
    FILE_SIZE=$(stat -f%z "$FIRMWARE_FILE")
else
    FILE_SIZE=$(stat -c%s "$FIRMWARE_FILE")
fi

# Compute MB without requiring bc
FILE_SIZE_KB=$((FILE_SIZE / 1024))
FILE_SIZE_MB_INT=$((FILE_SIZE_KB / 1024))
FILE_SIZE_MB_FRAC=$(( (FILE_SIZE_KB % 1024) * 100 / 1024 ))

echo "Total Image Size: $FILE_SIZE bytes (~${FILE_SIZE_MB_INT}.${FILE_SIZE_MB_FRAC} MB)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "SHA-256: $(shasum -a 256 "$FIRMWARE_FILE" | awk '{print $1}')" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "Excluded Packages (Minification Profile):" >> "$REPORT_FILE"
echo "  -luci -uhttpd -rpcd" >> "$REPORT_FILE"
echo "  -ppp -ppp-mod-pppoe" >> "$REPORT_FILE"
echo "  -kmod-usb-core -kmod-usb2 -kmod-usb3" >> "$REPORT_FILE"
echo "  -ip6tables -odhcp6c -kmod-ipv6 -ip6tables-mod-nat" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# MT3000 has 256MB NAND. Firmware partition is typically ~50MB max.
# Ultra-minified target: <20MB.
MAX_SIZE=$((20 * 1024 * 1024))
if [ "$FILE_SIZE" -gt "$MAX_SIZE" ]; then
    echo "[!] WARNING: Image size ($FILE_SIZE bytes) exceeds minification target of 20MB." >> "$REPORT_FILE"
    echo "    Consider removing additional kernel modules or reducing package set." >> "$REPORT_FILE"
else
    echo "[+] PASS: Image size ($FILE_SIZE bytes) is within ultra-minified target (<20MB)." >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "--- End of Report ---" >> "$REPORT_FILE"

echo "[+] Quantization analysis complete. Report written to $REPORT_FILE"
cat "$REPORT_FILE"
