#!/bin/bash
# MBSD Native WSL2 Build Script
# Executes directly inside Ubuntu WSL, bypassing the need for Docker.

echo "--- MBSD WSL2 Native Build Environment ---"
export DEBIAN_FRONTEND=noninteractive

echo "Installing OpenBSD cross-compile dependencies in WSL..."
sudo apt-get update
sudo apt-get install -y qemu-system-aarch64 python3 python3-pexpect python3-pip genisoimage mtools dosfstools curl

echo "Navigating to repository root..."
# In WSL, C:\ is mapped to /mnt/c/
cd /mnt/c/mbsd/docker || exit 1

echo "Triggering the Kernel Forge (build_kernel.py)..."
sudo python3 build_kernel.py

echo "Build complete. Extracting payload..."
cd /mnt/c/mbsd/out
ls -la bsd
