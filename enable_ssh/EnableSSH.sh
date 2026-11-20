#!/bin/bash
{
  echo "======================================"
  echo "          ENABLING SSH...             "
  echo "======================================"
  echo ark | sudo -S systemctl enable --now ssh 2>&1
  echo ark | sudo -S systemctl enable --now remote-autostart.service 2>/dev/null || true
  echo ""
  systemctl is-active ssh && echo "SSH Status: ACTIVE" || echo "SSH Status: FAILED"
  echo "IP: $(hostname -I)"
  echo "Returning in 5 seconds..."
} > /dev/tty1 2>&1
sleep 5
exit 0