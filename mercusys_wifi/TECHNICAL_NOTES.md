# Mercusys Wi-Fi Driver - Technical Reference & Troubleshooting

## Hardware & Environment
* **Target Device:** R36H Handheld Gaming Console (Rockchip RK3326 / ARM64)
* **Operating System:** playOS (Linux Kernel `4.4.189`)
* **Target Peripheral:** Mercusys USB Wi-Fi Dongle (MW150US)
* **USB Vendor & Product ID:** `2c4e:0102 Mercusys INC 802.11n NIC`
* **Physical Wi-Fi Chipset:** Realtek **RTL8188EU** / **RTL8188EUS**

---

## Critical Findings & Technical Context

### 1. Chipset Differentiation: RTL8188EU vs. RTL8188FU
* The playOS kernel contains a built-in driver named `rtl8188fu` (`usbcore: registered new interface driver rtl8188fu`, compiled with `=y`). Because it is built-in, attempting `modprobe rtl8188fu` returns an error.
* The Mercusys dongle (`2c4e:0102`) is **NOT** RTL8188FU. It is an **RTL8188EU** device.
* **Do not** attempt to force bind `2c4e:0102` to `rtl8188fu`. The correct driver module is **`8188eu.ko`**.

### 2. Root Cause of HAL Ops Error & Verified Firmware
During initial debugging, loading `8188eu.ko` caused this kernel error in `dmesg`:
```text
RTW: #### rtw_hal_ops_check - Error : Please hook hal_func.set_hw_reg_handler ####
RTW: #### rtw_hal_ops_check - Error : Please hook hal_func.GetHwRegHandler ####
```
* **True Cause:** The driver requires matching firmware microcode (`rtl8188eufw.bin`) located at `/lib/firmware/rtlwifi/rtl8188eufw.bin`. When missing or outdated, HAL initialization fails halfway, resulting in null pointer function pointers.
* **Verified Working Firmware:** `rtl8188eufw.bin` (Size: `15,262 bytes`, MD5: `b66178b87ed8f917997b9cf38fc0cfd3`).
* **Verified Working Driver Module:** `8188eu.ko` (Size: `1,167,320 bytes`, MD5: `959e7febc4be3bf6909fa877de7809b1`).
* **Note on Native Alias:** This driver binary contains `alias: usb:v2C4Ep0102d*` compiled natively inside. Once registered via `depmod -a`, the kernel automatically associates `2c4e:0102` to `8188eu`.

### 3. Hardware Stall & Cold Boot Requirement
* Realtek USB Wi-Fi chips contain internal microcontrollers that lock up in a "Stall State" if initialization fails or an improper driver is bound.
* When stuck, a software reload or soft reboot may not reset the USB controller registers.
* A **full power cycle (cold boot / `shutdown now`)** cuts power to the OTG port, resetting the dongle to a clean state.
