#!/bin/bash
# ==============================================================================
# Tool: Power Button Hold-to-Shutdown Setup Wizard (Universal Windows XP UI)
# Description: Uses the reusable xp_setup_ui binary (Direct SDL2 KMSDRM)
#              located in the daemon/ subfolder, configured via inline
#              INI-style blocks for header, step_name, options, and progress.
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

export SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$SCRIPT_DIR/daemon" ]; then
    export DAEMON_DIR="$SCRIPT_DIR/daemon"
elif [ -d "$SCRIPT_DIR/app" ]; then
    export DAEMON_DIR="$SCRIPT_DIR/app"
elif [ -d "$SCRIPT_DIR/power_button/daemon" ]; then
    export DAEMON_DIR="$SCRIPT_DIR/power_button/daemon"
else
    export DAEMON_DIR="$SCRIPT_DIR"
fi

UI_BIN="$DAEMON_DIR/xp_setup_ui"
UI_SRC="$DAEMON_DIR/xp_setup_ui.c"

# Ensure frontend / FindManager are always resumed on exit
cleanup_resume() {
    pkill -CONT -f "FindManager|playfe" 2>/dev/null || true
}
trap cleanup_resume EXIT INT TERM

# Auto-compile xp_setup_ui binary inside daemon/ subfolder if needed
if [ -f "$UI_SRC" ]; then
    if [ ! -x "$UI_BIN" ] || [ "$UI_SRC" -nt "$UI_BIN" ]; then
        gcc -O2 "$UI_SRC" -lSDL2 -o "$UI_BIN" 2>/dev/null || true
        chmod 755 "$UI_BIN" 2>/dev/null || true
    fi
fi

if [ ! -x "$UI_BIN" ]; then
    echo "[!] Error: Cannot find or compile xp_setup_ui binary in $DAEMON_DIR"
    exit 1
fi

# Pause playfe / FindManager so they stop swapping KMSDRM buffers while XP UI is active
pkill -STOP -f "FindManager|playfe" 2>/dev/null || true

# ==============================================================================
# Launch Universal Windows XP Setup UI Engine with Custom Multi-Page Config
# Controls:
#   - UP / DOWN    : Select Option ([X])
#   - LEFT / RIGHT : Select Action Button ([ OK ] / [ Back ] / [ Exit ])
#   - Button A / B : Trigger Focused Action Button
# ==============================================================================
"$UI_BIN" - << 'EOF'
header = Power Button Setup

# ------------------------------------------------------------------------------
# Step 1: Select Operation Mode (Install / Uninstall)
# ------------------------------------------------------------------------------
[page]
id = mode
title = Step 1: Select Action
var = SETUP_MODE
default = 0
option = install   | next          | Install / Configure      | Set hold duration and countdown timeout, then enable service.
option = uninstall | run:uninstall | Uninstall Service        | Stop and remove Power Button daemon from your R36H console.

# ------------------------------------------------------------------------------
# Step 2: Select Power Button Hold Duration (1.0s, 2.0s, 3.0s)
# ------------------------------------------------------------------------------
[page]
id = hold
title = Step 2: Hold Duration
var = HOLD_SEC
default = 0
option = 1.0 | next | 1 Second  (Recommended)  | Hold Power for 1s to start countdown (short press sleeps).
option = 2.0 | next | 2 Seconds (Medium)       | Hold Power for 2s to start countdown screen.
option = 3.0 | next | 3 Seconds (Safe)         | Hold Power for 3s to start countdown screen.

# ------------------------------------------------------------------------------
# Step 3: Select Shutdown Countdown Timeout (3s, 5s, 10s)
# ------------------------------------------------------------------------------
[page]
id = timeout
title = Step 3: Countdown Timeout
var = TIMEOUT_SEC
default = 1
option = 3  | run:install | 3 Seconds  (Fast)        | Wait 3s on countdown screen before shutting down.
option = 5  | run:install | 5 Seconds  (Standard)    | Wait 5s on countdown screen before shutting down.
option = 10 | run:install | 10 Seconds (Safe)        | Wait 10s on countdown screen before shutting down.

# ------------------------------------------------------------------------------
# Progress Workflow: Install & Configure
# ------------------------------------------------------------------------------
[progress]
id = install
line1 = Please wait while Setup copies files
line2 = to the playOS installation folders.
line3 = This will only take a few seconds to complete.
box_title = Setup is copying files...
step = 20  | Stopping: power-button-daemon  | systemctl stop power-button-daemon.service >/dev/null 2>&1 || true
step = 45  | Copying: power_button_daemon   | cp -f "$DAEMON_DIR/power_button_daemon.py" /usr/local/bin/power_button_daemon.py && sed -i "s/^HOLD_SECONDS = .*/HOLD_SECONDS = $HOLD_SEC/" /usr/local/bin/power_button_daemon.py && sed -i "s/^COUNTDOWN_SECONDS = .*/COUNTDOWN_SECONDS = $TIMEOUT_SEC/" /usr/local/bin/power_button_daemon.py && chmod 755 /usr/local/bin/power_button_daemon.py
step = 70  | Copying: countdown_ui.dll      | if [ -f "$DAEMON_DIR/countdown_ui" ]; then cp -f "$DAEMON_DIR/countdown_ui" /usr/local/bin/countdown_ui && chmod 755 /usr/local/bin/countdown_ui; elif [ -f "$DAEMON_DIR/countdown_ui.c" ] && [ ! -f /usr/local/bin/countdown_ui ]; then gcc -O2 "$DAEMON_DIR/countdown_ui.c" -lSDL2 -o /usr/local/bin/countdown_ui 2>/dev/null && chmod 755 /usr/local/bin/countdown_ui; fi
step = 85  | Copying: power-button.service  | cp -f "$DAEMON_DIR/power-button-daemon.service" /etc/systemd/system/power-button-daemon.service && chmod 644 /etc/systemd/system/power-button-daemon.service && if [ -f /etc/systemd/logind.conf ]; then if grep -q '^HandlePowerKey=' /etc/systemd/logind.conf; then sed -i 's/^HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf; else echo 'HandlePowerKey=ignore' >> /etc/systemd/logind.conf; fi; fi
step = 100 | Starting: systemd service      | systemctl daemon-reload && systemctl enable --now power-button-daemon.service >/dev/null 2>&1
complete_title = Installation Complete
complete_line = Service Status     : ACTIVE (Running in background)
complete_line = Hold Power Trigger : $HOLD_SEC Seconds
complete_line = Countdown Timeout  : $TIMEOUT_SEC Seconds before poweroff
complete_line = Cancel Shutdown    : Press ANY button during countdown

# ------------------------------------------------------------------------------
# Progress Workflow: Uninstall & Restore
# ------------------------------------------------------------------------------
[progress]
id = uninstall
line1 = Please wait while Setup removes files
line2 = from the playOS installation folders.
line3 = This will only take a few seconds to complete.
box_title = Setup is removing files...
step = 35  | Stopping: power-button-daemon  | systemctl stop power-button-daemon.service >/dev/null 2>&1 || true; systemctl disable power-button-daemon.service >/dev/null 2>&1 || true
step = 75  | Removing: system files         | rm -f /etc/systemd/system/power-button-daemon.service /usr/local/bin/power_button_daemon.py /usr/local/bin/countdown_ui
step = 100 | Reloading: systemd daemon      | systemctl daemon-reload >/dev/null 2>&1 || true
complete_title = Uninstall Complete
complete_line = Power Button Hold-to-Shutdown Daemon has been
complete_line = completely removed from your R36H console.
complete_line = Default playOS power button behavior is restored.
EOF

# Resume playfe / FindManager immediately
pkill -CONT -f "FindManager|playfe" 2>/dev/null || true

# Hide power_button's own .sh scripts from playfe TOOLS menu via gamelist.xml
if command -v python3 >/dev/null 2>&1; then
    SCRIPT_DIR="$SCRIPT_DIR" python3 - << 'PYEOF'
import os, xml.etree.ElementTree as ET
tools_dir = "/roms/tools"
script_dir = os.path.realpath(os.environ.get("SCRIPT_DIR", ""))
real_tools = os.path.realpath(tools_dir)
if os.path.isdir(tools_dir) and script_dir.startswith(real_tools + "/"):
    gamelist_path = os.path.join(tools_dir, "gamelist.xml")
    root = None
    if os.path.exists(gamelist_path):
        try: root = ET.parse(gamelist_path).getroot()
        except Exception: root = None
    if root is None: root = ET.Element("gameList")
    existing = {g.find("path").text.strip().lstrip("./"): g for g in root.findall("game") if g.find("path") is not None and g.find("path").text}
    for dp, _, fns in os.walk(script_dir):
        for fn in sorted(fns):
            if fn.lower().endswith(".sh"):
                rel_p = os.path.relpath(os.path.join(dp, fn), real_tools).replace("\\", "/")
                g = existing.get(rel_p)
                if g is None:
                    g = ET.SubElement(root, "game")
                    ET.SubElement(g, "path").text = "./" + rel_p
                    ET.SubElement(g, "name").text = os.path.splitext(fn)[0]
                h = g.find("hidden")
                if h is None: h = ET.SubElement(g, "hidden")
                h.text = "true"
    ET.indent(root, space="\t")
    with open(gamelist_path, "w", encoding="utf-8", newline="\n") as f:
        f.write('<?xml version="1.0"?>\n' + ET.tostring(root, encoding="unicode") + "\n")
PYEOF
    chown ark:ark /roms/tools/gamelist.xml 2>/dev/null || true
fi
exit 0
