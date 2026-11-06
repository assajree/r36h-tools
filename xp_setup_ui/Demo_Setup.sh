#!/bin/bash
# ==============================================================================
# Tool: Universal Setup UI Engine - Demo & Template Script
# Description: Copy xp_setup_ui (binary) into your tool's app/ or daemon/
#              subfolder, then customize the inline config block below.
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

export SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Locate xp_setup_ui binary (supports current folder, daemon/, or app/)
if [ -x "$SCRIPT_DIR/xp_setup_ui" ]; then
    UI_BIN="$SCRIPT_DIR/xp_setup_ui"
elif [ -x "$SCRIPT_DIR/daemon/xp_setup_ui" ]; then
    UI_BIN="$SCRIPT_DIR/daemon/xp_setup_ui"
elif [ -x "$SCRIPT_DIR/app/xp_setup_ui" ]; then
    UI_BIN="$SCRIPT_DIR/app/xp_setup_ui"
else
    echo "[!] Error: xp_setup_ui binary not found."
    exit 1
fi

# Always resume playfe / FindManager when script exits
cleanup_resume() {
    pkill -CONT -f "FindManager|playfe" 2>/dev/null || true
}
trap cleanup_resume EXIT INT TERM

# Pause playfe / FindManager so KMSDRM screen doesn't flicker
pkill -STOP -f "FindManager|playfe" 2>/dev/null || true

# ==============================================================================
# Custom Wizard Configuration
#   - UP / DOWN    : Select Option ([X])
#   - LEFT / RIGHT : Select Action Button ([ OK ] / [ Back ] / [ Exit ])
#   - Button A / B : Trigger Focused Action Button
# ==============================================================================
"$UI_BIN" - << 'EOF'
header = My Custom Tool Setup

# ------------------------------------------------------------------------------
# Step 1: Choose Operation
# ------------------------------------------------------------------------------
[page]
id = step1
title = Step 1: Select Action
var = MY_ACTION
default = 0
option = install   | next          | Install Tool             | Install and configure My Custom Tool on your R36H.
option = uninstall | run:uninstall | Uninstall Tool           | Remove My Custom Tool and restore default settings.

# ------------------------------------------------------------------------------
# Step 2: Choose Mode
# ------------------------------------------------------------------------------
[page]
id = step2
title = Step 2: Select Mode
var = MY_MODE
default = 0
option = fast     | run:install | Option 1 (Fast Mode)     | Optimized for maximum speed and low memory usage.
option = standard | run:install | Option 2 (Standard Mode) | Balanced settings recommended for most users.
option = safe     | run:install | Option 3 (Safe Mode)     | Extra safety checks enabled.

# ------------------------------------------------------------------------------
# Progress Workflow: Install
# ------------------------------------------------------------------------------
[progress]
id = install
line1 = Please wait while Setup configures your tool
line2 = on the R36H playOS system.
line3 = This will only take a few seconds.
box_title = Setup is installing files...
step = 35  | Preparing environment... | sleep 1
step = 70  | Applying mode: $MY_MODE  | sleep 1
step = 100 | Finalizing setup...      | sleep 1
complete_title = Installation Complete
complete_line = Tool Status   : INSTALLED
complete_line = Selected Mode : $MY_MODE
complete_line = Press A or B on [ OK ] to return to playOS.

# ------------------------------------------------------------------------------
# Progress Workflow: Uninstall
# ------------------------------------------------------------------------------
[progress]
id = uninstall
line1 = Please wait while Setup removes files
line2 = from your R36H console.
line3 = This will only take a few seconds.
box_title = Setup is removing files...
step = 50  | Removing files...   | sleep 1
step = 100 | Cleaning up...      | sleep 1
complete_title = Uninstall Complete
complete_line = My Custom Tool has been removed.
EOF

pkill -CONT -f "FindManager|playfe" 2>/dev/null || true
exit 0
