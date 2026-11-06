#!/bin/bash
# ==============================================================================
# Tool: Power Button Daemon Status Inspector for R36H (playOS)
# Description: Checks and displays current service status, PID, memory,
#              monitored event input node, and recent logs.
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
print_msg "      สถานะการทำงาน Power Button Daemon (R36H)            "
print_msg "=========================================================="
print_msg ""

# 1. Check Service Status
SVC_STATUS="INACTIVE (หยุดทำงาน)"
if systemctl is-active --quiet power-button-daemon.service 2>/dev/null; then
    SVC_STATUS="ACTIVE (กำลังทำงานปกติ ✓)"
fi

BOOT_STATUS="DISABLED"
if systemctl is-enabled --quiet power-button-daemon.service 2>/dev/null; then
    BOOT_STATUS="ENABLED (เริ่มอัตโนมัติตอนบูต ✓)"
fi

print_msg "  • สถานะ Service      : $SVC_STATUS"
print_msg "  • เปิดใช้งานตอนบูต  : $BOOT_STATUS"

# 2. Process Details
PID=$(systemctl show -p MainPID --value power-button-daemon.service 2>/dev/null)
if [ -n "$PID" ] && [ "$PID" -gt 0 ] 2>/dev/null; then
    MEM=$(grep VmRSS /proc/$PID/status 2>/dev/null | awk '{print $2, $3}')
    [ -z "$MEM" ] && MEM="N/A"
    print_msg "  • หมายเลข Process ID : $PID"
    print_msg "  • การใช้ RAM         : $MEM"
else
    print_msg "  • หมายเลข Process ID : ไม่มี (Service ไม่ได้รัน)"
fi

# 3. Input Device Event Node
DEV_NODE="ไม่พบ (Not Found)"
if [ -f /proc/bus/input/devices ]; then
    EV_NAME=$(awk '/Name="rk8xx_pwrkey"/ {found=1} found && /H: Handlers=/ {for(i=1;i<=NF;i++) if($i ~ /event/) print $i; exit}' /proc/bus/input/devices)
    if [ -n "$EV_NAME" ]; then
        DEV_NODE="/dev/input/$EV_NAME (rk8xx_pwrkey PMIC)"
    fi
fi
print_msg "  • ปุ่มที่ดักจับ      : $DEV_NODE"

# 4. Trigger Setting
print_msg "  • เงื่อนไขปิดเครื่อง : กดปุ่ม Power ค้าง 1.0 วิ (นับถอยหลัง 3 วิ - กดปุ่มใดๆ เพื่อยกเลิก)"
print_msg "  • เงื่อนไข Sleep     : กดปุ่ม Power สั้นๆ (< 1.0 วินาที)"

# 5. Recent Logs
print_msg ""
print_msg "--- บันทึกการทำงานล่าสุด (Recent Logs) ---"
if command -v journalctl >/dev/null 2>&1; then
    LOGS=$(journalctl -u power-button-daemon.service -n 4 --no-pager 2>/dev/null | tail -n 4)
    if [ -n "$LOGS" ]; then
        while IFS= read -r line; do
            print_msg "  $line"
        done <<< "$LOGS"
    else
        print_msg "  (ไม่มีประวัติ log)"
    fi
else
    print_msg "  (journalctl ไม่พร้อมใช้งาน)"
fi

print_msg "=========================================================="

# 6. Non-blocking input listener
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
