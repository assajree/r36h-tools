#!/bin/bash
# ==============================================================================
# Tool: Screen Off / Screen Saver for R36H (playOS)
# Description: Turns off LCD backlight to preserve display and save battery
#              while keeping CPU, downloads, and network connections active.
# Author: playOS Tools Suite
# Archetype: Archetype 3 (One-Shot Interactive)
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
INPUT_PIDS=""

restore_screen() {
    if [ "$RESTORED" -eq 1 ]; then
        return
    fi
    RESTORED=1

    # Terminate background input watchers if still active
    if [ -n "$INPUT_PIDS" ]; then
        kill -9 $INPUT_PIDS 2>/dev/null || true
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

# 3. Clear console before turning off backlight (Instant off)
clear > /dev/tty1 2>/dev/null || true
clear 2>/dev/null || true

# 4. Turn off screen (Backlight = 0 & fb0 blank)
if [ -n "$BACKLIGHT_DIR" ] && [ -w "$BACKLIGHT_DIR/brightness" ]; then
    echo 0 > "$BACKLIGHT_DIR/brightness" 2>/dev/null || true
fi

if [ -w /sys/class/graphics/fb0/blank ]; then
    echo 1 > /sys/class/graphics/fb0/blank 2>/dev/null || true
fi

# Debounce 0.6s so releasing the launch button in playOS does not immediately wake the screen
sleep 0.6

# 5. Dual-Input Listener: Evdev Python + Fallback /dev/input/event* via dd
INPUT_PIDS=""

# 5.1 Keyboard / TTY listener (falls back to sleep if stdin/tty1 returns EOF)
(
    if [ -t 0 ]; then
        read -s -n 1 -r 2>/dev/null || sleep 86400
    elif [ -c /dev/tty1 ]; then
        read -s -n 1 -r < /dev/tty1 2>/dev/null || sleep 86400
    else
        sleep 86400
    fi
) &
INPUT_PIDS="$INPUT_PIDS $!"

# 5.2 Python evdev watcher (if python3 and evdev module are present)
PYTHON_WATCHER_STARTED=0
if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import evdev, select" >/dev/null 2>&1; then
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
    else:
        import time; time.sleep(86400)
except Exception:
    import time; time.sleep(86400)
" 2>/dev/null &
        INPUT_PIDS="$INPUT_PIDS $!"
        PYTHON_WATCHER_STARTED=1
    fi
fi

# 5.3 Fallback dd listener on /dev/input/event* (Hardware buttons guarantee)
for ev in /dev/input/event*; do
    if [ -r "$ev" ]; then
        ( dd if="$ev" of=/dev/null bs=16 count=1 2>/dev/null ) &
        INPUT_PIDS="$INPUT_PIDS $!"
    fi
done

# Wait for any input source to trigger
wait -n $INPUT_PIDS 2>/dev/null || sleep 2

# Cleanup and restore
kill -9 $INPUT_PIDS 2>/dev/null || true
restore_screen

exit 0
