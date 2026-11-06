#!/bin/bash
# ==============================================================================
# Installer: Screenshot Utility & Hotkey Daemon for R36H / playOS (ARM64)
# Installs:
# 1. Background Hotkey Daemon (SELECT + Y) as systemd service
# 2. Standalone CLI command 'screenshot' in /usr/local/bin/
# 3. Clean up legacy EmulationStation menu shortcut if previously installed
# ==============================================================================

# 1. Root auto-escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="/usr/local/bin"
SAVE_DIR="/roms/screenshots"
SERVICE_NAME="screenshot-daemon.service"
SERVICE_SRC="${SCRIPT_DIR}/daemon/${SERVICE_NAME}"
SERVICE_DST="/etc/systemd/system/${SERVICE_NAME}"
TOOLS_LEGACY="/roms/tools/Screenshot.sh"

# 2. Dual output helper function
print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true

print_msg "=================================================="
print_msg "     Screenshot Suite Installer for R36H          "
print_msg "=================================================="
sleep 1

# Step 1: Verify dependencies
print_msg "\n[1/5] ตรวจสอบความพร้อมของระบบ..."
if ! command -v ffmpeg >/dev/null 2>&1; then
    print_msg " [X] ไม่พบ ffmpeg ในระบบ กรุณาตรวจสอบการติดตั้ง ffmpeg"
    sleep 5
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
    print_msg " [X] ไม่พบ python3 ในระบบ"
    sleep 5
    exit 1
fi
print_msg " [✓] พบ ffmpeg และ python3 พร้อมใช้งาน"

# Step 2: Ensure screenshot storage directory
print_msg "\n[2/5] เตรียมโฟลเดอร์สำหรับจัดเก็บบันทึกภาพ..."
mkdir -p "$SAVE_DIR"
chown -R ark:ark "$SAVE_DIR" 2>/dev/null || true
print_msg " [✓] โฟลเดอร์ ${SAVE_DIR} พร้อมใช้งาน"

# Step 3: Install CLI shortcut to /usr/local/bin/
print_msg "\n[3/5] ติดตั้งคำสั่ง CLI 'screenshot' ไปยัง ${BIN_DIR}..."
mkdir -p "$BIN_DIR"
cp -f "${SCRIPT_DIR}/app/screenshot.sh" "${BIN_DIR}/screenshot"
chmod 755 "${BIN_DIR}/screenshot"
print_msg " [✓] ติดตั้ง CLI สำเร็จ (พิมพ์ 'screenshot' ใน Terminal/SSH ได้ทันที)"

# Step 4: Clean up any legacy menu shortcut in /roms/tools/
print_msg "\n[4/5] ตรวจสอบและเก็บกวาดเมนูเก่า..."
if [ -f "$TOOLS_LEGACY" ]; then
    rm -f "$TOOLS_LEGACY"
    print_msg " [✓] ลบทางลัดเมนูเดิม (${TOOLS_LEGACY}) เพื่อให้เครื่องทำงานผ่านคีย์ลัดเต็มรูปแบบ"
else
    print_msg " [✓] ไม่พบเมนูเดิมใน /roms/tools/ (สะอาดเรียบร้อย)"
fi

# Step 5: Install & Start Systemd Hotkey Daemon
print_msg "\n[5/5] ติดตั้งและเริ่มทำงาน Daemon คีย์ลัด (SELECT + Y)..."
if [ -f "$SERVICE_SRC" ]; then
    chmod +x "${SCRIPT_DIR}/daemon/screenshot_daemon.py"
    cp -f "$SERVICE_SRC" "$SERVICE_DST"
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    systemctl restart "$SERVICE_NAME"
    sleep 1

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_msg " [✓] เริ่มทำงาน Screenshot Daemon สำเร็จ (Status: Active)"
    else
        print_msg " [!] Service ติดตั้งแล้วแต่อาจยังไม่พร้อม ตรวจสอบด้วย Status_Screenshot.sh"
    fi
else
    print_msg " [X] ไม่พบไฟล์ ${SERVICE_SRC}"
    exit 1
fi

# Summary
print_msg "\n=================================================="
print_msg "          ติดตั้งเสร็จสมบูรณ์เรียบร้อย!            "
print_msg "=================================================="
print_msg "วิธีใช้งาน:"
print_msg " 1. ขณะอยู่ในเมนูหรือกำลังเล่นเกม:"
print_msg "    - กดปุ่ม [SELECT + Y] พร้อมกันเพื่อแคปภาพทันที"
print_msg "    - หน้าจอจะกะพริบแสงชัตเตอร์ 1 ครั้งเพื่อยืนยัน"
print_msg " 2. ทาง Terminal / SSH:"
print_msg "    - แคปทันที: screenshot"
print_msg "    - นับถอยหลัง: screenshot 3 (เช่น 3 วินาที)"
print_msg " 3. ตรวจสอบสถานะและทดสอบปุ่ม:"
print_msg "    - รัน sudo bash Status_Screenshot.sh"
print_msg " 4. ไฟล์ภาพทั้งหมดจะถูกบันทึกที่:"
print_msg "    - ${SAVE_DIR}"
print_msg "=================================================="

sleep 5
