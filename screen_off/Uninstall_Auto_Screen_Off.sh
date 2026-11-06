#!/bin/bash
# ==============================================================================
# Uninstaller: Auto Screen Off Daemon for R36H (playOS)
# Description: Stops, disables, and removes the Auto Screen Off background service.
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

wait_for_exit() {
    print_msg "\n  >>> กดปุ่มใดก็ได้บนเครื่อง หรือ คีย์บอร์ด เพื่อกลับสู่เมนู <<<"
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

print_msg "=========================================================="
print_msg "     ปิดการทำงานและถอนการติดตั้ง Auto Screen Off         "
print_msg "=========================================================="
print_msg ""

SERVICE_NAME="auto-screen-off.service"
TARGET_BIN="/usr/local/bin/auto_screen_off_daemon.py"
TARGET_SERVICE="/etc/systemd/system/auto-screen-off.service"

# 1. Stop and disable service
print_msg "[1/3] กำลังหยุดและปิดการทำงานของ Service..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
systemctl disable "$SERVICE_NAME" 2>/dev/null || true

if pgrep -f "auto_screen_off_daemon.py" >/dev/null 2>&1; then
    pkill -9 -f "auto_screen_off_daemon.py" 2>/dev/null || true
fi
print_msg " [✓] หยุดการทำงานของ Service เรียบร้อย"

# 2. Remove installed files
print_msg "[2/3] กำลังลบไฟล์ระบบ Service และ Daemon..."
rm -f "$TARGET_SERVICE"
rm -f "$TARGET_BIN"
systemctl daemon-reload 2>/dev/null || true
systemctl reset-failed 2>/dev/null || true
print_msg " [✓] ลบไฟล์ติดตั้งออกจากระบบเรียบร้อย"

# 3. Ensure screen backlight is restored
print_msg "[3/3] ตรวจสอบความสว่างหน้าจอ..."
for b_path in /sys/class/backlight/*; do
    if [ -d "$b_path" ] && [ -w "$b_path/brightness" ]; then
        VAL=$(cat "$b_path/brightness" 2>/dev/null)
        if [ -z "$VAL" ] || [ "$VAL" -eq 0 ] 2>/dev/null; then
            MAX_VAL=$(cat "$b_path/max_brightness" 2>/dev/null)
            echo "${MAX_VAL:-100}" > "$b_path/brightness" 2>/dev/null || true
        fi
        break
    fi
done
if [ -w /sys/class/graphics/fb0/blank ]; then
    echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null || true
fi

print_msg ""
print_msg "=========================================================="
print_msg "   [✓] ปิดการทำงานและถอนการติดตั้ง Auto Screen Off สำเร็จ  "
print_msg "=========================================================="

wait_for_exit
clear > /dev/tty1 2>/dev/null || true

exit 0
