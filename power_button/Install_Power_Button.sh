#!/bin/bash
# ==============================================================================
# Tool: Power Button Hold-to-Shutdown Installer for R36H (playOS)
# Description: Installs and enables background systemd service to monitor
#              the power button and trigger safe shutdown when held for 3 seconds.
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true
clear 2>/dev/null || true

print_msg "=========================================================="
print_msg "   ติดตั้ง Power Button Hold-to-Shutdown สำหรับ R36H     "
print_msg "=========================================================="
print_msg ""

# 1. Check required files
DAEMON_DIR="$SCRIPT_DIR/daemon"
if [ ! -d "$DAEMON_DIR" ]; then
    DAEMON_DIR="$SCRIPT_DIR"
fi

if [ ! -f "$DAEMON_DIR/power_button_daemon.py" ] || [ ! -f "$DAEMON_DIR/power-button-daemon.service" ]; then
    print_msg "[!] ไม่พบไฟล์ power_button_daemon.py หรือ service unit ใน $DAEMON_DIR"
    exit 1
fi

# 2. Stop previous instance if running
print_msg "[1/5] กำลังตรวจสอบและหยุด Service เดิม (ถ้ามี)..."
systemctl stop power-button-daemon.service 2>/dev/null || true

# 3. Install daemon script and UI binary
print_msg "[2/5] กำลังติดตั้งสคริปต์และคอมไพล์ UI..."
cp -f "$DAEMON_DIR/power_button_daemon.py" /usr/local/bin/power_button_daemon.py
chmod 755 /usr/local/bin/power_button_daemon.py

if [ -f "$DAEMON_DIR/countdown_ui.c" ]; then
    gcc -O2 "$DAEMON_DIR/countdown_ui.c" -lSDL2 -o /usr/local/bin/countdown_ui 2>/dev/null || true
    chmod 755 /usr/local/bin/countdown_ui 2>/dev/null || true
fi

# 4. Install systemd service unit
print_msg "[3/5] กำลังติดตั้ง Systemd Service..."
cp -f "$DAEMON_DIR/power-button-daemon.service" /etc/systemd/system/power-button-daemon.service
chmod 644 /etc/systemd/system/power-button-daemon.service

# 5. Ensure systemd-logind ignores power key (prevents duplicate triggers)
print_msg "[4/5] กำลังตรวจสอบการตั้งค่า logind.conf..."
if [ -f /etc/systemd/logind.conf ]; then
    if grep -q "^HandlePowerKey=" /etc/systemd/logind.conf; then
        sed -i 's/^HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf
    else
        echo "HandlePowerKey=ignore" >> /etc/systemd/logind.conf
    fi
fi

# 6. Reload and start service
print_msg "[5/5] กำลังเปิดใช้งานและเริ่มทำงาน Service..."
systemctl daemon-reload
systemctl enable --now power-button-daemon.service

# Hide power_button's own .sh scripts from playfe TOOLS menu via gamelist.xml
if command -v python3 >/dev/null 2>&1; then
    SCRIPT_DIR="$SCRIPT_DIR" python3 - << 'PYEOF'
import os, xml.etree.ElementTree as ET
tools_dir = "/roms/tools"
script_dir = os.path.realpath(os.environ.get("SCRIPT_DIR", ""))
real_tools = os.path.realpath(tools_dir)
if os.path.isdir(tools_dir) and script_dir.startswith(real_tools + "/"):
    gamelist_path = os.path.join(tools_dir, "gamelist.xml")
    root = None
    if os.path.exists(gamelist_path):
        try: root = ET.parse(gamelist_path).getroot()
        except Exception: root = None
    if root is None: root = ET.Element("gameList")
    existing = {g.find("path").text.strip().lstrip("./"): g for g in root.findall("game") if g.find("path") is not None and g.find("path").text}
    for dp, _, fns in os.walk(script_dir):
        for fn in sorted(fns):
            if fn.lower().endswith(".sh"):
                rel_p = os.path.relpath(os.path.join(dp, fn), real_tools).replace("\\", "/")
                g = existing.get(rel_p)
                if g is None:
                    g = ET.SubElement(root, "game")
                    ET.SubElement(g, "path").text = "./" + rel_p
                    ET.SubElement(g, "name").text = os.path.splitext(fn)[0]
                h = g.find("hidden")
                if h is None: h = ET.SubElement(g, "hidden")
                h.text = "true"
    ET.indent(root, space="\t")
    with open(gamelist_path, "w", encoding="utf-8", newline="\n") as f:
        f.write('<?xml version="1.0"?>\n' + ET.tostring(root, encoding="unicode") + "\n")
PYEOF
    chown ark:ark /roms/tools/gamelist.xml 2>/dev/null || true
fi

sleep 1

# 7. Verification
if systemctl is-active --quiet power-button-daemon.service; then
    print_msg ""
    print_msg "=========================================================="
    print_msg "      [✓] ติดตั้งและเริ่มทำงานสำเร็จเรียบร้อย!            "
    print_msg "=========================================================="
    print_msg "  • กดปุ่ม Power ค้าง 1 วินาที : นับถอยหลัง 3 วิเพื่อปิดเครื่อง (กดปุ่มใดๆ เพื่อยกเลิก)"
    print_msg "  • กดปุ่ม Power สั้นๆ        : เข้าโหมด Sleep พักหน้าจอตามปกติ"
    print_msg "  • Service สถานะ             : กำลังทำงาน (ACTIVE)        "
    print_msg "=========================================================="
else
    print_msg ""
    print_msg "[X] เกิดข้อผิดพลาด: Service ไม่สามารถเริ่มทำงานได้"
    print_msg "ตรวจสอบ Log ด้วยคำสั่ง: journalctl -u power-button-daemon.service -n 20"
fi

# 8. Clean exit wait
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
