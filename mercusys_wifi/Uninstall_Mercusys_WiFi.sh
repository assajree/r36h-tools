#!/bin/bash
# ==============================================================================
# Script: Uninstall_Mercusys_WiFi.sh
# Target: R36H / playOS (Kernel: 4.4.189)
# Purpose: Uninstalls Mercusys Wi-Fi driver, auto-bind rules, and cleans system config.
# Note: Preserves passive firmware files in /lib/firmware/ as configured.
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

KERNEL_VER="$(uname -r)"
DEST_MOD_DIR="/lib/modules/${KERNEL_VER}/kernel/drivers/net/wireless/rockchip_wlan/rtl8188eu"

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

wait_for_exit() {
    print_msg "\n  >>> กดปุ่มใดก็ได้บนเครื่อง หรือ คีย์บอร์ด เพื่อปิดหน้านี้ <<<"
    (
        if [ -t 0 ]; then
            read -s -n 1 -r 2>/dev/null
        elif [ -c /dev/tty1 ]; then
            read -s -n 1 -r < /dev/tty1 2>/dev/null
        else
            read -s -n 1 -r 2>/dev/null
        fi
    ) &
    INPUT_PIDS="$!"
    for ev in /dev/input/event*; do
        if [ -r "$ev" ]; then
            ( dd if="$ev" of=/dev/null bs=16 count=1 2>/dev/null ) &
            INPUT_PIDS="$INPUT_PIDS $!"
        fi
    done
    wait -n $INPUT_PIDS 2>/dev/null || sleep 2
    kill -9 $INPUT_PIDS 2>/dev/null || true
}

clear > /dev/tty1 2>/dev/null || true
clear 2>/dev/null || true

print_msg "=================================================="
print_msg "  Mercusys Wi-Fi Driver Uninstaller for R36H      "
print_msg "  Kernel: ${KERNEL_VER}                            "
print_msg "=================================================="
sleep 1

# 1. ปิดอินเทอร์เฟซและถอดโมดูลออกจากเคอร์เนล
print_msg "\n[1/4] ปิดการทำงาน wlan0 และถอดไดรเวอร์ออกจากหน่วยความจำ..."
ip link set wlan0 down 2>/dev/null || true
rmmod 8188eu 2>/dev/null || modprobe -r 8188eu 2>/dev/null || true
print_msg " [✓] ถอดโมดูล 8188eu สำเร็จ"

# 2. ลบ Udev rules และ helper script
print_msg "\n[2/4] ลบการตั้งค่า Auto-Bind (udev rules & helper)..."
rm -f /etc/udev/rules.d/99-mercusys-wifi.rules
rm -f /usr/local/bin/bind_mercusys_wifi.sh
udevadm control --reload-rules 2>/dev/null || true
print_msg " [✓] ลบ udev rule และสคริปต์ผูกไดรเวอร์เรียบร้อย"

# 3. ล้างการตั้งค่าใน /etc/modules และ /etc/rc.local
print_msg "\n[3/4] ล้างรายการบูตอัตโนมัติใน /etc/modules และ /etc/rc.local..."
if [ -f /etc/modules ]; then
    sed -i '/^8188eu$/d' /etc/modules 2>/dev/null || true
fi
if [ -f /etc/rc.local ]; then
    sed -i '/bind_mercusys_wifi\.sh/d' /etc/rc.local 2>/dev/null || true
fi
print_msg " [✓] คืนค่าไฟล์ระบบเดิมเรียบร้อย"

# 4. ลบไฟล์โมดูลเคอร์เนลและอัปเดตสารบบ (depmod)
print_msg "\n[4/4] ลบไฟล์โมดูลเคอร์เนล 8188eu.ko..."
rm -f "${DEST_MOD_DIR}/8188eu.ko"
rmdir "$DEST_MOD_DIR" 2>/dev/null || true
depmod -a
print_msg " [✓] ลบไฟล์ไดรเวอร์และอัปเดต depmod เรียบร้อย"

print_msg "\n=================================================="
print_msg " [✓] ถอนการติดตั้งไดรเวอร์ Mercusys เรียบร้อยแล้ว!"
print_msg " หมายเหตุ: ไฟล์ firmware ใน /lib/firmware/ ถูกคงไว้"
print_msg "=================================================="

wait_for_exit
exit 0
