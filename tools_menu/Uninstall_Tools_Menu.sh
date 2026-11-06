#!/bin/bash
# ==============================================================================
# Uninstaller: Disable Tools Menu on playOS 4.0 (playfe) for R36H
# Description: Removes the <name>tools</name> category from
#              /etc/emulationstation/es_systems.cfg and restarts playfe.service.
# Author: playOS Tools Suite
# Archetype: Archetype 4 (System Configuration)
# ==============================================================================

# Root Privilege Escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

ES_SYSTEMS_CFG="/etc/emulationstation/es_systems.cfg"

clear > /dev/tty1 2>/dev/null || true
clear 2>/dev/null || true

print_msg "=================================================="
print_msg "      DISABLE TOOLS MENU FOR R36H (playOS)        "
print_msg "=================================================="
print_msg ""

print_msg "[1/2] กำลังนำหมวดหมู่ TOOLS ออกจาก $ES_SYSTEMS_CFG..."
if [ -f "$ES_SYSTEMS_CFG" ] && grep -q "<name>tools</name>" "$ES_SYSTEMS_CFG" 2>/dev/null; then
    python3 - << 'PYEOF'
import re

es_cfg = "/etc/emulationstation/es_systems.cfg"
with open(es_cfg, "r", encoding="utf-8", errors="ignore") as f:
    content = f.read()

pattern = re.compile(
    r"\s*<system>\s*<name>tools</name>.*?</system>",
    re.DOTALL,
)
new_content = pattern.sub("", content)
with open(es_cfg, "w", encoding="utf-8", newline="\n") as f:
    f.write(new_content)
PYEOF
    chown ark:ark "$ES_SYSTEMS_CFG" 2>/dev/null || true
    print_msg " [✓] นำหมวดหมู่ TOOLS ออกจาก $ES_SYSTEMS_CFG เรียบร้อย"
else
    print_msg " [-] ไม่พบหมวดหมู่ TOOLS ใน $ES_SYSTEMS_CFG (ข้าม)"
fi

print_msg "[2/2] กำลังรีเฟรชหน้าจอเมนู playOS (playfe.service)..."
if systemctl is-active --quiet playfe.service 2>/dev/null; then
    systemctl restart playfe.service 2>/dev/null || true
    print_msg " [✓] รีสตาร์ท playfe.service เรียบร้อยแล้ว"
fi

print_msg ""
print_msg "=================================================="
print_msg "        [✓] ปิดการแสดงผลเมนู TOOLS สำเร็จ!         "
print_msg "=================================================="
sleep 3
exit 0
