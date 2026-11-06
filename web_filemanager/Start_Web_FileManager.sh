#!/bin/bash
# ==============================================================================
# Tool: Start Web File Manager (Filebrowser)
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
        if [ -t 0 ]; then
            read -s -n 1 -r 2>/dev/null
        elif [ -c /dev/tty1 ]; then
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
    wait -n $INPUT_PIDS 2>/dev/null || sleep 2
    
    # Clean up all listeners
    kill -9 $INPUT_PIDS 2>/dev/null || true
}

is_running() {
    pgrep -x "filebrowser" > /dev/null 2>&1
}

clear > /dev/tty1 2>/dev/null || true

print_msg "=================================================="
print_msg "      Starting Web File Manager (Filebrowser)     "
print_msg "=================================================="

FB_BIN="/usr/local/bin/filebrowser"
if [ ! -x "$FB_BIN" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "${SCRIPT_DIR}/filebrowser" ]; then
        chmod +x "${SCRIPT_DIR}/filebrowser" 2>/dev/null || true
        FB_BIN="${SCRIPT_DIR}/filebrowser"
    elif [ -f "/roms/tools/web_filemanager/filebrowser" ]; then
        chmod +x "/roms/tools/web_filemanager/filebrowser" 2>/dev/null || true
        FB_BIN="/roms/tools/web_filemanager/filebrowser"
    else
        print_msg " [X] ไม่พบโปรแกรม filebrowser กรุณาติดตั้งก่อน (รัน Install_Web_FileManager.sh)"
        wait_for_exit
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
if is_running; then
    print_msg "\n [✓] Web File Manager กำลังทำงานอยู่แล้ว"
else
    print_msg "\n [1/2] กำลังเปิดระบบ Web File Manager..."
    ROOT_DIR="/roms"
    [ ! -d "$ROOT_DIR" ] && ROOT_DIR="/"
    
    DB_PATH="/usr/local/share/filebrowser.db"
    mkdir -p "$(dirname "$DB_PATH")" 2>/dev/null || true
    if [ ! -w "$(dirname "$DB_PATH")" ]; then
        DB_PATH="/tmp/filebrowser.db"
    fi
    
    rm -f /tmp/filebrowser.log
    
    # กำหนดค่าไม่ใช้รหัสผ่าน (noauth) ในฐานข้อมูล filebrowser
    if [ ! -f "$DB_PATH" ]; then
        "$FB_BIN" config init -d "$DB_PATH" --auth.method=noauth -a 0.0.0.0 -p 80 -r "$ROOT_DIR" > /dev/null 2>&1 || true
    fi
    "$FB_BIN" config set -d "$DB_PATH" --auth.method=noauth -a 0.0.0.0 -p 80 -r "$ROOT_DIR" > /dev/null 2>&1 || true

    nohup "$FB_BIN" --noauth -a 0.0.0.0 -p 80 -r "$ROOT_DIR" -d "$DB_PATH" > /tmp/filebrowser.log 2>&1 &
    disown
    sleep 2
fi

if is_running; then
    clear > /dev/tty1 2>/dev/null || true
    print_msg "=================================================="
    print_msg "          WEB FILE MANAGER พร้อมใช้งาน!           "
    print_msg "=================================================="
    print_msg " "
    print_msg "  +----------------------------------------------+"
    print_msg "  |                                              |"
    if [ -n "$IP_ADDR" ]; then
        print_msg "  |   เปิดเว็บเบราว์เซอร์บนมือถือหรือคอมพิวเตอร์:|"
        print_msg "  |                                              |"
        print_msg "  |   -->  http://${IP_ADDR}"
        if [ -n "$HOST_NAME" ]; then
            print_msg "  |   -->  http://${HOST_NAME}.local"
        fi
    else
        print_msg "  |   [!] ยังไม่ได้เชื่อมต่อสัญญาณ Wi-Fi          |"
        print_msg "  |                                              |"
        print_msg "  |   เชื่อมต่อ Wi-Fi แล้วเปิดเข้าผ่าน:          |"
        print_msg "  |   -->  http://<IP-เครื่อง-R36H>              |"
    fi
    print_msg "  |                                              |"
    print_msg "  +----------------------------------------------+"
    print_msg " "
    print_msg " - โฟลเดอร์: /roms (เกม, เซฟ, Tools)"
    print_msg " - สิทธิ์: เข้าได้ทันที ไม่ต้องใส่รหัสผ่าน (พอร์ต 80)"
    print_msg " - ปิดระบบ: เข้าเมนู Tools เลือก 'Stop Web File Manager'"
    print_msg "=================================================="
    wait_for_exit
else
    print_msg " [X] เกิดข้อผิดพลาดในการเริ่มระบบ"
    if [ -f /tmp/filebrowser.log ]; then
        print_msg " \n--- รายละเอียดข้อผิดพลาด (/tmp/filebrowser.log) ---"
        tail -n 10 /tmp/filebrowser.log | while IFS= read -r line; do
            print_msg "  $line"
        done
        print_msg " --------------------------------------------------"
    fi
    wait_for_exit
fi
