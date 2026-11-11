==============================================================================
Screen Off / Screen Saver Utility Suite for R36H & Handhelds (playOS & ArkOS)
==============================================================================

[ General Information / ข้อมูลทั่วไป ]
A lightweight, offline-first Screen Off utility suite designed for playOS 4.0 and ArkOS.
Turns off LCD backlight 100% (and blanks fb0) instantly or automatically after an idle timeout.
Features:
1. Protects screen from heat buildup when leaving device on.
2. Minimizes battery consumption.
3. Keeps CPU, Wi-Fi, SSH, Web File Manager, and background downloads running 100%.

------------------------------------------------------------------------------
[ Directory Structure / โครงสร้างไดเรกทอรี ]
------------------------------------------------------------------------------
screen_off/
├── Screen_Off_Setup.sh          <-- Top-level launcher (All-in-One TUI Manager)
├── README.txt                   <-- Documentation & User Guide
├── images/                      <-- Pre-packaged cover art directory for Ports/Tools
│   ├── Screen_Off-thumb.png     <-- 512x512 cover art for Screen_Off.sh
│   └── Screen_Off_Setup-thumb.png <-- 512x512 cover art for Screen_Off_Setup.sh
└── screen_off/                  <-- Internal data folder (side-by-side)
    ├── app/                     <-- Core scripts, cover arts & status config
    │   ├── Screen_Off.sh        <-- Instant screen off script (Smart Key-Down Wake)
    │   ├── Screen_Off-thumb.png
    │   ├── Screen_Off_Setup-thumb.png
    │   └── status.conf          <-- Persistent status configuration
    └── daemon/                  <-- Background idle listener & systemd service
        ├── auto_screen_off_daemon.py
        └── auto-screen-off.service

------------------------------------------------------------------------------
[ Deployment / วิธีติดตั้งลงเครื่อง ]
------------------------------------------------------------------------------
Copy 'Screen_Off_Setup.sh', 'images/', and 'screen_off/' together into either:
  1. /roms/ports/  (Recommended: PORTS menu is enabled by default on all systems)
  2. /roms/tools/  (Alternative: if TOOLS menu is enabled)

Then on your R36H console:
  Go to Ports (or Tools) -> Launch "Screen_Off_Setup.sh" -> Select "Install Screen Off"

Once installed, two clean menu items will appear:
  • Screen_Off.sh        : Instant manual screen blackout
  • Screen_Off_Setup.sh  : Change idle timeout or uninstall anytime

Dynamic State-Aware Actions:
• When NOT installed:
    1. Install Screen Off (choose idle timeout & install)
• When ALREADY installed:
    1. Config TimeOut     (change idle minutes timeout)
    2. Uninstall          (cleanly remove all shortcuts, service, & binaries)

Selectable Idle Timeout Options (in minutes):
    [ ] Disabled
    [ ] 1 Minute
    [ ] 3 Minutes
    [ ] 5 Minutes
    [*] 10 Minutes (Default)
    [ ] 15 Minutes
    [ ] 30 Minutes

------------------------------------------------------------------------------
[ How to Use / วิธีใช้งาน ]
------------------------------------------------------------------------------
1. Instant Manual Screen Off:
   - In EmulationStation / playfe: Go to "Tools" -> Launch "Screen_Off.sh"
   - Or in Terminal / SSH: Run 'screen_off'
   - Waking up: Press ANY button on the handheld or keyboard to restore backlight instantly.

2. Auto Screen Off Daemon:
   - Runs silently in the background as a systemd service.
   - When no buttons are pressed for the configured idle minutes, the screen turns off automatically.
   - Press ANY button to wake the screen immediately.
==============================================================================
