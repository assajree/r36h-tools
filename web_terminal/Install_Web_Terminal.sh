#!/bin/bash
# ==============================================================================
# Installer: Web Terminal (ttyd ARM64)
# Target: R36H / playOS (ARM64)
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_SRC="${SCRIPT_DIR}/app/ttyd"
DEST_BIN="/usr/local/bin/ttyd"
TOOLS_DIR="/roms/tools"

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true

print_msg "=================================================="
print_msg "     Web Terminal Installer for R36H (playOS)     "
print_msg "=================================================="
sleep 1

# 1. Check source binary
print_msg "\n[1/4] ตรวจสอบไฟล์โปรแกรม ttyd..."
if [ ! -f "$BIN_SRC" ]; then
    print_msg " [X] ไม่พบไฟล์ ttyd ใน ${SCRIPT_DIR}"
    exit 1
fi
print_msg " [✓] พบไฟล์โปรแกรม ttyd (ARM64)"

# 2. Install binary to /usr/local/bin
print_msg "\n[2/4] ติดตั้งไฟล์โปรแกรมไปยัง ${DEST_BIN}..."
cp -v "$BIN_SRC" "$DEST_BIN"
chmod 755 "$DEST_BIN"
print_msg " [✓] ติดตั้งโปรแกรมเรียบร้อย"

# 3. Create Tools directory if needed
print_msg "\n[3/4] ติดตั้งเมนูเครื่องมือไปยัง ${TOOLS_DIR}..."
mkdir -p "$TOOLS_DIR"

# 3.1 Install Start Script
if [ -f "${SCRIPT_DIR}/app/Start_Web_Terminal.sh" ]; then
    cp -v "${SCRIPT_DIR}/app/Start_Web_Terminal.sh" "${TOOLS_DIR}/Start_Web_Terminal.sh"
    chmod 755 "${TOOLS_DIR}/Start_Web_Terminal.sh"
elif [ -f "${SCRIPT_DIR}/Start_Web_Terminal.sh" ]; then
    cp -v "${SCRIPT_DIR}/Start_Web_Terminal.sh" "${TOOLS_DIR}/Start_Web_Terminal.sh"
    chmod 755 "${TOOLS_DIR}/Start_Web_Terminal.sh"
fi

# 3.2 Install Stop Script
if [ -f "${SCRIPT_DIR}/app/Stop_Web_Terminal.sh" ]; then
    cp -v "${SCRIPT_DIR}/app/Stop_Web_Terminal.sh" "${TOOLS_DIR}/Stop_Web_Terminal.sh"
    chmod 755 "${TOOLS_DIR}/Stop_Web_Terminal.sh"
elif [ -f "${SCRIPT_DIR}/Stop_Web_Terminal.sh" ]; then
    cp -v "${SCRIPT_DIR}/Stop_Web_Terminal.sh" "${TOOLS_DIR}/Stop_Web_Terminal.sh"
    chmod 755 "${TOOLS_DIR}/Stop_Web_Terminal.sh"
fi

print_msg " [✓] ติดตั้ง Start_Web_Terminal.sh และ Stop_Web_Terminal.sh ใน ${TOOLS_DIR} เรียบร้อย"

# 4. Create optional systemd service
print_msg "\n[4/4] กำหนดค่า Service ในระบบ..."
cat << 'EOF' > /etc/systemd/system/ttyd.service
[Unit]
Description=ttyd Web Terminal Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/roms
ExecStart=/usr/local/bin/ttyd -W -p 7681 -i 0.0.0.0 /bin/bash
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload 2>/dev/null || true
print_msg " [✓] ลงทะเบียน Service เรียบร้อย (ค่าเริ่มต้น: เปิดใช้งานตามต้องการผ่านเมนู Tools)"

print_msg "\n=================================================="
print_msg "              การติดตั้งเสร็จสมบูรณ์!             "
print_msg "=================================================="
print_msg "ท่านสามารถเปิดใช้งานได้จากเมนู Tools บนเครื่อง:"
print_msg " 1. 'Start Web Terminal' เพื่อเริ่มระบบ"
print_msg " 2. เข้าเว็บเบราว์เซอร์จากคอม/มือถือที่ http://<IP>:7681"
print_msg " 3. 'Stop Web Terminal' เพื่อปิดเมื่อเสร็จ"
print_msg "=================================================="
sleep 5
