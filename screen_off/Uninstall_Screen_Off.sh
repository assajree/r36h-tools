#!/bin/bash
# ==============================================================================
# Uninstaller: Screen Off Utility Suite for R36H (playOS)
# Description: Removes Screen_Off launcher from /roms/tools/ and /usr/local/bin/,
#              and cleans up Auto Screen Off background service if active.
# Author: playOS Tools Suite
# Archetype: Archetype 3 (One-Shot Interactive)
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
print_msg "    ถอนการติดตั้ง Screen Off Suite สำหรับ R36H (playOS)    "
print_msg "=========================================================="
print_msg ""

# 1. Stop and remove Auto Screen Off service if installed
print_msg "[1/3] ตรวจสอบและถอนการติดตั้ง Auto Screen Off Service..."
if [ -f "/etc/systemd/system/auto-screen-off.service" ] || systemctl is-active --quiet auto-screen-off.service 2>/dev/null; then
    systemctl stop auto-screen-off.service 2>/dev/null || true
    systemctl disable auto-screen-off.service 2>/dev/null || true
    pkill -9 -f "auto_screen_off_daemon.py" 2>/dev/null || true
    rm -f "/etc/systemd/system/auto-screen-off.service"
    rm -f "/usr/local/bin/auto_screen_off_daemon.py"
    systemctl daemon-reload 2>/dev/null || true
    print_msg " [✓] ถอนการติดตั้ง Auto Screen Off Service เรียบร้อย"
else
    print_msg " [-] ไม่พบ Auto Screen Off Service ในระบบ (ข้าม)"
fi

# 2. Remove launcher and cover art from /roms/tools/
print_msg "[2/3] กำลังลบเมนูเครื่องมือใน /roms/tools..."
if [ -f "/roms/tools/Screen_Off.sh" ]; then
    rm -f "/roms/tools/Screen_Off.sh"
    rm -f "/roms/tools/images/Screen_Off-thumb.png"
    print_msg " [✓] ลบ /roms/tools/Screen_Off.sh และรูปปกเรียบร้อย"
else
    print_msg " [-] ไม่พบ /roms/tools/Screen_Off.sh (ข้าม)"
fi

# 3. Remove CLI binary shortcut from /usr/local/bin/
print_msg "[3/3] กำลังลบคำสั่ง 'screen_off' จาก /usr/local/bin..."
if [ -f "/usr/local/bin/screen_off" ]; then
    rm -f "/usr/local/bin/screen_off"
    print_msg " [✓] ลบ /usr/local/bin/screen_off เรียบร้อย"
else
    print_msg " [-] ไม่พบ /usr/local/bin/screen_off (ข้าม)"
fi

# Ensure screen backlight is restored if blanked
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
print_msg "       [✓] ถอนการติดตั้ง Screen Off ทั้งหมดสำเร็จ         "
print_msg "=========================================================="

wait_for_exit
clear > /dev/tty1 2>/dev/null || true

exit 0
