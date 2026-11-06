#!/bin/bash
# ==============================================================================
# Tool: Screen Off / Screen Saver for R36H (playOS)
# Description: Turns off LCD backlight to preserve display and save battery
#              while keeping CPU, downloads, and network connections active.
# Author: playOS Tools Suite
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

# 1. Locate backlight controller and read current brightness
BACKLIGHT_DIR=""
SAVED_BRIGHTNESS=100

for b_path in /sys/class/backlight/*; do
    if [ -d "$b_path" ] && [ -w "$b_path/brightness" ]; then
        BACKLIGHT_DIR="$b_path"
        break
    fi
done

if [ -n "$BACKLIGHT_DIR" ]; then
    VAL=$(cat "$BACKLIGHT_DIR/brightness" 2>/dev/null)
    if [ -n "$VAL" ] && [ "$VAL" -gt 0 ] 2>/dev/null; then
        SAVED_BRIGHTNESS="$VAL"
    else
        MAX_VAL=$(cat "$BACKLIGHT_DIR/max_brightness" 2>/dev/null)
        if [ -n "$MAX_VAL" ] && [ "$MAX_VAL" -gt 0 ] 2>/dev/null; then
            SAVED_BRIGHTNESS="$MAX_VAL"
        else
            SAVED_BRIGHTNESS=100
        fi
    fi
fi

# 2. Safety restore function & Trap
RESTORED=0
WAIT_PID=""

restore_screen() {
    if [ "$RESTORED" -eq 1 ]; then
        return
    fi
    RESTORED=1

    # Terminate background input watcher if still active
    if [ -n "$WAIT_PID" ]; then
        kill -TERM "$WAIT_PID" 2>/dev/null || true
    fi

    # Restore framebuffer blanking if supported
    if [ -w /sys/class/graphics/fb0/blank ]; then
        echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null || true
    fi

    # Restore backlight brightness
    if [ -n "$BACKLIGHT_DIR" ] && [ -w "$BACKLIGHT_DIR/brightness" ]; then
        echo "$SAVED_BRIGHTNESS" > "$BACKLIGHT_DIR/brightness" 2>/dev/null || true
    fi

    print_msg "\n[✓] หน้าจอเปิดแล้ว กำลังกลับสู่เมนูหลัก..."
    sleep 0.5
}
trap restore_screen EXIT INT TERM HUP

# 3. Clear console before turning off backlight
clear > /dev/tty1 2>/dev/null || true
clear 2>/dev/null || true

# 4. Turn off screen (Backlight = 0 & fb0 blank)
if [ -n "$BACKLIGHT_DIR" ] && [ -w "$BACKLIGHT_DIR/brightness" ]; then
    echo 0 > "$BACKLIGHT_DIR/brightness" 2>/dev/null || true
fi

if [ -w /sys/class/graphics/fb0/blank ]; then
    echo 1 > /sys/class/graphics/fb0/blank 2>/dev/null || true
fi

# 5. Wait for ANY button or keypress to wake up
if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import evdev, select, sys, signal

def handle_exit(sig, frame):
    sys.exit(0)

signal.signal(signal.SIGINT, handle_exit)
signal.signal(signal.SIGTERM, handle_exit)
try:
    signal.signal(signal.SIGHUP, handle_exit)
except Exception:
    pass

try:
    devs = [evdev.InputDevice(p) for p in evdev.list_devices()]
    fds = [d.fd for d in devs if 1 in d.capabilities()]
    if sys.stdin.isatty():
        fds.append(sys.stdin.fileno())
    if fds:
        select.select(fds, [], [])
except Exception:
    pass
" 2>/dev/null &
    WAIT_PID=$!
    wait $WAIT_PID 2>/dev/null || true
else
    # Fallback for systems without python
    if [ -t 0 ]; then
        read -s -n 1 -r 2>/dev/null || sleep 2
    else
        sleep 5
    fi
fi

# Explicitly trigger restore_screen on natural exit
restore_screen

exit 0
