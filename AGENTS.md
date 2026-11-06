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
├── screenshot/                       <-- Framebuffer Screen Capture Utility
│   ├── screenshot.sh                <-- Dual-output capture script (fbdev /dev/fb0)
│   ├── Install_Screenshot.sh        <-- Standalone installer for /roms/tools/ & PATH
│   └── README.txt                   <-- User guide & instructions
├── quick_tools/                      <-- Top-level Shortcut Utility (00_tools)
│   ├── Create_Quick_Tools.sh        <-- Dual-output launcher for /roms/tools/ & CLI
│   ├── Install_Quick_Tools.sh       <-- Standalone installer for /roms/tools/
│   └── README.txt                   <-- User guide & instructions
├── screen_off/                       <-- Screen Preserver / Backlight Shutoff Utility
│   ├── Screen_Off.sh                <-- Dual-output screen off & evdev wake launcher
│   ├── Install_Screen_Off.sh        <-- Standalone installer for /roms/tools/ & PATH
│   └── README.txt                   <-- User guide & instructions
├── power_button/                     <-- Power Button Hold-to-Shutdown Daemon
│   ├── Install_Power_Button.sh      <-- Standalone installer & service activator
│   ├── Status_Power_Button.sh       <-- Status inspector (PID, RAM, device, logs)
│   ├── Uninstall_Power_Button.sh    <-- Clean uninstaller & teardown script
│   ├── README.txt                   <-- User guide & instructions
│   └── daemon/                      <-- Internal daemon subfolder
│       ├── power_button_daemon.py   <-- Python PMIC event listener (3s hold trigger)
│       └── power-button-daemon.service <-- Systemd background service unit
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


