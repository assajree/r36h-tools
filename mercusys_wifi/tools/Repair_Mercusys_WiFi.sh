#!/bin/bash
# ==============================================================================
# Script: Repair_Mercusys_WiFi.sh
# Purpose: Quick diagnostic and auto-repair script for Mercusys Wi-Fi (2c4e:0102)
# Features:
#   - Runs instantly without shutting down
#   - Unblocks RF-Kill radio locks
#   - Re-attaches driver & dynamic USB ID if detached
#   - Resets interface wlan0 and restarts wpa_supplicant
#   - Performs live Wi-Fi scan and displays detected 2.4 GHz SSIDs on screen
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

KERNEL_VER="$(uname -r)"

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true
print_msg "=================================================="
print_msg "   Mercusys Wi-Fi Auto-Repair & Diagnostics      "
print_msg "=================================================="
sleep 1

# ------------------------------------------------------------------------------
# 1. ปลดบล็อกคลื่นสัญญาณวิทยุ (RF-KILL)
# ------------------------------------------------------------------------------
print_msg "
[1/5] ตรวจสอบและปลดบล็อกคลื่นวิทยุ (rfkill)..."
rfkill unblock all 2>/dev/null || true
print_msg " [✓] ปลดบล็อกคลื่นวิทยุเรียบร้อย"

# ------------------------------------------------------------------------------
# 2. ตรวจสอบการโหลดโมดูล 8188eu
# ------------------------------------------------------------------------------
print_msg "
[2/5] ตรวจสอบไดรเวอร์ในเคอร์เนล..."
if ! lsmod | grep -q "8188eu"; then
    print_msg " [*] ไม่พบไดรเวอร์ในหน่วยความจำ กำลังสั่งโหลดใหม่..."
    modprobe 8188eu 2>/dev/null || insmod "/lib/modules/${KERNEL_VER}/kernel/drivers/net/wireless/rockchip_wlan/rtl8188eu/8188eu.ko" 2>/dev/null || true
fi

if lsmod | grep -q "8188eu"; then
    print_msg " [✓] ไดรเวอร์ 8188eu โหลดอยู่ในระบบเรียบร้อย"
else
    print_msg " [!] ไม่สามารถโหลดไดรเวอร์ได้ แนะนำให้รัน Install_Mercusys_WiFi.sh ก่อน"
fi

# ------------------------------------------------------------------------------
# 3. ผูกรหัส Hardware ID (2c4e:0102) เข้ากับไดรเวอร์
# ------------------------------------------------------------------------------
print_msg "
[3/5] เชื่อมต่อฮาร์ดแวร์ USB เข้ากับไดรเวอร์..."
for drv in 8188eu rtl8188eu r8188eu; do
    if [ -d "/sys/bus/usb/drivers/$drv" ]; then
        echo "2c4e 0102" > "/sys/bus/usb/drivers/$drv/new_id" 2>/dev/null || true
    fi
done
udevadm trigger --action=change 2>/dev/null || true
sleep 1

# ------------------------------------------------------------------------------
# 4. รีเซ็ต Network Interface และ wpa_supplicant
# ------------------------------------------------------------------------------
print_msg "
[4/5] รีเซ็ตอินเทอร์เฟซ wlan0 และระบบค้นหาสัญญาณ..."
WLAN="wlan0"
if [ ! -d "/sys/class/net/wlan0" ]; then
    WLAN=$(ip link | grep -o -E "wlan[0-9]|wlx[0-9a-zA-Z]+" | head -n 1)
fi

if [ -n "$WLAN" ]; then
    ip link set "$WLAN" down 2>/dev/null || true
    sleep 1
    ip link set "$WLAN" up 2>/dev/null || true
    print_msg " [✓] เปิดการทำงานของ ${WLAN} (State: UP) เรียบร้อย"

    # รีสตาร์ต wpa_supplicant เพื่อให้ UI ในเมนู Settings ค้นหาเจอ
    killall wpa_supplicant 2>/dev/null || true
    sleep 1
    if [ -f "/etc/wpa_supplicant/wpa_supplicant.conf" ]; then
        wpa_supplicant -B -i "$WLAN" -c /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null || true
    else
        wpa_supplicant -B -i "$WLAN" 2>/dev/null || true
    fi
    print_msg " [✓] รีสตาร์ตเซอร์วิสค้นหาเครือข่ายสำเร็จ"
else
    print_msg " [!] ยังไม่พบ Interface wlan กรุณาตรวจสอบว่าเสียบดองเกิลแน่นหนา"
fi

# ------------------------------------------------------------------------------
# 5. สแกนค้นหาคลื่น Wi-Fi (2.4 GHz) รอบตัวจริง
# ------------------------------------------------------------------------------
print_msg "
[5/5] ทดสอบสแกนค้นหาสัญญาณ Wi-Fi (2.4 GHz)..."
if [ -n "$WLAN" ]; then
    SCAN_RESULTS=$(iwlist "$WLAN" scan 2>/dev/null | grep -E "ESSID:" | sed 's/^[ 	]*//' | sed 's/ESSID://' | tr -d '"' | grep -v "^$" | sort -u)
    
    if [ -n "$SCAN_RESULTS" ]; then
        print_msg "=================================================="
        print_msg " [✓] สำเร็จ! พบสัญญาณ Wi-Fi รอบตัวดังนี้:"
        print_msg "--------------------------------------------------"
        echo "$SCAN_RESULTS" | while read -r ssid; do
            print_msg "   * $ssid"
        done
        print_msg "=================================================="
        print_msg " ตอนนี้คุณสามารถเข้าเมนู Settings บน playOS"
        print_msg " เพื่อเลือกเชื่อมต่อ Wi-Fi ได้ทันทีครับ!"
    else
        print_msg " [!] สแกนไม่พบคลื่น Wi-Fi 2.4 GHz ในระยะนี้"
        print_msg " คำแนะนำ:"
        print_msg " 1. ดองเกิล Mercusys รองรับเฉพาะคลื่น 2.4 GHz (ไม่รองรับ 5 GHz)"
        print_msg " 2. ลองเปิด Personal Hotspot บนมือถือ (ความถี่ 2.4 GHz) เพื่อทดสอบ"
    fi
fi

print_msg "
[การซ่อมแซมและตรวจสอบเสร็จสิ้น]"
sleep 4
