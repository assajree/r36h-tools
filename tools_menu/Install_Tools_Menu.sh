#!/bin/bash
# ==============================================================================
# Installer: Enable Tools Menu on playOS 4.0 (playfe) for R36H
# Description: Registers the <name>tools</name> category (/roms/tools/) in
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
TOOLS_DIR="/roms/tools"
IMAGES_DIR="/roms/tools/images"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

clear > /dev/tty1 2>/dev/null || true
clear 2>/dev/null || true

print_msg "=================================================="
print_msg "      ENABLE TOOLS MENU FOR R36H (playOS)         "
print_msg "=================================================="
print_msg ""

# 1. Verify es_systems.cfg exists
print_msg "[1/3] ตรวจสอบไฟล์ตั้งค่าเมนูระบบ ($ES_SYSTEMS_CFG)..."
if [ ! -f "$ES_SYSTEMS_CFG" ]; then
    print_msg " [!] ไม่พบไฟล์ $ES_SYSTEMS_CFG"
    sleep 3
    exit 1
fi

# 2. Ensure /roms/tools and /roms/tools/images exist
mkdir -p "$TOOLS_DIR" "$IMAGES_DIR"
chown ark:ark "$TOOLS_DIR" "$IMAGES_DIR" 2>/dev/null || true

# 3. Add <name>tools</name> block to es_systems.cfg if not present
print_msg "[2/3] เปิดใช้งานหมวดหมู่ TOOLS ใน $ES_SYSTEMS_CFG..."
if grep -q "<name>tools</name>" "$ES_SYSTEMS_CFG" 2>/dev/null; then
    print_msg " [*] หมวดหมู่ TOOLS ถูกเปิดใช้งานไว้แล้ว"
else
    cp -f "$ES_SYSTEMS_CFG" "${ES_SYSTEMS_CFG}.bak" 2>/dev/null || true
    python3 - << 'PYEOF'
import os

es_cfg = "/etc/emulationstation/es_systems.cfg"
with open(es_cfg, "r", encoding="utf-8", errors="ignore") as f:
    content = f.read()

if "<name>tools</name>" not in content and "</systemList>" in content:
    tools_block = """\t<system>
\t\t<name>tools</name>
\t\t<fullname>Tools</fullname>
\t\t<path>/roms/tools/</path>
\t\t<extension>.sh .SH</extension>
\t\t<command>sudo bash %ROM%</command>
\t\t<platform>pc</platform>
\t\t<theme>tools</theme>
\t</system>
</systemList>"""
    content = content.replace("</systemList>", tools_block)
    with open(es_cfg, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
PYEOF
    chown ark:ark "$ES_SYSTEMS_CFG" 2>/dev/null || true
    print_msg " [✓] เพิ่มหมวดหมู่ TOOLS ลงใน $ES_SYSTEMS_CFG สำเร็จ"
fi

# 3.1 Hide tools_menu's own .sh scripts in /roms/tools/gamelist.xml
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

# 4. Restart playfe.service so the menu updates immediately
print_msg "[3/3] กำลังรีเฟรชหน้าจอเมนู playOS (playfe.service)..."
if systemctl is-active --quiet playfe.service 2>/dev/null; then
    systemctl restart playfe.service 2>/dev/null || true
    print_msg " [✓] รีสตาร์ท playfe.service เรียบร้อยแล้ว"
else
    print_msg " [*] ไม่ได้รัน playfe.service อยู่ (การตั้งค่าจะมีผลเมื่อเข้าสู่เมนู)"
fi

print_msg ""
print_msg "=================================================="
print_msg "        [✓] เปิดใช้งานเมนู TOOLS สำเร็จ!            "
print_msg "=================================================="
print_msg "  • หมวดหมู่: TOOLS (/roms/tools/)"
print_msg "  • รูปปกแอป: /roms/tools/images/<ชื่อไฟล์>-thumb.png"
print_msg "=================================================="
sleep 3
exit 0
