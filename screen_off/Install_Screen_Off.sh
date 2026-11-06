#!/bin/bash
# ==============================================================================
# Installer: Screen Off / Screen Saver for R36H (playOS)
# Description: Installs Screen_Off.sh into /roms/tools/, /usr/local/bin/,
#              and registers Tools & Screen Off into the playOS UI menu.
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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_RUNNER="$SCRIPT_DIR/app/Screen_Off.sh"
APP_THUMB="$SCRIPT_DIR/app/Screen_Off-thumb.png"
TARGET_TOOLS_DIR="/roms/tools"
TARGET_IMAGES_DIR="/roms/tools/images"
TARGET_BIN_DIR="/usr/local/bin"
ES_SYSTEMS_CFG="/etc/emulationstation/es_systems.cfg"

clear > /dev/tty1 2>/dev/null || true
clear 2>/dev/null || true

print_msg "=================================================="
print_msg "        INSTALLING SCREEN OFF UTILITY             "
print_msg "=================================================="
print_msg ""

# 1. Verify app runner source exists
if [ ! -f "$APP_RUNNER" ]; then
    print_msg "[!] ไม่พบไฟล์ต้นฉบับ: $APP_RUNNER"
    sleep 3
    exit 1
fi

chmod +x "$APP_RUNNER"

# 2. Check and prepare tools & images directory
if [ ! -d "$TARGET_TOOLS_DIR" ]; then
    print_msg "[+] สร้างโฟลเดอร์ $TARGET_TOOLS_DIR..."
    mkdir -p "$TARGET_TOOLS_DIR"
fi
mkdir -p "$TARGET_IMAGES_DIR"

# 3. Copy launcher & cover art to /roms/tools/
print_msg "[+] ติดตั้งเมนู Screen_Off.sh ไปยัง $TARGET_TOOLS_DIR..."
cp -f "$APP_RUNNER" "$TARGET_TOOLS_DIR/Screen_Off.sh"
chmod 755 "$TARGET_TOOLS_DIR/Screen_Off.sh"
chown ark:ark "$TARGET_TOOLS_DIR/Screen_Off.sh" 2>/dev/null || true

if [ -f "$APP_THUMB" ]; then
    print_msg "[+] ติดตั้งไอคอนปก Screen_Off-thumb.png..."
    cp -f "$APP_THUMB" "$TARGET_IMAGES_DIR/Screen_Off-thumb.png"
    chown ark:ark "$TARGET_IMAGES_DIR/Screen_Off-thumb.png" 2>/dev/null || true
fi

# 4. Install CLI command to /usr/local/bin/screen_off
print_msg "[+] ติดตั้งคำสั่ง 'screen_off' ไปยัง $TARGET_BIN_DIR..."
mkdir -p "$TARGET_BIN_DIR"
cp -f "$APP_RUNNER" "$TARGET_BIN_DIR/screen_off"
chmod 755 "$TARGET_BIN_DIR/screen_off"

print_msg ""
print_msg "=================================================="
print_msg "           INSTALLATION COMPLETED!                "
print_msg "=================================================="
print_msg ""
print_msg "  [✓] เพิ่มเมนู Screen_Off.sh และรูปปกใน /roms/tools/ แล้ว"
print_msg "  [✓] สามารถพิมพ์ 'screen_off' ใน Terminal เพื่อดับจอได้ทันที"
print_msg "  [✓] เมื่อจอดับ กดปุ่มใดก็ได้บนตัวเครื่องเพื่อเปิดหน้าจอ"
print_msg ""
print_msg "กำลังกลับสู่เมนูหลักใน 4 วินาที..."
sleep 4
clear > /dev/tty1 2>/dev/null || true

exit 0
