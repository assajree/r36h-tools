# ARCHETYPES.md - Standard Tool Archetypes & PortMaster Directory Layouts

This document defines the standardized directory structures, lifecycle contracts, and EmulationStation / `playfe` integration models for all tools developed in the **playOS Tools Suite** on the **R36H Handheld Gaming Console**.

All tools developed or maintained in this workspace **MUST** adhere strictly to the PortMaster-aligned community standards and one of the standardized archetypes below.

---

## 1. Universal PortMaster Community Standards & Invariants

All user-facing tools must follow these core standards:

1. **Dual-Target Support (`/roms/ports/` as Primary Target):**
   * **Primary Target (`/roms/ports/`):** The `PORTS` menu is enabled by default on all handheld distributions (`playOS`, `dArkOS`, and `ArkOS`). In contrast, the `TOOLS` tab (`/roms/tools/`) is disabled by default in stock `playOS 4.0`. Therefore, **`/roms/ports/` is the primary, zero-setup target for all tools.**
   * **Shallow Scan in Ports:** In `playOS 4.0` (`playfe`), the `ports` system performs a **Shallow Scan** (only files directly in `/roms/ports/*.sh` are scanned; internal subdirectories like `/roms/ports/<tool_name>/*.sh` are ignored).

2. **Side-by-Side Packaging Architecture:**
   * The user-facing launcher script (e.g., `<Tool>.sh` or `<Tool>_Setup.sh`) sits directly in `/roms/ports/`, side-by-side with its dedicated internal data subfolder (`<tool_name>/`).
   * **Strict Lowercase Subfolders:** Data directory names **MUST be strictly lowercase alphanumeric** (e.g. `webfilemanager/`, `webterminal/`, `powerbutton/`, `screenoff/`). This eliminates cross-platform case-sensitivity bugs on FAT32/exFAT/ext4 filesystems and guarantees matching with the frontend's stem-matching auto-hide rules.
   * **Flat 1-Level Subfolder Hierarchy (PortMaster Standard):** Internal data subfolders must be flat. **Do NOT create nested `app/` or `daemon/` subfolders.** Core binaries, systemd units, configuration files, and assets reside directly inside `<tool_name>/`.

3. **Pre-Packaged Cover Art & Minimal Visual Standard (`images/`):**
   * **Standard Resolution & Aspect Ratio:**
     * **Official Standard:** **`512x512 PNG`** (Square 1:1, True RGB/RGBA).
     * **ทำไมต้องเป็น 512x512:** ให้ความคมชัดสูงสุดบนการ์ดเมนูของ `playfe` และ EmulationStation ตัวหนังสือคมกริบ ไม่เบลอ และโหลดเร็วมากบน RAM (ขนาดไฟล์ ~15–35 KB).
   * **Minimalist Design Standard (กฎการออกแบบสไตล์มินิมอล):**
     * **พื้นหลัง:** สีดำสนิท (#121212 หรือ #000000) เรียบเนียน 100% ไม่มีวงกลมหนาหรือกรอบลวดลายรอบนอก
     * **รูปไอคอน:** ใช้รูปทรง Flat เรียบง่าย ชัดเจน (เช่น โฟลเดอร์สีทึบเรียบๆ **ไม่มีเส้นกรอบสี่เหลี่ยมซ้อนด้านใน**) พร้อมสัญลักษณ์ใจความสำคัญตรงกลาง
     * **ตัวหนังสือ:** ขนาดใหญ่ คมชัด วางกึ่งกลางสมดุล (Centered Typography) อ่านง่ายชัดเจนบนหน้าจอเครื่องขนาดเล็ก
   * **Storage Locations:**
     * Root destination: `images/<Tool>-thumb.png` (or `<Tool>.png`) in `/roms/ports/images/` or `/roms/tools/images/`.
     * Package backup: `<tool_name>/images/<Tool>-thumb.png`.

4. **All-in-One TUI Manager Standard:**
   * User-facing tools use an interactive ncurses `dialog` TUI manager operating over `/dev/tty1` with `gptokeyb` gamepad bindings.
   * **When Uninstalled:** Displays only `[ 1 ] Install <Tool>` (exit via B or Cancel).
   * **When Installed:** Displays unified options (e.g., `Start Service`, `Stop Service`, `Toggle Auto-Start`, `Uninstall`, `Exit`) within a single launcher.
   * **Zero Clutter:** Subfolders must contain **zero extra `.sh` scripts** to ensure no helper scripts leak onto the frontend menus.

5. **Action Completion & Exit Lifecycle Standard:**
   * **Install & Uninstall:** Treated as one-shot actions that exit directly to the frontend (`exit 0`) after displaying the completion summary dialog (`Press A or Enter to exit.`).
   * **Single-Config Tools:** After saving the sole configuration setting, exit directly to the frontend (`exit 0`).
   * **Multi-Config Tools ($\ge 2$ settings):** After saving a setting, return to the setup menu (`Press A or Enter to continue.`) so the user can configure additional options before exiting manually via the menu's `Exit` option.
   * **Cancel / Back (Button B):** Always returns to the setup menu.

---

## 2. Overview Summary of Archetypes

| Archetype | Internal Subfolder | Lifecycle Model | Menu Entrypoint (Single Launcher) | Example Tools |
| :--- | :--- | :--- | :--- | :--- |
| **Archetype 1: On-Demand Service** | `<service_name>/` (Flat) | On-demand Start / Stop + Auto-Start toggle | `<Tool>.sh` (Single All-in-One TUI) | `WebFileManager`, `web_terminal` |
| **Archetype 2: Background Daemon** | `<daemon_name>/` (Flat) | Always-on systemd service (Boot autostart) | `<Tool>_Setup.sh` (Unified TUI Manager) | `power_button`, `screen_off` |
| **Archetype 3: One-Shot Interactive** | `<tool_name>/` (Flat) | Single-run runner, returns to UI | `<Tool>.sh` (Runner) + `<Tool>_Setup.sh` (Config) | `screenshot`, `speedtest`, `screen_off` |
| **Archetype 4: System Configuration** | *(None - flat)* | One-time setup/uninstall, no menu | CLI / SSH only (No frontend launcher) | `quick_tools`, `tools_menu`, `mercusys_wifi` |

---

## 3. Detailed Archetype Specifications

### Archetype 1: On-Demand Service Tools (Single All-in-One Launcher)
* **Use Case:** Web servers, network terminals, or background services that run only when requested by the user, providing clean start/stop toggling to reclaim RAM/CPU before gaming.
* **Menu Model:** A **single All-in-One TUI launcher** on the menu. Users no longer need separate `Start_*.sh` and `Stop_*.sh` shortcuts.
* **Workspace & Package Layout (Side-by-Side):**
  ```text
  <ToolName>/
  ├── <ToolName>.sh                 <-- Single All-in-One TUI Manager (Start, Stop, Auto-Start, Uninstall)
  ├── README.txt                    <-- User manual & documentation
  ├── images/                       <-- Root cover art directory
  │   └── <ToolName>-thumb.png      <-- 512x512 cover art for frontend menu
  └── <toolname>/                   <-- Strictly lowercase internal data folder (PortMaster Flat)
      ├── <binary_or_core>          <-- Standalone ARM64 binary (e.g. filebrowser, ttyd)
      ├── <tool>.service            <-- Systemd service template unit
      ├── status.conf               <-- Persistent state config
      └── images/
          └── <ToolName>-thumb.png  <-- Self-contained cover art backup
  ```
* **Deployment & Integration:** When copied to `/roms/ports/`, `<ToolName>.sh` and `images/<ToolName>-thumb.png` sit side-by-side with `webfilemanager/`. `playfe` automatically skips scanning `webfilemanager/` due to the shallow scan policy and lowercase stem-matching rule.

---

### Archetype 2: Background Daemon Tools (Always-On System Service)
* **Use Case:** Background system monitors, hardware button listeners, idle timers, or battery/power hooks that run continuously as systemd services in the background.
* **Workspace & Package Layout (Side-by-Side):**
  ```text
  <ToolName>/
  ├── <ToolName>_Setup.sh           <-- All-in-One TUI Manager (Setup, Timeout/Config, Uninstall)
  ├── README.txt                    <-- User manual & documentation
  ├── images/
  │   └── <ToolName>_Setup-thumb.png<-- 512x512 cover art for Setup card
  └── <toolname>/                   <-- Strictly lowercase internal data folder (PortMaster Flat)
      ├── <daemon_script_or_bin>    <-- Python listener or daemon binary
      ├── <tool>.service            <-- Systemd background service unit
      ├── status.conf               <-- Persistent state config
      └── images/
          └── <ToolName>_Setup-thumb.png
  ```
* **Deployment & Integration:** `<ToolName>_Setup.sh` auto-detects its directory (`/roms/ports/` or `/roms/tools/`), registers the background systemd service, and manages configuration live. In Ports, shallow scan natively ignores `<toolname>/`, keeping the menu clean with zero clutter.

---

### Archetype 3: One-Shot Interactive Tools (Menu Launcher / Runtime App)
* **Use Case:** Tools that perform an immediate, interactive task once and exit immediately back to the frontend, or dual-purpose tools that combine an instant runner with a setup manager.
* **Workspace & Package Layout (Side-by-Side):**
  ```text
  <ToolName>/
  ├── <ToolName>.sh                 <-- Instant execution runner (e.g. Screen_Off.sh, Speedtest.sh)
  ├── <ToolName>_Setup.sh           <-- All-in-One Settings & Uninstaller TUI
  ├── README.txt                    <-- User manual & documentation
  ├── images/
  │   ├── <ToolName>-thumb.png      <-- 512x512 cover art for instant runner card
  │   └── <ToolName>_Setup-thumb.png<-- 512x512 cover art for Setup card
  └── <toolname>/                   <-- Strictly lowercase internal data folder (PortMaster Flat)
      ├── status.conf               <-- Persistent state config
      ├── <modules_or_bin>          <-- Supporting binaries or libraries
      └── images/
          ├── <ToolName>-thumb.png
          └── <ToolName>_Setup-thumb.png
  ```
* **Deployment & Integration:** Displays two clear entries in `/roms/ports/`:
  1. `<ToolName>.sh` (Instant one-click runner)
  2. `<ToolName>_Setup.sh` (Settings & Uninstaller)

---

### Archetype 4: System Configuration Tools (Install / Uninstall Only)
* **Use Case:** Low-level kernel driver installers, mount hooks (e.g. bind mounts for exFAT), fstab persistence modifiers, or shell environment tweaks that directly apply persistent OS-level settings upon installation. These do **not** require a menu launcher in EmulationStation, do **not** require background daemons, and do **not** require an internal subfolder.
* **Root Directory:** Contains only the self-contained installation script, clean uninstallation script, and user manual.
* **Internal Subfolder:** None (flat root layout).
* **Layout Structure:**
  ```text
  <tool_name>/
  ├── Install_<Tool>.sh             <-- Direct setup script (applies OS settings/mounts immediately)
  ├── Uninstall_<Tool>.sh           <-- Clean teardown script (reverts OS settings/mounts)
  └── README.txt                    <-- User manual & documentation
  ```
* **Integration:** None (Hidden). These utilities are executed once from the terminal emulator or via remote SSH session. Their `Install_<Tool>.sh` script marks all `.sh` scripts in their own subfolder as `<hidden>true</hidden>` in `/roms/tools/gamelist.xml` if copied to tools.

---

## 4. Universal Stem-Matching Auto-Hiding Formula Table (Zero-`gamelist.xml`)

To prevent installer and teardown scripts from leaking into the `TOOLS` menu of `playfe`, all tools leverage the **Stem-Matching Auto-Skip Rule** (`clean_dir ⊆ clean_launcher`, length `> 4` chars). 

When this standard is met, `playfe` skips scanning the tool's internal subfolder natively:

| Tool Archetype | Subfolder Name (`/roms/ports/` or `tools/`) | Normalized Dir (`clean_dir`) | Top-Level Launcher | Normalized Launcher (`clean_launcher`) | Auto-Hide Condition | Result in `playfe` Menu |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Archetype 1** (Service) | `webfilemanager/` | `"webfilemanager"` (15 chars) | `WebFileManager.sh` | `"webfilemanager"` | `"webfilemanager"` $\subseteq$ `"webfilemanager"` | **Auto-Hidden** (Clean menu) |
| **Archetype 1** (Terminal) | `webterminal/` | `"webterminal"` (11 chars) | `WebTerminal.sh` | `"webterminal"` | `"webterminal"` $\subseteq$ `"webterminal"` | **Auto-Hidden** (Clean menu) |
| **Archetype 2** (Daemon) | `powerbutton/` | `"powerbutton"` (11 chars) | `Power_Button_Setup.sh` | `"powerbuttonsetup"` | `"powerbutton"` $\subseteq$ `"powerbuttonsetup"` | **Auto-Hidden** (Clean menu) |
| **Archetype 3** (One-Shot) | `speedtest/` | `"speedtest"` (9 chars) | `Speedtest.sh` | `"speedtest"` | `"speedtest"` $\subseteq$ `"speedtest"` | **Auto-Hidden** (Clean menu) |
| **Archetype 3** (One-Shot) | `screenoff/` | `"screenoff"` (9 chars) | `Screen_Off.sh`<br>`Screen_Off_Setup.sh` | `"screenoff"`<br>`"screenoffsetup"` | `"screenoff"` $\subseteq$ `"screenoff..."` | **Auto-Hidden** (Clean menu) |
| *(Anti-Pattern)* Mismatched Subfolder | `led_color/` | `"ledcolor"` (8 chars) | `Set_LED_to_Red.sh` | `"setledtored"` | `"ledcolor"` $\not\subseteq$ `"setledtored"` | ❌ **Leaks internal `.sh`!** |
| *(Anti-Pattern)* Short Subfolder | `led/` | `"led"` (3 chars $\le$ 4) | `Start_LED.sh` | `"startled"` | Length $\le 4$ fails auto-skip | ❌ **Leaks internal `.sh`!** |

> [!TIP]
> By strictly adhering to this table and using flat lowercase internal folders, **setup scripts do NOT need to write any Python or XML code to modify `gamelist.xml`**, keeping installation fast, robust, and 100% compliant with PortMaster and ArkOS conventions.
