#!/bin/bash
# ==============================================================================
# Tool: LED Color Switcher Installer for R36H (playOS)
# Description: Installs "Set LED to Red" and "Set LED to Blue" into /roms/tools/
# Folder Name Note: "set_led" normalized is "setled", which is a substring of
#                   "Set_LED_to_Red.sh" ("setledtored") and "Set_LED_to_Blue.sh"
#                   ("setledtoblue"). playfe auto-hides this folder completely!
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
print_msg "      ติดตั้งสคริปต์สลับสีไฟ LED สำหรับ R36H (playOS)     "
print_msg "=========================================================="
print_msg ""

# 1. Clean up legacy led_color folder and stale files if present
print_msg "[1/4] กำลังตรวจสอบและล้างไฟล์เวอร์ชันเก่า (ถ้ามี)..."
if [ -d "$TOOLS_DIR/led_color" ]; then
    rm -rf "$TOOLS_DIR/led_color"
fi

# 2. Locate app subfolder
APP_DIR="$SCRIPT_DIR/app"
if [ ! -d "$APP_DIR" ]; then
    APP_DIR="$SCRIPT_DIR"
fi

# 3. Verify launcher scripts exist
if [ ! -f "$APP_DIR/Set_LED_to_Red.sh" ] || [ ! -f "$APP_DIR/Set_LED_to_Blue.sh" ]; then
    print_msg "[!] Error: ไม่พบไฟล์ Set_LED_to_Red.sh หรือ Set_LED_to_Blue.sh ใน $APP_DIR"
    exit 1
fi

# 4. Install menu entrypoints to /roms/tools/
print_msg "[2/4] กำลังติดตั้งเมนูไปยัง $TOOLS_DIR..."
mkdir -p "$TOOLS_DIR"
cp -f "$APP_DIR/Set_LED_to_Red.sh" "$TOOLS_DIR/Set_LED_to_Red.sh"
cp -f "$APP_DIR/Set_LED_to_Blue.sh" "$TOOLS_DIR/Set_LED_to_Blue.sh"
chmod 755 "$TOOLS_DIR/Set_LED_to_Red.sh" "$TOOLS_DIR/Set_LED_to_Blue.sh"
chown ark:ark "$TOOLS_DIR/Set_LED_to_Red.sh" "$TOOLS_DIR/Set_LED_to_Blue.sh" 2>/dev/null || true

# 5. Clean up old gamelist.xml entries and ensure no stale references
print_msg "[3/4] กำลังจัดระเบียบ gamelist.xml..."
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
                norm_p = p.text.strip().lstrip("./")
                if norm_p.startswith("led_color/") or norm_p.startswith("set_led/"):
                    root.remove(g)
                    removed = True
        if removed:
            ET.indent(root, space="\t")
            with open(gamelist_path, "w", encoding="utf-8", newline="\n") as f:
                f.write('<?xml version="1.0"?>\n' + ET.tostring(root, encoding="unicode") + "\n")
    except Exception:
        pass
PYEOF
chown ark:ark /roms/tools/gamelist.xml 2>/dev/null || true

# 6. Refresh playfe if running
print_msg "[4/4] กำลังอัปเดตหน้าจอเมนู playfe..."
if systemctl is-active --quiet playfe.service 2>/dev/null; then
    systemctl restart playfe.service 2>/dev/null || true
fi

# 7. Verification
if [ -x "$TOOLS_DIR/Set_LED_to_Red.sh" ] && [ -x "$TOOLS_DIR/Set_LED_to_Blue.sh" ]; then
    print_msg ""
    print_msg "=========================================================="
    print_msg "           [✓] ติดตั้งสำเร็จเรียบร้อย!                    "
    print_msg "=========================================================="
    print_msg "  • เมนูที่ 1 : Set_LED_to_Red.sh   (เปลี่ยนไฟเป็นสีแดงทันที)"
    print_msg "  • เมนูที่ 2 : Set_LED_to_Blue.sh  (เปลี่ยนไฟเป็นสีน้ำเงินทันที)"
    print_msg "  • โฟลเดอร์ set_led ถูกซ่อนจากเมนู TOOLS อัตโนมัติ (Stem-Match)"
    print_msg "  • ระบบจำค่าสีที่เลือกไว้ถาวรข้ามการรีบูต"
    print_msg "=========================================================="
else
    print_msg "[!] เกิดข้อผิดพลาดในการติดตั้ง"
    exit 1
fi

sleep 2
exit 0
