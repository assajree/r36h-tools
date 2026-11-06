#!/bin/bash
# ==============================================================================
# Tool: Start Web Terminal (ttyd ARM64)
# Target: R36H / playOS (ARM64)
# ==============================================================================

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
print_msg "         Starting Web Terminal (ttyd)             "
print_msg "=================================================="

TTYD_BIN="/usr/local/bin/ttyd"
if [ ! -x "$TTYD_BIN" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -x "${SCRIPT_DIR}/ttyd" ]; then
        TTYD_BIN="${SCRIPT_DIR}/ttyd"
    elif [ -x "/roms/tools/web_terminal/ttyd" ]; then
        TTYD_BIN="/roms/tools/web_terminal/ttyd"
    else
        print_msg " [X] ไม่พบโปรแกรม ttyd กรุณาติดตั้งก่อน"
        sleep 5
        exit 1
    fi
fi

# ตรวจสอบ IP Wi-Fi
IP_ADDR=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
if [ -z "$IP_ADDR" ]; then
    IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

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
    print_msg " [✓] เปิดระบบสำเร็จ!"
    print_msg "=================================================="
    if [ -n "$IP_ADDR" ]; then
        print_msg " เปิดเว็บเบราว์เซอร์บนมือถือหรือคอมพิวเตอร์:"
        print_msg " --> http://${IP_ADDR}:7681"
    else
        print_msg " [!] ยังไม่ได้เชื่อมต่อ Wi-Fi"
        print_msg " เชื่อมต่อ Wi-Fi แล้วเข้าผ่าน IP:7681"
    fi
    print_msg "=================================================="
    print_msg " - สิทธิ์: Root Shell สมบูรณ์"
    print_msg " - โฟลเดอร์เริ่มต้น: /roms"
    print_msg " - เมื่อใช้งานเสร็จ เลือก 'Stop Web Terminal'"
    print_msg "=================================================="
else
    print_msg " [X] เกิดข้อผิดพลาดในการเริ่มระบบ ตรวจสอบ /tmp/ttyd.log"
fi

print_msg "\nกำลังกลับสู่หน้ารายการเมนูใน 10 วินาที..."
read -t 10 -n 1 -s -r 2>/dev/null || sleep 10
