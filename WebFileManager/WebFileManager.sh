#!/bin/bash
# ==============================================================================
# Tool: Web File Manager (Filebrowser) for R36H (playOS / dArkOS / ArkOS)
# Description: All-in-One ncurses TUI manager for Wireless Web File Manager.
#              State-Adaptive: Install Wizard -> Full Service Management.
# Archetype: Archetype 1 (On-Demand Service, Side-by-Side Ports/Tools)
# Standard: Native /dev/tty1 Console + gptokeyb (Zero fb0_mirror)
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

# ------------------------------------------------------------------------------
# Dynamic Location & Target Resolution (PortMaster Standard)
# ------------------------------------------------------------------------------
REAL_SCRIPT="$(realpath "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_SCRIPT")" && pwd)"
SCRIPT_NAME="$(basename "$REAL_SCRIPT")"

# PortMaster standard: launcher script sits next to lowercase data directory
if [ -d "$SCRIPT_DIR/webfilemanager" ]; then
    BASE_MENU_DIR="$SCRIPT_DIR"
    WFM_DIR="$SCRIPT_DIR/webfilemanager"
elif [ -d "$SCRIPT_DIR/WebFileManager" ]; then
    BASE_MENU_DIR="$SCRIPT_DIR"
    WFM_DIR="$SCRIPT_DIR/WebFileManager"
elif [ "$(basename "$SCRIPT_DIR")" = "webfilemanager" ] || [ "$(basename "$SCRIPT_DIR")" = "WebFileManager" ]; then
    BASE_MENU_DIR="$(dirname "$SCRIPT_DIR")"
    WFM_DIR="$SCRIPT_DIR"
else
    WFM_DIR="$SCRIPT_DIR"
    if [ -d "/roms/ports" ]; then
        BASE_MENU_DIR="/roms/ports"
    elif [ -d "/roms/tools" ]; then
        BASE_MENU_DIR="/roms/tools"
    else
        BASE_MENU_DIR="$SCRIPT_DIR"
    fi
fi

# Flat data directory: binaries and services live directly in $WFM_DIR
if [ -d "$WFM_DIR/app" ]; then
    APP_DIR="$WFM_DIR/app"
else
    APP_DIR="$WFM_DIR"
fi

STATUS_CONF="$WFM_DIR/status.conf"
GLOBAL_CONF="/etc/web_filemanager.conf"
CHOICE_TMP="/tmp/wfm_choice"

TARGET_BIN="/usr/local/bin/filebrowser"
TARGET_SERVICE="/etc/systemd/system/filebrowser.service"
REMOTE_AUTOSTART="/etc/systemd/system/remote-autostart.service"
DB_PATH="/usr/local/share/filebrowser.db"
VROOT_DIR="/var/run/webfilemanager/root"

prepare_virtual_root() {
    mkdir -p "$VROOT_DIR" 2>/dev/null || true
    rm -rf "$VROOT_DIR"/* 2>/dev/null || true

    # Direct Quick Links (Alphabetical: Q comes before S)
    if [ -d "/roms/ports" ]; then
        ln -sfn "/roms/ports" "$VROOT_DIR/[Quick Link] Ports" 2>/dev/null || true
    fi
    if [ -d "/roms/tools" ]; then
        ln -sfn "/roms/tools" "$VROOT_DIR/[Quick Link] Tools" 2>/dev/null || true
    fi

    # Storage Drives (Alphabetical: S comes after Q)
    if [ -d "/roms" ]; then
        ln -sfn "/roms" "$VROOT_DIR/[Storage] SD1 - Internal ROMs" 2>/dev/null || true
    fi
    if [ -d "/roms2" ]; then
        ln -sfn "/roms2" "$VROOT_DIR/[Storage] SD2 - External ROMs" 2>/dev/null || true
    else
        mkdir -p "$VROOT_DIR/[Storage] SD2 - External ROMs" 2>/dev/null || true
    fi
}

mkdir -p "$APP_DIR" 2>/dev/null || true

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
    rm -f "$CHOICE_TMP" "/tmp/wfm_keys.gptk" 2>/dev/null || true
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
            GPTK_CONF="/tmp/wfm_keys.gptk"
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
# Configuration Helpers & State Management
# ------------------------------------------------------------------------------
IS_INSTALLED=false
CUR_AUTOSTART="disabled"
CUR_ROOT="/roms"
CUR_PORT="80"

read_config() {
    IS_INSTALLED=false
    # Check status.conf
    if [ -f "$STATUS_CONF" ]; then
        local inst=$(grep -E "^INSTALLED=" "$STATUS_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r')
        local a=$(grep -E "^AUTOSTART=" "$STATUS_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r')
        local r=$(grep -E "^ROOT_DIR=" "$STATUS_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r')
        local p=$(grep -E "^PORT=" "$STATUS_CONF" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r')
        [ "$inst" = "true" ] && IS_INSTALLED=true
        [ -n "$a" ] && CUR_AUTOSTART="$a"
        [ -n "$r" ] && CUR_ROOT="$r"
        [ -n "$p" ] && CUR_PORT="$p"
    fi

    # Require binary in /usr/local/bin to be truly installed
    if [ -x "$TARGET_BIN" ] && [ "$IS_INSTALLED" = "true" ]; then
        IS_INSTALLED=true
    else
        IS_INSTALLED=false
    fi

    # Sync live state from systemd if filebrowser.service exists
    if [ -f "$TARGET_SERVICE" ]; then
        if systemctl is-enabled filebrowser.service >/dev/null 2>&1; then
            CUR_AUTOSTART="enabled"
        else
            CUR_AUTOSTART="disabled"
        fi
    fi
}

save_config() {
    cat << EOF > "$STATUS_CONF"
# Web File Manager Status Configuration
INSTALLED="${IS_INSTALLED}"
AUTOSTART="${CUR_AUTOSTART}"
ROOT_DIR="${CUR_ROOT}"
PORT="${CUR_PORT}"
EOF
    chmod 644 "$STATUS_CONF" 2>/dev/null || true
}

is_installed() {
    [ "$IS_INSTALLED" = "true" ] && [ -x "$TARGET_BIN" ]
}

is_service_running() {
    pgrep -x "filebrowser" >/dev/null 2>&1
}

get_service_pid() {
    pgrep -x "filebrowser" 2>/dev/null | head -n 1
}

get_ip_address() {
    local ip=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    if [ -z "$ip" ]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    echo "$ip"
}

get_hostname() {
    local h=$(hostname 2>/dev/null)
    [ "$h" = "localhost" ] && h=""
    echo "$h"
}

# ------------------------------------------------------------------------------
# Core Installation Routine with Visual Progress Bar (dialog --gauge)
# ------------------------------------------------------------------------------
install_with_progress() {
    local root_dir="$1"
    local autostart="$2"
    local port="$3"

    (
        echo 10
        echo "XXX"
        echo "Preparing installation..."
        echo "XXX"
        sleep 0.4

        echo 25
        echo "XXX"
        echo "Installing binary to /usr/local/bin..."
        echo "XXX"
        if [ -f "$WFM_DIR/filebrowser" ]; then
            cp -f "$WFM_DIR/filebrowser" "$TARGET_BIN"
        elif [ -f "$APP_DIR/filebrowser" ]; then
            cp -f "$APP_DIR/filebrowser" "$TARGET_BIN"
        elif [ -f "$SCRIPT_DIR/filebrowser" ]; then
            cp -f "$SCRIPT_DIR/filebrowser" "$TARGET_BIN"
        fi
        chmod 755 "$TARGET_BIN"
        sleep 0.4

        echo 50
        echo "XXX"
        echo "Configuring database (no password, port 80)..."
        echo "XXX"
        mkdir -p "$(dirname "$DB_PATH")" 2>/dev/null || true
        if [ ! -w "$(dirname "$DB_PATH")" ]; then
            DB_PATH="/tmp/filebrowser.db"
        fi

        # If stock db exists, copy it as base to preserve pre-configured anonymous permissions
        if [ -f "/home/ark/.config/filebrowser.db" ]; then
            cp -f "/home/ark/.config/filebrowser.db" "$DB_PATH" 2>/dev/null || true
        fi

        # Configure dark theme, list view, and follow external symlinks (for /roms2 auto-detection)
        "$TARGET_BIN" config init -d "$DB_PATH" --auth.method=noauth --branding.theme=dark --branding.name="Web File Manager" --followExternalSymlinks -a 0.0.0.0 -p "$port" -r "$root_dir" >/dev/null 2>&1 || true
        "$TARGET_BIN" config set -d "$DB_PATH" --auth.method=noauth --hideLoginButton --branding.theme=dark --branding.name="Web File Manager" --followExternalSymlinks -a 0.0.0.0 -p "$port" -r "$root_dir" --scope . >/dev/null 2>&1 || true
        # Ensure at least one admin profile exists with List view mode so anonymous noauth session loads cleanly
        "$TARGET_BIN" users add admin admin12345678 --perm.admin --viewMode=list -d "$DB_PATH" >/dev/null 2>&1 || true
        "$TARGET_BIN" users update 1 --scope . --perm.admin --viewMode=list -d "$DB_PATH" >/dev/null 2>&1 || true
        if [ -f "/home/ark/.config/filebrowser.db" ]; then
            "$TARGET_BIN" config set -d "/home/ark/.config/filebrowser.db" --auth.method=noauth >/dev/null 2>&1 || true
        fi
        sleep 0.4

        echo 75
        echo "XXX"
        echo "Configuring systemd service..."
        echo "XXX"
        if [ -f "$REMOTE_AUTOSTART" ]; then
            if grep -q "filebrowser" "$REMOTE_AUTOSTART"; then
                cp -n "$REMOTE_AUTOSTART" "${REMOTE_AUTOSTART}.bak" 2>/dev/null || true
                sed -i 's/filebrowser -a 0.0.0.0 -p 80 -d \/home\/ark\/.config\/filebrowser.db -r \/ &//g' "$REMOTE_AUTOSTART"
                sed -i 's/filebrowser -a 0.0.0.0 -p 80 [^&]*&//g' "$REMOTE_AUTOSTART"
            fi
        fi

        cat << EOF > "$TARGET_SERVICE"
[Unit]
Description=File Browser Web Service
After=network.target

[Service]
Type=simple
User=root
ExecStartPre=/bin/bash -c "mkdir -p /var/run/webfilemanager/root && rm -rf /var/run/webfilemanager/root/* && if [ -d /roms/ports ]; then ln -sfn /roms/ports '/var/run/webfilemanager/root/[Quick Link] Ports'; fi && if [ -d /roms/tools ]; then ln -sfn /roms/tools '/var/run/webfilemanager/root/[Quick Link] Tools'; fi && if [ -d /roms ]; then ln -sfn /roms '/var/run/webfilemanager/root/[Storage] SD1 - Internal ROMs'; fi && if [ -d /roms2 ]; then ln -sfn /roms2 '/var/run/webfilemanager/root/[Storage] SD2 - External ROMs'; else mkdir -p '/var/run/webfilemanager/root/[Storage] SD2 - External ROMs'; fi"
ExecStart=/usr/local/bin/filebrowser --noauth --followExternalSymlinks -a 0.0.0.0 -p ${port} -r /var/run/webfilemanager/root -d ${DB_PATH}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        chmod 644 "$TARGET_SERVICE"
        systemctl daemon-reload
        sleep 0.4

        echo 90
        echo "XXX"
        echo "Starting Web File Manager service..."
        echo "XXX"
        if [ "$autostart" = "enabled" ]; then
            systemctl enable filebrowser.service 2>/dev/null || true
        else
            systemctl disable filebrowser.service 2>/dev/null || true
        fi
        prepare_virtual_root
        pkill -9 -x "filebrowser" 2>/dev/null || true
        sleep 0.5
        systemctl start filebrowser.service 2>/dev/null || true
        sleep 0.5

        CUR_ROOT="$root_dir"
        CUR_AUTOSTART="$autostart"
        CUR_PORT="$port"
        IS_INSTALLED=true
        save_config
        sleep 0.4

        echo 100
        echo "XXX"
        echo "Installation & startup completed!"
        echo "XXX"
        sleep 0.4
    ) | dialog --backtitle "Web File Manager Installation" \
               --title " Installing... " \
               --gauge "Starting installation..." 8 54 0 > "$DIALOG_OUT" 2>&1

    return 0
}

run_install_flow() {
    # Step 1: Config Auto-Start
    run_dialog --backtitle "Web File Manager Installation" \
        --title " Auto-Start Configuration " \
        --no-tags \
        --menu "Choose whether Web File Manager should start automatically when console turns on:\n(Use D-Pad Up/Down to navigate, press A to select)" \
        14 58 2 \
        "disabled" "Disabled: Start on-demand (Save RAM for games)" \
        "enabled"  "Enabled : Always running in background" \
        2> "$CHOICE_TMP"

    local ret=$?
    [ $ret -ne 0 ] && return 0
    local sel_auto=$(cat "$CHOICE_TMP" 2>/dev/null | tr -d ' "\r\n')
    [ -z "$sel_auto" ] && sel_auto="disabled"

    # Step 2: Summary Dialog (Yes/No with [ Install ] and [ Back ])
    local auto_desc="DISABLED (Start manually on-demand)"
    [ "$sel_auto" = "enabled" ] && auto_desc="ENABLED (Start automatically on system boot)"

    run_dialog --backtitle "Web File Manager Installation" \
        --title " Configuration Summary " \
        --yes-label "Install" \
        --no-label "Back" \
        --yesno "Please review settings before installation:\n\n  - Application : Web File Manager (Filebrowser)\n  - Target Root : Virtual Root (SD1 & SD2)\n  - Port        : 80 (No password / noauth)\n  - Auto-Start  : ${auto_desc}\n\nSelect [ Install ] to proceed or [ Back ] to reconfigure." 16 60

    local confirm_ret=$?
    if [ $confirm_ret -ne 0 ]; then
        # User pressed Back, re-run flow
        run_install_flow
        return
    fi

    # Step 3: Execute Installation with Progress Bar & Start Service Immediately
    install_with_progress "/var/run/webfilemanager/root" "$sel_auto" "80"

    # Explicitly persist installed configuration in parent process
    CUR_ROOT="/var/run/webfilemanager/root"
    CUR_AUTOSTART="$sel_auto"
    CUR_PORT="80"
    IS_INSTALLED=true
    save_config

    local ip=$(get_ip_address)
    local h=$(get_hostname)
    local pid=$(get_service_pid)

    local url_str="http://${ip}:${CUR_PORT}"
    [ -n "$h" ] && url_str="${url_str}\n          http://${h}.local:${CUR_PORT}"
    if [ -z "$ip" ] || [ "$ip" = "127.0.0.1" ]; then
        url_str="Wi-Fi Disconnected (Connect Wi-Fi to use)"
    fi

    run_dialog --title " Installation Complete " \
        --msgbox "Web File Manager installed & started successfully!\n\nStatus   : ACTIVE (Running)\nPID      : ${pid:-N/A}\nURL      : ${url_str}\nStorage  : Virtual Root (SD1 & SD2)\nAuto-Boot: ${auto_desc}\n\nPress A or Enter to exit." 14 62

    exit 0
}

show_not_installed_menu() {
    run_dialog --backtitle "Web File Manager for R36H" \
        --title " Web File Manager Setup " \
        --menu "Web File Manager is NOT installed.\nPress A or Enter to begin installation:" \
        12 56 1 \
        "1" "Install Web File Manager" \
        2> "$CHOICE_TMP"

    local ret=$?
    [ $ret -ne 0 ] && exit 0

    local choice=$(cat "$CHOICE_TMP" 2>/dev/null | tr -d ' "\r\n')
    case "$choice" in
        1) run_install_flow ;;
        *) exit 0 ;;
    esac
}

# ------------------------------------------------------------------------------
# Action Handlers: Start, Stop, Auto-Start, Root Dir, Info, Uninstall
# ------------------------------------------------------------------------------
start_service() {
    # Prepare virtual root with SD1 and SD2 symlinks
    prepare_virtual_root

    if is_service_running; then
        local pid=$(get_service_pid)
        local ip=$(get_ip_address)
        local h=$(get_hostname)
        local url="http://${ip}:${CUR_PORT}"
        [ -n "$h" ] && url="${url}  or  http://${h}.local:${CUR_PORT}"

        run_dialog --title " Service Already Running " \
            --msgbox "Web File Manager is already active!\n\nPID: ${pid}\nURL: ${url}\nRoot: Virtual Root (SD1 & SD2)\nAuth: None (noauth)\n\nPress A or Enter to continue." 12 56
        return 0
    fi

    # Ensure any lingering process or database lock is freed
    pkill -9 -x "filebrowser" 2>/dev/null || true
    sleep 0.5

    # Start service via systemd if enabled, else start in background
    if [ -f "$TARGET_SERVICE" ] && systemctl is-enabled filebrowser.service >/dev/null 2>&1; then
        systemctl start filebrowser.service 2>/dev/null || true
    else
        rm -f /tmp/filebrowser.log
        nohup "$TARGET_BIN" --noauth --followExternalSymlinks -a 0.0.0.0 -p "$CUR_PORT" -r "$VROOT_DIR" -d "$DB_PATH" > /tmp/filebrowser.log 2>&1 &
        disown
    fi

    sleep 1.5

    if is_service_running; then
        local pid=$(get_service_pid)
        local ip=$(get_ip_address)
        local h=$(get_hostname)
        local msg="Web File Manager started successfully!\n\nPID: ${pid}\nRoot Directory: ${CUR_ROOT}\n"
        if [ -n "$ip" ]; then
            msg="${msg}Open in browser on PC or Mobile:\n  --> http://${ip}\n"
            [ -n "$h" ] && msg="${msg}  --> http://${h}.local\n"
        else
            msg="${msg}[!] Wi-Fi not connected yet.\nConnect Wi-Fi then access http://<Device-IP>\n"
        fi
        msg="${msg}\nPress A or Enter to continue."

        run_dialog --title " Service Started " \
            --msgbox "$msg" 14 56
    else
        local err_log=""
        if [ -f /tmp/filebrowser.log ]; then
            err_log="\n\nError details:\n$(tail -n 4 /tmp/filebrowser.log)"
        fi
        run_dialog --title " Start Failed " \
            --msgbox "Failed to start Web File Manager!${err_log}" 12 54
    fi
}

stop_service() {
    if ! is_service_running; then
        run_dialog --title " Stop Service " \
            --msgbox "Web File Manager is not running.\n(Nothing to stop)" 8 50
        return 0
    fi

    # Stop systemd service if running
    systemctl stop filebrowser.service 2>/dev/null || true

    # Terminate any remaining filebrowser processes
    pkill -9 -x "filebrowser" 2>/dev/null || true
    pkill -9 -f "filebrowser" 2>/dev/null || true
    sleep 1

    if ! is_service_running; then
        run_dialog --title " Service Stopped " \
            --msgbox "Web File Manager has been stopped.\nRAM reclaimed for games!\n\nPress A or Enter to continue." 9 52
    else
        run_dialog --title " Warning " \
            --msgbox "Could not terminate filebrowser process.\nPlease try again." 8 50
    fi
}

toggle_autostart() {
    read_config

    if [ "$CUR_AUTOSTART" = "enabled" ]; then
        # Switch to DISABLED
        systemctl disable filebrowser.service 2>/dev/null || true
        CUR_AUTOSTART="disabled"
        save_config

        run_dialog --title " Auto-Start Config " \
            --msgbox "Auto-Start on Boot is now DISABLED.\n\nWeb File Manager will NOT start automatically.\nYou can launch it on-demand from this menu." 10 54
    else
        # Switch to ENABLED
        if [ -f "$REMOTE_AUTOSTART" ]; then
            if grep -q "filebrowser" "$REMOTE_AUTOSTART"; then
                cp -n "$REMOTE_AUTOSTART" "${REMOTE_AUTOSTART}.bak" 2>/dev/null || true
                sed -i 's/filebrowser -a 0.0.0.0 -p 80 -d \/home\/ark\/.config\/filebrowser.db -r \/ &//g' "$REMOTE_AUTOSTART"
                sed -i 's/filebrowser -a 0.0.0.0 -p 80 [^&]*&//g' "$REMOTE_AUTOSTART"
            fi
        fi

        cat << EOF > "$TARGET_SERVICE"
[Unit]
Description=File Browser Web Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/filebrowser --noauth -a 0.0.0.0 -p ${CUR_PORT} -r ${CUR_ROOT} -d ${DB_PATH}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        chmod 644 "$TARGET_SERVICE"

        systemctl daemon-reload
        systemctl enable filebrowser.service 2>/dev/null || true

        # If not running, start it now
        if ! is_service_running; then
            systemctl start filebrowser.service 2>/dev/null || true
        fi

        CUR_AUTOSTART="enabled"
        save_config

        run_dialog --title " Auto-Start Config " \
            --msgbox "Auto-Start on Boot is now ENABLED!\n\nWeb File Manager will run automatically at boot.\nPort 80 conflict in remote-autostart has been resolved." 11 56
    fi
}

perform_uninstall() {
    run_dialog --title " Confirm Uninstall " \
        --yesno "Are you sure you want to uninstall Web File Manager?\n\nThis will:\n- Stop and remove filebrowser background service\n- Clean up systemd configuration\n- Remove binaries from /usr/local/bin\n- Keep menu launcher intact for easy re-installation\n\nContinue?" 14 56

    local ret=$?
    [ $ret -ne 0 ] && return 0

    # Stop service
    systemctl stop filebrowser.service 2>/dev/null || true
    systemctl disable filebrowser.service 2>/dev/null || true
    pkill -9 -x "filebrowser" 2>/dev/null || true
    pkill -9 -f "filebrowser" 2>/dev/null || true

    # Remove systemd unit
    rm -f "$TARGET_SERVICE" 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true

    # Remove our custom database, but PRESERVE /usr/local/bin/filebrowser so stock playOS built-in can still run!
    rm -f "$DB_PATH" 2>/dev/null || true

    # Restore remote-autostart if backup exists
    if [ -f "${REMOTE_AUTOSTART}.bak" ]; then
        cp -f "${REMOTE_AUTOSTART}.bak" "$REMOTE_AUTOSTART" 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null || true
    fi

    # Clean legacy tools scripts if present (preserve WebFileManager.sh & thumbnail)
    rm -f "/roms/tools/Start_Web_FileManager.sh" "/roms/tools/Stop_Web_FileManager.sh" 2>/dev/null || true
    rm -f "/roms/tools/images/Start_Web_FileManager-thumb.png" "/roms/tools/images/Stop_Web_FileManager-thumb.png" 2>/dev/null || true

    # Update status.conf
    IS_INSTALLED=false
    CUR_AUTOSTART="disabled"
    save_config

    run_dialog --title " Uninstall Complete " \
        --msgbox "Web File Manager uninstalled successfully!\n\nPress A or Enter to exit." 8 50

    exit 0
}

# ------------------------------------------------------------------------------
# Installed Management Menu
# ------------------------------------------------------------------------------
show_installed_menu() {
    while true; do
        read_config

        local status_str="[STOPPED]"
        local auto_str="[Auto: OFF]"
        if is_service_running; then
            status_str="[RUNNING]"
        fi
        if [ "$CUR_AUTOSTART" = "enabled" ]; then
            auto_str="[Auto: ON]"
        fi

        local ip_short=$(get_ip_address)
        local h_short=$(get_hostname)
        local url_display="No Wi-Fi"
        if [ -n "$ip_short" ]; then
            url_display="http://${ip_short}"
            [ -n "$h_short" ] && url_display="${url_display}  or  http://${h_short}.local"
        fi

        local menu_prompt="Status: ${status_str} ${auto_str}\nURL: ${url_display}\n\nChoose an action below:"

        run_dialog --backtitle "Web File Manager (Filebrowser) for R36H" \
            --title " Web File Manager Manager " \
            --menu "$menu_prompt" \
            15 58 5 \
            "1" "Start Service     (Run in background)" \
            "2" "Stop Service      (Reclaim RAM for games)" \
            "3" "Toggle Auto-Start (Currently: ${CUR_AUTOSTART^^})" \
            "4" "Uninstall         (Clean removal from system)" \
            "5" "Exit              (Return to frontend)" \
            2> "$CHOICE_TMP"

        local ret=$?
        [ $ret -ne 0 ] && break

        local choice=$(cat "$CHOICE_TMP" 2>/dev/null | tr -d ' "\r\n')
        case "$choice" in
            1) start_service ;;
            2) stop_service ;;
            3) toggle_autostart ;;
            4) perform_uninstall ;;
            5) break ;;
            *) break ;;
        esac
    done

    exit 0
}

# ------------------------------------------------------------------------------
# Main Entry Point (State-Adaptive)
# ------------------------------------------------------------------------------
main() {
    while true; do
        read_config

        if ! is_installed; then
            show_not_installed_menu
        else
            show_installed_menu
        fi
    done
}

main
