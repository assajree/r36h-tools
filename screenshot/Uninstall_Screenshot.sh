#!/bin/bash
# ==============================================================================
# Uninstaller: Screenshot Suite for R36H / playOS (ARM64)
# Stops and removes:
# 1. Systemd Hotkey Daemon (screenshot-daemon.service)
# 2. CLI shortcut /usr/local/bin/screenshot
# 3. Any lingering menu shortcuts in /roms/tools/
# Note: Saved screenshots in /roms/screenshots/ are safely preserved!
# ==============================================================================

# 1. Root auto-escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SERVICE_NAME="screenshot-daemon.service"
SERVICE_DST="/etc/systemd/system/${SERVICE_NAME}"
BIN_PATH="/usr/local/bin/screenshot"
TOOLS_MENU="/roms/tools/Screenshot.sh"

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true

print_msg "=================================================="
print_msg "       Uninstall Screenshot Suite for R36H        "
print_msg "=================================================="
sleep 1

# Step 1: Stop and disable daemon service
print_msg "\n[1/3] หยุดการทำงานและปิด Service..."
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    print_msg " [✓] หยุดการทำงาน $SERVICE_NAME แล้ว"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    print_msg " [✓] ปิดการเริ่มทำงานอัตโนมัติตอนบูตแล้ว"
fi

if [ -f "$SERVICE_DST" ]; then
    rm -f "$SERVICE_DST"
    systemctl daemon-reload
    print_msg " [✓] ลบไฟล์ Service ออกจากระบบเรียบร้อย"
fi

# Step 2: Remove CLI executable
print_msg "\n[2/3] ลบคำสั่ง CLI..."
if [ -f "$BIN_PATH" ]; then
    rm -f "$BIN_PATH"
    print_msg " [✓] ลบ ${BIN_PATH} สำเร็จ"
else
    print_msg " [✓] ไม่พบ ${BIN_PATH} (ข้าม)"
fi

# Step 3: Remove any legacy menu shortcut
print_msg "\n[3/3] ลบเมนูทางลัดใน Tools (ถ้ามี)..."
if [ -f "$TOOLS_MENU" ]; then
    rm -f "$TOOLS_MENU"
    print_msg " [✓] ลบ ${TOOLS_MENU} สำเร็จ"
else
    print_msg " [✓] ไม่พบทางลัดใน /roms/tools/ (ข้าม)"
fi

print_msg "\n=================================================="
print_msg "          ถอนการติดตั้งเสร็จสมบูรณ์!              "
print_msg "=================================================="
print_msg "หมายเหตุ: ไฟล์ภาพที่เคยบันทึกไว้ใน /roms/screenshots/"
print_msg "         ยังคงถูกเก็บรักษาไว้อย่างปลอดภัย ไม่ถูกลบ"
print_msg "=================================================="

sleep 3
