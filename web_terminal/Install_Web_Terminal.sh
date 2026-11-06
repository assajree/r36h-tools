#!/bin/bash
# ==============================================================================
# Installer: Web Terminal (ttyd ARM64)
# Target: R36H / playOS (ARM64)
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_SRC="${SCRIPT_DIR}/ttyd"
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

# 3.1 Start Script
cat << 'EOF' > "${TOOLS_DIR}/Start_Web_Terminal.sh"
#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

wait_for_exit() {
    print_msg "\n  >>> กดปุ่มใดก็ได้บนเครื่อง หรือ คีย์บอร์ด เพื่อปิดหน้านี้ <<<"
    
    # 1. Listen for keypress on stdin/tty1
    (
        if [ -c /dev/tty1 ]; then
            read -s -n 1 -r < /dev/tty1 2>/dev/null
        else
            read -s -n 1 -r 2>/dev/null
        fi
    ) &
    INPUT_PIDS="$!"
    
    # 2. Listen for gamepad button events (evdev)
    for ev in /dev/input/event*; do
        if [ -r "$ev" ]; then
            ( dd if="$ev" of=/dev/null bs=16 count=1 2>/dev/null ) &
            INPUT_PIDS="$INPUT_PIDS $!"
        fi
    done
    
    # Wait until ANY listener receives input
    wait -n $INPUT_PIDS 2>/dev/null || wait $INPUT_PIDS 2>/dev/null || sleep 2
    
    # Clean up all listeners
    kill -9 $INPUT_PIDS 2>/dev/null || true
}

clear > /dev/tty1 2>/dev/null || true

print_msg "=================================================="
print_msg "         Starting Web Terminal (ttyd)             "
print_msg "=================================================="

TTYD_BIN="/usr/local/bin/ttyd"
if [ ! -x "$TTYD_BIN" ]; then
    print_msg " [X] ไม่พบโปรแกรม ttyd กรุณาติดตั้งก่อน"
    sleep 5
    exit 1
fi

# ตรวจสอบ IP Wi-Fi
IP_ADDR=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
if [ -z "$IP_ADDR" ]; then
    IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

HOST_NAME=$(hostname 2>/dev/null)
[ "$HOST_NAME" = "localhost" ] && HOST_NAME=""

# ตรวจสอบว่าโปรแกรมกำลังทำงานอยู่แล้วหรือไม่
if pgrep -f "$TTYD_BIN" > /dev/null 2>&1; then
    print_msg "\n [!] Web Terminal กำลังทำงานอยู่แล้ว"
else
    print_msg "\n [1/2] กำลังเปิดระบบ Web Terminal..."
    ROOT_DIR="/roms"
    [ ! -d "$ROOT_DIR" ] && ROOT_DIR="/"
    
    cd "$ROOT_DIR" || cd /
    nohup "$TTYD_BIN" -W -p 7681 -i 0.0.0.0 /bin/bash > /tmp/ttyd.log 2>&1 &
    sleep 2
fi

if pgrep -f "$TTYD_BIN" > /dev/null 2>&1; then
    clear > /dev/tty1 2>/dev/null || true
    print_msg "=================================================="
    print_msg "            WEB TERMINAL พร้อมใช้งาน!             "
    print_msg "=================================================="
    print_msg " "
    print_msg "  +----------------------------------------------+"
    print_msg "  |                                              |"
    if [ -n "$IP_ADDR" ]; then
        print_msg "  |   เปิดเว็บเบราว์เซอร์บนมือถือหรือคอมพิวเตอร์:|"
        print_msg "  |                                              |"
        print_msg "  |   -->  http://${IP_ADDR}:7681"
        if [ -n "$HOST_NAME" ]; then
            print_msg "  |   -->  http://${HOST_NAME}.local:7681"
        fi
    else
        print_msg "  |   [!] ยังไม่ได้เชื่อมต่อสัญญาณ Wi-Fi          |"
        print_msg "  |                                              |"
        print_msg "  |   เชื่อมต่อ Wi-Fi แล้วเปิดเข้าผ่าน:          |"
        print_msg "  |   -->  http://<IP-เครื่อง-R36H>:7681         |"
    fi
    print_msg "  |                                              |"
    print_msg "  +----------------------------------------------+"
    print_msg " "
    print_msg " - สิทธิ์: Root Shell สมบูรณ์"
    print_msg " - โฟลเดอร์เริ่มต้น: /roms"
    print_msg " - ปิดระบบ: เข้าเมนู Tools เลือก 'Stop Web Terminal'"
    print_msg "=================================================="
    wait_for_exit
else
    print_msg " [X] เกิดข้อผิดพลาดในการเริ่มระบบ ตรวจสอบ /tmp/ttyd.log"
    sleep 5
fi
EOF
chmod 755 "${TOOLS_DIR}/Start_Web_Terminal.sh"

# 3.2 Stop Script
cat << 'EOF' > "${TOOLS_DIR}/Stop_Web_Terminal.sh"
#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true

print_msg "=================================================="
print_msg "         Stopping Web Terminal (ttyd)             "
print_msg "=================================================="

if pgrep -f "ttyd" > /dev/null 2>&1; then
    pkill -f "ttyd" 2>/dev/null || true
    sleep 1
    print_msg "\n [✓] ปิดการทำงาน Web Terminal สำเร็จ"
    print_msg " คืนแรม (RAM) ให้ระบบสำหรับเล่นเกมเรียบร้อย"
else
    print_msg "\n [i] Web Terminal ไม่ได้เปิดทำงานอยู่"
fi

print_msg "=================================================="
print_msg "\nกำลังกลับสู่หน้ารายการเมนูใน 3 วินาที..."
sleep 3
EOF
chmod 755 "${TOOLS_DIR}/Stop_Web_Terminal.sh"
print_msg " [✓] สร้าง Start_Web_Terminal.sh และ Stop_Web_Terminal.sh ใน ${TOOLS_DIR} เรียบร้อย"

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
print_msg " 3. 'Stop Web Terminal' เพื่อปิดคืน RAM เมื่อเสร็จ"
print_msg "=================================================="
sleep 5
