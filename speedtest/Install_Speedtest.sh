#!/bin/bash
# ==============================================================================
# Installer: Speedtest Benchmark for R36H / playOS (ARM64)
# Installs standalone Speedtest tool to /roms/tools/ and /usr/local/bin/
# ==============================================================================

# 1. Root auto-escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_DIR="/roms/tools"
BIN_DIR="/usr/local/bin"

# 2. Dual output helper function
print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true

print_msg "=================================================="
print_msg "     Speedtest Installer for R36H (playOS)       "
print_msg "=================================================="
sleep 1

# 1. Verify source files
print_msg "\n[1/4] ตรวจสอบความสมบูรณ์ของไฟล์ต้นทาง..."
if [ ! -f "${SCRIPT_DIR}/speedtest.py" ] || [ ! -f "${SCRIPT_DIR}/speedtest_runner.py" ]; then
    print_msg " [X] ไม่พบไฟล์ที่จำเป็นใน ${SCRIPT_DIR}"
    sleep 5
    exit 1
fi
print_msg " [✓] พบไฟล์ speedtest.py และ speedtest_runner.py"

# 2. Install files to /usr/local/bin
print_msg "\n[2/4] ติดตั้งไฟล์สคริปต์ไปยัง ${BIN_DIR}..."
mkdir -p "$BIN_DIR"
cp -f "${SCRIPT_DIR}/speedtest.py" "${BIN_DIR}/speedtest.py"
cp -f "${SCRIPT_DIR}/speedtest_runner.py" "${BIN_DIR}/speedtest_runner.py"
chmod 755 "${BIN_DIR}/speedtest.py" "${BIN_DIR}/speedtest_runner.py"

# Create symlinks for terminal CLI convenience
ln -sf "${BIN_DIR}/speedtest_runner.py" "${BIN_DIR}/speedtest"
ln -sf "${BIN_DIR}/speedtest.py" "${BIN_DIR}/speedtest-cli"
print_msg " [✓] ติดตั้ง CLI speedtest เรียบร้อย (พิมพ์ speedtest ใน terminal ได้ทันที)"

# 3. Install menu item to /roms/tools/
print_msg "\n[3/4] ติดตั้งเมนู Speedtest ไปยัง ${TOOLS_DIR}..."
mkdir -p "$TOOLS_DIR"
TARGET_TOOL="${TOOLS_DIR}/Speedtest.sh"

cp -f "${SCRIPT_DIR}/speedtest.sh" "$TARGET_TOOL"
chmod 755 "$TARGET_TOOL"

# Also ensure /roms/tools/speedtest directory exists with all source scripts
mkdir -p "${TOOLS_DIR}/speedtest"
cp -f "${SCRIPT_DIR}/speedtest.py" "${TOOLS_DIR}/speedtest/"
cp -f "${SCRIPT_DIR}/speedtest_runner.py" "${TOOLS_DIR}/speedtest/"
cp -f "${SCRIPT_DIR}/speedtest.sh" "${TOOLS_DIR}/speedtest/"
chmod 755 "${TOOLS_DIR}/speedtest/"*.sh "${TOOLS_DIR}/speedtest/"*.py 2>/dev/null || true

print_msg " [✓] สร้างเมนู ${TARGET_TOOL} สำเร็จ"

# 4. Verify system python
print_msg "\n[4/4] ตรวจสอบสภาพแวดล้อม Python3..."
if command -v python3 >/dev/null 2>&1; then
    PY_VER=$(python3 --version 2>&1)
    print_msg " [✓] ตรวจพบ ${PY_VER}"
else
    print_msg " [!] คำเตือน: ตรวจไม่พบ python3 ใน PATH"
fi

print_msg "\n=================================================="
print_msg "          ติดตั้ง Speedtest สำเร็จเรียบร้อย!       "
print_msg "=================================================="
print_msg " วิธีเรียกใช้งาน:"
print_msg " 1. จากหน้าจอเครื่อง: เลือกเมนู Tools -> Speedtest"
print_msg " 2. จาก Terminal/SSH: พิมพ์ 'speedtest' แล้วกด Enter"
print_msg "=================================================="
print_msg "\nกำลังกลับสู่หน้ารายการเมนูใน 8 วินาที..."
sleep 8
