#!/bin/bash
# GL-MT3000 OpenWrt Flash Backup & U-Boot Audit Script
# Run this on your host machine to safely dump the router's flash partitions over SSH.

ROUTER_IP="${1:-192.168.8.1}"
BACKUP_DIR="mt3000_flash_backup_$(date +%Y%m%d_%H%M%S)"

echo "=== MBSD: GL-MT3000 Flash Backup & U-Boot Audit ==="
echo "Target: root@$ROUTER_IP"
echo "Backup Directory: $BACKUP_DIR"

mkdir -p "$BACKUP_DIR"

# 1. Fetch partition layout
echo "[*] Fetching /proc/mtd layout..."
ssh -o StrictHostKeyChecking=no root@$ROUTER_IP "cat /proc/mtd" > "$BACKUP_DIR/proc_mtd.txt"

if [ ! -s "$BACKUP_DIR/proc_mtd.txt" ]; then
    echo "[!] Failed to connect or read /proc/mtd. Ensure the router is booted into OpenWrt and reachable."
    exit 1
fi

cat "$BACKUP_DIR/proc_mtd.txt"

# 2. Backup critical partitions
# Typical MT7981 OpenWrt layout:
# mtd0: bl2, mtd1: u-boot-env, mtd2: Factory, mtd3: fip, mtd4: ubi
PARTITIONS=("bl2" "u-boot-env" "Factory" "fip" "ubi")

for part_name in "${PARTITIONS[@]}"; do
    # Find the mtdX device number for the partition
    MTD_DEV=$(grep -i "\"$part_name\"" "$BACKUP_DIR/proc_mtd.txt" | cut -d: -f1)
    
    if [ -n "$MTD_DEV" ]; then
        echo "[*] Backing up $part_name ($MTD_DEV)..."
        ssh -o StrictHostKeyChecking=no root@$ROUTER_IP "cat /dev/${MTD_DEV}" > "$BACKUP_DIR/${part_name}.bin"
    else
        echo "[-] Partition '$part_name' not found in /proc/mtd. Skipping."
    fi
done

# 3. Check U-Boot for EFI/FIT support
if [ -f "$BACKUP_DIR/fip.bin" ]; then
    echo "[*] Scanning FIP (U-Boot) for 'bootefi' and 'FIT' strings..."
    strings "$BACKUP_DIR/fip.bin" | grep -iE 'bootefi|fit' > "$BACKUP_DIR/uboot_capabilities.txt"
    
    if grep -qi 'bootefi' "$BACKUP_DIR/uboot_capabilities.txt"; then
        echo "[+] SUCCESS: 'bootefi' string found in U-Boot! EFI RAM boot should be possible."
    else
        echo "[!] WARNING: 'bootefi' string NOT found. U-Boot might not support EFI booting."
    fi
else
    echo "[!] FIP backup failed, cannot check U-Boot capabilities."
fi

echo "[*] Backup complete! Artifacts saved to $BACKUP_DIR"
