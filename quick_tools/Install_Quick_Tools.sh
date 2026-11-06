#!/bin/bash
# ==============================================================================
# Installer: Quick Tools Shortcut Installer for R36H (playOS)
# Description: Installs Create_Quick_Tools.sh into /roms/tools/ and runs it
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="/roms/tools"

echo "=================================================="
echo "      INSTALLING QUICK TOOLS SHORTCUT TOOL        "
echo "=================================================="

if [ ! -d "$TARGET_DIR" ]; then
    echo "[!] Creating $TARGET_DIR..."
    mkdir -p "$TARGET_DIR"
fi

echo "[+] Copying Create_Quick_Tools.sh to $TARGET_DIR..."
cp "$SCRIPT_DIR/Create_Quick_Tools.sh" "$TARGET_DIR/Create_Quick_Tools.sh"
chmod +x "$TARGET_DIR/Create_Quick_Tools.sh"
chown ark:ark "$TARGET_DIR/Create_Quick_Tools.sh"

echo "[+] Executing initial setup..."
bash "$TARGET_DIR/Create_Quick_Tools.sh"

echo "[OK] Installation completed successfully!"
exit 0
