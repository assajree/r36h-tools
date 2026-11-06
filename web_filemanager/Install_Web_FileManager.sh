#!/bin/bash
# ==============================================================================
# Installer: Web File Manager (Filebrowser ARM64)
# Target: R36H / playOS (ARM64)
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_SRC="${SCRIPT_DIR}/filebrowser"
DEST_BIN="/usr/local/bin/filebrowser"
TOOLS_DIR="/roms/tools"

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true

print_msg "=================================================="
print_msg "    Web File Manager Installer for R36H (playOS)  "
print_msg "=================================================="
sleep 1

# 1. Check source binary
print_msg "\n[1/4] ตรวจสอบไฟล์โปรแกรม filebrowser..."
if [ ! -f "$BIN_SRC" ]; then
    print_msg " [X] ไม่พบไฟล์ filebrowser ใน ${SCRIPT_DIR}"
    exit 1
fi
print_msg " [✓] พบไฟล์โปรแกรม filebrowser (ARM64)"

# 2. Install binary to /usr/local/bin
print_msg "\n[2/4] ติดตั้งไฟล์โปรแกรมไปยัง ${DEST_BIN}..."
cp -v "$BIN_SRC" "$DEST_BIN"
chmod 755 "$DEST_BIN"
print_msg " [✓] ติดตั้งโปรแกรมเรียบร้อย"

# 2.1 Initialize Database with noauth
DB_PATH="/usr/local/share/filebrowser.db"
mkdir -p "$(dirname "$DB_PATH")" 2>/dev/null || true
if [ ! -w "$(dirname "$DB_PATH")" ]; then
    DB_PATH="/tmp/filebrowser.db"
fi

if [ ! -f "$DB_PATH" ]; then
    "$DEST_BIN" config init -d "$DB_PATH" --auth.method=noauth -a 0.0.0.0 -p 80 -r "/roms" > /dev/null 2>&1 || true
fi
"$DEST_BIN" config set -d "$DB_PATH" --auth.method=noauth -a 0.0.0.0 -p 80 -r "/roms" > /dev/null 2>&1 || true

# อัปเดตฐานข้อมูล playOS เดิม (ถ้ามี) ให้เป็น noauth ด้วย
if [ -f "/home/ark/.config/filebrowser.db" ]; then
    "$DEST_BIN" config set -d "/home/ark/.config/filebrowser.db" --auth.method=noauth > /dev/null 2>&1 || true
fi
print_msg " [✓] ตั้งค่าฐานข้อมูลโหมดไม่ต้องใช้รหัสผ่าน (noauth) เรียบร้อย"

# 3. Create Tools directory if needed
print_msg "\n[3/4] ติดตั้งเมนูเครื่องมือไปยัง ${TOOLS_DIR}..."
mkdir -p "$TOOLS_DIR"

# 3.1 Install Start Script
if [ -f "${SCRIPT_DIR}/Start_Web_FileManager.sh" ]; then
    cp -v "${SCRIPT_DIR}/Start_Web_FileManager.sh" "${TOOLS_DIR}/Start_Web_FileManager.sh"
    chmod 755 "${TOOLS_DIR}/Start_Web_FileManager.sh"
fi

# 3.2 Install Stop Script
if [ -f "${SCRIPT_DIR}/Stop_Web_FileManager.sh" ]; then
    cp -v "${SCRIPT_DIR}/Stop_Web_FileManager.sh" "${TOOLS_DIR}/Stop_Web_FileManager.sh"
    chmod 755 "${TOOLS_DIR}/Stop_Web_FileManager.sh"
fi

print_msg " [✓] ติดตั้ง Start_Web_FileManager.sh และ Stop_Web_FileManager.sh ใน ${TOOLS_DIR} เรียบร้อย"

# 4. Create optional systemd service
print_msg "\n[4/4] กำหนดค่า Service ในระบบ..."
cat << 'EOF' > /etc/systemd/system/filebrowser.service
[Unit]
Description=File Browser Web Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/filebrowser --noauth -a 0.0.0.0 -p 80 -r /roms -d /usr/local/share/filebrowser.db
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload 2>/dev/null || true
print_msg " [✓] ลงทะเบียน Service เรียบร้อย"

print_msg "\n=================================================="
print_msg "              การติดตั้งเสร็จสมบูรณ์!             "
print_msg "=================================================="
print_msg "ท่านสามารถเปิดใช้งานได้จากเมนู Tools บนเครื่อง:"
print_msg " 1. 'Start Web File Manager' เพื่อเริ่มระบบ"
print_msg " 2. เข้าเว็บเบราว์เซอร์จากคอม/มือถือที่ http://<IP>"
print_msg " 3. 'Stop Web File Manager' เพื่อปิดเมื่อเสร็จ"
print_msg "=================================================="
sleep 5
