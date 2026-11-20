========================================================================
Remote Services Manager v1.0 for R36H (playOS / ArkOS)
========================================================================

Overview:
  A self-contained native Linux ncurses TUI to toggle Boot Autostart
  and Live Running State for background remote file services:
    1. Samba File Sharing (smbd + nmbd)
    2. FileBrowser Web File Manager (Port 80)
    3. Quick Presets:
       - Disable All (Gaming Mode: frees RAM/CPU on boot & immediately)
       - Enable All  (Transfer Mode: enables & starts Samba + Web UI)

Safety Guarantee:
  - SSH (sshd) and NTP (timedatectl) are NEVER disabled or stopped.
  - A one-time backup of /etc/systemd/system/remote-autostart.service
    is saved as remote-autostart.service.orig before first edit.

Installation (PortMaster / playOS):
  1. Copy Remote_Services.sh to /roms/ports/ (or /roms/tools/).
  2. Copy images/Remote_Services-thumb.png to /roms/ports/images/
     (or /roms/tools/images/).
  3. Launch "Remote Services" from the PORTS (or TOOLS) menu.

Controls:
  - D-Pad Up/Down : Move selection
  - A / Enter     : Confirm / Toggle
  - B / Esc       : Exit back to frontend
========================================================================
