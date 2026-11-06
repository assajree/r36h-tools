#!/bin/bash
# ==============================================================================
# Tool: Speedtest Benchmark for R36H / playOS (ARM64)
# Features: Ping, Download, and Upload measurement with Dual Output (/dev/tty1 + SSH)
# ==============================================================================

# 1. Root auto-escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

# 2. Dual output helper function
print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

# 3. Gamepad & Keyboard responsive exit handler
wait_for_exit() {
    print_msg "\n  >>> กดปุ่มใดก็ได้ หรือรอ 15 วินาที เพื่อกลับสู่เมนูหลัก <<<"
    
    # 3.1 Listen for keypress on stdin / tty1
    (
        if [ -c /dev/tty1 ]; then
            read -s -n 1 -r < /dev/tty1 2>/dev/null
        else
            read -s -n 1 -r 2>/dev/null
        fi
    ) &
    INPUT_PIDS="$!"
    
    # 3.2 Listen for gamepad button events (evdev)
    for ev in /dev/input/event*; do
        if [ -r "$ev" ]; then
            ( dd if="$ev" of=/dev/null bs=16 count=1 2>/dev/null ) &
            INPUT_PIDS="$INPUT_PIDS $!"
        fi
    done
    
    # 3.3 Countdown timer (15 seconds)
    (
        sleep 15
    ) &
    INPUT_PIDS="$INPUT_PIDS $!"
    
    # Wait until ANY listener receives input or timeout occurs
    wait -n $INPUT_PIDS 2>/dev/null || wait $INPUT_PIDS 2>/dev/null || sleep 2
    
    # Clean up background listener processes
    kill -9 $INPUT_PIDS 2>/dev/null || true
}

# 4. Clear console framebuffer
clear > /dev/tty1 2>/dev/null || true

# 5. Resolve script directory and runner paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_BIN="/usr/bin/python3"
[ ! -x "$PYTHON_BIN" ] && PYTHON_BIN="$(command -v python3 2>/dev/null || command -v python 2>/dev/null)"

RUNNER_SCRIPT="${SCRIPT_DIR}/speedtest_runner.py"
if [ ! -f "$RUNNER_SCRIPT" ]; then
    if [ -f "/roms/tools/speedtest/speedtest_runner.py" ]; then
        RUNNER_SCRIPT="/roms/tools/speedtest/speedtest_runner.py"
    elif [ -f "/usr/local/bin/speedtest_runner.py" ]; then
        RUNNER_SCRIPT="/usr/local/bin/speedtest_runner.py"
    fi
fi

# 6. Pre-flight check: Network connectivity
print_msg "=================================================="
print_msg "         R36H playOS Speedtest Benchmark          "
print_msg "=================================================="
print_msg "กำลังตรวจสอบการเชื่อมต่อ Wi-Fi / อินเทอร์เน็ต..."

IP_ADDR=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
if [ -z "$IP_ADDR" ]; then
    IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

if [ -z "$IP_ADDR" ]; then
    print_msg "\n [X] ตรวจไม่พบการเชื่อมต่ออินเทอร์เน็ต!"
    print_msg "     - กรุณาเปิดและเชื่อมต่อ Wi-Fi ก่อนทำการทดสอบ"
    print_msg "     - หากใช้ USB Wi-Fi Dongle ให้ตรวจสอบว่าไฟสถานะติด"
    print_msg "=================================================="
    print_msg "\nกำลังกลับสู่เมนูหลักใน 7 วินาที..."
    sleep 7
    exit 1
fi

print_msg " [✓] พบการเชื่อมต่อ (IP: ${IP_ADDR})"

# 7. Check Python & Runner availability
if [ -z "$PYTHON_BIN" ] || [ ! -x "$PYTHON_BIN" ]; then
    print_msg " [X] ไม่พบโปรแกรม Python3 ในระบบ playOS"
    sleep 6
    exit 1
fi

if [ ! -f "$RUNNER_SCRIPT" ]; then
    print_msg " [X] ไม่พบไฟล์ ${RUNNER_SCRIPT}"
    sleep 6
    exit 1
fi

# 8. Run Speedtest benchmark
"$PYTHON_BIN" -u "$RUNNER_SCRIPT"

# 9. Wait before returning to EmulationStation
wait_for_exit
