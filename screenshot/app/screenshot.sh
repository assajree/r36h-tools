#!/bin/bash
# ==============================================================================
# Screenshot Utility for R36H (playOS / RK3326)
# Command-line & Script Screen Capture via Framebuffer (/dev/fb0)
# ==============================================================================

# 1. Root auto-escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

TTY_DEV="/dev/tty1"

# Dual print helper: writes to terminal stdout and /dev/tty1 framebuffer console if available
print_ui() {
    echo -e "$@"
    if [ -w "$TTY_DEV" ] && [ "$TTY_DEV" != "$(tty 2>/dev/null)" ]; then
        echo -e "$@" > "$TTY_DEV" 2>/dev/null || true
    fi
}

flash_shutter() {
    for b in /sys/class/backlight/*/brightness; do
        if [ -w "$b" ]; then
            curr=$(cat "$b" 2>/dev/null || echo 100)
            echo 0 > "$b" 2>/dev/null
            sleep 0.08
            echo "$curr" > "$b" 2>/dev/null
            break
        fi
    done
}

# Determine default delay:
# If terminal interactive (SSH/Terminal), default delay is 0 (instant)
# User can pass delay in seconds as first argument (e.g. `screenshot 3`)
DELAY=${1:-0}

# Target directory and filename setup
SAVE_DIR="/roms/screenshots"
mkdir -p "$SAVE_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="$SAVE_DIR/screenshot_${TIMESTAMP}.png"

print_ui "=========================================="
print_ui "         R36H SCREENSHOT UTILITY          "
print_ui "=========================================="

if [ "$DELAY" -gt 0 ]; then
    print_ui "Capturing screen in $DELAY seconds..."
    REMAIN=$DELAY
    while [ "$REMAIN" -gt 0 ]; do
        print_ui "  [Countdown] $REMAIN..."
        sleep 1
        REMAIN=$((REMAIN - 1))
    done
fi

print_ui "Capturing framebuffer (/dev/fb0)..."

# Capture framebuffer using ffmpeg
ffmpeg -y -f fbdev -i /dev/fb0 -frames:v 1 -update 1 "$OUTPUT_FILE" >/dev/null 2>&1
CAPTURE_STATUS=$?

if [ $CAPTURE_STATUS -eq 0 ] && [ -s "$OUTPUT_FILE" ]; then
    # Camera shutter flash effect
    flash_shutter

    # Fix ownership to ark so user can edit/delete easily
    chown ark:ark "$OUTPUT_FILE" 2>/dev/null
    print_ui "------------------------------------------"
    print_ui "SUCCESS: Screenshot saved!"
    print_ui "Location  : $OUTPUT_FILE"
    print_ui "Resolution: 640x480 (PNG)"
    print_ui "------------------------------------------"
else
    print_ui "------------------------------------------"
    print_ui "ERROR: Failed to capture screen."
    print_ui "------------------------------------------"
    exit 1
fi
