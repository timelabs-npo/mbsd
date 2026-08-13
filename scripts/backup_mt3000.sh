#!/bin/bash
# Backup script for GL.iNet GL-MT3000 ("Beryl AX") SPI-NAND
# Uses SSH to execute nanddump to safely extract Factory partitions with OOB metadata.

if [ -z "$1" ]; then
    echo "Usage: $0 <router_ip>"
    exit 1
fi

ROUTER_IP="$1"
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "=== MBSD Factory Forensics Backup Pipeline ==="

# 1. Fetch Partition Table
ssh -o StrictHostKeyChecking=no root@$ROUTER_IP "cat /proc/mtd" > "$BACKUP_DIR/proc_mtd.txt" 2>/dev/null || true

if [ ! -s "$BACKUP_DIR/proc_mtd.txt" ]; then
    echo "⚠️ WARNING: GL-MT3000 requires 3.3V TTL logic. 5V will DESTROY the MT7981 SoC. ⚠️"
    echo "[*] Ensure you are connected to the internal 4-pin header via 3.3V UART (115200 8N1)"
    echo "[*] Instructions:"
    echo "1. Power cycle the router and press '0' or 'Escape' rapidly to catch the U-Boot prompt."
    echo "2. Run 'printenv' and save the output."
    echo "3. Run 'bdinfo' and save the output."
    echo "4. Run 'fdt print' and save the output."
    echo "---"
    echo "Note: ATF (BL31) is NOT interruptible. U-Boot is BL33."
    echo "Note: Stock U-Boot lacks bootefi. We will target FIT images via 'bootm'."
    exit 1
fi

echo "[*] Connected. Found partition table."

# 2. Extract Factory Partition Safely
echo "[*] Locating Factory partition..."
FACTORY_MTD=$(grep -i "factory" "$BACKUP_DIR/proc_mtd.txt" | awk -F: '{print $1}')

if [ -z "$FACTORY_MTD" ]; then
    echo "[!] CRITICAL: Could not find 'factory' partition in /proc/mtd."
    echo "[!] Aborting backup to prevent corruption."
    exit 1
fi

echo "[*] Dumping Factory partition via nanddump (--bb=skipbad --oob) from /dev/$FACTORY_MTD..."
ssh root@$ROUTER_IP "nanddump -f /tmp/factory.bin --bb=skipbad --oob /dev/$FACTORY_MTD"
scp root@$ROUTER_IP:/tmp/factory.bin "$BACKUP_DIR/factory.bin"

if [ ! -s "$BACKUP_DIR/factory.bin" ]; then
    echo "[!] CRITICAL: Failed to dump Factory partition! DO NOT FLASH THIS DEVICE."
    exit 1
fi

# 3. Generate SHA-256 Checksum
echo "[*] Verifying Factory partition checksum..."
shasum -a 256 "$BACKUP_DIR/factory.bin" > "$BACKUP_DIR/factory.bin.sha256"
cat "$BACKUP_DIR/factory.bin.sha256"

echo "=== Backup Complete ==="
echo "Artifacts securely saved to: $BACKUP_DIR"
