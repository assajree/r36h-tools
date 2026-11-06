#!/bin/bash
# ==============================================================================
# Tool: Screenshot Daemon Status & Diagnostics Inspector for R36H (playOS)
# Description: Checks and displays current service status, PID, memory,
#              recent screenshots, logs, and includes a live Button Tester.
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

TTY_DEV="/dev/tty1"

print_msg() {
    echo -e "$1"
    if [ -w "$TTY_DEV" ] && [ "$TTY_DEV" != "$(tty 2>/dev/null)" ]; then
        echo -e "$1" > "$TTY_DEV" 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true
clear 2>/dev/null || true

print_msg "=========================================================="
print_msg "        สถานะการทำงาน Screenshot Daemon (R36H)            "
print_msg "=========================================================="
print_msg ""

SERVICE_NAME="screenshot-daemon.service"

# 1. Check Service Status
SVC_STATUS="INACTIVE (หยุดทำงาน)"
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    SVC_STATUS="ACTIVE (กำลังทำงานปกติ ✓)"
fi

BOOT_STATUS="DISABLED"
if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    BOOT_STATUS="ENABLED (เริ่มอัตโนมัติตอนบูต ✓)"
fi

print_msg "  • สถานะ Service      : $SVC_STATUS"
print_msg "  • เปิดใช้งานตอนบูต  : $BOOT_STATUS"

# 2. Process Details
PID=$(systemctl show -p MainPID --value "$SERVICE_NAME" 2>/dev/null)
if [ -n "$PID" ] && [ "$PID" -gt 0 ] 2>/dev/null; then
    MEM=$(grep VmRSS /proc/$PID/status 2>/dev/null | awk '{print $2, $3}')
    [ -z "$MEM" ] && MEM="N/A"
    print_msg "  • หมายเลข Process ID : $PID"
    print_msg "  • การใช้ RAM         : $MEM"
else
    print_msg "  • หมายเลข Process ID : ไม่มี (Service ไม่ได้รัน)"
fi

# 3. CLI Command
CLI_STATUS="ไม่พบไฟล์"
if [ -x "/usr/local/bin/screenshot" ]; then
    CLI_STATUS="พร้อมใช้งาน (/usr/local/bin/screenshot ✓)"
fi
print_msg "  • คำสั่ง CLI         : $CLI_STATUS"

# 4. Storage & Recent Files
SAVE_DIR="/roms/screenshots"
TOTAL_FILES=0
if [ -d "$SAVE_DIR" ]; then
    TOTAL_FILES=$(find "$SAVE_DIR" -type f -name "*.png" 2>/dev/null | wc -l)
fi
print_msg "  • โฟลเดอร์เซฟภาพ     : $SAVE_DIR"
print_msg "  • จำนวนภาพที่บันทึก   : $TOTAL_FILES ภาพ"

if [ "$TOTAL_FILES" -gt 0 ]; then
    print_msg "\n--- ภาพบันทึกล่าสุด (Last 5 Screenshots) ---"
    ls -lt "$SAVE_DIR"/*.png 2>/dev/null | head -n 5 | awk '{print "   " $9, "(" $5 " bytes)"}'
fi

# 5. Recent Logs
print_msg "\n--- บันทึกการทำงานล่าสุด (Recent Logs) ---"
if command -v journalctl >/dev/null 2>&1; then
    journalctl -u "$SERVICE_NAME" -n 5 --no-pager 2>/dev/null | while IFS= read -r line; do
        print_msg "  $line"
    done
else
    print_msg "  (journalctl ไม่พร้อมใช้งาน)"
fi

print_msg "=========================================================="
print_msg "กด [T] หรือ [1] เพื่อเข้าโหมดทดสอบปุ่มกด (Button Test Mode)"
print_msg "กดปุ่มอื่น หรือ Enter เพื่อออกจากการตรวจสอบ"
print_msg "=========================================================="

read -t 10 -n 1 -r USER_CHOICE || USER_CHOICE=""
echo ""

if [[ "$USER_CHOICE" == "t" || "$USER_CHOICE" == "T" || "$USER_CHOICE" == "1" ]]; then
    python3 -c '
import os, glob, select, struct, sys

EV_KEY = 1
SELECT_CODES = {314, 353}
Y_CODES = {308, 307, 21}

NAME_MAP = {
    304: "BTN_SOUTH / A",
    305: "BTN_EAST / B",
    307: "BTN_NORTH / X",
    308: "BTN_WEST / Y",
    310: "BTN_TL / L1",
    311: "BTN_TR / R1",
    312: "BTN_TL2 / L2",
    313: "BTN_TR2 / R2",
    314: "BTN_SELECT / SELECT",
    315: "BTN_START / START",
    316: "BTN_MODE / FN",
    353: "KEY_SELECT",
    21: "KEY_Y"
}

fds = {}
for p in sorted(glob.glob("/dev/input/event*")):
    try:
        fd = os.open(p, os.O_RDONLY | os.O_NONBLOCK)
        fds[fd] = p
    except Exception:
        pass

print("\n--- เข้าสู่โหมดทดสอบปุ่มกด (กดปุ่มบนตัวเครื่องเพื่อดูผล, กด Ctrl+C เพื่อออก) ---")
print(f"กำลังตรวจจับ {len(fds)} input devices...\n")

try:
    while True:
        rlist, _, _ = select.select(list(fds.keys()), [], [], 1.0)
        for fd in rlist:
            while True:
                try:
                    data = os.read(fd, 24)
                    if not data or len(data) < 24:
                        break
                    sec, usec, ev_type, ev_code, ev_value = struct.unpack("qqHHi", data)
                    if ev_type == EV_KEY:
                        state_str = "PRESSED" if ev_value == 1 else ("REPEAT" if ev_value == 2 else "RELEASED")
                        btn_name = NAME_MAP.get(ev_code, f"Code {ev_code}")
                        tag = ""
                        if ev_code in SELECT_CODES:
                            tag = " [ปุ่ม SELECT ของ Hotkey!]"
                        elif ev_code in Y_CODES:
                            tag = " [ปุ่ม Y ของ Hotkey!]"
                        print(f"Device: {fds[fd]} | Button: {btn_name:<20} | State: {state_str:<8}{tag}")
                except BlockingIOError:
                    break
                except Exception:
                    break
except KeyboardInterrupt:
    print("\nออกจากโหมดทดสอบปุ่มกดเรียบร้อย")
finally:
    for fd in fds:
        try:
            os.close(fd)
        except Exception:
            pass
'
fi
