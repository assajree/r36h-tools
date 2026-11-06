#!/bin/bash
# ==============================================================================
# Installer: Mercusys USB Wi-Fi (2c4e:0102) Standalone Installer
# Target: R36H / playOS (Kernel: 4.4.189)
# Features:
#   - Standalone execution from folder
#   - Installs firmware & 8188eu kernel module
#   - Configures persistent udev rules (auto-bind on boot and hotplug)
#   - Prompts user to power off (Cold Boot) to reset USB bus completely
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FW_SRC="${SCRIPT_DIR}/rtl8188eufw.bin"
KO_SRC="${SCRIPT_DIR}/8188eu.ko"
KERNEL_VER="$(uname -r)"
DEST_MOD_DIR="/lib/modules/${KERNEL_VER}/kernel/drivers/net/wireless/rockchip_wlan/rtl8188eu"
DEST_FW_DIR="/lib/firmware/rtlwifi"

# Helper to print to both active shell and /dev/tty1 (for EmulationStation UI)
print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

print_header() {
    print_msg "=================================================="
    print_msg "  Mercusys Wi-Fi Dongle Standalone Installer      "
    print_msg "  Hardware: 2c4e:0102 | Kernel: ${KERNEL_VER}     "
    print_msg "=================================================="
}

print_header
sleep 1

# ------------------------------------------------------------------------------
# 1. ตรวจสอบความสมบูรณ์ของไฟล์ต้นทาง
# ------------------------------------------------------------------------------
print_msg "\n[1/5] ตรวจสอบไฟล์ติดตั้งภายในโฟลเดอร์..."
if [ ! -f "$FW_SRC" ]; then
    print_msg " [X] ไม่พบไฟล์ rtl8188eufw.bin ที่ ${SCRIPT_DIR}"
    exit 1
fi
if [ ! -f "$KO_SRC" ]; then
    print_msg " [X] ไม่พบไฟล์ 8188eu.ko ที่ ${SCRIPT_DIR}"
    exit 1
fi
print_msg " [✓] พบไฟล์ rtl8188eufw.bin และ 8188eu.ko ครบถ้วน"

# ------------------------------------------------------------------------------
# 2. ปลดบล็อก RFKILL
# ------------------------------------------------------------------------------
print_msg "\n[2/5] ปลดบล็อกคลื่นวิทยุ (rfkill unblock all)..."
rfkill unblock all 2>/dev/null || true

# ------------------------------------------------------------------------------
# 3. ติดตั้ง Firmware ไปยัง /lib/firmware/
# ------------------------------------------------------------------------------
print_msg "\n[3/5] ติดตั้งไฟล์เฟิร์มแวร์ลงระบบ..."
mkdir -p "$DEST_FW_DIR"
cp -v "$FW_SRC" "${DEST_FW_DIR}/rtl8188eufw.bin"
cp -v "$FW_SRC" "/lib/firmware/rtl8188eufw.bin"
chmod 644 "${DEST_FW_DIR}/rtl8188eufw.bin" "/lib/firmware/rtl8188eufw.bin" 2>/dev/null || true
print_msg " [✓] ติดตั้งเฟิร์มแวร์ลง /lib/firmware/rtlwifi/ เรียบร้อย"

# ------------------------------------------------------------------------------
# 4. ติดตั้ง Kernel Module และอัปเดตสารบบ (depmod)
# ------------------------------------------------------------------------------
print_msg "\n[4/5] ติดตั้งโมดูลเคอร์เนล 8188eu.ko..."
mkdir -p "$DEST_MOD_DIR"
cp -v "$KO_SRC" "${DEST_MOD_DIR}/8188eu.ko"
chmod 644 "${DEST_MOD_DIR}/8188eu.ko"
depmod -a
print_msg " [✓] อัปเดต depmod สำเร็จ"

# ------------------------------------------------------------------------------
# 5. สร้างระบบผูกไดรเวอร์อัตโนมัติแบบถาวร (Persistent Auto-Bind)
# ------------------------------------------------------------------------------
print_msg "\n[5/5] ตั้งค่าระบบผูกไดรเวอร์อัตโนมัติ (Persistent)..."

# 5.1 สคริปต์ตัวช่วยผูกไดรเวอร์
cat << 'EOF' > /usr/local/bin/bind_mercusys_wifi.sh
#!/bin/sh
rfkill unblock all 2>/dev/null || true
/sbin/modprobe 8188eu 2>/dev/null || /sbin/insmod /lib/modules/$(uname -r)/kernel/drivers/net/wireless/rockchip_wlan/rtl8188eu/8188eu.ko 2>/dev/null
for drv in 8188eu rtl8188eu r8188eu; do
    if [ -d "/sys/bus/usb/drivers/$drv" ]; then
        echo "2c4e 0102" > "/sys/bus/usb/drivers/$drv/new_id" 2>/dev/null || true
    fi
done
sleep 1
if [ -d /sys/class/net/wlan0 ]; then
    ip link set wlan0 up 2>/dev/null || true
fi
EOF
chmod 755 /usr/local/bin/bind_mercusys_wifi.sh

# 5.2 Udev rule (ทำงานทันทีเมื่อเสียบดองเกิล หรือเมื่อระบบตรวจพบฮาร์ดแวร์ตอนบูต)
cat << 'EOF' > /etc/udev/rules.d/99-mercusys-wifi.rules
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2c4e", ATTR{idProduct}=="0102", RUN+="/usr/local/bin/bind_mercusys_wifi.sh"
EOF

# 5.3 เพิ่มชื่อโมดูลใน /etc/modules เพื่อให้โหลดตอนเปิดเครื่องอัตโนมัติ
if [ -f /etc/modules ]; then
    if ! grep -qx "8188eu" /etc/modules 2>/dev/null; then
        echo "8188eu" >> /etc/modules
    fi
fi

# 5.4 เสริมใน /etc/rc.local (ถ้ามี)
if [ -f /etc/rc.local ]; then
    if ! grep -q "bind_mercusys_wifi.sh" /etc/rc.local; then
        sed -i -e '$i \/usr\/local\/bin\/bind_mercusys_wifi.sh\n' /etc/rc.local 2>/dev/null || true
    fi
fi

udevadm control --reload-rules 2>/dev/null || true
/usr/local/bin/bind_mercusys_wifi.sh
udevadm trigger --action=change 2>/dev/null || true
print_msg " [✓] บันทึก udev rule และ startup helper เรียบร้อย"

# ------------------------------------------------------------------------------
# 6. รายงานผลและเตรียมดับเครื่อง (Cold Boot) เพื่อรีเซ็ตพอร์ต USB
# ------------------------------------------------------------------------------
print_msg "\n=================================================="
print_msg " [✓] ติดตั้งไดรเวอร์และระบบ Auto-Bind เสร็จสมบูรณ์!"
print_msg "=================================================="
print_msg " เพื่อตัดไฟพอร์ต USB และรีเซ็ตชิป Wi-Fi Dongle 100%"
print_msg " ระบบจำเป็นต้องปิดเครื่องสนิท (Cold Boot)"
print_msg " หลังจากเครื่องดับแล้ว ให้กดปุ่ม Power เพื่อเปิดเครื่องใหม่"
print_msg "--------------------------------------------------"
print_msg " >> กดปุ่มใดๆ เพื่อปิดเครื่องทันที (หรือรอ 10 วินาที) <<"
print_msg "=================================================="

# รองรับการกดปุ่มทั้งใน Terminal และหน้าจอ tty1 หรือหน่วงเวลา 10 วินาที
if [ -t 0 ]; then
    read -t 10 -n 1 -r 2>/dev/null || true
elif [ -e /dev/tty1 ]; then
    read -t 10 -n 1 -r </dev/tty1 2>/dev/null || sleep 10
else
    sleep 10
fi

print_msg "\nกำลังปิดเครื่อง (System will power off now...)"
sleep 2
shutdown now
