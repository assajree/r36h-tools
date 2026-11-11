#!/bin/bash

#-----------------------------------#
#    Install Realtek Bluetooth      #
#  + Wi-Fi firmware for dArkOS      #
#            By Jason               #
#-----------------------------------#

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SRC_BASE="/roms/tools/rtl"
DST_BASE="/lib/firmware"

clear > /dev/tty1
echo "--------------------------------------" > /dev/tty1
echo "|   Realtek Firmware Installer       |" > /dev/tty1
echo "--------------------------------------" > /dev/tty1
echo "" > /dev/tty1
sleep 2

# Bluetooth firmware
if [ -d "$SRC_BASE/rtl_bt" ]; then
    echo "Installing Realtek Bluetooth firmware..." > /dev/tty1
    sleep 2
    mkdir -p "$DST_BASE/rtl_bt"
    cp -v "$SRC_BASE/rtl_bt/"* "$DST_BASE/rtl_bt/" > /dev/tty1 2>&1 || true
    find "$DST_BASE/rtl_bt" -type f -exec chmod 644 {} \; 2>/dev/null
    echo "Bluetooth firmware installed." > /dev/tty1
else
    echo "No rtl_bt folder found. Skipping Bluetooth." > /dev/tty1
fi
sleep 2
echo "" > /dev/tty1

# Wi-Fi firmware
if [ -d "$SRC_BASE/rtlwifi" ]; then
    echo "Installing Realtek Wi-Fi firmware..." > /dev/tty1
    sleep 2
    mkdir -p "$DST_BASE/rtlwifi"
    cp -v "$SRC_BASE/rtlwifi/"* "$DST_BASE/rtlwifi/" > /dev/tty1 2>&1 || true
    find "$DST_BASE/rtlwifi" -type f -exec chmod 644 {} \; 2>/dev/null
    echo "Wi-Fi firmware installed." > /dev/tty1
else
    echo "No rtlwifi folder found. Skipping Wi-Fi." > /dev/tty1
fi
sleep 2
echo "" > /dev/tty1

# Reload modules
echo "Reloading Realtek kernel modules..." > /dev/tty1
sleep 2

MODULES=$(lsmod | awk '{print $1}' | grep -E '^rtl|^bt|^btrtl|^btusb|^btbcm|^btintel|^rtk')

for mod in $(echo "$MODULES" | tac); do
    modprobe -r "$mod" 2>/dev/null || true
done

sleep 2

for mod in $MODULES; do
    modprobe "$mod" 2>/dev/null || true
done

echo "Kernel modules reloaded." > /dev/tty1
sleep 2
echo "" > /dev/tty1

echo "Firmware installation completed." > /dev/tty1
echo "System will power off now..." > /dev/tty1
sleep 2

shutdown now
