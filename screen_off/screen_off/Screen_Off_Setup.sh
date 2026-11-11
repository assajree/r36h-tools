#!/bin/bash
# ==============================================================================
# Tool: Screen Off Setup / Manager (playOS & ArkOS)
# Description: All-in-one ncurses TUI manager for Install, Timeout Config,
#              and Uninstall with dynamic dual-target (Ports / Tools) support.
# Author: playOS Tools Suite
# Archetype: Archetype 2 & 3 (Side-by-Side Ports/Tools Architecture)
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

# Determine Base Menu Directory & Screen Off Internal Directory
if [ -d "$SCRIPT_DIR/screen_off" ]; then
    # Standard Side-by-Side mode (e.g. /roms/ports/ or /roms/tools/)
    BASE_MENU_DIR="$SCRIPT_DIR"
    SCREEN_OFF_DIR="$SCRIPT_DIR/screen_off"
elif [ "$(basename "$SCRIPT_DIR")" = "screen_off" ]; then
    # Running directly from inside the screen_off subfolder
    BASE_MENU_DIR="$(dirname "$SCRIPT_DIR")"
    SCREEN_OFF_DIR="$SCRIPT_DIR"
else
    # Fallback to standard locations
    SCREEN_OFF_DIR="$SCRIPT_DIR"
    if [ -d "/roms/ports" ]; then
        BASE_MENU_DIR="/roms/ports"
    elif [ -d "/roms/tools" ]; then
        BASE_MENU_DIR="/roms/tools"
    elif [ -d "/opt/system/Tools" ]; then
        BASE_MENU_DIR="/opt/system/Tools"
    else
        BASE_MENU_DIR="$SCRIPT_DIR"
    fi
fi

APP_DIR="$SCREEN_OFF_DIR/app"
DAEMON_DIR="$SCREEN_OFF_DIR/daemon"
STATUS_CONF="$APP_DIR/status.conf"
CHOICE_TMP="/tmp/screen_off_choice"

TARGET_IMAGES_DIR="$BASE_MENU_DIR/images"
TARGET_BIN_DIR="/usr/local/bin"
TARGET_DAEMON="/usr/local/bin/auto_screen_off_daemon.py"
TARGET_SERVICE="/etc/systemd/system/auto-screen-off.service"

# Detect OS environment
IS_PLAYOS=0
if [ -f "/usr/local/bin/playfe" ] || systemctl is-active --quiet playfe.service 2>/dev/null; then
    IS_PLAYOS=1
fi

IS_SSH=0
if [ -n "$SSH_TTY" ] || [ -n "$SSH_CLIENT" ] || [ -n "$SSH_CONNECTION" ]; then
    IS_SSH=1
fi

GPTOKEYB_PID=""
GPTOKEYB_BIN=""

cleanup() {
    rm -f "$CHOICE_TMP" "/tmp/screen_off_keys.gptk" 2>/dev/null || true
    if [ -n "$GPTOKEYB_PID" ]; then
        kill -9 "$GPTOKEYB_PID" 2>/dev/null || true
    fi
    pkill -9 -f "gptokeyb.*Screen_Off_Setup" 2>/dev/null || true

    if [ "$IS_SSH" -eq 0 ]; then
        printf "\033c\e[?25h" > /dev/tty1 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM HUP

# Setup TTY display routing & Controller Bridge
if [ "$IS_SSH" -eq 0 ]; then
    # Joystick control via gptokeyb (Standard Ports controller bridge)
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
        pgrep -f "gptokeyb.*Screen_Off_Setup" | xargs kill -9 2>/dev/null || true

        GPTK_CONF="/opt/inttools/keys.gptk"
        if [ ! -f "$GPTK_CONF" ]; then
            GPTK_CONF="/tmp/screen_off_keys.gptk"
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

        "$GPTOKEYB_BIN" -1 "Screen_Off_Setup.sh" -c "$GPTK_CONF" >/dev/null 2>&1 &
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

# Ensure dialog is available
if ! command -v dialog >/dev/null 2>&1; then
    echo "=========================================================="
    echo "  [!] Notice: 'dialog' package is missing."
    echo "      Cannot launch TUI setup wizard."
    echo "=========================================================="
    exit 1
fi

# ------------------------------------------------------------------------------
# Status Management
# ------------------------------------------------------------------------------
load_status() {
    CURRENT_INSTALLED=0
    CURRENT_TIMEOUT_MINS=10
    CURRENT_TIMEOUT_LABEL="10 Minutes"

    # Check status.conf first
    if [ -f "$STATUS_CONF" ]; then
        local conf_inst=$(grep -E "^INSTALLED=" "$STATUS_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r')
        local conf_mins=$(grep -E "^TIMEOUT_MINUTES=" "$STATUS_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r')
        local conf_lbl=$(grep -E "^STATUS_LABEL=" "$STATUS_CONF" 2>/dev/null | cut -d'=' -f2- | tr -d '"\r')

        if [ "$conf_inst" = "true" ]; then
            CURRENT_INSTALLED=1
            [ -n "$conf_mins" ] && CURRENT_TIMEOUT_MINS="$conf_mins"
            [ -n "$conf_lbl" ] && CURRENT_TIMEOUT_LABEL="$conf_lbl"
            return
        elif [ "$conf_inst" = "false" ]; then
            CURRENT_INSTALLED=0
            CURRENT_TIMEOUT_LABEL="Not Installed"
            return
        fi
    fi

    # Fallback to system inspection if status.conf is absent
    if [ -f "$BASE_MENU_DIR/Screen_Off.sh" ] || \
       [ -f "$TARGET_BIN_DIR/screen_off" ] || \
       [ -f "$TARGET_SERVICE" ] || \
       systemctl is-active --quiet auto-screen-off.service 2>/dev/null; then
        CURRENT_INSTALLED=1

        if [ -f "$TARGET_SERVICE" ]; then
            if ! systemctl is-enabled --quiet auto-screen-off.service 2>/dev/null && \
               ! systemctl is-active --quiet auto-screen-off.service 2>/dev/null; then
                CURRENT_TIMEOUT_MINS=0
                CURRENT_TIMEOUT_LABEL="Disabled"
            else
                local sec=$(grep -oE "auto_screen_off_daemon\.py [0-9]+" "$TARGET_SERVICE" 2>/dev/null | awk '{print $2}')
                if [ -n "$sec" ] && [ "$sec" -gt 0 ] 2>/dev/null; then
                    CURRENT_TIMEOUT_MINS=$((sec / 60))
                    if [ "$CURRENT_TIMEOUT_MINS" -eq 1 ]; then
                        CURRENT_TIMEOUT_LABEL="1 Minute"
                    else
                        CURRENT_TIMEOUT_LABEL="$CURRENT_TIMEOUT_MINS Minutes"
                    fi
                else
                    CURRENT_TIMEOUT_MINS=10
                    CURRENT_TIMEOUT_LABEL="10 Minutes"
                fi
            fi
        else
            CURRENT_TIMEOUT_MINS=0
            CURRENT_TIMEOUT_LABEL="Disabled"
        fi
    else
        CURRENT_INSTALLED=0
        CURRENT_TIMEOUT_LABEL="Not Installed"
    fi
}

save_status() {
    local installed="$1"
    local mins="$2"
    local label="$3"
    local sec=0
    [ "$mins" -gt 0 ] 2>/dev/null && sec=$((mins * 60))

    mkdir -p "$APP_DIR"
    cat <<EOF > "$STATUS_CONF"
# Screen Off Suite Status Configuration
INSTALLED=$installed
TIMEOUT_MINUTES=$mins
TIMEOUT_SECONDS=$sec
STATUS_LABEL="$label"
LAST_UPDATED="$(date '+%Y-%m-%d %H:%M:%S')"
EOF
}

# ------------------------------------------------------------------------------
# Action: Timeout Selection (Menu in Minutes)
# ------------------------------------------------------------------------------
choose_timeout() {
    local default_item="${CURRENT_TIMEOUT_MINS:-10}"

    rm -f "$CHOICE_TMP" 2>/dev/null
    dialog \
        --backtitle "Screen Off / Screen Saver Suite for Handhelds" \
        --title "Idle Screen Off Timeout" \
        --ok-label "Select" \
        --cancel-label "Back" \
        --default-item "$default_item" \
        --menu "\nSelect idle timeout before screen turns off automatically:\n\nUse D-Pad Up/Down to navigate, A to select:" \
        16 54 7 \
        "0"  "Disabled" \
        "1"  "1 Minute" \
        "3"  "3 Minutes" \
        "5"  "5 Minutes" \
        "10" "10 Minutes (Default)" \
        "15" "15 Minutes" \
        "30" "30 Minutes" \
        2> "$CHOICE_TMP" < "$DIALOG_IN" > "$DIALOG_OUT"

    local ret=$?
    if [ $ret -ne 0 ]; then
        rm -f "$CHOICE_TMP" 2>/dev/null
        return 1
    fi

    SELECTED_MINUTES=$(cat "$CHOICE_TMP" 2>/dev/null | tr -d ' "\r\n')
    rm -f "$CHOICE_TMP" 2>/dev/null

    if [ -z "$SELECTED_MINUTES" ]; then
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Action: Perform Installation / Timeout Configuration
# ------------------------------------------------------------------------------
do_install_or_config() {
    local is_reconfig="$1"
    local minutes="$2"
    local sec=0
    local label=""

    if [ "$minutes" -eq 0 ]; then
        sec=0
        label="Disabled"
    elif [ "$minutes" -eq 1 ]; then
        sec=60
        label="1 Minute"
    else
        sec=$((minutes * 60))
        label="$minutes Minutes"
    fi

    (
        echo "15" ; echo "XXX" ; echo "Preparing target directories ($BASE_MENU_DIR)..." ; echo "XXX" ; sleep 0.3
        mkdir -p "$BASE_MENU_DIR" "$TARGET_IMAGES_DIR" "$TARGET_BIN_DIR"

        echo "35" ; echo "XXX" ; echo "Installing Screen_Off.sh to $BASE_MENU_DIR..." ; echo "XXX" ; sleep 0.3
        cp -f "$APP_DIR/Screen_Off.sh" "$BASE_MENU_DIR/Screen_Off.sh"
        chmod 755 "$BASE_MENU_DIR/Screen_Off.sh"
        chown ark:ark "$BASE_MENU_DIR/Screen_Off.sh" 2>/dev/null || true

        if [ -f "$APP_DIR/Screen_Off-thumb.png" ]; then
            cp -f "$APP_DIR/Screen_Off-thumb.png" "$TARGET_IMAGES_DIR/Screen_Off-thumb.png"
            chown ark:ark "$TARGET_IMAGES_DIR/Screen_Off-thumb.png" 2>/dev/null || true
        elif [ -f "$SCRIPT_DIR/images/Screen_Off-thumb.png" ]; then
            cp -f "$SCRIPT_DIR/images/Screen_Off-thumb.png" "$TARGET_IMAGES_DIR/Screen_Off-thumb.png"
            chown ark:ark "$TARGET_IMAGES_DIR/Screen_Off-thumb.png" 2>/dev/null || true
        fi

        echo "50" ; echo "XXX" ; echo "Ensuring Screen_Off_Setup.sh in $BASE_MENU_DIR..." ; echo "XXX" ; sleep 0.2
        if [ "$SCRIPT_DIR" != "$BASE_MENU_DIR" ] && [ -f "$SCRIPT_DIR/Screen_Off_Setup.sh" ]; then
            cp -f "$SCRIPT_DIR/Screen_Off_Setup.sh" "$BASE_MENU_DIR/Screen_Off_Setup.sh"
            chmod 755 "$BASE_MENU_DIR/Screen_Off_Setup.sh"
            chown ark:ark "$BASE_MENU_DIR/Screen_Off_Setup.sh" 2>/dev/null || true
        fi
        if [ -f "$APP_DIR/Screen_Off_Setup-thumb.png" ]; then
            cp -f "$APP_DIR/Screen_Off_Setup-thumb.png" "$TARGET_IMAGES_DIR/Screen_Off_Setup-thumb.png"
            chown ark:ark "$TARGET_IMAGES_DIR/Screen_Off_Setup-thumb.png" 2>/dev/null || true
        elif [ -f "$SCRIPT_DIR/images/Screen_Off_Setup-thumb.png" ]; then
            cp -f "$SCRIPT_DIR/images/Screen_Off_Setup-thumb.png" "$TARGET_IMAGES_DIR/Screen_Off_Setup-thumb.png"
            chown ark:ark "$TARGET_IMAGES_DIR/Screen_Off_Setup-thumb.png" 2>/dev/null || true
        fi

        # Remove obsolete status/setup scripts
        rm -f "$BASE_MENU_DIR/Screen_Off_Status.sh" 2>/dev/null || true
        rm -f "$TARGET_IMAGES_DIR/Screen_Off_Status-thumb.png" 2>/dev/null || true
        rm -f "$BASE_MENU_DIR/Status_Auto_Screen_Off.sh" 2>/dev/null || true
        rm -f "$BASE_MENU_DIR/Setup_Auto_Screen_Off.sh" 2>/dev/null || true
        rm -f "$BASE_MENU_DIR/Uninstall_Auto_Screen_Off.sh" 2>/dev/null || true
        rm -f "$BASE_MENU_DIR/Install_Screen_Off.sh" 2>/dev/null || true
        rm -f "$BASE_MENU_DIR/Uninstall_Screen_Off.sh" 2>/dev/null || true

        echo "65" ; echo "XXX" ; echo "Installing CLI command to $TARGET_BIN_DIR/screen_off..." ; echo "XXX" ; sleep 0.3
        cp -f "$APP_DIR/Screen_Off.sh" "$TARGET_BIN_DIR/screen_off"
        chmod 755 "$TARGET_BIN_DIR/screen_off"

        echo "85" ; echo "XXX" ; echo "Configuring background daemon ($label)..." ; echo "XXX" ; sleep 0.3
        if [ "$sec" -eq 0 ]; then
            systemctl stop auto-screen-off.service 2>/dev/null || true
            systemctl disable auto-screen-off.service 2>/dev/null || true
        else
            cp -f "$DAEMON_DIR/auto_screen_off_daemon.py" "$TARGET_DAEMON"
            chmod 755 "$TARGET_DAEMON"

            sed "s|ExecStart=.*|ExecStart=/usr/bin/python3 $TARGET_DAEMON $sec|" \
                "$DAEMON_DIR/auto-screen-off.service" > "$TARGET_SERVICE"
            chmod 644 "$TARGET_SERVICE"

            systemctl daemon-reload 2>/dev/null || true
            systemctl enable auto-screen-off.service 2>/dev/null || true
            systemctl restart auto-screen-off.service 2>/dev/null || true
        fi

        echo "95" ; echo "XXX" ; echo "Writing status configuration..." ; echo "XXX" ; sleep 0.2
        save_status "true" "$minutes" "$label"

        echo "100"; echo "XXX" ; echo "Configuration applied successfully!" ; echo "XXX" ; sleep 0.2
    ) | dialog \
        --backtitle "Screen Off / Screen Saver Suite for Handhelds" \
        --title "Applying Changes" \
        --gauge "\nPlease wait while applying configuration..." 9 58 0 \
        > "$DIALOG_OUT" 2>/dev/null

    local title="Installation Complete"
    if [ "$is_reconfig" -eq 1 ]; then
        title="Configuration Updated"
    fi

    dialog \
        --backtitle "Screen Off / Screen Saver Suite for Handhelds" \
        --title "$title" \
        --ok-label "OK" \
        --msgbox "\nScreen Off configuration applied successfully!\n\n• Idle Timeout : $label\n• Manual Mode  : Run 'Screen_Off.sh' in $BASE_MENU_DIR\n• Terminal CLI : Type 'screen_off' in console\n• Wake Method  : Press any button on handheld\n\nPress A or Enter to exit." \
        13 60 < "$DIALOG_IN" > "$DIALOG_OUT"
}

# ------------------------------------------------------------------------------
# Action: Perform Uninstallation
# ------------------------------------------------------------------------------
do_uninstall() {
    dialog \
        --backtitle "Screen Off / Screen Saver Suite for Handhelds" \
        --title "Confirm Uninstallation" \
        --yes-label "Yes, Uninstall" \
        --no-label "Back" \
        --yesno "\nAre you sure you want to completely uninstall Screen Off?\n\nThis will remove the 'Screen_Off.sh' shortcut, CLI command,\nand terminate the background auto-screen-off service." \
        11 60 < "$DIALOG_IN" > "$DIALOG_OUT"

    if [ $? -ne 0 ]; then
        return 1
    fi

    (
        echo "25" ; echo "XXX" ; echo "Stopping and disabling background service..." ; echo "XXX" ; sleep 0.3
        systemctl stop auto-screen-off.service 2>/dev/null || true
        systemctl disable auto-screen-off.service 2>/dev/null || true
        pkill -9 -f "auto_screen_off_daemon.py" 2>/dev/null || true
        rm -f "$TARGET_SERVICE"
        rm -f "$TARGET_DAEMON"
        systemctl daemon-reload 2>/dev/null || true

        echo "60" ; echo "XXX" ; echo "Removing Screen_Off.sh from $BASE_MENU_DIR..." ; echo "XXX" ; sleep 0.3
        rm -f "$BASE_MENU_DIR/Screen_Off.sh"
        rm -f "$TARGET_IMAGES_DIR/Screen_Off-thumb.png"
        rm -f "$TARGET_BIN_DIR/screen_off"

        # Also clean shortcuts in other standard locations if present
        for t_dir in "/roms/ports" "/roms/tools" "/opt/system/Tools"; do
            if [ -d "$t_dir" ] && [ "$t_dir" != "$BASE_MENU_DIR" ]; then
                rm -f "$t_dir/Screen_Off.sh"
                rm -f "$t_dir/images/Screen_Off-thumb.png"
            fi
        done

        echo "85" ; echo "XXX" ; echo "Restoring display backlight..." ; echo "XXX" ; sleep 0.3
        for b_path in /sys/class/backlight/*; do
            if [ -d "$b_path" ] && [ -w "$b_path/brightness" ]; then
                VAL=$(cat "$b_path/brightness" 2>/dev/null)
                if [ -z "$VAL" ] || [ "$VAL" -eq 0 ] 2>/dev/null; then
                    MAX_VAL=$(cat "$b_path/max_brightness" 2>/dev/null)
                    echo "${MAX_VAL:-100}" > "$b_path/brightness" 2>/dev/null || true
                fi
                break
            fi
        done
        if [ -w /sys/class/graphics/fb0/blank ]; then
            echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null || true
        fi

        echo "95" ; echo "XXX" ; echo "Updating status configuration..." ; echo "XXX" ; sleep 0.2
        save_status "false" 0 "Not Installed"

        echo "100"; echo "XXX" ; echo "Uninstallation completed!" ; echo "XXX" ; sleep 0.2
    ) | dialog \
        --backtitle "Screen Off / Screen Saver Suite for Handhelds" \
        --title "Uninstallation Progress" \
        --gauge "\nRemoving Screen Off suite from system..." 9 58 0 \
        > "$DIALOG_OUT" 2>/dev/null

    dialog \
        --backtitle "Screen Off / Screen Saver Suite for Handhelds" \
        --title "Uninstallation Complete" \
        --ok-label "OK" \
        --msgbox "\nScreen Off Suite has been completely uninstalled.\n\nAll services, shortcuts, and binaries were removed.\n\nPress A or Enter to exit." \
        11 58 < "$DIALOG_IN" > "$DIALOG_OUT"
    return 0
}

# ------------------------------------------------------------------------------
# Main Flow: Interactive Navigation Loop
# ------------------------------------------------------------------------------
while true; do
    load_status

    rm -f "$CHOICE_TMP" 2>/dev/null

    if [ "$CURRENT_INSTALLED" -eq 1 ]; then
        # State: INSTALLED
        dialog \
            --backtitle "Screen Off / Screen Saver Suite for Handhelds" \
            --title "Screen Off Setup" \
            --ok-label "Select" \
            --cancel-label "Exit" \
            --menu "\nScreen Off is currently INSTALLED in $BASE_MENU_DIR.\nCurrent Timeout: $CURRENT_TIMEOUT_LABEL\n\nChoose an action:" \
            14 56 2 \
            "1" "Config TimeOut" \
            "2" "Uninstall" \
            2> "$CHOICE_TMP" < "$DIALOG_IN" > "$DIALOG_OUT"

        RET=$?
        if [ $RET -ne 0 ]; then
            break
        fi

        ACTION=$(cat "$CHOICE_TMP" 2>/dev/null | tr -d ' "\r\n')
        rm -f "$CHOICE_TMP" 2>/dev/null

        case "$ACTION" in
            1)
                if choose_timeout; then
                    do_install_or_config 1 "$SELECTED_MINUTES"
                    exit 0
                fi
                ;;
            2)
                if do_uninstall; then
                    exit 0
                fi
                ;;
        esac
    else
        # State: NOT INSTALLED
        dialog \
            --backtitle "Screen Off / Screen Saver Suite for Handhelds" \
            --title "Screen Off Setup" \
            --ok-label "Select" \
            --cancel-label "Exit" \
            --menu "\nScreen Off is currently NOT installed.\nTarget Location: $BASE_MENU_DIR\n\nChoose an action:" \
            13 56 1 \
            "1" "Install Screen Off" \
            2> "$CHOICE_TMP" < "$DIALOG_IN" > "$DIALOG_OUT"

        RET=$?
        if [ $RET -ne 0 ]; then
            break
        fi

        ACTION=$(cat "$CHOICE_TMP" 2>/dev/null | tr -d ' "\r\n')
        rm -f "$CHOICE_TMP" 2>/dev/null

        case "$ACTION" in
            1)
                if choose_timeout; then
                    do_install_or_config 0 "$SELECTED_MINUTES"
                    exit 0
                fi
                ;;
        esac
    fi
done

exit 0
