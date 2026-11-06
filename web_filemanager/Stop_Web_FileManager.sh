#!/bin/bash
# ==============================================================================
# Tool: Stop Web File Manager (Filebrowser)
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
print_msg "      Stopping Web File Manager (Filebrowser)     "
print_msg "=================================================="

if pgrep -f "filebrowser" > /dev/null 2>&1; then
    pkill -f "filebrowser" 2>/dev/null || true
    sleep 1
    print_msg "\n [✓] ปิดการทำงาน Web File Manager สำเร็จ"
    print_msg " คืนแรม (RAM) ให้ระบบสำหรับเล่นเกมเรียบร้อย"
else
    print_msg "\n [i] Web File Manager ไม่ได้เปิดทำงานอยู่"
fi

print_msg "=================================================="
print_msg "\nกำลังกลับสู่หน้ารายการเมนูใน 3 วินาที..."
sleep 3
