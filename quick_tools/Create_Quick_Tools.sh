#!/bin/bash
# ==============================================================================
# Tool: Create Quick Tools Shortcut for R36H (playOS)
# Description: Creates a top-level persistent shortcut (00_tools) for /roms/tools
# Author: playOS Tools Suite
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

# Dual-Output Handling (Display to /dev/tty1 if available)
if [ -c /dev/tty1 ]; then
    exec > /dev/tty1 2>&1
fi

# Clear screen for clean UI
clear

echo "=================================================="
echo "          R36H QUICK TOOLS SHORTCUT               "
echo "=================================================="
echo ""
echo "[*] Initializing shortcut configuration..."
echo ""

# 1. Target and Source validation
SRC_DIR="/roms/tools"
DST_DIR="/roms/00_tools"

if [ ! -d "$SRC_DIR" ]; then
    echo "[!] Error: Source directory $SRC_DIR does not exist!"
    sleep 5
    exit 1
fi

# 2. Create Mount Point
if [ ! -d "$DST_DIR" ]; then
    echo "[+] Creating top directory: $DST_DIR"
    mkdir -p "$DST_DIR"
else
    echo "[*] Directory $DST_DIR already exists."
fi

# 3. Apply Bind Mount if not currently mounted
if mountpoint -q "$DST_DIR"; then
    echo "[*] Bind Mount: Already mounted and active."
else
    echo "[+] Mounting $SRC_DIR to $DST_DIR..."
    mount --bind "$SRC_DIR" "$DST_DIR"
    if [ $? -eq 0 ]; then
        echo "[OK] Bind Mount activated successfully."
    else
        echo "[!] Error: Failed to bind mount $DST_DIR"
    fi
fi

# 4. Configure Persistence in /etc/fstab
FSTAB_ENTRY="/roms/tools /roms/00_tools none nofail,x-systemd.device-timeout=7,bind 0 0"
if grep -q "00_tools" /etc/fstab; then
    echo "[*] Persistence: /etc/fstab entry already configured."
else
    echo "[+] Adding persistent entry to /etc/fstab..."
    echo "$FSTAB_ENTRY" >> /etc/fstab
    echo "[OK] Persistence enabled across reboots."
fi

# 5. Configure Terminal Alias (cdt) in .bashrc
BASHRC_FILE="/home/ark/.bashrc"
if [ -f "$BASHRC_FILE" ]; then
    if grep -q "alias cdt=" "$BASHRC_FILE"; then
        echo "[*] Terminal Alias: 'cdt' command already present."
    else
        echo "[+] Adding 'cdt' alias to $BASHRC_FILE..."
        echo "alias cdt='cd /roms/tools'" >> "$BASHRC_FILE"
        echo "[OK] Terminal shortcut 'cdt' added."
    fi
fi

echo ""
echo "=================================================="
echo "           CONFIGURATION COMPLETE!                "
echo "=================================================="
echo ""
echo "  [✓] /roms/00_tools is now at the TOP of your files"
echo "  [✓] Persistent across reboots (/etc/fstab)"
echo "  [✓] Type 'cdt' in terminal to jump to tools"
echo ""
echo "Returning to EmulationStation in 5 seconds..."

for i in 5 4 3 2 1; do
    echo -n "$i... "
    sleep 1
done
echo ""

clear
exit 0
