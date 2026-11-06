# AGENTS.md - Tools Suite for R36H (playOS)

## 1. Project Overview & Objective
This workspace is a **Swiss Army Knife / Multi-Tool Suite** dedicated to developing, packaging, and maintaining standalone utility tools for the **R36H Handheld Gaming Console** running **playOS**.

The goal is to provide reliable, plug-and-play, and offline-first tools that seamlessly integrate with the console's EmulationStation interface (`/roms/tools/`), on-screen terminal emulator, or remote SSH sessions.

---

## 2. Target Hardware & System Environment
* **Target Device:** R36H Handheld Gaming Console
* **SoC / Architecture:** Rockchip RK3326 (ARM64 / ARMv8 / aarch64)
* **Operating System:** playOS
* **Linux Kernel Version:** `4.4.189`
* **Target Display Console:** `/dev/tty1` (EmulationStation framebuffer / text console)
* **SSH Access & Authentication:**
  * **Port:** `22` (OpenSSH)
  * **Default User:** `ark`
  * **Default Password:** `ark`
  * **Privilege Escalation:** Direct root SSH password login is disabled (`PermitRootLogin prohibit-password`). Must login as `ark` and escalate via `sudo -i` or `sudo <cmd>`.
* **Runtime & Scripting Environments:**
  * **Shell:** Bash (`/bin/bash`), Sh (`/bin/sh`)
  * **Python 3:** `/usr/bin/python3` (Python `3.13.5` pre-installed)
  * **Pip:** `/usr/lib/python3/dist-packages/pip` (pip `25.1.1` pre-installed)
* **Network & Port Conventions:**
  * **Port 22:** SSH server
  * **Port 80:** Standalone Web File Manager (noauth, scoped to `/roms/`)
  * **Port 7681:** Standalone Web Terminal (ttyd, root shell)
* **Target Filesystem Layout:**
  * SD Card ROMs partition: `/roms/`
  * EmulationStation Tools menu: `/roms/tools/`
  * User/custom scripts location: `/usr/local/bin/`
  * Kernel modules directory: `/lib/modules/4.4.189/`
  * System firmware directory: `/lib/firmware/` and `/lib/firmware/rtlwifi/`

---

## 3. Tool Catalog & Workspace Structure

```text
d:\me\r36h\tools\
├── AGENTS.md                         <-- Master workspace rules & specifications
├── mercusys_wifi/                    <-- Wi-Fi Driver & Persistence Tool
│   ├── Install_Mercusys_WiFi.sh     <-- All-in-one standalone installer
│   ├── Repair_Mercusys_WiFi.sh      <-- Diagnostic & repair tool
│   ├── 8188eu.ko                     <-- Compiled 4.4.189 kernel module
│   ├── rtl8188eufw.bin               <-- Realtek firmware microcode
│   ├── TECHNICAL_NOTES.md            <-- Deep hardware quirks & findings
│   └── README.txt                    <-- User guide
├── web_filemanager/                  <-- Wireless Web File Browser (Filebrowser)
│   ├── filebrowser                   <-- ARM64 standalone binary
│   ├── Install_Web_FileManager.sh   <-- Setup script
│   ├── Start_Web_FileManager.sh     <-- Launcher with on-screen IP display
│   ├── Stop_Web_FileManager.sh      <-- Teardown script to reclaim RAM for games
│   └── README.txt                    <-- User guide
├── web_terminal/                     <-- Wireless Web Terminal (ttyd)
│   ├── ttyd                          <-- ARM64 standalone binary
│   ├── Install_Web_Terminal.sh      <-- Setup script
│   ├── Start_Web_Terminal.sh        <-- Launcher with on-screen IP display
│   ├── Stop_Web_Terminal.sh         <-- Teardown script to reclaim RAM for games
│   └── README.txt                    <-- User guide
├── check_usb/                        <-- USB Hardware Diagnostics
│   ├── check_usb.sh                 <-- lsusb & loaded module inspector
│   └── check_usb_wait_power.sh      <-- Power / OTG diagnostic script
├── speedtest/                        <-- Network Benchmark Utility
│   ├── speedtest.sh                 <-- Runner script
│   └── install_speedtest.sh         <-- Installation script
├── rtl/                              <-- Realtek firmware repository (dArkOS origin)
└── XNL RTL8188FTV/                   <-- Reference RTL8188FU driver archive
```

> **Note on Tool Details:** Deep hardware specifics (such as RTL8188EU HAL ops, USB vendor IDs, and firmware hashes) are maintained in each tool's local documentation (e.g., [`mercusys_wifi/TECHNICAL_NOTES.md`](file:///d:/me/r36h/tools/mercusys_wifi/TECHNICAL_NOTES.md)).

---

## 4. Tool Architecture & Execution Standards (Dual-Execution Contract)

Every tool developed in this workspace must adhere to the **Dual-Execution Contract**:

1. **Dual-Environment Support:**
   * **EmulationStation Tools Menu (`/roms/tools/`):** When launched via the console's UI, scripts must write output to `/dev/tty1` so that progress, status, and instructions are clearly visible on the R36H screen.
   * **Terminal Emulator / SSH:** When run interactively via terminal or SSH, output must also appear on standard stdout/stderr without freezing or breaking.

2. **100% Offline / Standalone First:**
   * The R36H often operates without internet access.
   * All required binaries, kernel modules, firmware, and dependencies must be pre-packaged locally in the tool's folder. Never rely on `apt-get` or remote downloads for essential installation unless explicitly documented.

3. **Screen Control & Lifecycle UX:**
   * **Clear Screen:** Always clear `/dev/tty1` before printing UI menus or progress.
   * **Readable Hold:** Scripts providing output on screen should include a hold or countdown (e.g., `sleep 10` or `read -n 1`) before exiting, preventing the console from instantly flashing back to EmulationStation before the user can read the results.
   * **Clean Resource Teardown:** Long-running services (e.g. Web File Manager) must provide a lightweight shutdown script (`Stop_*.sh`) so users can free CPU and RAM before launching performance-sensitive emulators.

4. **Root Privilege Escalation:**
   * Scripts requiring root privileges must automatically self-elevate:
     ```bash
     if [ "$(id -u)" -ne 0 ]; then
         exec sudo -E "$0" "$@"
     fi
     ```

---

## 5. Universal Constraints & Rules for AI Agents

When authoring, modifying, or packaging tools for playOS on R36H, AI agents **MUST** follow these rules:

1. **Always Use Unix Line Endings (LF):**
   * All shell scripts (`.sh`), configuration files, and systemd units must be saved with Unix line feeds (`\n`), never Windows CRLF (`\r\n`). CRLF causes `\r: command not found` fatal errors on Linux.

2. **No Pipe Character (`|`) in User Instructions:**
   * The built-in on-screen terminal emulator on playOS does **NOT** provide a pipe (`|`) key.
   * Never instruct the user to type piped commands (e.g., `cat file | grep ...`). Always encapsulate multi-step logic into an executable shell script and instruct the user to run `sudo bash /path/to/script.sh`.

3. **Dual Output Pattern:**
   * When writing user-facing scripts for `/roms/tools/`, redirect or mirror output to `/dev/tty1`:
     ```bash
     {
       echo "======================================"
       echo "          MY TOOL TITLE               "
       echo "======================================"
     } > /dev/tty1 2>&1
     ```

4. **Preserve Subdirectory Modular Documentation:**
   * Keep `AGENTS.md` clean and focused on general environment specifications, architecture, and coding standards.
   * Place tool-specific configuration manuals, wiring/chipset notes, or driver quirks inside the respective tool folder.

5. **Do Not Automatically Generate ZIP Archives:**
   * Do **NOT** automatically compress folders or create `.zip` archives unless explicitly requested by the user. Keep tools maintained as clean, direct source directories and files within the workspace.
