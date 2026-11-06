#!/bin/bash
# ==============================================================================
# Tool: Real Linux ncurses `dialog` TUI inside playOS Terminal (via fb0_mirror)
# Description: Demonstrates running genuine /usr/bin/dialog (ncurses TUI) on
#              /dev/tty1 while fb0_mirror streams /dev/fb0 onto the KMSDRM
#              display and bridges R36H gamepad inputs via TIOCSTI.
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

export SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/fb0_mirror.c" ] && [ "$SCRIPT_DIR/fb0_mirror.c" -nt "$SCRIPT_DIR/fb0_mirror" ]; then
    gcc -O2 "$SCRIPT_DIR/fb0_mirror.c" -lSDL2 -o "$SCRIPT_DIR/fb0_mirror" 2>/dev/null || true
    chmod 755 "$SCRIPT_DIR/fb0_mirror" 2>/dev/null || true
elif [ -f "$SCRIPT_DIR/setup_ui/fb0_mirror.c" ] && [ "$SCRIPT_DIR/setup_ui/fb0_mirror.c" -nt "$SCRIPT_DIR/setup_ui/fb0_mirror" ]; then
    gcc -O2 "$SCRIPT_DIR/setup_ui/fb0_mirror.c" -lSDL2 -o "$SCRIPT_DIR/setup_ui/fb0_mirror" 2>/dev/null || true
    chmod 755 "$SCRIPT_DIR/setup_ui/fb0_mirror" 2>/dev/null || true
fi

if [ -x "$SCRIPT_DIR/fb0_mirror" ]; then
    MIRROR_BIN="$SCRIPT_DIR/fb0_mirror"
elif [ -x "$SCRIPT_DIR/setup_ui/fb0_mirror" ]; then
    MIRROR_BIN="$SCRIPT_DIR/setup_ui/fb0_mirror"
elif [ -x "/roms/tools/setup_ui/fb0_mirror" ]; then
    MIRROR_BIN="/roms/tools/setup_ui/fb0_mirror"
elif [ -x "$SCRIPT_DIR/xp_setup_ui/fb0_mirror" ]; then
    MIRROR_BIN="$SCRIPT_DIR/xp_setup_ui/fb0_mirror"
elif [ -x "/roms/tools/xp_setup_ui/fb0_mirror" ]; then
    MIRROR_BIN="/roms/tools/xp_setup_ui/fb0_mirror"
else
    echo "[!] Error: fb0_mirror binary not found."
    exit 1
fi

MIRROR_PID=""

cleanup_all() {
    if [ -n "$MIRROR_PID" ]; then
        kill -TERM "$MIRROR_PID" 2>/dev/null || true
        wait "$MIRROR_PID" 2>/dev/null || true
    fi
    printf "\033c" > /dev/tty1 2>/dev/null || true
    killall -CONT FindManager playfe 2>/dev/null || true
}
trap cleanup_all EXIT INT TERM

# 1. Freeze FindManager / playfe so they stop flipping their GLES2 buffer
killall -STOP FindManager playfe 2>/dev/null || true

# 2. Configure readable console font on /dev/tty1
setfont /usr/share/consolefonts/Lat7-TerminusBold20x10.psf.gz -C /dev/tty1 2>/dev/null || \
setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz -C /dev/tty1 2>/dev/null || true
printf "\033c\e[?25l" > /dev/tty1

# 3. Launch fb0_mirror in the background (streams /dev/fb0 -> KMSDRM & bridges gamepad -> /dev/tty1)
"$MIRROR_BIN" >/dev/null 2>&1 &
MIRROR_PID=$!
sleep 0.3

export TERM=linux

# 4. Run genuine ncurses `dialog` on /dev/tty1!
CHOICE=$(dialog \
    --backtitle "Real Linux ncurses TUI (dialog + fb0_mirror)" \
    --title "Step 1: Select Action" \
    --ok-label "OK" \
    --cancel-label "Exit" \
    --menu "\nUse D-Pad UP/DOWN to choose an option,\nLEFT/RIGHT to switch buttons, and A/B to confirm:" \
    15 56 4 \
    "1" "Install / Configure Service" \
    "2" "Check System Status" \
    "3" "Test Progress Gauge Bar" \
    "4" "Quit without changes" \
    --output-fd 3 3>&1 < /dev/tty1 > /dev/tty1 2>/dev/tty1)

RET=$?

if [ $RET -eq 0 ] && [ "$CHOICE" != "4" ]; then
    (
        echo "25" ; echo "XXX" ; echo "Preparing system environment..." ; echo "XXX" ; sleep 0.6
        echo "60" ; echo "XXX" ; echo "Applying Option $CHOICE..." ; echo "XXX" ; sleep 0.6
        echo "100"; echo "XXX" ; echo "Completed!" ; echo "XXX" ; sleep 0.5
    ) | dialog \
        --backtitle "Real Linux ncurses TUI (dialog + fb0_mirror)" \
        --title "Progress" \
        --gauge "\nExecuting selected operation..." 9 52 0 \
        > /dev/tty1 2>/dev/tty1

    dialog \
        --backtitle "Real Linux ncurses TUI (dialog + fb0_mirror)" \
        --title "Complete" \
        --msgbox "\nOperation ($CHOICE) finished successfully!\n\nPress A or B on < OK > to return to playOS." \
        10 52 < /dev/tty1 > /dev/tty1 2>/dev/tty1

    echo "=========================================================="
    echo "  [OK] Real ncurses dialog completed! Selected option: $CHOICE"
    echo "=========================================================="
else
    echo "=========================================================="
    echo "  [i] Exited ncurses dialog without changes."
    echo "=========================================================="
fi

exit 0
