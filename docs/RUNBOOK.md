# GL-MT3000 Hardware Runbook & UART Safety Protocols

> [!CAUTION]
> **CRITICAL VOLTAGE RISK (THE "5V BUG")**
> The GL.iNet GL-MT3000 uses an **internal 4-pin UART header**. It is NOT a USB-C port.
> The logic level of the MT7981 SoC is strictly **3.3V**. If you connect a 5V TTL adapter, you will permanently destroy the SoC. 
> You MUST use a verified 3.3V adapter (e.g., CH341/CP2102) with a confirmed 3.3V jumper setting.

## 1. MANDATORY FIRST STEP: Factory Forensics

> [!CAUTION]
> **BEFORE ANY BUILD OR FLASH OPERATION IS PERMITTED TO EXECUTE:**
> You must dump the `Factory` partition (containing per-unit EEPROM radio calibration data). If this partition is corrupted and you don't have a backup, the router's Wi-Fi is permanently destroyed.

The backup script (`scripts/backup_mt3000.sh`) uses `dd` over SSH to safely extract the Factory MTD partition, performing a dual-pass read with SHA-256 verification to ensure data integrity.
**Do not proceed to flashing if the Factory dump fails.**

## 2. Physical UART Connection
1. Open the router casing.
2. Locate the unpopulated 4-pin through-hole header on the PCB.
3. Solder standard 2.54mm header pins (or use high-quality test clips).
4. Connect the 3.3V TTL Adapter:
   - `GND` -> `GND`
   - `TX`  -> `RX`
   - `RX`  -> `TX`
   - *Leave VCC disconnected!*

## 2. Console Access & U-Boot Interrupt
1. Launch terminal at `115200 8N1` (e.g., `screen /dev/ttyUSB0 115200`).
2. Power on the router.
3. Mash the `0` or `Escape` key immediately to interrupt U-Boot (BL33). *Note: The ATF (BL31) sequence cannot be interrupted.*

## 3. U-Boot Web Recovery (Ethernet — No UART Required)
The GL-MT3000 supports a built-in U-Boot Web Recovery mode accessible via Ethernet:
1. Disconnect the router from power.
2. Connect an Ethernet cable between your computer and the router's **LAN** port.
3. Set your computer's IP to `192.168.1.2/24` (static).
4. Hold the **Reset** button while powering on the router.
5. Continue holding for ~10 seconds until the power LED flashes rapidly.
6. Open a browser to `http://192.168.1.1`.
7. Upload the `release/mbsd-uboot-recovery.itb` file through the web interface.
8. Wait for the flash to complete and the router to reboot.

## 4. Safe Recovery Boot via UART (`bootm`)
Stock U-Boot 2022.07-rc3 on the MT7981 does **not** support `bootefi`. 
Do not attempt to load raw `.efi` or `bsd.rd` formats.
The correct, non-destructive boot path for testing FIT images (`.itb`) is:
```uboot
tftpboot ${loadaddr} mbsd-overlay.itb
bootm ${loadaddr}
```
