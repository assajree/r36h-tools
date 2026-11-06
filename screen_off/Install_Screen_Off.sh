#!/bin/bash
# ==============================================================================
# Installer: Screen Off / Screen Saver for R36H (playOS)
# Description: Installs Screen_Off.sh into /roms/tools/ and /usr/local/bin/
# Author: playOS Tools Suite
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
TARGET_TOOLS_DIR="/roms/tools"
TARGET_BIN_DIR="/usr/local/bin"

clear > /dev/tty1 2>/dev/null || true

print_msg "=================================================="
print_msg "        INSTALLING SCREEN OFF UTILITY             "
print_msg "=================================================="
print_msg ""

# 1. Check tools directory
if [ ! -d "$TARGET_TOOLS_DIR" ]; then
    print_msg "[!] Creating $TARGET_TOOLS_DIR..."
    mkdir -p "$TARGET_TOOLS_DIR"
fi

# 2. Copy script to /roms/tools/
print_msg "[+] Installing Screen_Off.sh to $TARGET_TOOLS_DIR..."
cp "$SCRIPT_DIR/Screen_Off.sh" "$TARGET_TOOLS_DIR/Screen_Off.sh"
chmod +x "$TARGET_TOOLS_DIR/Screen_Off.sh"
chown ark:ark "$TARGET_TOOLS_DIR/Screen_Off.sh" 2>/dev/null || true

# 3. Create CLI command in /usr/local/bin/screen_off
print_msg "[+] Registering 'screen_off' command in $TARGET_BIN_DIR..."
mkdir -p "$TARGET_BIN_DIR"
cp "$SCRIPT_DIR/Screen_Off.sh" "$TARGET_BIN_DIR/screen_off"
chmod +x "$TARGET_BIN_DIR/screen_off"

print_msg ""
print_msg "=================================================="
print_msg "           INSTALLATION COMPLETED!                "
print_msg "=================================================="
print_msg ""
print_msg "  [✓] มีเมนู Screen_Off.sh ในเมนู Tools เรียบร้อยแล้ว"
print_msg "  [✓] สามารถพิมพ์ 'screen_off' ใน Terminal เพื่อดับจอได้ทันที"
print_msg "  [✓] เมื่อจอดับ กดปุ่มใดก็ได้บนตัวเครื่องเพื่อเปิดหน้าจอ"
print_msg ""
print_msg "กำลังกลับสู่เมนูหลักใน 4 วินาที..."
sleep 4
clear > /dev/tty1 2>/dev/null || true

exit 0
