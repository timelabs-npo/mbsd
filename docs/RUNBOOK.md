# GL-MT3000 Hardware Runbook & UART Safety Protocols

> [!CAUTION]
> **CRITICAL VOLTAGE RISK (THE "5V BUG")**
> The GL.iNet GL-MT3000 uses an **internal 4-pin UART header**. It is NOT a USB-C port.
> The logic level of the MT7981 SoC is strictly **3.3V**. If you connect a 5V TTL adapter, you will permanently destroy the SoC. 
> You MUST use a verified 3.3V adapter (e.g., CH341/CP2102) with a confirmed 3.3V jumper setting.

## 1. Physical UART Connection
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

## 3. Safe Recovery Boot (`bootm`)
Stock U-Boot 2022.07-rc3 on the MT7981 does **not** support `bootefi`. 
Do not attempt to load raw `.efi` or `bsd.rd` formats.
The correct, non-destructive boot path for testing FIT images (`.itb`) is:
```uboot
tftpboot ${loadaddr} mbsd-overlay.itb
bootm ${loadaddr}
```
