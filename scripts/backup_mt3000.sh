#!/bin/bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <ROUTER_IP>"
    echo "Example: $0 192.168.8.1"
    exit 1
fi

ROUTER_IP="$1"
SSH_USER="root"
BACKUP_DIR="backups"

mkdir -p "$BACKUP_DIR"

echo "[*] Connecting to $ROUTER_IP to locate Factory partition..."
# Identify the mtd block for "factory" or "Factory"
MTD_LINE=$(ssh -o StrictHostKeyChecking=no "$SSH_USER@$ROUTER_IP" "cat /proc/mtd | grep -i 'factory'") || {
    echo "[!] FATAL: Could not find 'factory' partition on router."
    exit 1
}

# Example line: mtd3: 00200000 00020000 "Factory"
MTD_DEV=$(echo "$MTD_LINE" | awk -F: '{print $1}')
if [ -z "$MTD_DEV" ]; then
    echo "[!] FATAL: Failed to parse MTD device from: $MTD_LINE"
    exit 1
fi

echo "[+] Found Factory partition at /dev/$MTD_DEV"

PASS1="$BACKUP_DIR/Factory_pass1.bin"
PASS2="$BACKUP_DIR/Factory_pass2.bin"

echo "[*] Starting Pass 1 extraction..."
ssh -o StrictHostKeyChecking=no "$SSH_USER@$ROUTER_IP" "dd if=/dev/${MTD_DEV}ro 2>/dev/null" > "$PASS1"

echo "[*] Starting Pass 2 extraction (verification)..."
ssh -o StrictHostKeyChecking=no "$SSH_USER@$ROUTER_IP" "dd if=/dev/${MTD_DEV}ro 2>/dev/null" > "$PASS2"

HASH1=$(shasum -a 256 "$PASS1" | awk '{print $1}')
HASH2=$(shasum -a 256 "$PASS2" | awk '{print $1}')

if [ "$HASH1" != "$HASH2" ]; then
    echo "[!] FATAL: Pass 1 and Pass 2 hashes do not match! The NAND read is unstable or data is changing."
    echo "Pass 1: $HASH1"
    echo "Pass 2: $HASH2"
    rm -f "$PASS1" "$PASS2"
    exit 1
fi

echo "[+] Dual-pass validation successful! Hashes match."
echo "[+] SHA-256: $HASH1"

mv "$PASS1" "$BACKUP_DIR/Factory.bin"
rm "$PASS2"

echo "$HASH1  Factory.bin" > "$BACKUP_DIR/Factory.sha256"
echo "[+] Backup saved to $BACKUP_DIR/Factory.bin and manifest written to $BACKUP_DIR/Factory.sha256"
