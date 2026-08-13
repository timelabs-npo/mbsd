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
