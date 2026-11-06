#!/bin/bash
# ==============================================================================
# Set LED to Blue - R36H (playOS)
# Switches power indicator LED to Blue instantly with boot persistence.
# ==============================================================================

# 1. Root privilege self-escalation
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

# 2. Hardware GPIO 77 Initialization & Immediate Color Switch
if [ ! -d /sys/class/gpio/gpio77 ]; then
    echo 77 > /sys/class/gpio/export 2>/dev/null || true
fi
echo out > /sys/class/gpio/gpio77/direction 2>/dev/null || true
echo 0 > /sys/class/gpio/gpio77/value 2>/dev/null || true

# 3. Boot-time Persistence: Update /usr/local/bin/fix_power_led
if [ -f /usr/local/bin/fix_power_led.green ]; then
    cp -f /usr/local/bin/fix_power_led.green /usr/local/bin/fix_power_led
else
    cat << 'EOF' > /usr/local/bin/fix_power_led
#!/bin/bash
echo 77 > /sys/class/gpio/export 2>/dev/null || true
echo out > /sys/class/gpio/gpio77/direction 2>/dev/null || true
echo 0 > /sys/class/gpio/gpio77/value 2>/dev/null || true
EOF
    chmod 755 /usr/local/bin/fix_power_led
fi

# 4. Runtime Battery Monitor Integration: Update batt_life_warning.py
if [ -f /usr/local/bin/batt_life_warning.py.green ]; then
    cp -f /usr/local/bin/batt_life_warning.py.green /usr/local/bin/batt_life_warning.py
    chmod 755 /usr/local/bin/batt_life_warning.py
    systemctl restart batt_led 2>/dev/null || true
fi

exit 0
