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
