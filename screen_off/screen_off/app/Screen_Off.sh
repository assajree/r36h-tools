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
            SAVED_BRIGHTNESS=80
        fi
    fi
fi

if [ -z "$SAVED_BRIGHTNESS" ] || [ "$SAVED_BRIGHTNESS" -le 0 ] 2>/dev/null; then
    SAVED_BRIGHTNESS=80
fi

# 2. Safety restore function & Trap
RESTORED=0
restore_screen() {
    if [ "$RESTORED" -eq 1 ]; then
        return
    fi
    RESTORED=1

    # Restore framebuffer blanking
    if [ -w /sys/class/graphics/fb0/blank ]; then
        echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null || true
    fi

    # Restore backlight brightness
    if [ -n "$BACKLIGHT_DIR" ] && [ -w "$BACKLIGHT_DIR/brightness" ]; then
        echo "$SAVED_BRIGHTNESS" > "$BACKLIGHT_DIR/brightness" 2>/dev/null || true
    fi
}
trap restore_screen EXIT INT TERM HUP

# 3. Clear console before turning off backlight (Instant silent blackout)
clear > /dev/tty1 2>/dev/null || true
clear 2>/dev/null || true

# 4. Turn off screen (Backlight = 0 & fb0 blank)
if [ -n "$BACKLIGHT_DIR" ] && [ -w "$BACKLIGHT_DIR/brightness" ]; then
    echo 0 > "$BACKLIGHT_DIR/brightness" 2>/dev/null || true
fi

if [ -w /sys/class/graphics/fb0/blank ]; then
    echo 1 > /sys/class/graphics/fb0/blank 2>/dev/null || true
fi

# 5. Smart Input Listener in Python
# - Drains initial button events (e.g. user releasing button 'A')
# - Ignores button release (value == 0) and analog drift (EV_ABS)
# - Wakes up ONLY on genuine key-down (value == 1) or keyboard keypress
python3 -c '
import evdev, select, sys, time, signal

def handle_sig(s, f):
    sys.exit(0)

signal.signal(signal.SIGINT, handle_sig)
signal.signal(signal.SIGTERM, handle_sig)

# Open all input devices that support EV_KEY
devs = []
for p in evdev.list_devices():
    try:
        d = evdev.InputDevice(p)
        if 1 in d.capabilities():
            devs.append(d)
    except Exception:
        pass

# Drain initial events (ignore button "A" release from launcher)
time.sleep(0.4)
for d in devs:
    try:
        while d.read_one() is not None:
            pass
    except Exception:
        pass

fds = {d.fd: d for d in devs}
read_list = list(fds.keys())

# Also include stdin / tty if available
if sys.stdin.isatty():
    read_list.append(sys.stdin.fileno())

# Wait for key-down event
while True:
    try:
        r, _, _ = select.select(read_list, [], [])
    except Exception:
        break

    for fd in r:
        if fd in fds:
            d = fds[fd]
            try:
                for ev in d.read():
                    if ev.type == 1 and ev.value == 1:
                        # Genuine button pressed down!
                        sys.exit(0)
            except Exception:
                pass
        else:
            # stdin / keyboard activity
            sys.exit(0)
' 2>/dev/null

restore_screen
exit 0
