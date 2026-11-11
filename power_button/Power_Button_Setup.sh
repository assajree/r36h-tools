#!/bin/bash
# ==============================================================================
# Tool: Power Button Setup & Manager for R36H (playOS / dArkOS / ArkOS)
# Description: All-in-One ncurses TUI manager for Power Button Daemon.
#              Configures hold duration, shutdown countdown, and short press.
# Archetype: Archetype 2 (Background Daemon, Side-by-Side Ports/Tools)
# Standard: Native /dev/tty1 Console + gptokeyb (Zero fb0_mirror)
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

# ------------------------------------------------------------------------------
# Dynamic Location & Target Resolution
# ------------------------------------------------------------------------------
REAL_SCRIPT="$(realpath "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_SCRIPT")" && pwd)"
SCRIPT_NAME="$(basename "$REAL_SCRIPT")"

if [ -d "$SCRIPT_DIR/power_button" ]; then
    # Standard Side-by-Side mode (e.g. /roms/ports/ or /roms/tools/)
    BASE_MENU_DIR="$SCRIPT_DIR"
    POWER_BUTTON_DIR="$SCRIPT_DIR/power_button"
elif [ "$(basename "$SCRIPT_DIR")" = "power_button" ]; then
    # Running directly from inside internal subfolder
    BASE_MENU_DIR="$(dirname "$SCRIPT_DIR")"
    POWER_BUTTON_DIR="$SCRIPT_DIR"
else
    POWER_BUTTON_DIR="$SCRIPT_DIR"
    if [ -d "/roms/ports" ]; then
        BASE_MENU_DIR="/roms/ports"
    elif [ -d "/roms/tools" ]; then
        BASE_MENU_DIR="/roms/tools"
    else
        BASE_MENU_DIR="$SCRIPT_DIR"
    fi
fi

APP_DIR="$POWER_BUTTON_DIR/app"
DAEMON_DIR="$POWER_BUTTON_DIR/daemon"
STATUS_CONF="$APP_DIR/status.conf"
GLOBAL_CONF="/etc/power_button.conf"
CHOICE_TMP="/tmp/power_button_choice"

TARGET_DAEMON="/usr/local/bin/power_button_daemon.py"
TARGET_COUNTDOWN="/usr/local/bin/countdown_ui"
TARGET_SERVICE="/etc/systemd/system/power-button-daemon.service"

mkdir -p "$APP_DIR" "$DAEMON_DIR"

# Detect SSH vs Direct Console
IS_SSH=0
if [ -n "$SSH_TTY" ] || [ -n "$SSH_CLIENT" ] || [ -n "$SSH_CONNECTION" ]; then
    IS_SSH=1
fi

GPTOKEYB_PID=""
GPTOKEYB_BIN=""

# ------------------------------------------------------------------------------
# Lifecycle & Gamepad Input Helpers (Native tty1 + gptokeyb, Zero fb0_mirror)
# ------------------------------------------------------------------------------
cleanup() {
    rm -f "$CHOICE_TMP" "/tmp/power_button_keys.gptk" 2>/dev/null || true
    if [ -n "$GPTOKEYB_PID" ]; then
        kill -9 "$GPTOKEYB_PID" 2>/dev/null || true
    fi
    pkill -9 -f "gptokeyb.*$SCRIPT_NAME" 2>/dev/null || true

    if [ "$IS_SSH" -eq 0 ]; then
        printf "\033c\e[?25h" > /dev/tty1 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM HUP

# Setup TTY display routing & Controller Bridge
if [ "$IS_SSH" -eq 0 ]; then
    if [ -x "/opt/inttools/gptokeyb" ]; then
        GPTOKEYB_BIN="/opt/inttools/gptokeyb"
    elif [ -x "/usr/local/bin/gptokeyb" ]; then
        GPTOKEYB_BIN="/usr/local/bin/gptokeyb"
    elif command -v gptokeyb >/dev/null 2>&1; then
        GPTOKEYB_BIN="$(command -v gptokeyb)"
    fi

    if [ -n "$GPTOKEYB_BIN" ]; then
        chmod 666 /dev/uinput 2>/dev/null || true
        export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
        pkill -9 -f "gptokeyb.*$SCRIPT_NAME" 2>/dev/null || true

        GPTK_CONF="/opt/inttools/keys.gptk"
        if [ ! -f "$GPTK_CONF" ]; then
            GPTK_CONF="/tmp/power_button_keys.gptk"
            cat << 'EOF' > "$GPTK_CONF"
up = up
down = down
left = left
right = right
a = enter
b = esc
x = space
y = space
select = tab
start = enter
EOF
        fi

        "$GPTOKEYB_BIN" -1 "$SCRIPT_NAME" -c "$GPTK_CONF" >/dev/null 2>&1 &
        GPTOKEYB_PID=$!
    fi

    setfont /usr/share/consolefonts/Lat7-TerminusBold20x10.psf.gz -C /dev/tty1 2>/dev/null || \
    setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz -C /dev/tty1 2>/dev/null || true
    printf "\033c\e[?25l" > /dev/tty1 2>/dev/null || true

    DIALOG_IN="/dev/tty1"
    DIALOG_OUT="/dev/tty1"
    export TERM=linux
else
    DIALOG_IN="/dev/stdin"
    DIALOG_OUT="/dev/stdout"
fi

# Ensure dialog binary is available
if ! command -v dialog >/dev/null 2>&1; then
    echo "Error: 'dialog' package is not installed." >&2
    exit 1
fi

# Universal Dialog Wrapper: Guarantees routing to /dev/tty1 or terminal
run_dialog() {
    dialog "$@" < "$DIALOG_IN" > "$DIALOG_OUT"
}

# ------------------------------------------------------------------------------
# Configuration Helpers
# ------------------------------------------------------------------------------
CUR_HOLD="1.0"
CUR_COUNTDOWN="3"
CUR_SHORT="sleep"

read_current_config() {
    if [ -f "$GLOBAL_CONF" ]; then
        local h=$(grep -E "^HOLD_SECONDS=" "$GLOBAL_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r')
        local c=$(grep -E "^COUNTDOWN_SECONDS=" "$GLOBAL_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r')
        local s=$(grep -E "^SHORT_PRESS_ACTION=" "$GLOBAL_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r')
        [ -n "$h" ] && CUR_HOLD="$h"
        [ -n "$c" ] && CUR_COUNTDOWN="$c"
        [ -n "$s" ] && CUR_SHORT="$s"
    elif [ -f "$STATUS_CONF" ]; then
        local h=$(grep -E "^HOLD_SECONDS=" "$STATUS_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r')
        local c=$(grep -E "^COUNTDOWN_SECONDS=" "$STATUS_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r')
        local s=$(grep -E "^SHORT_PRESS_ACTION=" "$STATUS_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r')
        [ -n "$h" ] && CUR_HOLD="$h"
        [ -n "$c" ] && CUR_COUNTDOWN="$c"
        [ -n "$s" ] && CUR_SHORT="$s"
    fi
}

save_config() {
    local h="$1"
    local c="$2"
    local s="$3"

    CUR_HOLD="$h"
    CUR_COUNTDOWN="$c"
    CUR_SHORT="$s"

    cat << EOF > "$GLOBAL_CONF"
# Power Button Daemon Global Configuration
HOLD_SECONDS=$h
COUNTDOWN_SECONDS=$c
SHORT_PRESS_ACTION=$s
EOF

    cat << EOF > "$STATUS_CONF"
# Power Button Status Configuration
INSTALLED=true
HOLD_SECONDS=$h
COUNTDOWN_SECONDS=$c
SHORT_PRESS_ACTION=$s
EOF
    chmod 644 "$GLOBAL_CONF" "$STATUS_CONF" 2>/dev/null || true

    if systemctl is-active --quiet power-button-daemon.service 2>/dev/null; then
        systemctl restart power-button-daemon.service 2>/dev/null || true
    fi
}

is_daemon_installed() {
    if [ -f "$TARGET_SERVICE" ] && [ -f "$TARGET_DAEMON" ]; then
        return 0
    fi
    return 1
}

# ------------------------------------------------------------------------------
# Action Handlers: Install, Wizard, Uninstall
# ------------------------------------------------------------------------------
perform_install() {
    local hold="$1"
    local count="$2"
    local short="$3"

    # Copy daemon script and countdown binary
    if [ -f "$DAEMON_DIR/power_button_daemon.py" ]; then
        cp -f "$DAEMON_DIR/power_button_daemon.py" "$TARGET_DAEMON"
    else
        echo "Error: Daemon source not found!" >&2
        return 1
    fi
    chmod 755 "$TARGET_DAEMON"

    if [ -f "$DAEMON_DIR/countdown_ui" ]; then
        cp -f "$DAEMON_DIR/countdown_ui" "$TARGET_COUNTDOWN"
        chmod 755 "$TARGET_COUNTDOWN"
    fi

    # Save initial configuration
    save_config "$hold" "$count" "$short"

    # Install systemd unit
    if [ -f "$DAEMON_DIR/power-button-daemon.service" ]; then
        cp -f "$DAEMON_DIR/power-button-daemon.service" "$TARGET_SERVICE"
    else
        cat << 'EOF' > "$TARGET_SERVICE"
[Unit]
Description=Power Button Hold-to-Shutdown Daemon for R36H
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/power_button_daemon.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    fi
    chmod 644 "$TARGET_SERVICE"

    # Enable and start service
    systemctl daemon-reload
    systemctl enable power-button-daemon.service
    systemctl restart power-button-daemon.service

    # Sync launcher to active menu if running side-by-side
    if [ -d "$BASE_MENU_DIR" ] && [ "$BASE_MENU_DIR" != "$SCRIPT_DIR" ]; then
        cp -f "$REAL_SCRIPT" "$BASE_MENU_DIR/Power_Button_Setup.sh" 2>/dev/null || true
        chmod 755 "$BASE_MENU_DIR/Power_Button_Setup.sh" 2>/dev/null || true
    fi

    return 0
}

perform_uninstall() {
    systemctl stop power-button-daemon.service 2>/dev/null || true
    systemctl disable power-button-daemon.service 2>/dev/null || true
    rm -f "$TARGET_SERVICE" "$TARGET_DAEMON" "$TARGET_COUNTDOWN" "$GLOBAL_CONF" 2>/dev/null || true
    systemctl daemon-reload

    cat << EOF > "$STATUS_CONF"
# Power Button Status Configuration
INSTALLED=false
EOF
    chmod 644 "$STATUS_CONF" 2>/dev/null || true
    return 0
}

# ------------------------------------------------------------------------------
# Dialog TUI Menus
# ------------------------------------------------------------------------------
run_custom_wizard() {
    # Step 1: Hold Duration
    run_dialog --backtitle "Power Button Setup Wizard (Step 1/3)" \
        --title " Hold Duration " \
        --menu "Select how long the power button must be held before starting shutdown countdown:" \
        14 56 3 \
        "1.0" "1.0 Second  (Quick Hold)" \
        "2.0" "2.0 Seconds (Standard Hold)" \
        "3.0" "3.0 Seconds (Long Hold - Prevent Accidental)" \
        2> "$CHOICE_TMP"
    [ $? -ne 0 ] && return 1
    local wiz_hold=$(cat "$CHOICE_TMP")

    # Step 2: Countdown Duration
    run_dialog --backtitle "Power Button Setup Wizard (Step 2/3)" \
        --title " Shutdown Countdown " \
        --menu "Select shutdown countdown duration (cancellable via A, B, X, Y buttons):" \
        14 56 3 \
        "3"  "3 Seconds  (Quick Countdown)" \
        "5"  "5 Seconds  (Standard Countdown)" \
        "10" "10 Seconds (Safe Countdown)" \
        2> "$CHOICE_TMP"
    [ $? -ne 0 ] && return 1
    local wiz_count=$(cat "$CHOICE_TMP")

    # Step 3: Short Press Action
    run_dialog --backtitle "Power Button Setup Wizard (Step 3/3)" \
        --title " Short Press Action " \
        --menu "Select action when power button is pressed quickly (< Hold Time):" \
        14 56 3 \
        "sleep"      "Sleep      (System Suspend)" \
        "screen_off" "Screen Off (Turn Off LCD Backlight)" \
        "none"       "None       (Ignore Short Press)" \
        2> "$CHOICE_TMP"
    [ $? -ne 0 ] && return 1
    local wiz_short=$(cat "$CHOICE_TMP")

    perform_install "$wiz_hold" "$wiz_count" "$wiz_short"

    run_dialog --backtitle "Power Button Setup Wizard" \
        --title " Installation Complete " \
        --msgbox "Power Button Daemon installed and activated successfully!\n\nConfigured Settings:\n  - Hold Duration : ${wiz_hold}s\n  - Shutdown Timer: ${wiz_count}s\n  - Short Press   : ${wiz_short}\n\nPress A or Enter to exit." \
        13 54

    exit 0
}

show_not_installed_menu() {
    while true; do
        run_dialog --backtitle "Power Button Manager (playOS / ArkOS)" \
            --title " Main Setup Menu " \
            --menu "Power Button Daemon is NOT installed.\nChoose an action below:" \
            14 54 2 \
            "1" "Install Power Button Daemon" \
            "2" "Exit" \
            2> "$CHOICE_TMP"

        local ret=$?
        [ $ret -ne 0 ] && exit 0

        local choice=$(cat "$CHOICE_TMP")
        case "$choice" in
            1)
                run_dialog --backtitle "Installation Mode" \
                    --title " Choose Install Mode " \
                    --menu "Select your preferred installation method:" \
                    14 56 2 \
                    "1" "Default Install (Hold 1.0s, Countdown 3s, Sleep)" \
                    "2" "Custom Setup Wizard (Step-by-Step Settings)" \
                    2> "$CHOICE_TMP"
                local mode_ret=$?
                if [ $mode_ret -eq 0 ]; then
                    local mode_choice=$(cat "$CHOICE_TMP")
                    if [ "$mode_choice" = "1" ]; then
                        perform_install "1.0" "3" "sleep"
                        run_dialog --backtitle "Power Button Setup" \
                            --title " Installation Complete " \
                            --msgbox "Power Button Daemon installed with DEFAULT settings:\n\n  - Hold Duration : 1.0s\n  - Shutdown Timer: 3s\n  - Short Press   : sleep (Suspend)\n\nPress A or Enter to exit." \
                            13 54
                        exit 0
                    elif [ "$mode_choice" = "2" ]; then
                        run_custom_wizard
                    fi
                fi
                ;;
            2)
                exit 0
                ;;
        esac
    done
}

show_installed_menu() {
    while true; do
        read_current_config
        local s_status="Active"
        systemctl is-active --quiet power-button-daemon.service 2>/dev/null || s_status="Stopped"

        run_dialog --backtitle "Power Button Manager (playOS / ArkOS)" \
            --title " Main Management Menu " \
            --menu "Service: [ $s_status ]\nCurrent: Hold=${CUR_HOLD}s | Timer=${CUR_COUNTDOWN}s | Short=${CUR_SHORT}\n\nSelect an option to configure:" \
            16 58 5 \
            "1" "Configure Hold Time" \
            "2" "Configure Countdown Duration" \
            "3" "Configure Short Press Action" \
            "4" "Uninstall Power Button Daemon" \
            "5" "Exit" \
            2> "$CHOICE_TMP"

        local ret=$?
        [ $ret -ne 0 ] && exit 0

        local choice=$(cat "$CHOICE_TMP")
        case "$choice" in
            1)
                run_dialog --backtitle "Configure Hold Duration" \
                    --title " Hold Duration " \
                    --default-item "$CUR_HOLD" \
                    --menu "Select how long power button must be held to trigger shutdown:" \
                    14 56 3 \
                    "1.0" "1.0 Second  (Quick Hold)" \
                    "2.0" "2.0 Seconds (Standard Hold)" \
                    "3.0" "3.0 Seconds (Long Hold - Prevent Accidental)" \
                    2> "$CHOICE_TMP"
                if [ $? -eq 0 ]; then
                    local new_hold=$(cat "$CHOICE_TMP")
                    save_config "$new_hold" "$CUR_COUNTDOWN" "$CUR_SHORT"
                    run_dialog --title " Setting Saved " \
                        --msgbox "Hold Duration updated to ${new_hold}s.\n\nPress A or Enter to continue." 8 46
                fi
                ;;
            2)
                run_dialog --backtitle "Configure Countdown Duration" \
                    --title " Shutdown Countdown " \
                    --default-item "$CUR_COUNTDOWN" \
                    --menu "Select countdown duration before graceful shutdown:" \
                    14 56 3 \
                    "3"  "3 Seconds  (Quick Countdown)" \
                    "5"  "5 Seconds  (Standard Countdown)" \
                    "10" "10 Seconds (Safe Countdown)" \
                    2> "$CHOICE_TMP"
                if [ $? -eq 0 ]; then
                    local new_count=$(cat "$CHOICE_TMP")
                    save_config "$CUR_HOLD" "$new_count" "$CUR_SHORT"
                    run_dialog --title " Setting Saved " \
                        --msgbox "Shutdown Countdown updated to ${new_count}s.\n\nPress A or Enter to continue." 8 46
                fi
                ;;
            3)
                run_dialog --backtitle "Configure Short Press Action" \
                    --title " Short Press Action " \
                    --default-item "$CUR_SHORT" \
                    --menu "Select action when power button is pressed briefly:" \
                    14 56 3 \
                    "sleep"      "Sleep      (System Suspend)" \
                    "screen_off" "Screen Off (Turn Off LCD Backlight)" \
                    "none"       "None       (Ignore Short Press)" \
                    2> "$CHOICE_TMP"
                if [ $? -eq 0 ]; then
                    local new_short=$(cat "$CHOICE_TMP")
                    save_config "$CUR_HOLD" "$CUR_COUNTDOWN" "$new_short"
                    run_dialog --title " Setting Saved " \
                        --msgbox "Short Press Action updated to ${new_short}.\n\nPress A or Enter to continue." 8 46
                fi
                ;;
            4)
                run_dialog --backtitle "Uninstall Confirmation" \
                    --title " Uninstall Daemon " \
                    --yesno "Are you sure you want to stop and completely uninstall the Power Button Daemon from your system?" \
                    8 54
                if [ $? -eq 0 ]; then
                    perform_uninstall
                    run_dialog --title " Uninstalled " \
                        --msgbox "Power Button Daemon has been completely uninstalled.\n\nPress A or Enter to exit." \
                        9 48
                    exit 0
                fi
                ;;
            5)
                exit 0
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Entrypoint Main
# ------------------------------------------------------------------------------
if is_daemon_installed; then
    show_installed_menu
else
    show_not_installed_menu
fi

exit 0
