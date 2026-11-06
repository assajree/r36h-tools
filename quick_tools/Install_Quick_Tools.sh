#!/bin/bash
# ==============================================================================
# Tool: Quick Tools Shortcut Installer for R36H (playOS)
# Description: Creates a top-level persistent shortcut (/roms/00_tools)
#              bound to /roms/tools for fast file manager access
# Author: playOS Tools Suite
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

# Dual-Output Messaging Helper
print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1
    fi
}

# Clear /dev/tty1 if available for clean display
if [ -w /dev/tty1 ]; then
    clear > /dev/tty1 2>/dev/null
fi

print_msg "=================================================="
print_msg "      INSTALLING QUICK TOOLS SHORTCUT (00_tools)  "
print_msg "=================================================="
print_msg ""
print_msg "[*] Initializing shortcut configuration..."

SRC_DIR="/roms/tools"
DST_DIR="/roms/00_tools"
FSTAB_ENTRY="/roms/tools /roms/00_tools none nofail,x-systemd.device-timeout=7,bind 0 0"

# 1. Clean up legacy standalone runner if previously installed
LEGACY_RUNNER="/roms/tools/Create_Quick_Tools.sh"
if [ -f "$LEGACY_RUNNER" ]; then
    print_msg "[+] Cleaning up legacy runner: $LEGACY_RUNNER..."
    rm -f "$LEGACY_RUNNER"
fi

# 2. Source validation
if [ ! -d "$SRC_DIR" ]; then
    print_msg "[!] Warning: Source directory $SRC_DIR does not exist. Creating it..."
    mkdir -p "$SRC_DIR"
fi

# 3. Create Mount Point
if [ ! -d "$DST_DIR" ]; then
    print_msg "[+] Creating top directory: $DST_DIR"
    mkdir -p "$DST_DIR"
else
    print_msg "[*] Directory $DST_DIR already exists."
fi

# 4. Apply Bind Mount if not currently mounted
if mountpoint -q "$DST_DIR"; then
    print_msg "[*] Bind Mount: Already mounted and active."
else
    print_msg "[+] Mounting $SRC_DIR to $DST_DIR..."
    mount --bind "$SRC_DIR" "$DST_DIR"
    if [ $? -eq 0 ]; then
        print_msg "[OK] Bind Mount activated successfully."
    else
        print_msg "[!] Error: Failed to bind mount $DST_DIR"
    fi
fi

# 5. Configure Persistence in /etc/fstab
if grep -q "00_tools" /etc/fstab 2>/dev/null; then
    print_msg "[*] Persistence: /etc/fstab entry already configured."
else
    print_msg "[+] Adding persistent entry to /etc/fstab..."
    echo "$FSTAB_ENTRY" >> /etc/fstab
    print_msg "[OK] Persistence enabled across reboots."
fi

# 6. Configure Terminal Alias (cdt) in .bashrc for ark & root
add_alias() {
    local target_rc="$1"
    if [ -f "$target_rc" ]; then
        if grep -q "alias cdt=" "$target_rc"; then
            print_msg "[*] Terminal Alias: 'cdt' command already present in $target_rc."
        else
            print_msg "[+] Adding 'cdt' alias to $target_rc..."
            echo "alias cdt='cd /roms/tools'" >> "$target_rc"
            print_msg "[OK] Terminal shortcut 'cdt' added to $target_rc."
        fi
    fi
}

add_alias "/home/ark/.bashrc"
add_alias "/root/.bashrc"

print_msg ""
print_msg "=================================================="
print_msg "           CONFIGURATION COMPLETE!                "
print_msg "=================================================="
print_msg ""
print_msg "  [✓] /roms/00_tools is now at the TOP of your files"
print_msg "  [✓] Persistent across reboots (/etc/fstab)"
print_msg "  [✓] Type 'cdt' in terminal to jump to tools"
print_msg ""
print_msg "Returning to EmulationStation in 5 seconds..."

for i in 5 4 3 2 1; do
    echo -n "$i... "
    if [ -w /dev/tty1 ]; then
        echo -n "$i... " > /dev/tty1
    fi
    sleep 1
done

print_msg ""
if [ -w /dev/tty1 ]; then
    clear > /dev/tty1 2>/dev/null
fi
exit 0
