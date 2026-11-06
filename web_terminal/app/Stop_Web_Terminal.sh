#!/bin/bash
# ==============================================================================
# Tool: Stop Web Terminal (ttyd ARM64)
# Target: R36H / playOS (ARM64)
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true

print_msg "=================================================="
print_msg "         Stopping Web Terminal (ttyd)             "
print_msg "=================================================="

# ปิด systemd service (ถ้ามี)
systemctl stop ttyd.service 2>/dev/null || true

# ปิด process ttyd ทั้งหมด
if pgrep -x "ttyd" > /dev/null 2>&1 || pgrep -f "ttyd" > /dev/null 2>&1; then
    pkill -9 -x "ttyd" 2>/dev/null || true
    pkill -9 -f "ttyd" 2>/dev/null || true
    sleep 1
    print_msg "\n [✓] ปิดการทำงาน Web Terminal สำเร็จ"
    print_msg " คืนแรม (RAM) ให้ระบบสำหรับเล่นเกมเรียบร้อย"
else
    print_msg "\n [i] Web Terminal ไม่ได้เปิดทำงานอยู่"
fi

print_msg "=================================================="
print_msg "\nกำลังกลับสู่หน้ารายการเมนูใน 3 วินาที..."
sleep 3
