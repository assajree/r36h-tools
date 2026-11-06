#!/bin/bash
# ==============================================================================
# Tool: LED Color Switcher Uninstaller for R36H (playOS)
# Description: Removes "Set LED to Red" and "Set LED to Blue" from /roms/tools/
#              and restores default Blue LED status.
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

TOOLS_DIR="/roms/tools"

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true
clear 2>/dev/null || true

print_msg "=========================================================="
print_msg "     ถอนการติดตั้งสคริปต์สลับสีไฟ LED สำหรับ R36H       "
print_msg "=========================================================="
print_msg ""

# 1. Restore LED to default Blue state
print_msg "[1/4] กำลังคืนค่าสีไฟเริ่มต้น (สีน้ำเงิน)..."
if [ -f /usr/local/bin/fix_power_led.green ]; then
    cp -f /usr/local/bin/fix_power_led.green /usr/local/bin/fix_power_led
fi
if [ -f /usr/local/bin/batt_life_warning.py.green ]; then
    cp -f /usr/local/bin/batt_life_warning.py.green /usr/local/bin/batt_life_warning.py
fi
echo 0 > /sys/class/gpio/gpio77/value 2>/dev/null || true
systemctl restart batt_led 2>/dev/null || true

# 2. Remove launchers from /roms/tools/
print_msg "[2/4] กำลังลบเมนูออกจาก $TOOLS_DIR..."
rm -f "$TOOLS_DIR/Set_LED_to_Red.sh"
rm -f "$TOOLS_DIR/Set_LED_to_Blue.sh"

# 3. Clean up gamelist.xml entries
print_msg "[3/4] กำลังอัปเดต gamelist.xml..."
python3 - << 'PYEOF' 2>/dev/null || true
import os
import xml.etree.ElementTree as ET

gamelist_path = "/roms/tools/gamelist.xml"
if os.path.exists(gamelist_path):
    try:
        tree = ET.parse(gamelist_path)
        root = tree.getroot()
        removed = False
        for g in list(root.findall("game")):
            p = g.find("path")
            if p is not None and p.text:
                norm_p = p.text.strip()
                if norm_p in ["./Set_LED_to_Red.sh", "./Set_LED_to_Blue.sh"]:
                    root.remove(g)
                    removed = True
        if removed:
            ET.indent(root, space="\t")
            with open(gamelist_path, "w", encoding="utf-8", newline="\n") as f:
                f.write('<?xml version="1.0"?>\n' + ET.tostring(root, encoding="unicode") + "\n")
    except Exception:
        pass
PYEOF

# 4. Refresh playfe if running
print_msg "[4/4] กำลังอัปเดตหน้าจอเมนู playfe..."
if systemctl is-active --quiet playfe.service 2>/dev/null; then
    systemctl restart playfe.service 2>/dev/null || true
fi

print_msg ""
print_msg "=========================================================="
print_msg "           [✓] ถอนการติดตั้งเรียบร้อย!                    "
print_msg "=========================================================="
sleep 2
exit 0
