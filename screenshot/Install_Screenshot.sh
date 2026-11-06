#!/bin/bash
# ==============================================================================
# Installer: Screenshot Utility for R36H / playOS (ARM64)
# Installs standalone Screenshot tool to /roms/tools/ and /usr/local/bin/
# ==============================================================================

# 1. Root auto-escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_DIR="/roms/tools"
BIN_DIR="/usr/local/bin"
SAVE_DIR="/roms/screenshots"

# 2. Dual output helper function
print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true

print_msg "=================================================="
print_msg "     Screenshot Installer for R36H (playOS)       "
print_msg "=================================================="
sleep 1

# Step 1: Verify dependencies
print_msg "\n[1/4] ตรวจสอบความพร้อมของระบบ..."
if ! command -v ffmpeg >/dev/null 2>&1; then
    print_msg " [X] ไม่พบ ffmpeg ในระบบ กรุณาตรวจสอบการติดตั้ง ffmpeg"
    sleep 5
    exit 1
fi
print_msg " [✓] พบ ffmpeg พร้อมใช้งาน"

# Step 2: Install CLI shortcut to /usr/local/bin
print_msg "\n[2/4] ติดตั้งคำสั่ง screenshot ไปยัง ${BIN_DIR}..."
mkdir -p "$BIN_DIR"
cp -f "${SCRIPT_DIR}/screenshot.sh" "${BIN_DIR}/screenshot"
chmod 755 "${BIN_DIR}/screenshot"
print_msg " [✓] ติดตั้ง CLI เรียบร้อย (พิมพ์ 'screenshot' ใน Terminal/SSH ได้ทันที)"

# Step 3: Install menu launcher to /roms/tools/
print_msg "\n[3/4] ติดตั้งเมนูไปยัง ${TOOLS_DIR}..."
mkdir -p "$TOOLS_DIR"
cp -f "${SCRIPT_DIR}/screenshot.sh" "${TOOLS_DIR}/Screenshot.sh"
chmod 755 "${TOOLS_DIR}/Screenshot.sh"
print_msg " [✓] สร้างเมนู Screenshot.sh ใน Tools สำเร็จ"

# Step 4: Ensure target screenshot directory
print_msg "\n[4/4] เตรียมโฟลเดอร์สำหรับจัดเก็บบันทึกภาพ..."
mkdir -p "$SAVE_DIR"
chown -R ark:ark "$SAVE_DIR" 2>/dev/null || true
print_msg " [✓] โฟลเดอร์ ${SAVE_DIR} พร้อมใช้งาน"

# Summary
print_msg "\n=================================================="
print_msg "          ติดตั้งสำเร็จสมบูรณ์!                    "
print_msg "=================================================="
print_msg "การใช้งาน:"
print_msg " 1. จากเมนู EmulationStation: เข้า Tools -> Screenshot"
print_msg "    (จะมีเวลานับถอยหลัง 3 วินาทีเพื่อเตรียมหน้าจอ)"
print_msg " 2. จาก Terminal/SSH:"
print_msg "    - แคปทันที: screenshot"
print_msg "    - ตั้งเวลานับถอยหลัง: screenshot 5 (เช่น 5 วินาที)"
print_msg " 3. ไฟล์ภาพจะถูกบันทึกลงที่: ${SAVE_DIR}"
print_msg "=================================================="

sleep 5
