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
├── ARCHETYPES.md                     <-- Standardized tool archetypes & layout rules
├── PLAYFE_MENU_GUIDE.md              <-- playOS 4.0 Frontend (playfe) menu & cover art guide
├── mercusys_wifi/                    <-- Wi-Fi Driver & Persistence Tool
│   ├── Install_Mercusys_WiFi.sh     <-- All-in-one standalone installer
│   ├── Uninstall_Mercusys_WiFi.sh   <-- Clean uninstaller script
│   ├── TECHNICAL_NOTES.md            <-- Deep hardware quirks & findings
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
│   ├── Setup_UI.sh                  <-- Interactive Windows XP Setup UI Wizard (SDL2)
│   ├── Install_Power_Button.sh      <-- Standalone installer & service activator
│   ├── Status_Power_Button.sh       <-- Status inspector (PID, RAM, device, logs)
│   ├── Uninstall_Power_Button.sh    <-- Clean uninstaller & teardown script
│   ├── README.txt                   <-- User guide & instructions
│   └── daemon/                      <-- Internal daemon subfolder
│       ├── xp_setup_ui              <-- Standalone ARM64 Universal Setup UI binary
│       ├── countdown_ui             <-- Standalone ARM64 Countdown Overlay binary
│       ├── power_button_daemon.py   <-- Python PMIC event listener (3s hold trigger)
│       └── power-button-daemon.service <-- Systemd background service unit
├── xp_setup_ui/                      <-- Universal Windows XP Setup UI Engine (Reusable)
│   ├── xp_setup_ui.c                <-- Direct SDL2 KMSDRM Universal Setup UI source
│   ├── countdown_ui.c               <-- Direct SDL2 KMSDRM Countdown Overlay source
│   ├── xp_setup_ui                  <-- Pre-compiled ARM64 binary for any tool
│   ├── Demo_Setup.sh                <-- Template launcher script with inline config
│   └── README.txt                   <-- Integration & customization manual
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

### 4.1 Standard Tool Archetypes & Directory Layouts

To keep the user-facing workspace and `/roms/tools/` clean and intuitive, all tools developed or maintained in this workspace **MUST** adhere to one of three standardized directory archetypes based on their execution lifecycle:

#### Archetype 1: On-Demand Service Tools (with Start / Stop)
* **Use Case:** Services, web servers, or daemons that run on-demand (when started by the user) and provide a clean stop script to reclaim CPU/RAM before gaming (e.g. `web_terminal`, `web_filemanager`).
* **Root Directory:** Contains only the setup, uninstall scripts, and user manual.
* **Internal Subfolder (`app/`):** Houses binaries, core runtime files, and the `Start_*.sh` / `Stop_*.sh` scripts.
* **Layout Structure:**
  ```text
  <tool_name>/
  ├── Install_<Tool>.sh       <-- User setup script (copies Start/Stop to /roms/tools/)
  ├── Uninstall_<Tool>.sh     <-- Clean uninstaller (removes services, binary, & shortcuts)
  ├── README.txt              <-- User manual & documentation
  └── app/                    <-- Internal application subfolder
      ├── <binary_or_core>    <-- Standalone ARM64 binary or core assets
      ├── Start_<Tool>.sh     <-- Launcher script with on-screen IP display
      └── Stop_<Tool>.sh      <-- Teardown script to reclaim RAM for games
  ```
* **EmulationStation Integration:** Running `Install_<Tool>.sh` copies or symlinks `Start_<Tool>.sh` and `Stop_<Tool>.sh` directly to `/roms/tools/` so they appear as menu items in EmulationStation.

#### Archetype 2: Background Daemon Tools (Always-On / System Service, No Start/Stop)
* **Use Case:** Background system monitors, hardware button listeners, or battery/power hooks that run continuously as systemd services without requiring manual start/stop toggling (e.g. `power_button`).
* **Root Directory:** Contains only setup, status inspector, clean uninstaller, and user manual.
* **Internal Subfolder (`daemon/`):** Houses the daemon script/binary and the systemd unit file.
* **Layout Structure:**
  ```text
  <tool_name>/
  ├── Install_<Tool>.sh       <-- Setup script (registers and enables systemd service)
  ├── Status_<Tool>.sh        <-- Status inspector (shows PID, RAM usage, hardware & logs)
  ├── Uninstall_<Tool>.sh     <-- Clean uninstaller (stops, disables, & deletes service)
  ├── README.txt              <-- User manual & documentation
  └── daemon/                 <-- Internal daemon subfolder
      ├── <daemon_script>     <-- Python PMIC/evdev listener or daemon binary
      └── <tool>.service      <-- Systemd background service unit
  ```
* **System Integration:** Running `Install_<Tool>.sh` registers the service into `/etc/systemd/system/`, enables it for boot-time autostart, and starts it immediately.

#### Archetype 3: One-Shot Utility Tools (Single-Run / No Daemon)
* **Use Case:** Tools that perform an immediate task once and exit immediately, without leaving background processes (e.g. `screenshot`, `speedtest`, `quick_tools`).
* **Root Directory:** Contains only setup/installer script, uninstaller (if system files or tools/PATH were modified), and user manual.
* **Internal Subfolder (`app/`):** Houses runtime scripts, helper modules, or binaries.
* **Layout Structure:**
  ```text
  <tool_name>/
  ├── Install_<Tool>.sh       <-- Setup script (places menu launcher or PATH symlink)
  ├── Uninstall_<Tool>.sh     <-- Optional uninstaller (removes installed launcher/shortcuts)
  ├── README.txt              <-- User manual & documentation
  └── app/                    <-- Internal application subfolder
      ├── <tool_runner>.sh    <-- Dual-output execution runner
      └── <modules_or_bin>    <-- Supporting scripts or libraries
  ```
* **EmulationStation Integration:** Running `Install_<Tool>.sh` copies or links the main execution script to `/roms/tools/` for single-click execution from the console menu.

---

### 4.2 Universal Setup UI Engine (`xp_setup_ui`) Usage Policy

The workspace provides a reusable C/SDL2 KMSDRM graphical setup wizard engine in [`xp_setup_ui/`](file:///d:/me/r36h/tools/xp_setup_ui/).

* **When to Use `xp_setup_ui`:**
  * Use `xp_setup_ui` **ONLY** when the user explicitly requests a graphical UI, Setup Wizard, or controller-navigable options menu (`UP/DOWN` to select options, `LEFT/RIGHT` to select `[ OK ]` / `[ Back ]` / `[ Exit ]`, and `A` or `B` to confirm).
  * By default, standard installers (`Install_<Tool>.sh`) should remain simple, non-interactive shell scripts unless a UI/Wizard is requested.
* **How to Package & Integrate (`No Recompilation Needed`):**
  * Copy **only** the pre-compiled ARM64 binary [`xp_setup_ui/xp_setup_ui`](file:///d:/me/r36h/tools/xp_setup_ui/xp_setup_ui) into the target tool's internal subfolder (`<tool_name>/daemon/xp_setup_ui` or `<tool_name>/app/xp_setup_ui`).
  * **Never** clutter individual tool folders with `.c` source files (`xp_setup_ui.c`, `countdown_ui.c`). All C source code is maintained centrally in [`xp_setup_ui/`](file:///d:/me/r36h/tools/xp_setup_ui/).
  * Create the launcher script (e.g., `Setup_UI.sh` based on [`xp_setup_ui/Demo_Setup.sh`](file:///d:/me/r36h/tools/xp_setup_ui/Demo_Setup.sh)) that pauses `FindManager|playfe` (`pkill -STOP -f "FindManager|playfe"`), pipes the custom `header`, `[page]`, and `[progress]` configuration block to `xp_setup_ui - << 'EOF'`, and resumes `FindManager|playfe` (`pkill -CONT -f "FindManager|playfe"`) on exit.

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

6. **Keep C Source Code in `xp_setup_ui/` and Binaries in Tool Subfolders:**
   * Only use `xp_setup_ui` when the user explicitly asks for a graphical Setup UI or controller-selectable menu. When used, place the compiled `xp_setup_ui` binary inside the tool's subfolder (`daemon/` or `app/`) and keep all `.c` source files in [`xp_setup_ui/`](file:///d:/me/r36h/tools/xp_setup_ui/).

7. **Follow `playfe` Naming & Subfolder Hiding Rules in `/roms/tools/`:**
   * **Stem-Matching Rule (Menu Tools — Archetypes 1 & 3):** For any tool that places a top-level launcher `.sh` in `/roms/tools/`, its subfolder name (`<tool_name>/`) normalized to lowercase alphanumeric (`[a-z0-9]`, length `> 4`) **MUST** be a substring of the top-level `.sh` filename stem so `playfe` automatically hides the subfolder from the menu (e.g., `/roms/tools/Screen_Off.sh` (`screenoff`) auto-hides `/roms/tools/screen_off/`; `/roms/tools/Start_Web_Terminal.sh` (`startwebterminal`) auto-hides `/roms/tools/web_terminal/`).
   * **Non-Menu Tools Must Hide Their `.sh` Scripts in `/roms/tools/gamelist.xml` (Archetypes 2 & 4):** Any tool that does **NOT** want an icon displayed in the `TOOLS` menu (i.e. has no matching top-level `.sh` launcher in `/roms/tools/`, such as `power_button`, `quick_tools`, `tools_menu`, `mercusys_wifi`) **MUST** include a step in its `Install_*.sh` script to update `/roms/tools/gamelist.xml` and set `<hidden>true</hidden>` for all `.sh` files inside its own folder (`$SCRIPT_DIR`).

---

## 6. Remote Testing & Deployment Workflow on R36H (SSH / SFTP)

When live testing on physical hardware is requested, agents must follow this standardized 5-step lifecycle:

```mermaid
flowchart LR
    A["1. Upload (SFTP)"] --> B["2. Setup (Install)"]
    B --> C["3. Stop (Clean Teardown)"]
    C --> D["4. Start & Verify Service"]
    D --> E["5. Stop (Resource Reclaim)"]
```

### Testing Lifecycle Steps

1. **Step 1: Upload (SFTP / SCP)**
   * Target Host: `192.168.1.9` (Port: `22`, User: `ark`, Pass: `ark`)
   * Transfer tool package to `/roms/tools/<tool_directory>/`
   * Sync entrypoint shortcuts to `/roms/tools/`
   * Ensure executable permissions: `chmod 755 /roms/tools/*.sh /roms/tools/<tool_directory>/*.sh`

2. **Step 2: Setup / Installation (`Install_*.sh`)**
   * Execute `sudo bash /roms/tools/<tool_directory>/Install_<Tool>.sh`
   * Verify binary destination (e.g. `/usr/local/bin/<binary>`)
   * Verify database / configuration initialization (e.g. `auth.method=noauth`)
   * Verify systemd service registration (if applicable)

3. **Step 3: Stop / Teardown Verification (`Stop_*.sh`)**
   * Execute `sudo bash /roms/tools/Stop_<Tool>.sh`
   * Check process table (`pgrep -x "<binary>"`) to confirm termination
   * Verify target port is completely freed (no socket bind collisions)

4. **Step 4: Start & Verification (`Start_*.sh`)**
   * Execute `sudo bash /roms/tools/Start_<Tool>.sh < /dev/null`
   * Verify process is running in background (obtain active PID)
   * Verify on-screen text display (`/dev/tty1`) and IP address formatting
   * Verify HTTP or socket connectivity (e.g. `GET http://<IP>:<Port>/` returns `200 OK` without authentication prompts)

5. **Step 5: Clean Teardown**
   * Re-run `Stop_<Tool>.sh` to verify repeatable cleanup and ensure 0% leftover CPU/RAM before emulator launch.

### ⚠️ Execution Policy for Remote Testing
* **On-Demand Only (Do NOT Test Automatically):**
  * Agents must **NOT** automatically connect to the physical R36H or run SSH/SFTP deployment cycles on every code edit or turn.
  * Live testing on hardware must be performed **ONLY** when the user explicitly instructs to test/deploy (or after design/scope alignment via `/grill-me`).

---

## 7. System Insights & Runtime Quirks (playOS Knowledge)

Key technical findings and platform quirks discovered on physical R36H running playOS:

### 1. Built-in `remote-autostart.service` & Port 80 Management
* **Boot-time Service:** playOS ships with `/etc/systemd/system/remote-autostart.service` enabled by default. It automatically launches background services on system boot:
  ```bash
  ExecStart=/bin/bash -c "timedatectl set-ntp 1 & systemctl start smbd & systemctl start nmbd & systemctl start ssh.service & filebrowser -a 0.0.0.0 -p 80 -d /home/ark/.config/filebrowser.db -r / &"
  ```
* **Port 80 Collision:** Because `filebrowser` is already running on port 80 out of the box, any script that attempts to start a second instance without checking process status will fail immediately with:
  `Error: listen tcp 0.0.0.0:80: bind: address already in use`
* **Default Database & Credentials:** The system default database is `/home/ark/.config/filebrowser.db` (default auth: `ark:ark`, scope `/`). When configuring `noauth` or installing custom database instances (`/usr/local/share/filebrowser.db`), also apply `filebrowser config set -d /home/ark/.config/filebrowser.db --auth.method=noauth` so boot-time services adhere to the unauthenticated open-access policy.

### 2. Process Matching Standard (`pgrep -x` vs `pgrep -f`)
* **Short Name vs. Full Path:**
  * When playOS starts binaries via shell commands (e.g., `filebrowser ...`), `/proc/<pid>/cmdline` contains the short command name, **not** `/usr/local/bin/filebrowser`.
  * Using `pgrep -f "$BIN_PATH"` (e.g. `pgrep -f "/usr/local/bin/filebrowser"`) produces a **false negative**, causing launcher scripts to believe the daemon is stopped when it is actively running.
  * Conversely, `pgrep -f "filebrowser"` can produce **false positives** by matching transient subshells or wrapper scripts that contain the string in their arguments.
* **Standard Solution:** Always check daemon status with exact process name matching:
  ```bash
  is_running() {
      pgrep -x "<binary_name>" > /dev/null 2>&1
  }
  ```

### 3. Dual-Input Listener & Evdev Non-Blocking Loop (`wait_for_exit`)
* **Terminal vs Framebuffer Detection:**
  * Scripts running interactively via SSH have standard input (`stdin`) connected to a TTY (`[ -t 0 ]` is true).
  * Scripts launched via EmulationStation execute on `/dev/tty1` and lack a keyboard, requiring gamepad input via `/dev/input/event*`.
* **The `wait -n` EOF Hang Bug:**
  * In earlier implementations: `wait -n $INPUT_PIDS || wait $INPUT_PIDS` was used.
  * When executed non-interactively or when `stdin` reaches EOF (such as through piped inputs or subshells), `read` exits with code 1.
  * Because the return code was non-zero, bash evaluated the fallback `|| wait $INPUT_PIDS` (without `-n`), which blocked indefinitely waiting for the persistent gamepad `dd` listeners.
* **Standard Non-Blocking Pattern:**
  ```bash
  wait_for_exit() {
      print_msg "\n  >>> กดปุ่มใดก็ได้บนเครื่อง หรือ คีย์บอร์ด เพื่อปิดหน้านี้ <<<"
      (
          if [ -t 0 ]; then
              read -s -n 1 -r 2>/dev/null
          elif [ -c /dev/tty1 ]; then
              read -s -n 1 -r < /dev/tty1 2>/dev/null
          else
              read -s -n 1 -r 2>/dev/null
          fi
      ) &
      INPUT_PIDS="$!"
      for ev in /dev/input/event*; do
          if [ -r "$ev" ]; then
              ( dd if="$ev" of=/dev/null bs=16 count=1 2>/dev/null ) &
              INPUT_PIDS="$INPUT_PIDS $!"
          fi
      done
      wait -n $INPUT_PIDS 2>/dev/null || sleep 2
      kill -9 $INPUT_PIDS 2>/dev/null || true
  }
  ```

### 4. Background Daemon Detachment (`disown` Requirement)
* When launcher scripts start daemons via `nohup <binary> <args> > /tmp/<log> 2>&1 &`, the process remains linked to the script's job table in bash.
* If the launcher script exits or is interrupted by EmulationStation, the child daemon may receive `SIGHUP` or `SIGTERM` if the subshell process group is cleaned up.
* **Standard Pattern:** Always invoke `disown` immediately after backgrounding long-running daemons:
  ```bash
  nohup "$BIN" <args> > /tmp/<tool>.log 2>&1 &
  disown
  sleep 2
  ```

### 5. playOS 4.0 Graphical Frontend (`playfe`) Menu & Cover Art Integration
* **Frontend Service:** playOS 4.0 uses `/usr/local/bin/playfe` (managed by `playfe.service`), which reads `/etc/emulationstation/es_systems.cfg` and automatically matches cover art in `/roms/<system>/images/`.
* **Enabling the `TOOLS` Category (`tools_menu`):** Run [`tools_menu/Install_Tools_Menu.sh`](file:///d:/me/r36h/tools/tools_menu/Install_Tools_Menu.sh) to register `<name>tools</name>` (with `<path>/roms/tools/</path>`, `<theme>tools</theme>`, `<command>sudo bash %ROM%</command>`) in `/etc/emulationstation/es_systems.cfg` and restart `playfe.service`. Built-in system icons (`/usr/local/share/playfe/logos/tools.png` and `tools-card.png`) are pre-installed on playOS.
* **Cover Art (`512x512` PNG, Zero-`gamelist.xml`):** Each tool installer (`Install_<Tool>.sh`) only needs to copy `<ScriptStem>.sh` to `/roms/tools/` and `<ScriptStem>-thumb.png` to `/roms/tools/images/<ScriptStem>-thumb.png`. `playfe` automatically discovers both the script name and its cover art without requiring `gamelist.xml`.
* **`playfe` Subdirectory Hiding Mechanics (`play::GamelistParser::scanDirectory` at `0x6df40`):**
  1. **Rule 1 — Stem-Matching Auto-Skip (for `.sh` systems):**
     * `playfe` normalizes every top-level `.sh` filename stem in `/roms/tools/` by stripping all non-alphanumeric characters and lowercasing (`[a-z0-9]`, must be `> 4` chars).
     * When scanning subdirectories in `/roms/tools/`, `playfe` normalizes each subdirectory name the same way (`[a-z0-9]`, `> 4` chars). If the normalized subdirectory name is a **substring** of any top-level `.sh` stem, `playfe` **skips scanning that subdirectory completely**:

     | Top-Level Script (`/roms/tools/`) | Normalized Stem | Subdirectory (`/roms/tools/`) | Normalized Dir | Result in `playfe` |
     | :--- | :--- | :--- | :--- | :--- |
     | `Screen_Off.sh` | `screenoff` | `screen_off/` | `screenoff` | **Auto-Hidden** (`screenoff` ⊆ `screenoff`) |
     | `Start_Web_Terminal.sh` | `startwebterminal` | `web_terminal/` | `webterminal` | **Auto-Hidden** (`webterminal` ⊆ `startwebterminal`) |
     | `Start_Web_FileManager.sh` | `startwebfilemanager` | `web_filemanager/` | `webfilemanager` | **Auto-Hidden** (`webfilemanager` ⊆ `startwebfilemanager`) |
     | `Speedtest.sh` | `speedtest` | `speedtest/` | `speedtest` | **Auto-Hidden** (`speedtest` ⊆ `speedtest`) |
     | *(Mismatch)* `Run_Net.sh` | `runnet` | `speedtest/` | `speedtest` | **NOT Hidden** (`speedtest` ⊈ `runnet` — leaks inner `.sh`!) |
     | *(Too Short)* ` Tool.sh` | `tool` (≤ 4 chars) | `tool/` | `tool` (≤ 4 chars) | **NOT Hidden** (length must be `> 4` alphanumeric chars) |

  2. **Rule 2 — Hiding Non-Menu Tools via `gamelist.xml` (`<hidden>true</hidden>`):**
     * When a tool does **NOT** place a top-level `.sh` launcher in `/roms/tools/` (Archetype 2 Background Daemons & Archetype 4 System Configuration tools like `power_button/`, `quick_tools/`, `tools_menu/`, `mercusys_wifi/`), `playfe` will recurse into its subfolder and show its `Install_*.sh` / `Uninstall_*.sh` scripts in the `TOOLS` menu unless hidden.
     * Therefore, every non-menu tool's `Install_*.sh` **MUST** run the standard `gamelist.xml` hiding snippet to mark all `.sh` files inside its own `$SCRIPT_DIR` as `<hidden>true</hidden>`:
       ```bash
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
       ```
  3. **Rule 3 — Dot-Directory (`d_name[0] == '.'`) & Asset Folder Skip (No `.sh` inside):**
     * Any subdirectory starting with `.` is skipped immediately at the `readdir` loop (`0x6e030`), and subdirectories that contain no `.sh` files (such as `/roms/tools/images/`) never appear in the menu because `scanDirectory` only adds files matching `<extension>` (`.sh .SH`).
* **Launch Quirks (`stdin` & Button Release Debounce):** `playfe` runs scripts with `stdin` (`fd 0`) attached to `/dev/null` (so `read` subshells inside `wait -n` must append `|| sleep 86400`), and scripts that immediately listen for raw `/dev/input/event*` wake events must `sleep 0.6` first to ignore the `B` launch button release event.
* **Full Reference:** See [`PLAYFE_MENU_GUIDE.md`](file:///d:/me/r36h/tools/PLAYFE_MENU_GUIDE.md) for the complete architecture and installer templates.

### 6. `playOS Terminal` (`FindManager`) Output Buffering & Direct SDL2 KMSDRM UI
* **How `FindManager` Runs Scripts:** The built-in `playOS Terminal` app (`/opt/FindManager_Data/FindManager`) executes scripts via `popen(cmd, "r")` in a background thread (`terminalWorker`), rendering only `"Running.."` via NanoVG/GLES2 at 60 FPS until the child process exits (`pclose`), and only then prints the collected `stdout` buffer as plain text (without ANSI escape code parsing).
* **Why Text TUIs Cannot Render Live inside `FindManager`:** Writing to `stdout` is buffered until process exit, and writing to `/dev/tty1` is covered by `FindManager`'s GLES2 DRM surface.
* **Standard Solution (`xp_setup_ui`):** When an interactive controller-driven UI is requested, freeze `FindManager|playfe` (`pkill -STOP -f "FindManager|playfe"`), launch [`xp_setup_ui`](file:///d:/me/r36h/tools/xp_setup_ui/xp_setup_ui) (which renders directly to KMSDRM via SDL2 and reads `/dev/input/event*` for D-Pad `544..547` and buttons `304`/`305`), print a plain-text summary to `stdout` on completion, and resume `FindManager|playfe` (`pkill -CONT -f "FindManager|playfe"`).



