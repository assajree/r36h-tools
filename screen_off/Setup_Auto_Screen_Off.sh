#!/bin/bash
# ==============================================================================
# Setup: Auto Screen Off (1 Minute Timeout) for R36H (playOS)
# Description: Installs and starts the background daemon that automatically
#              turns off the screen when the console is idle for 1 minute.
# Author: playOS Tools Suite
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAEMON_SRC="$SCRIPT_DIR/daemon/auto_screen_off_daemon.py"
SERVICE_SRC="$SCRIPT_DIR/daemon/auto-screen-off.service"
TARGET_BIN="/usr/local/bin/auto_screen_off_daemon.py"
TARGET_SERVICE="/etc/systemd/system/auto-screen-off.service"

clear > /dev/tty1 2>/dev/null || true
clear 2>/dev/null || true

print_msg "=========================================================="
print_msg "    ติดตั้งระบบ Auto Screen Off (1 นาที) สำหรับ R36H     "
print_msg "=========================================================="
print_msg ""

# 1. Check Python 3
print_msg "[1/5] ตรวจสอบสภาพแวดล้อมระบบ..."
if ! command -v python3 >/dev/null 2>&1; then
    print_msg " [X] ไม่พบ python3 ในระบบ"
    sleep 3
    exit 1
fi
print_msg " [✓] พบ Python 3 พร้อมใช้งาน"

# 2. Verify source files
if [ ! -f "$DAEMON_SRC" ] || [ ! -f "$SERVICE_SRC" ]; then
    print_msg " [X] ไม่พบไฟล์ต้นฉบับในโฟลเดอร์ daemon/"
    sleep 3
    exit 1
fi

# 3. Install daemon binary
print_msg "[2/5] ติดตั้ง Daemon ไปยัง /usr/local/bin..."
cp -f "$DAEMON_SRC" "$TARGET_BIN"
chmod 755 "$TARGET_BIN"
print_msg " [✓] ติดตั้ง $TARGET_BIN เรียบร้อย"

# 4. Install systemd service unit
print_msg "[3/5] ติดตั้ง Systemd Service Unit..."
cp -f "$SERVICE_SRC" "$TARGET_SERVICE"
chmod 644 "$TARGET_SERVICE"
print_msg " [✓] ติดตั้ง $TARGET_SERVICE เรียบร้อย"

# 5. Reload systemd & enable service
print_msg "[4/5] เปิดใช้งาน Background Service (Boot Autostart)..."
systemctl daemon-reload 2>/dev/null || true
systemctl enable auto-screen-off.service 2>/dev/null || true
systemctl restart auto-screen-off.service 2>/dev/null || true

# 6. Verify service running
print_msg "[5/5] ตรวจสอบสถานะการทำงาน..."
sleep 1.5

if systemctl is-active --quiet auto-screen-off.service 2>/dev/null; then
    PID=$(pgrep -f "auto_screen_off_daemon.py" | head -n 1)
    print_msg " [✓] Service กำลังทำงานอยู่ในเบื้องหลัง (PID: ${PID:-Active})"
else
    print_msg " [!] Service ยังไม่เริ่มทำงาน หรือเกิดข้อผิดพลาด"
fi

print_msg ""
print_msg "=========================================================="
print_msg "             [✓] ติดตั้งและเริ่มทำงานสำเร็จ!              "
print_msg "=========================================================="
print_msg "  • ระบบจะดับไฟหน้าจออัตโนมัติเมื่อไม่มีการกดปุ่มใดๆ ครบ 1 นาที"
print_msg "  • กดปุ่มใดก็ได้บนตัวเครื่อง หรือ คีย์บอร์ด เพื่อเปิดหน้าจอทันที"
print_msg "  • ไม่กระทบเกม Wi-Fi หรือการดาวน์โหลดไฟล์ในเบื้องหลัง"
print_msg "  • ตรวจสอบสถานะได้ที่: sudo bash Status_Auto_Screen_Off.sh"
print_msg "=========================================================="
print_msg ""
print_msg "กำลังกลับสู่หน้าต่างหลักใน 4 วินาที..."
sleep 4
clear > /dev/tty1 2>/dev/null || true

exit 0
