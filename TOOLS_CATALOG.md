# TOOLS_CATALOG.md - Master Tool Catalog & Workspace Blueprint

สารบัญเครื่องมือ โครงสร้างไฟล์ และสถานะการทำงานของชุด Utility Tools ทั้งหมดสำหรับ **R36H** (`playOS 4.0`)

---

## 1. ตารางสรุปภาพรวมเครื่องมือ (Quick Reference Table)

| ไดเรกทอรี | Archetype | รายการเมนูใน `/roms/tools/` | หน้าที่หลัก & คำอธิบายสั้น |
| :--- | :--- | :--- | :--- |
| [`mercusys_wifi/`](file:///d:/me/r36h/tools/mercusys_wifi/) | Archetype 4 (Driver) | *(ซ่อนใน gamelist.xml)* | ติดตั้งไดรเวอร์ RTL8188EU (`8188eu.ko`) สำหรับ USB Wi-Fi ดองเกิล Mercusys MW150US |
| [`web_filemanager/`](file:///d:/me/r36h/tools/web_filemanager/) | Archetype 1 (Service) | `Start_Web_FileManager.sh`<br>`Stop_Web_FileManager.sh` | เว็บเบราว์เซอร์จัดการไฟล์แบบไร้สาย (Filebrowser พอร์ต 80) ส่องตรงเข้า `/roms/` |
| [`web_terminal/`](file:///d:/me/r36h/tools/web_terminal/) | Archetype 1 (Service) | `Start_Web_Terminal.sh`<br>`Stop_Web_Terminal.sh` | เว็บเทอร์มินัลไร้สาย (ttyd พอร์ต 7681) สิทธิ์ Root Shell ควบคุมเครื่องผ่านเบราว์เซอร์ |
| [`check_usb/`](file:///d:/me/r36h/tools/check_usb/) | Archetype 3 (One-Shot) | `check_usb.sh` | ตรวจสอบอุปกรณ์ USB OTG, ชิปเซ็ตที่เชื่อมต่อ, และไดรเวอร์เคอร์เนลที่โหลดอยู่ |
| [`speedtest/`](file:///d:/me/r36h/tools/speedtest/) | Archetype 3 (One-Shot) | `Speedtest.sh` | วัดความเร็วอินเทอร์เน็ต (Ping / Download / Upload) แสดงผลสองภาษาบนหน้าจอเครื่อง |
| [`screenshot/`](file:///d:/me/r36h/tools/screenshot/) | Archetype 2 & 3 | `Screenshot.sh` | จับภาพหน้าจอ Framebuffer (`/dev/fb0`) + Background Daemon ฟังปุ่ม SELECT+Y |
| [`quick_tools/`](file:///d:/me/r36h/tools/quick_tools/) | Archetype 4 (Mount) | *(ซ่อนใน gamelist.xml)* | สร้างทางลัด `/roms/00_tools` แบบ Bind Mount เพื่อให้เข้าถึง Tools ได้จากหน้าแรก |
| [`tools_menu/`](file:///d:/me/r36h/tools/tools_menu/) | Archetype 4 (Config) | *(ซ่อนใน gamelist.xml)* | เปิดใช้งานแท็บหมวดหมู่ `TOOLS` ใน `es_systems.cfg` บน playOS 4.0 (`playfe`) |
| [`set_led/`](file:///d:/me/r36h/tools/set_led/) | Archetype 3 (One-Shot) | `Set_LED_to_Red.sh`<br>`Set_LED_to_Blue.sh` | สลับสีไฟสถานะ LED (สีแดง/สีน้ำเงิน) จำค่าข้ามการรีบูต + ปรับปรุง `batt_led.service` |
| [`nfsu2_thai/`](file:///d:/me/r36h/tools/nfsu2_thai/) | Archetype 3 (One-Shot) | `NFSU2_Language_Thai.sh`<br>`NFSU2_Language_English.sh`<br>`Uninstall_NFSU2_Thai.sh` | ติดตั้งภาษาไทย NFSU2 ทันทีตอน Install, เมนูสลับภาษาบนเครื่อง, และกู้คืนไฟล์เดิมพร้อมถอนการติดตั้ง |
| [`screen_off/`](file:///d:/me/r36h/tools/screen_off/) | Archetype 2 & 3 | `Screen_Off.sh` | สั่งดับไฟหน้าจอ (Backlight) ทันทีเพื่อประหยัดแบตเตอรี่ + Auto Screen Off Daemon (1 นาที) |
| [`power_button/`](file:///d:/me/r36h/tools/power_button/) | Archetype 2 (Daemon) | *(ซ่อนใน gamelist.xml)* | Background Daemon ดักฟังปุ่ม Power (กดค้าง 1 วิ แสดงนับถอยหลัง 3 วิก่อนปิดเครื่อง) |
| [`setup_ui/`](file:///d:/me/r36h/tools/setup_ui/) | Engine / Shared | `Demo_Setup.sh`<br>`Demo_Dialog_TUI.sh` | ไลบรารีกลาง C/SDL2 KMSDRM UI Setup Wizard และ `fb0_mirror` สำหรับแสดง TUI จริง |
| [`rtl/`](file:///d:/me/r36h/tools/rtl/) | Assets / Firmware | — | คลังไฟล์ Microcode เฟิร์มแวร์ Realtek RTL8xxx จาก dArkOS |
| [`XNL RTL8188FTV/`](file:///d:/me/r36h/tools/XNL%20RTL8188FTV/) | Reference | — | ซอร์สโค้ดและไฟล์อ้างอิงไดรเวอร์ RTL8188FU จากผู้ผลิต |

---

## 2. แผนผังโครงสร้างไฟล์อย่างละเอียด (Complete Workspace Tree)

```text
d:\me\r36h\tools\
├── AGENTS.md                         <-- Master workspace rules & specifications
├── ARCHETYPES.md                     <-- Standardized tool archetypes & layout rules
├── TOOLS_CATALOG.md                  <-- This file (Master catalog & directory blueprint)
├── PLAYFE_MENU_GUIDE.md              <-- playOS 4.0 Frontend (playfe) menu & cover art guide
├── NCURSES_TUI_GUIDE.md              <-- Genuine Linux ncurses TUI (dialog + fb0_mirror) guide
├── LED_HARDWARE_GUIDE.md             <-- R36H Power/Status LED hardware architecture & sysfs guide
├── WIFI_HARDWARE_GUIDE.md            <-- Realtek USB Wi-Fi (RTL8188EU) architecture & quirks guide
├── mercusys_wifi/                    <-- Wi-Fi Driver & Persistence Tool
│   ├── Install_Mercusys_WiFi.sh     <-- All-in-one standalone installer
│   ├── Uninstall_Mercusys_WiFi.sh   <-- Clean uninstaller script
│   ├── README.txt                    <-- User guide
│   ├── driver/                       <-- Kernel module & firmware binary subfolder
│   │   ├── 8188eu.ko                 <-- Compiled 4.4.189 kernel module
│   │   └── rtl8188eufw.bin           <-- Realtek firmware microcode
│   └── tools/                        <-- Diagnostics & helper scripts subfolder
│       ├── Repair_Mercusys_WiFi.sh  <-- Diagnostic & repair tool
│       ├── Check_WiFi_Signal.sh     <-- Wi-Fi signal & status monitor
│       └── *.sh                      <-- Individual helper scripts
├── web_filemanager/                  <-- Wireless Web File Browser (Filebrowser)
│   ├── filebrowser                   <-- ARM64 standalone binary
│   ├── Install_Web_FileManager.sh   <-- Setup script
│   ├── Start_Web_FileManager.sh     <-- Launcher with on-screen IP display
│   ├── Stop_Web_FileManager.sh      <-- Teardown script to reclaim RAM for games
│   └── README.txt                    <-- User guide
├── web_terminal/                     <-- Wireless Web Terminal (ttyd)
│   ├── Install_Web_Terminal.sh      <-- Setup script
│   ├── Uninstall_Web_Terminal.sh    <-- Clean uninstaller script
│   ├── README.txt                    <-- User guide
│   └── app/                          <-- Internal application subfolder
│       ├── ttyd                      <-- ARM64 standalone binary
│       ├── Start_Web_Terminal.sh     <-- Launcher with on-screen IP display
│       └── Stop_Web_Terminal.sh      <-- Teardown script to reclaim RAM for games
├── check_usb/                        <-- USB Hardware Diagnostics
│   ├── check_usb.sh                 <-- lsusb & loaded module inspector
│   └── check_usb_wait_power.sh      <-- Power / OTG diagnostic script
├── speedtest/                        <-- Network Benchmark Utility (Ping/DL/UL)
│   ├── speedtest.py                 <-- Bundled & patched speedtest CLI module
│   ├── speedtest_runner.py          <-- Python UI runner & Thai display formatter
│   ├── speedtest.sh                 <-- Dual-output launcher for EmulationStation & CLI
│   ├── Install_Speedtest.sh         <-- Standalone installer for /roms/tools/ & PATH
│   └── README.txt                   <-- User guide & instructions
├── screenshot/                       <-- Framebuffer Screen Capture Utility & Hotkey Daemon
│   ├── Install_Screenshot.sh        <-- Standalone installer (CLI & Systemd Daemon)
│   ├── Status_Screenshot.sh         <-- Status inspector & realtime Button Tester
│   ├── Uninstall_Screenshot.sh      <-- Clean uninstaller (removes daemon & CLI)
│   ├── README.txt                   <-- User guide & instructions
│   ├── app/                         <-- Internal application subfolder
│   │   └── screenshot.sh            <-- CLI capture script (fbdev /dev/fb0)
│   └── daemon/                      <-- Internal daemon subfolder
│       ├── screenshot_daemon.py     <-- Python SELECT+Y listener with shutter flash
│       └── screenshot-daemon.service <-- Systemd background service unit
├── quick_tools/                      <-- Top-level Shortcut Utility (00_tools)
│   ├── Install_Quick_Tools.sh       <-- Standalone installer for /roms/00_tools bind mount
│   ├── Uninstall_Quick_Tools.sh     <-- Clean uninstaller for /roms/00_tools
│   └── README.txt                   <-- User guide & instructions
├── tools_menu/                       <-- playOS 4.0 TOOLS Menu Enabler (es_systems.cfg)
│   ├── Install_Tools_Menu.sh        <-- Enables <name>tools</name> in es_systems.cfg & restarts playfe
│   ├── Uninstall_Tools_Menu.sh      <-- Removes <name>tools</name> from es_systems.cfg
│   └── README.txt                   <-- User guide & instructions
├── set_led/                          <-- Power LED Color Switcher Utility (Red / Blue)
│   ├── Install_Set_LED.sh           <-- Standalone installer for /roms/tools/
│   ├── Uninstall_Set_LED.sh         <-- Clean uninstaller (restores Blue default)
│   ├── README.txt                   <-- User guide & instructions
│   └── app/                         <-- Internal application subfolder
│       ├── Set_LED_to_Red.sh        <-- Instant switch to Red with boot persistence
│       └── Set_LED_to_Blue.sh       <-- Instant switch to Blue with boot persistence
├── nfsu2_thai/                       <-- Need for Speed: Underground 2 Thai & Tools
│   ├── Install_NFSU2_Tools.sh       <-- Standalone installer (Auto-Setup game & installs Tools)
│   ├── README.txt                   <-- User guide & instructions
│   └── app/                         <-- Internal application subfolder
│       ├── NFSU2_Language_Thai.sh   <-- Instant switch to Thai
│       ├── NFSU2_Language_English.sh<-- Instant switch to English
│       ├── Uninstall_NFSU2_Thai.sh  <-- Restore original files from .backup_thai/ & clean menu
│       ├── generate_icons.py        <-- Icon generation utility
│       └── gamedata/                <-- Game assets for auto-setup
│           ├── SPEED2.EXE           <-- Pre-patched Thai executable (4.78 MB)
│           └── LANGUAGES/           <-- Thailand.bin (264 KB, Name entry safe)
├── screen_off/                       <-- Screen Preserver / Backlight Shutoff Utility
│   ├── Install_Screen_Off.sh        <-- Standalone installer for /roms/tools/ & PATH
│   ├── Uninstall_Screen_Off.sh      <-- Clean uninstaller for full Screen Off suite
│   ├── Setup_Auto_Screen_Off.sh     <-- One-click setup for Auto Screen Off (1 min idle)
│   ├── Status_Auto_Screen_Off.sh    <-- Status inspector (PID, RAM, service status, logs)
│   ├── Uninstall_Auto_Screen_Off.sh <-- Teardown script for Auto Screen Off daemon only
│   ├── README.txt                   <-- User guide & instructions
│   ├── app/                         <-- Internal application subfolder
│   │   └── Screen_Off.sh            <-- Dual-output screen off & dual-input wake launcher
│   └── daemon/                      <-- Auto screen off daemon subfolder
│       ├── auto_screen_off_daemon.py <-- Python idle listener (60s timeout)
│       └── auto-screen-off.service  <-- Systemd background service unit
├── power_button/                     <-- Power Button Hold-to-Shutdown Daemon
│   ├── Setup_UI.sh                  <-- Interactive Setup UI Wizard (SDL2)
│   ├── Install_Power_Button.sh      <-- Standalone installer & service activator
│   ├── Status_Power_Button.sh       <-- Status inspector (PID, RAM, device, logs)
│   ├── Uninstall_Power_Button.sh    <-- Clean uninstaller & teardown script
│   ├── README.txt                   <-- User guide & instructions
│   └── daemon/                      <-- Internal daemon subfolder
│       ├── setup_ui                 <-- Standalone ARM64 Universal Setup UI binary
│       ├── countdown_ui             <-- Standalone ARM64 Countdown Overlay binary
│       ├── power_button_daemon.py   <-- Python PMIC event listener (3s hold trigger)
│       └── power-button-daemon.service <-- Systemd background service unit
├── setup_ui/                         <-- Universal Setup UI & Framebuffer Mirror Engine (SDL2 KMSDRM)
│   ├── setup_ui.c                   <-- Direct SDL2 KMSDRM Universal Setup UI source
│   ├── fb0_mirror.c                 <-- /dev/fb0 (/dev/tty1) to KMSDRM mirror & TIOCSTI input bridge
│   ├── countdown_ui.c               <-- Direct SDL2 KMSDRM Countdown Overlay source
│   ├── setup_ui                     <-- Pre-compiled ARM64 Setup UI binary for any tool
│   ├── fb0_mirror                   <-- Pre-compiled ARM64 /dev/fb0 mirror binary for real dialog TUIs
│   ├── Demo_Setup.sh                <-- Template launcher script for setup_ui (inline config)
│   ├── Demo_Dialog_TUI.sh           <-- Template launcher script for real Linux dialog + fb0_mirror
│   └── README.txt                   <-- Integration & customization manual
├── rtl/                              <-- Realtek firmware repository (dArkOS origin)
└── XNL RTL8188FTV/                   <-- Reference RTL8188FU driver archive
```
