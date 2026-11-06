#!/bin/bash
# ==============================================================================
# Tool: Web Terminal Uninstaller for R36H (playOS)
# Description: Stops, disables service, and removes ttyd binary and tool shortcuts.
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
print_msg "     ถอนการติดตั้ง Web Terminal สำหรับ R36H (playOS)      "
print_msg "=========================================================="
print_msg ""

# 1. Stop service and process
print_msg "[1/4] กำลังหยุดระบบและปิดการใช้งาน Service..."
systemctl stop ttyd.service 2>/dev/null || true
systemctl disable ttyd.service 2>/dev/null || true
if pgrep -x "ttyd" > /dev/null 2>&1 || pgrep -f "ttyd" > /dev/null 2>&1; then
    pkill -9 -x "ttyd" 2>/dev/null || true
    pkill -9 -f "ttyd" 2>/dev/null || true
fi

# 2. Remove systemd service unit
print_msg "[2/4] กำลังลบการตั้งค่า Service..."
rm -f /etc/systemd/system/ttyd.service
systemctl daemon-reload 2>/dev/null || true
systemctl reset-failed 2>/dev/null || true

# 3. Remove binary from /usr/local/bin
print_msg "[3/4] กำลังลบโปรแกรม ttyd จาก /usr/local/bin..."
rm -f /usr/local/bin/ttyd

# 4. Remove menu shortcuts & cover art from /roms/tools
print_msg "[4/4] กำลังลบเมนูเครื่องมือใน /roms/tools..."
rm -f /roms/tools/Start_Web_Terminal.sh
rm -f /roms/tools/Stop_Web_Terminal.sh
rm -f /roms/tools/images/Start_Web_Terminal-thumb.png
rm -f /roms/tools/images/Stop_Web_Terminal-thumb.png

print_msg ""
print_msg "=========================================================="
print_msg "      [✓] ถอนการติดตั้ง Web Terminal เรียบร้อยแล้ว        "
print_msg "=========================================================="
wait_for_exit
exit 0
