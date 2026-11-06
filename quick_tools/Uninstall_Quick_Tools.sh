#!/bin/bash
# ==============================================================================
# Tool: Quick Tools Shortcut Uninstaller for R36H (playOS)
# Description: Safely unmounts and removes /roms/00_tools, cleans /etc/fstab,
#              and removes terminal alias 'cdt'
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
print_msg "     UNINSTALLING QUICK TOOLS SHORTCUT (00_tools) "
print_msg "=================================================="
print_msg ""

DST_DIR="/roms/00_tools"
LEGACY_RUNNER="/roms/tools/Create_Quick_Tools.sh"

# 1. Unmount /roms/00_tools if mounted
if mountpoint -q "$DST_DIR" 2>/dev/null; then
    print_msg "[+] Unmounting $DST_DIR (lazy unmount)..."
    umount -l "$DST_DIR" 2>/dev/null || true
    if [ $? -eq 0 ]; then
        print_msg "[OK] Unmounted $DST_DIR successfully."
    else
        print_msg "[!] Warning: Failed to unmount $DST_DIR."
    fi
else
    print_msg "[*] $DST_DIR is not currently mounted."
fi

# 2. Remove mount point directory if empty
if [ -d "$DST_DIR" ]; then
    print_msg "[+] Removing directory: $DST_DIR..."
    rmdir "$DST_DIR" 2>/dev/null || rm -rf "$DST_DIR" 2>/dev/null || true
    print_msg "[OK] Directory removed."
fi

# 3. Remove entry from /etc/fstab
if grep -q "00_tools" /etc/fstab 2>/dev/null; then
    print_msg "[+] Removing 00_tools persistence entry from /etc/fstab..."
    sed -i '/00_tools/d' /etc/fstab
    print_msg "[OK] Persistence removed from /etc/fstab."
else
    print_msg "[*] No 00_tools entry found in /etc/fstab."
fi

# 4. Remove alias 'cdt' from .bashrc files
remove_alias() {
    local target_rc="$1"
    if [ -f "$target_rc" ] && grep -q "alias cdt=" "$target_rc" 2>/dev/null; then
        print_msg "[+] Removing 'cdt' alias from $target_rc..."
        sed -i '/alias cdt=/d' "$target_rc"
        print_msg "[OK] Removed alias from $target_rc."
    fi
}

remove_alias "/home/ark/.bashrc"
remove_alias "/root/.bashrc"

# 5. Remove legacy runner if present
if [ -f "$LEGACY_RUNNER" ]; then
    print_msg "[+] Removing legacy runner: $LEGACY_RUNNER..."
    rm -f "$LEGACY_RUNNER"
    print_msg "[OK] Legacy runner removed."
fi

print_msg ""
print_msg "=================================================="
print_msg "           UNINSTALL COMPLETE!                    "
print_msg "=================================================="
print_msg ""
print_msg "  [✓] /roms/00_tools unmounted and removed"
print_msg "  [✓] /etc/fstab entry cleaned"
print_msg "  [✓] Terminal alias 'cdt' removed"
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
