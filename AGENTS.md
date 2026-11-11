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
  * **Status:** Fully supported. Agents can interact with the device directly via SSH (e.g. Python `paramiko` or OpenSSH).
  * **IP Address & Hostnames (mDNS):**
    * **mDNS Resolution:** Fully supported out of the box via Avahi/Bonjour (`.local` domain). Agents can resolve IP or connect directly using hostname without asking the user.
    * **playOS Hostname (Default/Active):** `playos.local` (resolves via `ping playos.local` or `Resolve-DnsName playos.local`).
    * **dArkOS Hostname (User Setup):** `svvv.local` (when booting into dArkOS).
    * **Fallback:** Only ask the user for manual IP if `.local` mDNS resolution fails or times out.
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
├── TOOLS_CATALOG.md                  <-- Complete tool catalog, status table, & detailed file tree
├── PLAYFE_MENU_GUIDE.md              <-- playOS 4.0 Frontend (playfe) menu & cover art guide
├── NCURSES_TUI_GUIDE.md              <-- Genuine Linux ncurses TUI (dialog + fb0_mirror) guide
├── LED_HARDWARE_GUIDE.md             <-- R36H Power/Status LED hardware architecture & sysfs guide
└── WIFI_HARDWARE_GUIDE.md            <-- Realtek USB Wi-Fi (RTL8188EU) architecture & quirks guide
```

> [!NOTE] Master Tool Catalog & Hardware Guides
> * The complete breakdown of all tools, their archetypes, playOS menu launcher integration, and full file trees are centrally maintained in **[`TOOLS_CATALOG.md`](file:///d:/me/r36h/tools/TOOLS_CATALOG.md)**.
> * Deep hardware architecture and subsystem specifics are documented in central guides: [`LED_HARDWARE_GUIDE.md`](file:///d:/me/r36h/tools/LED_HARDWARE_GUIDE.md) and [`WIFI_HARDWARE_GUIDE.md`](file:///d:/me/r36h/tools/WIFI_HARDWARE_GUIDE.md).

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

5. **Action Completion & Exit Lifecycle Standard:**
   * **Install & Uninstall:** Always treated as One-Shot actions. Upon completion, show a summary dialog (`dialog --msgbox`) stating `Press A or Enter to exit.` and immediately call `exit 0` to return control to the frontend.
   * **Single-Config Tools (e.g. `Screen Off` with only 1 setting):** Completing configuration finishes the user's intent. Show summary with `Press A or Enter to exit.` and call `exit 0` directly.
   * **Multi-Config Tools ($\ge 2$ settings):** Completing one setting must show `Press A or Enter to continue.` and **return to the Main Setup Menu**, allowing the user to configure additional settings in the same session without re-opening the app. Exiting is performed manually via the menu's `Exit` option (or Button `B` / Cancel).
   * **Cancel / Back (Button B):** Always returns to the Setup Menu to allow choosing another action.

---

### 4.1 Standard Tool Archetypes & Directory Layouts

To keep the user-facing workspace and handheld menus clean and intuitive, all tools developed or maintained in this workspace **MUST** adhere to one of the standardized directory archetypes based on their execution lifecycle.

> [!IMPORTANT] Dual-Target Support (`/roms/ports/` vs `/roms/tools/`) & Side-by-Side Packaging
> * **Primary Target (`/roms/ports/`):** The `PORTS` menu is enabled by default on all handheld systems (`playOS`, `dArkOS`, and `ArkOS`). In contrast, the `TOOLS` tab (`/roms/tools/`) is disabled by default in stock `playOS 4.0`. Therefore, user-facing tools must support **`/roms/ports/` as the primary, zero-setup target**, while retaining seamless compatibility with `/roms/tools/`.
> * **Shallow Scan in Ports:** In `playOS 4.0` (`playfe`), the `ports` system performs a **Shallow Scan** (only files directly in `/roms/ports/*.sh` are scanned; subdirectories are ignored).
> * **Side-by-Side Layout:** To ensure instant visibility upon copying to `/roms/ports/`, the user-facing launcher (e.g., `<Tool>_Setup.sh`) **must sit side-by-side** with the internal subfolder (`<tool_name>/`).
> * **Workspace Encapsulation:** In the local workspace (`d:\me\r36h\tools/<tool_name>/`), all files remain strictly inside `<tool_name>/` (containing `<Tool>_Setup.sh`, `README.txt`, and the internal data folder `<tool_name>/`).

#### Archetype 1: On-Demand Service Tools (with Start / Stop)
* **Use Case:** Services, web servers, or daemons that run on-demand (when started by the user) and provide a clean stop script to reclaim CPU/RAM before gaming (e.g. `web_terminal`, `web_filemanager`).
* **Root Directory:** Contains `<Tool>_Setup.sh`, user manual, and internal `<tool_name>/` data folder.
* **Internal Subfolder (`<tool_name>/app/`):** Houses binaries, core runtime files, and the `Start_*.sh` / `Stop_*.sh` scripts with cover arts.
* **Layout Structure (Side-by-Side):**
  ```text
  <tool_name>/
  ├── <Tool>_Setup.sh         <-- All-in-One TUI Manager (Install, Config, Uninstall)
  ├── README.txt              <-- User manual & documentation
  └── <tool_name>/            <-- Internal application subfolder (side-by-side)
      └── app/
          ├── <binary_or_core>
          ├── Start_<Tool>.sh
          ├── Start_<Tool>-thumb.png
          ├── Stop_<Tool>.sh
          └── Stop_<Tool>-thumb.png
  ```
* **Menu Integration:** Running `<Tool>_Setup.sh` copies or symlinks `Start_<Tool>.sh` and `Stop_<Tool>.sh` directly into the active menu directory (`/roms/ports/` or `/roms/tools/`).

#### Archetype 2: Background Daemon Tools (Always-On / System Service)
* **Use Case:** Background system monitors, hardware button listeners, idle timers, or battery/power hooks that run continuously as systemd services without requiring manual start/stop toggling (e.g. `power_button`, `screen_off`).
* **Root Directory:** Contains `<Tool>_Setup.sh`, user manual, and internal `<tool_name>/` data folder.
* **Internal Subfolder (`<tool_name>/daemon/` & `<tool_name>/app/`):** Houses the daemon script/binary, systemd unit, and status config.
* **Layout Structure (Side-by-Side):**
  ```text
  <tool_name>/
  ├── <Tool>_Setup.sh         <-- All-in-One TUI Manager (Setup, Timeout/Config, Uninstall)
  ├── README.txt              <-- User manual & documentation
  └── <tool_name>/            <-- Internal data subfolder (side-by-side)
      ├── app/
      │   ├── <Tool>_Setup-thumb.png
      │   └── status.conf     <-- Persistent state config
      └── daemon/
          ├── <daemon_script> <-- Python PMIC/evdev listener or daemon binary
          └── <tool>.service  <-- Systemd background service unit
  ```
* **System Integration:** Running `<Tool>_Setup.sh` registers the service into `/etc/systemd/system/`, enables it for boot-time autostart, and provides live status configuration.

#### Archetype 3: One-Shot Interactive Tools (Menu Launcher / Runtime App)
* **Use Case:** Tools that perform an immediate task once and exit immediately back to the frontend, or dual-purpose tools that combine an instant launcher with a setup manager (e.g. `screenshot`, `speedtest`, `screen_off`).
* **Root Directory:** Contains `<Tool>_Setup.sh`, user manual, and internal `<tool_name>/` data folder.
* **Internal Subfolder (`<tool_name>/app/`):** Houses runtime scripts, helper modules, cover arts, and status config.
* **Layout Structure (Side-by-Side):**
  ```text
  <tool_name>/
  ├── <Tool>_Setup.sh         <-- All-in-One TUI Manager (Install, Config, Uninstall)
  ├── README.txt              <-- User manual & documentation
  └── <tool_name>/            <-- Internal data subfolder (side-by-side)
      └── app/
          ├── <Tool>.sh       <-- Instant execution runner
          ├── <Tool>-thumb.png<-- 512x512 cover art for instant runner
          ├── <Tool>_Setup-thumb.png<-- 512x512 cover art for Setup wizard
          ├── status.conf     <-- Persistent state config
          └── <modules_or_bin>
  ```
* **Menu Integration:** Running `<Tool>_Setup.sh` installs `<Tool>.sh` and its cover art into the active menu directory (`/roms/ports/` or `/roms/tools/`), displaying two clear entries: the instant action tool and the setup wizard.

---

### 4.2 Universal Setup UI Engine (`setup_ui`) Usage Policy

The workspace provides a reusable C/SDL2 KMSDRM graphical setup wizard engine in [`setup_ui/`](file:///d:/me/r36h/tools/setup_ui/).

* **When to Use `setup_ui`:**
  * Use `setup_ui` **ONLY** when the user explicitly requests a graphical UI, Setup Wizard, or controller-navigable options menu (`UP/DOWN` to select options, `LEFT/RIGHT` to select `[ OK ]` / `[ Back ]` / `[ Exit ]`, and `A` or `B` to confirm).
  * By default, standard installers (`Install_<Tool>.sh`) should remain simple, non-interactive shell scripts unless a UI/Wizard is requested.
* **How to Package & Integrate (`No Recompilation Needed`):**
  * Copy **only** the pre-compiled ARM64 binary [`setup_ui/setup_ui`](file:///d:/me/r36h/tools/setup_ui/setup_ui) into the target tool's internal subfolder (`<tool_name>/daemon/setup_ui` or `<tool_name>/app/setup_ui`).
  * **Never** clutter individual tool folders with `.c` source files (`setup_ui.c`, `countdown_ui.c`). All C source code is maintained centrally in [`setup_ui/`](file:///d:/me/r36h/tools/setup_ui/).
  * Create the launcher script (e.g., `Setup_UI.sh` based on [`setup_ui/Demo_Setup.sh`](file:///d:/me/r36h/tools/setup_ui/Demo_Setup.sh)) that pauses `FindManager|playfe` (`pkill -STOP -f "FindManager|playfe"`), pipes the custom `header`, `[page]`, and `[progress]` configuration block to `setup_ui - << 'EOF'`, and resumes `FindManager|playfe` (`pkill -CONT -f "FindManager|playfe"`) on exit.
* **Bitmap Font Bit-Order Rule:** When embedding or rendering 8x8 bitmap fonts in custom SDL2 KMSDRM binaries, ensure bit extraction matches the array's endianness (e.g. `setup_ui.c` uses LSB-first `font8x8_basic`, requiring `bits & (1 << col)`). See [Section 7.7](#7-embedded-bitmap-font-bit-order--horizontal-mirroring-lsb-vs-msb-in-sdl2-ui).

---

## 5. Universal Constraints & Rules for AI Agents

When authoring, modifying, or packaging tools for playOS on R36H, AI agents **MUST** follow these rules:

1. **Always Use Unix Line Endings (LF):**
   * All shell scripts (`.sh`), configuration files, and systemd units must be saved with Unix line feeds (`\n`), never Windows CRLF (`\r\n`). CRLF causes `\r: command not found` fatal errors on Linux.

2. **Dual Output Pattern:**
   * When writing user-facing scripts for `/roms/tools/`, redirect or mirror output to `/dev/tty1`:
     ```bash
     {
       echo "======================================"
       echo "          MY TOOL TITLE               "
       echo "======================================"
     } > /dev/tty1 2>&1
     ```

3. **Preserve Subdirectory Modular Documentation:**
   * Keep `AGENTS.md` clean and focused on general environment specifications, architecture, and coding standards.
   * Place tool-specific configuration manuals, wiring/chipset notes, or driver quirks inside the respective tool folder.

4. **Do Not Automatically Generate ZIP Archives:**
   * Do **NOT** automatically compress folders or create `.zip` archives unless explicitly requested by the user. Keep tools maintained as clean, direct source directories and files within the workspace.

5. **Keep C Source Code in `setup_ui/` and Binaries in Tool Subfolders:**
   * Only use `setup_ui` when the user explicitly asks for a graphical Setup UI or controller-selectable menu. When used, place the compiled `setup_ui` binary inside the tool's subfolder (`daemon/` or `app/`) and keep all `.c` source files in [`setup_ui/`](file:///d:/me/r36h/tools/setup_ui/).

6. **Universal Stem-Matching Naming Standard (Auto-Hides Setup/Subfolders without `gamelist.xml` Code):**
   * **Core Principle:** Every tool installed under `/roms/tools/<tool_name>/` **MUST** place at least one top-level launcher `.sh` directly in `/roms/tools/` whose filename stem matches the subfolder name according to the Stem-Matching Formula. By following this standard, `playfe` automatically skips scanning the internal subfolder natively, completely eliminating the need to write Python/XML snippets to inject `<hidden>true</hidden>` into `gamelist.xml`.
   * **The Stem-Matching Formula:**
     1. `clean_name`: Convert string to lowercase and strip all non-alphanumeric characters (`[a-z0-9]`).
     2. **Length Constraint:** `length(clean_dir) > 4` (must have at least 5 alphanumeric characters).
     3. **Substring Constraint:** `clean_dir` **MUST** be a substring of `clean_launcher` (`clean_dir ⊆ clean_launcher`).
   * **Standard Naming Formulas by Archetype:**
     * **Archetype 1 (On-Demand Services):**
       - Subfolder: `/roms/tools/<service_name>/` (e.g. `web_terminal/` $\rightarrow$ `"webterminal"`)
       - Top-Level Launcher: `/roms/tools/Start_<service_name>.sh` (e.g. `"startwebterminal"`)
       - Result: `"webterminal"` $\subseteq$ `"startwebterminal"` $\rightarrow$ **Auto-Hidden!**
     * **Archetype 2 (Background Daemons / Services):**
       - Subfolder: `/roms/tools/<daemon_name>/` (e.g. `power_button/` $\rightarrow$ `"powerbutton"`)
        - Top-Level Launcher: `<Daemon>_Setup.sh` (e.g. `Power_Button_Setup.sh` $\rightarrow$ "powerbuttonsetup")
        - Result: "powerbutton" $\subseteq$ "powerbuttonsetup" $\rightarrow$ **Auto-Hidden!** (Gives user a useful All-in-One Setup/Config entrypoint without cluttering the menu with internal scripts).
     * **Archetype 3 (One-Shot Utilities — Single Launcher):**
       - Subfolder: `/roms/tools/<tool_name>/` (e.g. `speedtest/` $\rightarrow$ `"speedtest"`)
       - Top-Level Launcher: `/roms/tools/<tool_name>.sh` (e.g. `Speedtest.sh` $\rightarrow$ `"speedtest"`)
       - Result: `"speedtest"` $\subseteq$ `"speedtest"` $\rightarrow$ **Auto-Hidden!**
     * **Archetype 3 (One-Shot Utilities — Multi-Action / Toggle Launchers):**
       - Subfolder: `/roms/tools/<common_prefix>/` (e.g. `set_led/` $\rightarrow$ `"setled"`)
       - Top-Level Launchers: `/roms/tools/<Common_Prefix>_<Action1>.sh`, `<Common_Prefix>_<Action2>.sh` (e.g. `Set_LED_to_Red.sh` $\rightarrow$ `"setledtored"`, `Set_LED_to_Blue.sh` $\rightarrow$ `"setledtoblue"`)
       - Result: `"setled"` $\subseteq$ `"setledtored"` and `"setled"` $\subseteq$ `"setledtoblue"` $\rightarrow$ **Auto-Hidden!**
   * **Technical Reference (`gamelist.xml` Fallback):**
     - Modifying `gamelist.xml` via Python `xml.etree.ElementTree` with `<hidden>true</hidden>` is retained strictly as an optional technical fallback for legacy tools or pure non-menu drivers, but is **NOT required or recommended** for tools adhering to this naming standard.

7. **Strict Anti-Clutter Rule: Eliminate Non-Essential `.sh` Files from Subfolders (playOS Recursive Scan Invariant):**
   * **Core Principle:** In **playOS**, the frontend `playfe` recursively traverses all folders inside `/roms/tools/`. If a subfolder does not match a top-level stem or lacks `<hidden>true</hidden>`, `playfe` discovers and presents **every single `.sh` file** on the handheld's main menu, even if buried inside internal folders like `app/` or `scripts/`.
   * **Operational Requirement:** Always keep **only the single necessary `.sh` launcher** in distribution packages and target tools directories. Never bundle auxiliary, fallback, or separate CLI helper `.sh` scripts (e.g. `Install_*.sh`, `Uninstall_*.sh`, helper toggles) inside subfolders. All setup, switching, and management logic must be internal to the main launcher or handled via compiled ELF ARM64 binaries (`fb0_mirror`, `setup_ui`) to prevent polluting the TOOLS menu.

8. **User Language & Communication Preference (Thai Language):**
   * **Mandatory Language for Summaries and Explanations:** Always communicate, summarize, explain steps, and provide user-facing updates in **Thai (ภาษาไทย)**.
   * Technical terms, code symbols, paths, and command syntax may remain in English, but all explanations, summaries, and conversational responses must be clearly and naturally written in Thai.

9. **Deprecation of `fb0_mirror` (Native Console & `gptokeyb` Standard):**
   * **Core Invariant:** Do **NOT** use, bundle, or compile `fb0_mirror` in tool suites.
   * **Architectural Rationale:** On both `playOS` (`playfe`) and `ArkOS` (`emulationstation`), launching a tool script from the menu automatically pauses frontend rendering and grants direct control of `/dev/tty1`. Running an auxiliary framebuffer-capturing daemon (`fb0_mirror`) creates redundant processes, risks TIOCSTI keycode race conditions, and introduces unnecessary failure points.
   * **Mandatory Standard:**
     - Render terminal user interfaces using genuine Linux `dialog` outputting directly to the text console / `/dev/tty1`.
     - Translate gamepad inputs into console keystrokes using `/opt/inttools/gptokeyb` or `/usr/bin/gptokeyb`.
     - Ensure 100% feature and visual parity between `playOS` and `ArkOS` without requiring secondary mirror binaries.

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
   * Target Host: `playos.local` (or `svvv.local` if on dArkOS, fallback to manual IP if mDNS fails) (Port: `22`, User: `ark`, Pass: `ark`)
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
      # Note: Use bs=48 because sizeof(struct input_event) is 24 bytes on 64-bit
      # kernels (aarch64) and 16 bytes on 32-bit. bs=16 causes EINVAL on 64-bit!
      for ev in /dev/input/event*; do
          if [ -r "$ev" ]; then
              ( dd if="$ev" of=/dev/null bs=48 count=1 2>/dev/null ) &
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

### 5. Frontend Architecture & Menu Refresh: playOS (`playfe`) vs. dArkOS / ArkOS (`emulationstation`)

#### 5.1 Frontend Service Differences & Caching Mechanics
Handheld devices (R36H / R36S) run either **playOS 4.0** (with `playfe`) or **dArkOS / ArkOS** (with `emulationstation`). Their frontend lifecycles and menu-refresh requirements differ fundamentally:

| Property | playOS 4.0 (`playfe`) | dArkOS / ArkOS (`emulationstation`) |
| :--- | :--- | :--- |
| **Active Service** | `playfe.service` | `emulationstation.service` |
| **Binary Path** | `/usr/local/bin/playfe` | `/usr/bin/emulationstation/emulationstation` |
| **Launch Wrapper** | None (direct binary) | `/usr/bin/emulationstation/emulationstation.sh` |
| **Tools Directory** | `/roms/tools/` | `/roms/tools/` (bind-mounted to `/opt/system/Tools/` via `/etc/fstab`) |
| **Tools Menu Origin** | `<system>` block in `es_systems.cfg` | Internal `GuiTools::addScriptsToMenu` (`0x28ca40`) compiled in binary |
| **Menu Caching** | Cached in `/home/ark/.config/playfe/library.tsv` | Cached in process RAM at startup (never polls directory while active) |
| **Why Scripts Don't Appear** | Stale `library.tsv` if service not restarted | Process RAM cache still holds previous directory listing from boot |
| **CLI Refresh Command** | `sudo systemctl restart playfe.service` | `sudo systemctl restart emulationstation.service` |
| **On-Device UI Refresh** | Not available (automatic on reboot) | Controller `START` -> **UI SETTINGS** -> **UPDATE GAMES LISTS** |

#### 5.2 Mandatory Universal Frontend Refresh Snippet for Install / Uninstall Scripts
Because tools may be installed on either playOS or dArkOS/ArkOS, all installers (`Install_*.sh`) and uninstallers (`Uninstall_*.sh`) **MUST** execute the universal dual-refresh sequence before exiting:

```bash
# Universal Frontend Reload for dArkOS / ArkOS (emulationstation) and playOS (playfe)
sync
sudo systemctl restart emulationstation.service 2>/dev/null || true
if systemctl is-active --quiet playfe.service 2>/dev/null; then
    systemctl restart playfe.service 2>/dev/null || true
fi
```
* **Why `sudo systemctl restart emulationstation.service` is first:** On dArkOS / ArkOS, `emulationstation` takes over `/dev/tty1`. Restarting the service forces an immediate re-read of `/opt/system/Tools/` (`/roms/tools/`) and `/roms/ports/gamelist.xml` without requiring a reboot.
* **Why silent fallback (`2>/dev/null || true`):** If running on playOS where `emulationstation.service` is not installed or inactive, systemd ignores it silently and restarts `playfe.service`.

#### 5.3 playOS 4.0 Graphical Frontend (`playfe`) Menu & Cover Art Integration
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

### 6. `playOS Terminal` (`FindManager`) Output Buffering, `setup_ui`, & Real `dialog` TUI (`fb0_mirror`)
* **How `FindManager` Runs Scripts:** The built-in `playOS Terminal` app (`/opt/FindManager_Data/FindManager`) executes scripts via `popen(cmd, "r")` in a background thread (`terminalWorker`), rendering only `"Running.."` via NanoVG/GLES2 at 60 FPS until the child process exits (`pclose`), and only then prints the collected `stdout` buffer as plain text (without ANSI escape code parsing).
* **Why Text TUIs Cannot Render Live inside `FindManager`:** Writing to `stdout` is buffered until process exit, and writing to `/dev/tty1` renders into `/dev/fb0` (`DMA addr: 0x00000000`), whereas the Rockchip VOP hardware (`ff460000.vop`, `win1-0`) remains pointed at `FindManager`/`playfe`'s DRM GEM buffer (`addr: 0x0012c000`).
* **Standard Solution A — Declarative Setup Wizard ([`setup_ui`](file:///d:/me/r36h/tools/setup_ui/setup_ui)):** Freeze `FindManager`/`playfe` (`killall -STOP FindManager playfe`), launch `setup_ui` (which renders directly to KMSDRM via SDL2 and reads `/dev/input/event*` for D-Pad `544..547` and buttons `304`/`305`), print a plain-text summary to `stdout` on completion, and resume (`killall -CONT FindManager playfe`).
* **Standard Solution B — Genuine Linux ncurses `dialog` / `whiptail` ([`fb0_mirror`](file:///d:/me/r36h/tools/setup_ui/fb0_mirror)):**
  * Run `fb0_mirror` in the background while executing `dialog` on `/dev/tty1`.
  * `fb0_mirror` reads `/dev/fb0` via `pread()` into heap RAM (avoiding Mali GLES2 `VM_IO` `mmap_sem` deadlocks), uploads it as an opaque `SDL_PIXELFORMAT_RGB888` texture (`SDL_BLENDMODE_NONE` to ignore `fbcon`'s `Alpha = 0`), detaches SDL2's internal `/dev/tty1` reader (`dup2` to `/dev/null` + `KDSKBMODE = K_UNICODE` + `KDSETMODE = KD_TEXT` so `SDL_EVDEV_kbd` cannot steal keystrokes), and injects R36H gamepad presses into `/dev/tty1` via `ioctl(tty_fd, TIOCSTI, &c)`.
  * **Dynamic OS-Aware Button Mapping:** `fb0_mirror` dynamically arbitrates between `playfe` (`/home/ark/.config/playfe/playfe.cfg` `swap_ab`) and legacy ArkOS (`es_settings.cfg` / `Switch_AB`), mapping OK to `\n` (Enter) and Cancel/Exit to `\033\033` (Double ESC) to ensure 100% native button consistency across frontends.
  * **Interactive Menu Choice Capture Standard:** Always capture selections via a temporary file:
    ```bash
    dialog ... 2> "$CHOICE_TMP" < "$DIALOG_IN" > "$DIALOG_OUT"
    RET=$?
    SELECTED=$(cat "$CHOICE_TMP" 2>/dev/null | tr -d ' "\r\n')
    rm -f "$CHOICE_TMP"
    ```
    *Never* use subshell FD swapping (`--output-fd 3 3>&1 ...`), which causes empty string capture bugs in bash subshells.
  * **Progress Gauge (`--gauge`) Stdin Isolation:** `dialog --gauge` reads exclusively from `stdin` via pipe (`|`). *Never* append `< "$DIALOG_IN"` to `--gauge`, as it breaks the pipe and hangs the terminal indefinitely. Pipe `stdin` normally and redirect only stdout/stderr: `> "$DIALOG_OUT" 2>/dev/null`.
  * **Frontend Restart Ban (Parent-Child Deadlock Prevention):** *Never* invoke `systemctl restart playfe.service` or `systemctl restart emulationstation.service` from inside any menu-launched script. Because the script runs in the frontend's cgroup, restarting the parent triggers a 90-second systemd deadlock. `playfe` automatically pauses and resumes rendering in 0.1s on `exit 0`, and detects newly added files via inotify (`libraryChanged`).
  * **Handheld Single-Choice Standard (Avoid `--radiolist`):** *Always* use `dialog --menu` with `--default-item "$CURRENT_VALUE"` instead of `dialog --radiolist`. On handheld gamepads mapped via `gptokeyb`, button `A` maps to `Enter`. In `--radiolist`, pressing `Enter` without `Space` submits the default pre-checked item instead of the user-highlighted option.
  * **Dual-OS Input Architecture:**
    * **playOS 4.0:** Frontend `playfe` runs on SDL2 KMSDRM. Requires `fb0_mirror` to mirror `/dev/fb0` and inject controller inputs via `ioctl(TIOCSTI)`.
    * **dArkOS / ArkOS:** Frontend runs on framebuffer `/dev/fb0` and uses `/opt/inttools/gptokeyb` for gamepad-to-keyboard mapping.
  * **Full Reference:** See [`NCURSES_TUI_GUIDE.md`](file:///d:/me/r36h/tools/NCURSES_TUI_GUIDE.md) and [`setup_ui/Demo_Dialog_TUI.sh`](file:///d:/me/r36h/tools/setup_ui/Demo_Dialog_TUI.sh).

### 7. Embedded Bitmap Font Bit-Order & Horizontal Mirroring (LSB vs. MSB in SDL2 UI)
* **The Symptom:** In custom C/SDL2 KMSDRM graphical interfaces (such as `setup_ui`), text can appear horizontally mirrored / flipped (e.g., character 'B' has its straight backbone on the right side and rounded curves facing left; 'C' has its opening facing left instead of right).
* **The Root Cause (LSB-First vs. MSB-First Mismatch):**
  * Embedded bitmap font headers (such as Daniel Hepper's widely used `font8x8_basic`) store individual scanline rows as 8-bit unsigned chars (`uint8_t`), where **Bit 0** corresponds to the **leftmost pixel** (Column 0) and **Bit 7** corresponds to the **rightmost pixel** (Column 7).
  * If the character rendering loop extracts bits using an MSB-first pattern:
    ```c
    /* ❌ BUG: MSB-first extraction on LSB-first font table -> Horizontal Mirroring */
    if (bits & (0x80 >> col)) {
        SDL_Rect r = { x + col * scale_x, y + row * scale_y, scale_x, scale_y };
        SDL_RenderFillRect(rend, &r);
    }
    ```
    `col = 0` evaluates Bit 7 (rightmost pixel) and draws it at the leftmost coordinate, completely mirroring every character along the vertical axis.
  * The correct extraction loop for LSB-first font arrays:
    ```c
    /* ✅ CORRECT: LSB-first extraction matching font8x8_basic */
    if (bits & (1 << col)) {
        SDL_Rect r = { x + col * scale_x, y + row * scale_y, scale_x, scale_y };
        SDL_RenderFillRect(rend, &r);
    }
    ```
* **Quick Rule of Thumb to Detect Table Bit-Order:**
  * Inspect the definition of uppercase `'C'` (ASCII 67):
    * If `'C'` contains `{0x3C, 0x66, 0x03, 0x03, 0x03, 0x66, 0x3C, 0x00}`: `0x03` (`00000011b`) has its 1s in lower bits (bits 0 and 1) representing the left vertical spine of the 'C'. This table is **LSB-first** and **MUST** use `(bits & (1 << col))`.
    * If `'C'` contains `{0x3C, 0x66, 0xC0, 0xC0, 0xC0, 0x66, 0x3C, 0x00}`: `0xC0` (`11000000b`) has its 1s in upper bits (bits 7 and 6) representing the left vertical spine of the 'C'. This table is **MSB-first** and **MUST** use `(bits & (0x80 >> col))`.

---

### 8. Power Indicator LED Hardware Architecture & Color Switching (R36H / RK3326)
* **Target Hardware:** R36H (`HL-R36H-V20`) running playOS / ArkOS base.
* **Legacy DTB Dummy Node:**
  * `/sys/class/leds/blue:heartbeat` is mapped to `gpio-17` (`GPIO0_C1`). This is a legacy entry inherited from the Odroid Go Advance / RG351 device tree and is **NOT** connected to the physical LED on R36H. Writing to it has no visible effect.
* **Active Hardware LED Pin (`gpio77`):**
  * The physical bi-color status LED is wired directly to **`gpio77`** (`GPIO2_PB5`).
  * **2-State Bi-Color Drive:**
    * `gpio77 = 0` (Logic Low): Powers the **BLUE LED** (referred to as "Green" in legacy ArkOS scripts like `Change LED to Green.sh` and `batt_life_warning.py.green`).
    * `gpio77 = 1` (Logic High): Powers the **RED LED** (matches `Change LED to Red.sh` and `batt_life_warning.py.red`).
    * `gpio77 direction: in` (High-Z): Circuit pull-down leaves the Blue LED illuminated.
  * **Software Turn-Off Limitation:**
    * The physical LED circuit is a direct 1-bit, 2-state design without a hardware power-gate / cutoff transistor.
    * **The LED cannot be completely turned off via software.** It will always display either Blue (`0`) or Red (`1`). To completely black it out, users must apply physical opaque tape (e.g. electrical tape) over the LED inside the shell.
* **Battery Life Daemon Integration (`batt_led.service`):**
  * `batt_led.service` runs `/usr/local/bin/batt_life_warning.py` in the background, constantly enforcing the LED color every 30 seconds.
  * **Persistent Color Switching:** To make color changes stick across reboots and runtime:
    1. Update `/sys/class/gpio/gpio77/value` immediately.
    2. Copy the corresponding boot script (`/usr/local/bin/fix_power_led.red` or `.green`) to `/usr/local/bin/fix_power_led`.
    3. Copy the corresponding battery warning daemon script (`/usr/local/bin/batt_life_warning.py.red` or `.green`) to `/usr/local/bin/batt_life_warning.py`.
    4. Restart the service: `systemctl restart batt_led`.

### 9. Wi-Fi Driver Architecture, Realtek Firmware & RTL8188EU Kernel Quirks
* **Hardware & Peripherals:** Mercusys MW150US USB Wi-Fi dongle (`2c4e:0102 Mercusys INC 802.11n NIC`) using Realtek **RTL8188EU / RTL8188EUS** chipset on playOS (Linux Kernel `4.4.189` / ARM64).
* **RTL8188EU vs. Built-in RTL8188FU:**
  * playOS kernel compiles `rtl8188fu` as a built-in static driver (`=y`). It cannot be managed via `modprobe`.
  * The Mercusys dongle (`2c4e:0102`) is **NOT** RTL8188FU; force-binding to `rtl8188fu` causes controller lockup. The correct driver is external module **`8188eu.ko`**.
* **HAL Ops Check Failure & Firmware Dependency:**
  * Missing firmware `/lib/firmware/rtlwifi/rtl8188eufw.bin` aborts HAL initialization halfway, causing `RTW: #### rtw_hal_ops_check - Error : Please hook hal_func.set_hw_reg_handler ####`.
  * Verified working firmware: `rtl8188eufw.bin` (`15,262 bytes`, MD5: `b66178b87ed8f917997b9cf38fc0cfd3`).
  * Verified working module: `8188eu.ko` (`1,167,320 bytes`, MD5: `959e7febc4be3bf6909fa877de7809b1`).
* **Hardware Stall & Cold Boot Requirement:**
  * Realtek USB microcontrollers latch into a hardware "Stall State" if initialization fails.
  * Soft reboots (`reboot`) do **not** cut power to the OTG USB port.
  * A full cold boot (`shutdown now`) is required to drain power rail capacitors and reset the dongle to a clean state.
* **Full Reference:** See [`WIFI_HARDWARE_GUIDE.md`](file:///d:/me/r36h/tools/WIFI_HARDWARE_GUIDE.md).

### 10. Frontend Lifecycle & Deadlock Prevention (Never Restart playfe from Menu Scripts)
* **Execution Model:**
  * In `playOS 4.0`, launching an item from the Ports or Tools menu executes via:
    `sudo perfmax %GOVERNOR% %ROM%; nice -n -19 %ROM%; sudo perfnorm`
  * The frontend `playfe` halts graphic rendering and waits synchronously for `%ROM%` (the child script) to exit.
  * Once the child script terminates (`exit 0`), `playfe` automatically re-acquires the DRM/KMS display and redraws the menu in less than **0.1 seconds**.
* **The 90-Second Deadlock Bug:**
  * When launched from the frontend, the child script belongs to the `playfe.service` systemd cgroup.
  * If the script runs `systemctl restart playfe.service`, `systemctl` blocks waiting for systemd to restart the service, while systemd waits for all processes in the cgroup (including the child script itself) to exit.
  * This triggers a **90-second systemd deadlock** (`State 'final-sigterm' timed out`), leaving `/dev/tty1` cleared with a stuck blinking cursor `\e[?25h`.
* **Universal Rule:**
  * **Never invoke `systemctl restart playfe.service` or `systemctl restart emulationstation.service` inside scripts launched from menus.**
  * `playfe` automatically watches the filesystem (`[playfe] library changed on disk: reloaded`) and reflects newly added/removed files seamlessly upon child script exit.






