#!/bin/bash
# ==============================================================================
# Tool: Power Button Hold-to-Shutdown Uninstaller for R36H (playOS)
# Description: Stops, disables, and removes the power button daemon service.
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

clear > /dev/tty1 2>/dev/null || true
clear 2>/dev/null || true

print_msg "=========================================================="
print_msg "   ถอนการติดตั้ง Power Button Daemon สำหรับ R36H         "
print_msg "=========================================================="
print_msg ""

print_msg "[1/3] กำลังหยุดและปิดการใช้งาน Service..."
systemctl stop power-button-daemon.service 2>/dev/null || true
systemctl disable power-button-daemon.service 2>/dev/null || true

print_msg "[2/3] กำลังลบไฟล์ระบบ..."
rm -f /etc/systemd/system/power-button-daemon.service
rm -f /usr/local/bin/power_button_daemon.py
rm -f /usr/local/bin/countdown_ui

print_msg "[3/3] กำลังรีโหลด Systemd Daemon..."
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

print_msg ""
print_msg "=========================================================="
print_msg "      [✓] ถอนการติดตั้งเรียบร้อยแล้ว                      "
print_msg "=========================================================="

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
exit 0
