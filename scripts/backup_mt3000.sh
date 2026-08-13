#!/bin/bash
# Backup script for GL.iNet GL-MT3000 ("Beryl AX") SPI-NAND
# Uses SSH to execute nanddump to safely extract critical partitions with OOB metadata.

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <router_ip> [--with-ubi]"
    exit 1
fi

ROUTER_IP="$1"
WITH_UBI=0
if [ "$2" == "--with-ubi" ]; then
    WITH_UBI=1
fi

BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "=== MBSD Full Firmware Forensics Backup Pipeline ==="

# 1. Fetch Partition Table
ssh -o StrictHostKeyChecking=no root@$ROUTER_IP "cat /proc/mtd" > "$BACKUP_DIR/proc_mtd.txt" 2>/dev/null || true

if [ ! -s "$BACKUP_DIR/proc_mtd.txt" ]; then
    echo "⚠️ WARNING: GL-MT3000 requires 3.3V TTL logic. 5V will DESTROY the MT7981 SoC. ⚠️"
    echo "[*] Ensure you are connected to the internal 4-pin header via 3.3V UART (115200 8N1)"
    exit 1
fi

echo "[*] Connected. Found partition table."

# Function to safely dump and verify a partition
dump_and_verify() {
    PART_NAME=$1
    MTD_DEV=$(grep -i "$PART_NAME" "$BACKUP_DIR/proc_mtd.txt" | awk -F: '{print $1}')
    
    if [ -z "$MTD_DEV" ]; then
        echo "[!] CRITICAL: Could not find '$PART_NAME' partition in /proc/mtd."
        exit 1
    fi

    echo "[*] Dumping $PART_NAME partition (Pass 1) from /dev/$MTD_DEV..."
    ssh root@$ROUTER_IP "nanddump -f /tmp/${PART_NAME}_1.bin --bb=skipbad --oob /dev/$MTD_DEV"
    scp root@$ROUTER_IP:/tmp/${PART_NAME}_1.bin "$BACKUP_DIR/${PART_NAME}_1.bin"
    shasum -a 256 "$BACKUP_DIR/${PART_NAME}_1.bin" | awk '{print $1}' > "$BACKUP_DIR/${PART_NAME}_1.sha256"

    echo "[*] Dumping $PART_NAME partition (Pass 2) from /dev/$MTD_DEV..."
    ssh root@$ROUTER_IP "nanddump -f /tmp/${PART_NAME}_2.bin --bb=skipbad --oob /dev/$MTD_DEV"
    scp root@$ROUTER_IP:/tmp/${PART_NAME}_2.bin "$BACKUP_DIR/${PART_NAME}_2.bin"
    shasum -a 256 "$BACKUP_DIR/${PART_NAME}_2.bin" | awk '{print $1}' > "$BACKUP_DIR/${PART_NAME}_2.sha256"

    echo "[*] Verifying NAND stability for $PART_NAME..."
    if cmp -s "$BACKUP_DIR/${PART_NAME}_1.sha256" "$BACKUP_DIR/${PART_NAME}_2.sha256"; then
        echo "[+] VERIFIED: $PART_NAME checksum is stable."
        mv "$BACKUP_DIR/${PART_NAME}_1.bin" "$BACKUP_DIR/${PART_NAME}.bin"
        mv "$BACKUP_DIR/${PART_NAME}_1.sha256" "$BACKUP_DIR/${PART_NAME}.sha256"
        rm "$BACKUP_DIR/${PART_NAME}_2.bin" "$BACKUP_DIR/${PART_NAME}_2.sha256"
        ssh root@$ROUTER_IP "rm /tmp/${PART_NAME}_1.bin /tmp/${PART_NAME}_2.bin"
    else
        echo "[!] FATAL: $PART_NAME read instability detected! Checksums diverge."
        echo "[!] This indicates a failing NAND cell or physical read error."
        echo "[!] DO NOT FLASH THIS DEVICE."
        exit 1
    fi
}

# 2. Extract Required Partitions Safely
dump_and_verify "bl2"
dump_and_verify "fip"
dump_and_verify "u-boot-env"
dump_and_verify "factory"

if [ "$WITH_UBI" -eq 1 ]; then
    echo "[*] --with-ubi flag passed. Dumping entire userland (this will take a while)..."
    dump_and_verify "ubi"
fi

echo "=== Backup Complete ==="
echo "Artifacts securely verified and saved to: $BACKUP_DIR"
