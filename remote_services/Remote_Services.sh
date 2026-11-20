#!/bin/bash
# ==============================================================================
# Tool: Remote Services Manager v1.0 (R36H / playOS / ArkOS)
# Description: Native Linux ncurses TUI to toggle Boot Autostart and Live State
#              of background remote services:
#                - Samba File Sharing (smbd + nmbd)
#                - FileBrowser Web File Manager (Port 80)
#              SSH (sshd) and NTP (timedatectl) are ALWAYS protected.
# Archetype: Archetype 3 (One-Shot Interactive TUI Tool, Single-File Flat)
# Standard: Native /dev/tty1 Console + gptokeyb (Zero fb0_mirror)
# UI Language: 100% Pure ASCII English (Console Font Invariant)
# ==============================================================================

# 1. Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

REAL_SCRIPT="$(realpath "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || echo "$0")"
SCRIPT_NAME="$(basename "$REAL_SCRIPT")"

# ------------------------------------------------------------------------------
# 2. Environment Detection & Gamepad Input Setup (Native /dev/tty1 + gptokeyb)
# ------------------------------------------------------------------------------
IS_SSH=0
if [ -n "$SSH_TTY" ] || [ -n "$SSH_CLIENT" ] || [ -n "$SSH_CONNECTION" ]; then
    IS_SSH=1
fi

GPTOKEYB_PID=""
GPTOKEYB_BIN=""
CHOICE_TMP="/tmp/remote_services_choice.$$"
GPTK_CONF="/tmp/remote_services_keys.gptk"

cleanup() {
    rm -f "$CHOICE_TMP" "$GPTK_CONF" 2>/dev/null || true
    if [ -n "$GPTOKEYB_PID" ]; then
        kill -9 "$GPTOKEYB_PID" 2>/dev/null || true
    fi
    pkill -9 -f "gptokeyb" 2>/dev/null || true
    killall -9 gptokeyb 2>/dev/null || true

    if [ "$IS_SSH" -eq 0 ]; then
        printf "\033c\e[?25h" > /dev/tty1 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM HUP

if [ "$IS_SSH" -eq 0 ]; then
    for cand in "/opt/inttools/gptokeyb" "/usr/local/bin/gptokeyb" "$(command -v gptokeyb 2>/dev/null)"; do
        if [ -n "$cand" ] && [ -x "$cand" ]; then
            GPTOKEYB_BIN="$cand"
            break
        fi
    done

    if [ -n "$GPTOKEYB_BIN" ]; then
        chmod 666 /dev/uinput 2>/dev/null || true
        export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
        pkill -9 -f "gptokeyb" 2>/dev/null || true
        killall -9 gptokeyb 2>/dev/null || true
        sleep 0.1

        # Dynamic A/B Button Mapping (Priority 1: playfe.cfg, Priority 2: ES / Switch_AB)
        OK_BTN="b"
        BACK_BTN="a"
        if [ -f "/home/ark/.config/playfe/playfe.cfg" ]; then
            if grep -qiE '^swap_ab\s*=\s*(true|1)' "/home/ark/.config/playfe/playfe.cfg" 2>/dev/null; then
                OK_BTN="a"
                BACK_BTN="b"
            fi
        elif [ -f "/var/cache/Switch_AB" ] || grep -qi 'name="InvertButtons" value="true"' "/home/ark/.emulationstation/es_settings.cfg" 2>/dev/null; then
            OK_BTN="b"
            BACK_BTN="a"
        else
            OK_BTN="a"
            BACK_BTN="b"
        fi

        cat << EOF > "$GPTK_CONF"
up = up
down = down
left = left
right = right
$OK_BTN = enter
$BACK_BTN = esc
start = enter
select = esc
l1 = pageup
r1 = pagedown
EOF

        TARGET_NAME="$SCRIPT_NAME"
        case "$TARGET_NAME" in
            bash|sh|dash|"") TARGET_NAME="Remote_Services.sh" ;;
        esac

        "$GPTOKEYB_BIN" "$TARGET_NAME" -c "$GPTK_CONF" >/dev/null 2>&1 &
        GPTOKEYB_PID=$!
    fi

    DIALOG_IN="/dev/tty1"
    DIALOG_OUT="/dev/tty1"
    printf "\033c\e[?25l" > /dev/tty1 2>/dev/null || true
    export TERM=linux
else
    DIALOG_IN="/dev/tty"
    DIALOG_OUT="/dev/tty"
fi

# Verify dialog binary
if ! command -v dialog >/dev/null 2>&1; then
    echo "ERROR: 'dialog' is not installed on this system." > "$DIALOG_OUT"
    sleep 3
    exit 1
fi

REMOTE_UNIT="/etc/systemd/system/remote-autostart.service"
REMOTE_ORIG="/etc/systemd/system/remote-autostart.service.orig"
FB_UNIT="/etc/systemd/system/filebrowser.service"

# ------------------------------------------------------------------------------
# 3. Safe Service Inspection & Modification Helpers
# ------------------------------------------------------------------------------
get_ip() {
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip" ] && ip="No Wi-Fi"
    echo "$ip"
}

scan_status() {
    # Samba (smbd + nmbd) Autostart check
    SAMBA_AUTO=0
    if [ -f "$REMOTE_UNIT" ] && systemctl is-enabled --quiet remote-autostart.service 2>/dev/null; then
        if grep -qE 'systemctl start (smbd|nmbd)' "$REMOTE_UNIT" 2>/dev/null; then
            SAMBA_AUTO=1
        fi
    fi
    if systemctl is-enabled --quiet smbd 2>/dev/null || systemctl is-enabled --quiet nmbd 2>/dev/null; then
        SAMBA_AUTO=1
    fi

    # Samba Live status
    SAMBA_LIVE=0
    if systemctl is-active --quiet smbd 2>/dev/null || systemctl is-active --quiet nmbd 2>/dev/null; then
        SAMBA_LIVE=1
    fi

    # FileBrowser Autostart check
    FB_AUTO=0
    if [ -f "$FB_UNIT" ] && systemctl is-enabled --quiet filebrowser.service 2>/dev/null; then
        FB_AUTO=1
    elif [ -f "$REMOTE_UNIT" ] && systemctl is-enabled --quiet remote-autostart.service 2>/dev/null; then
        if grep -q 'filebrowser' "$REMOTE_UNIT" 2>/dev/null; then
            FB_AUTO=1
        fi
    fi

    # FileBrowser Live status
    FB_LIVE=0
    if systemctl is-active --quiet filebrowser.service 2>/dev/null || pgrep -x filebrowser >/dev/null 2>&1; then
        FB_LIVE=1
    fi

    # SSH Live status (Read-Only, Always Protected)
    SSH_LIVE="Stopped"
    if systemctl is-active --quiet ssh.service 2>/dev/null || systemctl is-active --quiet sshd.service 2>/dev/null || pgrep -x sshd >/dev/null 2>&1; then
        SSH_LIVE="Running"
    fi

    [ "$SAMBA_AUTO" -eq 1 ] && SAMBA_AUTO_STR="ON" || SAMBA_AUTO_STR="OFF"
    [ "$SAMBA_LIVE" -eq 1 ] && SAMBA_LIVE_STR="Running" || SAMBA_LIVE_STR="Stopped"
    [ "$FB_AUTO" -eq 1 ] && FB_AUTO_STR="ON" || FB_AUTO_STR="OFF"
    [ "$FB_LIVE" -eq 1 ] && FB_LIVE_STR="Running" || FB_LIVE_STR="Stopped"
    DEV_IP="$(get_ip)"
}

# Safely update /etc/systemd/system/remote-autostart.service without ever touching ssh or timedatectl
update_remote_autostart() {
    local target="$1"  # samba | filebrowser
    local state="$2"   # on | off
    [ -f "$REMOTE_UNIT" ] || return 0

    if [ ! -f "$REMOTE_ORIG" ]; then
        cp -f "$REMOTE_UNIT" "$REMOTE_ORIG" 2>/dev/null || true
    fi

    python3 - "$REMOTE_UNIT" "$target" "$state" << 'PYEOF'
import re, sys

unit_path, target, state = sys.argv[1], sys.argv[2], sys.argv[3]
with open(unit_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

out_lines = []
for line in lines:
    if line.startswith("ExecStart="):
        m = re.match(r'^(ExecStart=/bin/bash -c ")(.*)(")\s*$', line)
        if m:
            prefix, body, suffix = m.group(1), m.group(2), m.group(3)
            # Split commands on '&', preserve non-empty commands
            parts = [p.strip() for p in body.split("&") if p.strip()]

            if target == "samba":
                parts = [p for p in parts if not re.match(r'^systemctl\s+start\s+(smbd|nmbd)(\.service)?$', p)]
                if state == "on":
                    parts.append("systemctl start smbd")
                    parts.append("systemctl start nmbd")
            elif target == "filebrowser":
                parts = [p for p in parts if "filebrowser" not in p]
                if state == "on":
                    parts.append("filebrowser -a 0.0.0.0 -p 80 -d /home/ark/.config/filebrowser.db -r /")

            # Always guarantee ssh.service remains present
            if not any("ssh" in p for p in parts):
                parts.append("systemctl start ssh.service")

            new_body = " & ".join(parts) + " &"
            line = f"{prefix}{new_body}{suffix}\n"
    out_lines.append(line)

with open(unit_path, "w", encoding="utf-8", newline="\n") as f:
    f.writelines(out_lines)
PYEOF
    systemctl daemon-reload >/dev/null 2>&1 || true
}

set_samba() {
    local enable="$1"  # 1=ON, 0=OFF
    if [ "$enable" -eq 1 ]; then
        if [ -f "$REMOTE_UNIT" ]; then
            update_remote_autostart "samba" "on"
            systemctl enable remote-autostart.service >/dev/null 2>&1 || true
        else
            systemctl enable smbd nmbd >/dev/null 2>&1 || true
        fi
        systemctl start smbd nmbd >/dev/null 2>&1 || true
    else
        update_remote_autostart "samba" "off"
        systemctl disable --now smbd nmbd >/dev/null 2>&1 || true
        pkill -x smbd >/dev/null 2>&1 || true
        pkill -x nmbd >/dev/null 2>&1 || true
    fi
    sync
}

set_filebrowser() {
    local enable="$1"  # 1=ON, 0=OFF
    if [ "$enable" -eq 1 ]; then
        if [ -f "$FB_UNIT" ]; then
            # Keep port 80 free from duplicate remote-autostart entry
            update_remote_autostart "filebrowser" "off"
            systemctl enable --now filebrowser.service >/dev/null 2>&1 || true
        else
            update_remote_autostart "filebrowser" "on"
            systemctl enable remote-autostart.service >/dev/null 2>&1 || true
            if ! pgrep -x filebrowser >/dev/null 2>&1 && command -v filebrowser >/dev/null 2>&1; then
                nohup filebrowser -a 0.0.0.0 -p 80 -d /home/ark/.config/filebrowser.db -r / >/dev/null 2>&1 &
            fi
        fi
    else
        if [ -f "$FB_UNIT" ]; then
            systemctl disable --now filebrowser.service >/dev/null 2>&1 || true
        fi
        update_remote_autostart "filebrowser" "off"
        pkill -x filebrowser >/dev/null 2>&1 || true
    fi
    sync
}

show_msg() {
    local title="$1"
    local text="$2"
    local h="${3:-11}"
    local w="${4:-60}"
    dialog --backtitle "Remote Services Manager v1.0 | IP: $DEV_IP" \
        --title "$title" \
        --msgbox "$text" "$h" "$w" < "$DIALOG_IN" > "$DIALOG_OUT" 2>/dev/null
}

# ------------------------------------------------------------------------------
# 4. Main Interactive Loop (Multi-Config Tool: returns to menu after each action)
# ------------------------------------------------------------------------------
while true; do
    scan_status

    if [ "$SAMBA_AUTO" -eq 1 ] || [ "$SAMBA_LIVE" -eq 1 ]; then
        SAMBA_ACTION="0"
        SAMBA_LABEL="Samba (smbd + nmbd)       -> Disable & Stop"
    else
        SAMBA_ACTION="1"
        SAMBA_LABEL="Samba (smbd + nmbd)       -> Enable & Start"
    fi

    if [ "$FB_AUTO" -eq 1 ] || [ "$FB_LIVE" -eq 1 ]; then
        FB_ACTION="0"
        FB_LABEL="FileBrowser (Port 80)     -> Disable & Stop"
    else
        FB_ACTION="1"
        FB_LABEL="FileBrowser (Port 80)     -> Enable & Start"
    fi

    BACKTITLE="Remote Services Manager v1.0 | IP: $DEV_IP | SSH: Protected"
    MENU_PROMPT="\nCurrent Service Status:\n  * Samba (smbd+nmbd) : Boot $SAMBA_AUTO_STR | Now $SAMBA_LIVE_STR\n  * FileBrowser (:80) : Boot $FB_AUTO_STR | Now $FB_LIVE_STR\n  * SSH (sshd :22)    : Protected ($SSH_LIVE)\n\nSelect an action, or press < Exit > (Button B) to quit:"

    dialog \
        --backtitle "$BACKTITLE" \
        --title "Remote Services Manager v1.0" \
        --ok-label "Select" \
        --cancel-label "Exit" \
        --menu "$MENU_PROMPT" \
        19 64 4 \
        "1" "$SAMBA_LABEL" \
        "2" "$FB_LABEL" \
        "3" "Disable All (Gaming Mode  - Max Free RAM/CPU)" \
        "4" "Enable All  (Transfer Mode - Samba + Web UI)" \
        2> "$CHOICE_TMP" < "$DIALOG_IN" > "$DIALOG_OUT"

    RET=$?
    CHOICE=$(cat "$CHOICE_TMP" 2>/dev/null | tr -d ' "\r\n')
    rm -f "$CHOICE_TMP"

    if [ $RET -ne 0 ] || [ -z "$CHOICE" ]; then
        break
    fi

    case "$CHOICE" in
        "1")
            set_samba "$SAMBA_ACTION"
            scan_status
            if [ "$SAMBA_ACTION" -eq 1 ]; then
                show_msg "Samba Enabled" \
                    "\n  [OK] Samba (smbd + nmbd) ENABLED & STARTED!\n\n  * Boot Autostart : $SAMBA_AUTO_STR\n  * Live Status    : $SAMBA_LIVE_STR\n  * Share Path     : \\\\\\\\$DEV_IP\\\\roms\n\n  Press A or Enter to continue." 12 60
            else
                show_msg "Samba Disabled" \
                    "\n  [OK] Samba (smbd + nmbd) DISABLED & STOPPED!\n\n  * Boot Autostart : $SAMBA_AUTO_STR\n  * Live Status    : $SAMBA_LIVE_STR\n  * SSH remains untouched ($SSH_LIVE)\n\n  Press A or Enter to continue." 12 60
            fi
            ;;
        "2")
            set_filebrowser "$FB_ACTION"
            scan_status
            if [ "$FB_ACTION" -eq 1 ]; then
                show_msg "FileBrowser Enabled" \
                    "\n  [OK] FileBrowser (Port 80) ENABLED & STARTED!\n\n  * Boot Autostart : $FB_AUTO_STR\n  * Live Status    : $FB_LIVE_STR\n  * Web URL        : http://$DEV_IP/\n\n  Press A or Enter to continue." 12 60
            else
                show_msg "FileBrowser Disabled" \
                    "\n  [OK] FileBrowser (Port 80) DISABLED & STOPPED!\n\n  * Boot Autostart : $FB_AUTO_STR\n  * Live Status    : $FB_LIVE_STR\n  * SSH remains untouched ($SSH_LIVE)\n\n  Press A or Enter to continue." 12 60
            fi
            ;;
        "3")
            set_samba 0
            set_filebrowser 0
            scan_status
            show_msg "Gaming Mode Active" \
                "\n  [OK] All Remote File Services DISABLED & STOPPED!\n\n  * Samba (smbd+nmbd) : Boot $SAMBA_AUTO_STR | Now $SAMBA_LIVE_STR\n  * FileBrowser (:80) : Boot $FB_AUTO_STR | Now $FB_LIVE_STR\n  * SSH (sshd :22)    : Protected ($SSH_LIVE)\n\n  Maximum RAM/CPU freed for gaming.\n  Press A or Enter to continue." 13 62
            ;;
        "4")
            set_samba 1
            set_filebrowser 1
            scan_status
            show_msg "Transfer Mode Active" \
                "\n  [OK] All Remote File Services ENABLED & STARTED!\n\n  * Samba (smbd+nmbd) : Boot $SAMBA_AUTO_STR | Now $SAMBA_LIVE_STR\n  * FileBrowser (:80) : Boot $FB_AUTO_STR | Now $FB_LIVE_STR\n  * Web UI            : http://$DEV_IP/\n  * SMB Share         : \\\\\\\\$DEV_IP\\\\roms\n\n  Press A or Enter to continue." 14 62
            ;;
    esac
done

exit 0
