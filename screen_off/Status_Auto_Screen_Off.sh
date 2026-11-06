#!/bin/bash
# ==============================================================================
# Status Inspector: Auto Screen Off Daemon for R36H (playOS)
# Description: Displays service status, active PID, memory usage, and recent logs.
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
print_msg "    สถานะระบบ Auto Screen Off (1 นาที) สำหรับ R36H       "
print_msg "=========================================================="
print_msg ""

SERVICE_NAME="auto-screen-off.service"
IS_ACTIVE=0

if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    IS_ACTIVE=1
    print_msg " [สถานะ Service] : \033[1;32mกำลังทำงาน (ACTIVE / RUNNING)\033[0m"
else
    print_msg " [สถานะ Service] : \033[1;31mไม่ได้ทำงาน (INACTIVE / STOPPED)\033[0m"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    print_msg " [การเปิดตอนบูต] : \033[1;32mเปิดอัตโนมัติ (ENABLED)\033[0m"
else
    print_msg " [การเปิดตอนบูต] : \033[1;33mปิดอยู่ (DISABLED)\033[0m"
fi

PID=$(pgrep -f "auto_screen_off_daemon.py" | head -n 1)
if [ -n "$PID" ]; then
    RAM_USAGE=$(ps -o rss= -p "$PID" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
    CPU_USAGE=$(ps -o %cpu= -p "$PID" 2>/dev/null | tr -d ' ')
    print_msg " [Process PID]   : $PID"
    print_msg " [การใช้ RAM]    : ${RAM_USAGE:-0 MB}"
    print_msg " [การใช้ CPU]    : ${CPU_USAGE:-0.0}%"
else
    print_msg " [Process PID]   : -"
fi

print_msg " [เวลา Timeout]  : 60 วินาที (1 นาที)"

# Show backlight status
for b_path in /sys/class/backlight/*; do
    if [ -d "$b_path" ] && [ -r "$b_path/brightness" ]; then
        CURR_B=$(cat "$b_path/brightness" 2>/dev/null)
        MAX_B=$(cat "$b_path/max_brightness" 2>/dev/null)
        print_msg " [ระดับความสว่าง] : $CURR_B / $MAX_B"
        break
    fi
done

print_msg ""
print_msg "----------------------------------------------------------"
print_msg " บันทึก Log การทำงานล่าสุด (Journal Log):"
print_msg "----------------------------------------------------------"
if command -v journalctl >/dev/null 2>&1; then
    LOGS=$(journalctl -u "$SERVICE_NAME" -n 6 --no-pager 2>/dev/null | sed 's/^/  /')
    if [ -n "$LOGS" ]; then
        print_msg "$LOGS"
    else
        print_msg "  (ยังไม่มีบันทึก Log ในระบบ)"
    fi
else
    print_msg "  (คำสั่ง journalctl ไม่พร้อมใช้งาน)"
fi

print_msg "=========================================================="
wait_for_exit
clear > /dev/tty1 2>/dev/null || true

exit 0
