#!/bin/bash
# ==============================================================================
# Tool: Check Wi-Fi Signal & Status (iwconfig wlan0)
# Target: R36H / playOS (ARM64)
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

print_msg() {
    echo -e "$1"
    if [ -w /dev/tty1 ]; then
        echo -e "$1" > /dev/tty1 2>/dev/null || true
    fi
}

clear > /dev/tty1 2>/dev/null || true

print_msg "=================================================="
print_msg "         R36H Wi-Fi Signal & Status Check         "
print_msg "=================================================="

# ตรวจสอบการมีอยู่ของอินเทอร์เฟซ wlan0
if ! ip link show wlan0 > /dev/null 2>&1; then
    print_msg "\n [X] ไม่พบอุปกรณ์ Wi-Fi (wlan0)"
    print_msg "     กรุณาตรวจสอบว่าเสียบ USB Wi-Fi Dongle แน่นดีแล้วหรือไม่"
    print_msg "=================================================="
    print_msg "กำลังกลับสู่หน้ารายการเมนูใน 10 วินาที..."
    read -t 10 -n 1 -s -r 2>/dev/null || sleep 10
    exit 1
fi

print_msg "\n[1] ข้อมูลสัญญาณวิทยุ (iwconfig wlan0):"
print_msg "--------------------------------------------------"
IW_OUT=$(iwconfig wlan0 2>&1)
print_msg "$IW_OUT"
print_msg "--------------------------------------------------"

# สกัดข้อมูลสำคัญ
SSID=$(echo "$IW_OUT" | grep -oP 'ESSID:"\K[^"]+')
BITRATE=$(echo "$IW_OUT" | grep -oP 'Bit Rate=\K[^ ]+ [^ ]+')
QUALITY=$(echo "$IW_OUT" | grep -oP 'Link Quality=\K[^ ]+')
SIGNAL=$(echo "$IW_OUT" | grep -oP 'Signal level=\K[^ ]+ dBm')
IP_ADDR=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

print_msg "\n[2] สรุปสถานะการเชื่อมต่อ:"
if [ -n "$SSID" ]; then
    print_msg " - Wi-Fi Name (SSID) : $SSID"
else
    print_msg " - Wi-Fi Name (SSID) : [!] ยังไม่ได้เชื่อมต่อ Wi-Fi"
fi

if [ -n "$IP_ADDR" ]; then
    print_msg " - IP Address (wlan0): $IP_ADDR"
else
    print_msg " - IP Address (wlan0): [!] ยังไม่ได้รับ IP"
fi

[ -n "$BITRATE" ] && print_msg " - ความเร็วลิงก์สูงสุด : $BITRATE"
[ -n "$QUALITY" ] && print_msg " - คุณภาพสัญญาณ     : $QUALITY"
[ -n "$SIGNAL" ]  && print_msg " - ความแรงสัญญาณ (dBm): $SIGNAL"

# แนะนำระดับสัญญาณ
if [ -n "$SIGNAL" ]; then
    DBM_VAL=$(echo "$SIGNAL" | tr -dc '0-9-')
    print_msg ""
    if [ "$DBM_VAL" -ge -55 ] 2>/dev/null; then
        print_msg " [✓] คุณภาพสัญญาณ: ยอดเยี่ยม (ใกล้เราเตอร์ / ความเร็วเต็มสปีด)"
    elif [ "$DBM_VAL" -ge -70 ] 2>/dev/null; then
        print_msg " [✓] คุณภาพสัญญาณ: ปานกลาง (ใช้งานได้เสถียรปกติ)"
    elif [ "$DBM_VAL" -ge -80 ] 2>/dev/null; then
        print_msg " [!] คุณภาพสัญญาณ: ค่อนข้างอ่อน (อาจมีแกว่งหรือหลุดบ้าง)"
    else
        print_msg " [X] คุณภาพสัญญาณ: อ่อนมาก (แนะนำให้ขยับใกล้เราเตอร์มากขึ้น)"
    fi
fi

print_msg "=================================================="
print_msg "กดปุ่มใดๆ หรือรอ 15 วินาทีเพื่อออก..."
read -t 15 -n 1 -s -r 2>/dev/null || sleep 15
