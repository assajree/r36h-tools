#!/bin/bash
# ==============================================================================
# Screenshot Utility for R36H (playOS / RK3326)
# Dual-Execution Support: EmulationStation Tools Menu (/roms/tools/) & Terminal/SSH
# ==============================================================================

# Auto-elevate to root if not already root
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

TTY_DEV="/dev/tty1"

# Dual print helper: writes to terminal stdout and /dev/tty1 framebuffer console
print_ui() {
    echo "$@"
    if [ -e "$TTY_DEV" ] && [ "$TTY_DEV" != "$(tty 2>/dev/null)" ]; then
        echo "$@" > "$TTY_DEV" 2>/dev/null
    fi
}

clear_screen() {
    clear 2>/dev/null
    if [ -e "$TTY_DEV" ]; then
        clear > "$TTY_DEV" 2>/dev/null
    fi
}

# Determine default delay:
# If stdout is a terminal (Interactive TTY / SSH), default delay is 0 (instant)
# If launched from EmulationStation Tools menu, default delay is 3 seconds
if [ -t 1 ]; then
    DEFAULT_DELAY=0
    IS_MENU=false
else
    DEFAULT_DELAY=3
    IS_MENU=true
fi

# Override delay with command line argument if supplied (e.g. `screenshot 5`)
DELAY=${1:-$DEFAULT_DELAY}

# Target directory and filename setup
SAVE_DIR="/roms/screenshots"
mkdir -p "$SAVE_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="$SAVE_DIR/screenshot_${TIMESTAMP}.png"

clear_screen

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
    # Fix ownership to ark so user can edit/delete easily
    chown ark:ark "$OUTPUT_FILE" 2>/dev/null
    print_ui "------------------------------------------"
    print_ui "SUCCESS: Screenshot saved!"
    print_ui "Location : $OUTPUT_FILE"
    print_ui "Resolution: 640x480 (PNG)"
    print_ui "------------------------------------------"
else
    print_ui "------------------------------------------"
    print_ui "ERROR: Failed to capture screen."
    print_ui "------------------------------------------"
fi

# Hold screen if running from EmulationStation tools menu so user can read result
if [ "$IS_MENU" = true ]; then
    print_ui "Returning to menu in 3 seconds..."
    sleep 3
fi
