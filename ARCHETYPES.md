# ARCHETYPES.md - Standard Tool Archetypes & Directory Layouts

This document defines the standardized directory structures, lifecycle contracts, and EmulationStation integration models for all tools developed in the **playOS Tools Suite** on the **R36H Handheld Gaming Console**.

All tools developed or maintained in this workspace **MUST** adhere strictly to one of the four archetypes below.

---

## Overview Summary

| Archetype | Subfolder | Lifecycle Model | Menu Integration (Dual-Target) | Example Tools |
| :--- | :--- | :--- | :--- | :--- |
| **Archetype 1: On-Demand Service** | `app/` | Manual Start / Stop (User-controlled) | `/roms/ports/` (Default) or `/roms/tools/` (`Start_*.sh` & `Stop_*.sh`) | `web_terminal`, `web_filemanager` |
| **Archetype 2: Background Daemon** | `daemon/` | Always-on systemd service (Boot autostart) | `/roms/ports/` (Default) or `/roms/tools/` (Unified `<Tool>_Setup.sh`) | `power_button`, `screen_off` |
| **Archetype 3: One-Shot Interactive** | `app/` | Single-run runner, returns to UI | `/roms/ports/` (Default) or `/roms/tools/` (`<Tool>.sh` & `<Tool>_Setup.sh`) | `screenshot`, `speedtest`, `screen_off` |
| **Archetype 4: System Configuration** | *(None - flat)* | One-time setup/uninstall, no menu | No (Run once via SSH / Terminal) | `quick_tools`, `tools_menu` |

---

## Detailed Archetype Specifications

### Universal Dual-Target Standard (`/roms/ports/` vs `/roms/tools/`) & Side-by-Side Layout
For all user-facing tools (Archetypes 1, 2, and 3):
* **Primary Target (`/roms/ports/`):** The `PORTS` menu is enabled by default on all handheld systems (`playOS`, `dArkOS`, and `ArkOS`). In contrast, the `TOOLS` tab (`/roms/tools/`) is disabled by default in stock `playOS 4.0`. Therefore, **`/roms/ports/` is the primary, zero-setup target for general users.**
* **Shallow Scan in Ports:** In `playOS 4.0` (`playfe`), the `ports` system performs a **Shallow Scan** (only files directly in `/roms/ports/*.sh` are scanned; subdirectories like `/roms/ports/<tool_name>/*.sh` are ignored).
* **Side-by-Side Packaging Requirement:**
  To ensure instant visibility in `ports`, the user-facing launcher (e.g., `<Tool>_Setup.sh`) **must sit side-by-side** with the internal subfolder (`<tool_name>/`) and the pre-packaged cover art directory (`images/`).
* **Pre-Packaged `images/` Directory:** Every package must include `images/` containing `512x512` cover arts (e.g. `<Tool>_Setup-thumb.png`, `<Tool>-thumb.png`), allowing frontends (`playfe` / `EmulationStation`) to display artwork immediately upon copying without waiting for installation.
* **Unified All-in-One TUI Manager:** Instead of fragmented `Install_*.sh` and `Uninstall_*.sh` scripts, modern tools use an interactive TUI wizard (`<Tool>_Setup.sh`) that dynamically detects install status, manages configuration options, and provides clean uninstallation from a single menu loop.
* **Dynamic State-Adaptive Setup Menu Standard:**
  * **When NOT Installed:** The main menu MUST present only **`Install`** and **`Exit`** (never clutter the uninstalled state with configuration items).
    * Under **`Install`**, provide two clear modes:
      1. **`Default Install`:** Installs immediately using recommended system defaults (one-click instant setup).
      2. **`Custom Setup Wizard`:** Guides the user through configuration options step-by-step before finalizing installation.
  * **When Installed:** The main menu presents individual settings (`Configure <Option>`), **`Uninstall`**, and **`Exit`**, allowing instant reconfiguration of any individual setting without re-running the full wizard.
  * **Menu Language:** All on-screen TUI text, titles, prompts, and options must be **100% English** to prevent font corruption or missing glyphs on `/dev/tty1`.
* **Action Completion & Exit Lifecycle Standard:**
  * **Install & Uninstall:** One-shot actions that exit directly to the frontend (`exit 0`) after displaying the completion summary dialog (`Press A or Enter to exit.`).
  * **Single-Config Tools:** After saving the sole configuration setting, exit directly to the frontend (`exit 0`).
  * **Multi-Config Tools ($\ge 2$ settings):** After saving a setting, return to the setup menu (`Press A or Enter to continue.`) so the user can configure additional options before exiting manually via the menu's `Exit` option.
  * **Cancel / Back:** Always returns to the setup menu.

---

### Archetype 1: On-Demand Service Tools (with Start / Stop)
* **Use Case:** Services, web servers, or network daemons that run only when explicitly requested by the user and provide a clean stop script to reclaim CPU and RAM before launching performance-sensitive emulators.
* **Workspace & Package Layout (Side-by-Side):**
  ```text
  <tool_name>/
  ├── <Tool>_Setup.sh               <-- All-in-One TUI Manager (Install, Config, Uninstall)
  ├── README.txt                    <-- User manual & documentation
  └── <tool_name>/                  <-- Internal data subfolder (copied alongside setup script)
      └── app/                      <-- Internal application subfolder
          ├── <binary_or_core>      <-- Standalone ARM64 binary or core assets
          ├── Start_<Tool>.sh       <-- Launcher script with on-screen IP display
          ├── Start_<Tool>-thumb.png<-- 512x512 cover art for Start menu item
          ├── Stop_<Tool>.sh        <-- Teardown script to reclaim RAM for games
          └── Stop_<Tool>-thumb.png <-- 512x512 cover art for Stop menu item
  ```
* **Deployment & Integration:** When deployed to `/roms/ports/` (or `/roms/tools/`), running `<Tool>_Setup.sh` installs `Start_<Tool>.sh` and `Stop_<Tool>.sh` alongside their cover arts into the active menu directory (`/roms/ports/images/`).

---

### Archetype 2: Background Daemon Tools (Always-On / System Service)
* **Use Case:** Background system monitors, hardware button listeners, idle timers, or battery/power hooks that run continuously as systemd services in the background.
* **Workspace & Package Layout (Side-by-Side):**
  ```text
  <tool_name>/
  ├── <Tool>_Setup.sh               <-- All-in-One TUI Manager (Setup, Timeout/Config, Uninstall)
  ├── README.txt                    <-- User manual & documentation
  └── <tool_name>/                  <-- Internal data subfolder (copied alongside setup script)
      ├── app/                      <-- Optional status config & cover arts
      │   ├── <Tool>_Setup-thumb.png<-- 512x512 cover art for Setup card
      │   └── status.conf           <-- Persistent state config
      └── daemon/                   <-- Internal daemon subfolder
          ├── <daemon_script>       <-- Python listener or daemon binary
          └── <tool>.service        <-- Systemd background service unit
  ```
* **System & Frontend Integration:** `<Tool>_Setup.sh` auto-detects its directory (`/roms/ports/` or `/roms/tools/`), registers the background systemd service, and manages configuration. In Ports, `playfe`'s shallow scan natively ignores the internal `<tool_name>/` subfolder, keeping the menu clean with zero clutter.

---

### Archetype 3: One-Shot Interactive Tools (Menu Launcher / Runtime App)
* **Use Case:** Tools that perform an immediate, interactive task once and exit immediately back to the frontend, or dual-purpose tools that combine an instant launcher with a setup manager.
* **Workspace & Package Layout (Side-by-Side):**
  ```text
  <tool_name>/
  ├── <Tool>_Setup.sh               <-- All-in-One TUI Manager (Install, Config, Uninstall)
  ├── README.txt                    <-- User manual & documentation
  └── <tool_name>/                  <-- Internal data subfolder (copied alongside setup script)
      └── app/                      <-- Internal application subfolder
          ├── <Tool>.sh             <-- Instant execution runner (e.g. Screen_Off.sh)
          ├── <Tool>-thumb.png      <-- 512x512 cover art for instant runner card
          ├── <Tool>_Setup-thumb.png<-- 512x512 cover art for Setup card
          ├── status.conf           <-- Persistent state config
          └── <modules_or_bin>      <-- Supporting scripts or libraries
  ```
* **Deployment & Integration:** When installed via `<Tool>_Setup.sh`, the instant launcher `<Tool>.sh` and its cover art are placed into the active menu directory (`/roms/ports/` or `/roms/tools/`). The menu displays two clear entries:
  1. `<Tool>.sh` (Immediate action)
  2. `<Tool>_Setup.sh` (Settings & Uninstaller)

---

### Archetype 4: System Configuration Tools (Install / Uninstall Only)
* **Use Case:** System configuration tools, mount hooks (e.g. bind mounts for exFAT), fstab persistence modifiers, or shell environment tweaks that directly apply persistent OS-level settings upon installation. These do **not** require a menu launcher in EmulationStation, do **not** require background daemons, and do **not** require an `app/` subfolder.
* **Root Directory:** Contains only the self-contained installation script, clean uninstallation script, and user manual.
* **Internal Subfolder:** None (flat root layout).
* **Layout Structure:**
  ```text
  <tool_name>/
  ├── Install_<Tool>.sh       <-- Direct setup script (applies OS settings/mounts immediately)
  ├── Uninstall_<Tool>.sh     <-- Clean teardown script (reverts OS settings/mounts)
  └── README.txt              <-- User manual & documentation
  ```
* **EmulationStation / `playfe` Integration:** None (Hidden). These utilities are executed once from the terminal emulator or via remote SSH session. Their `Install_<Tool>.sh` script marks all `.sh` scripts in their own subfolder as `<hidden>true</hidden>` in `/roms/tools/gamelist.xml` so the `/roms/tools/` menu stays uncluttered.

---

## 3. Universal Stem-Matching Auto-Hiding Formula Table (Zero-`gamelist.xml`)

To prevent installer (`Install_*.sh`) and teardown (`Uninstall_*.sh`) scripts from leaking into the `TOOLS` menu of `playfe`, all tools should leverage the **Stem-Matching Auto-Skip Rule** (`clean_dir ⊆ clean_launcher`, length `> 4` chars). 

When this standard is met, `playfe` skips scanning the tool's internal subfolder natively:

| Tool Archetype | Subfolder Name (`/roms/tools/`) | Normalized Dir (`clean_dir`) | Top-Level Launcher (`/roms/tools/`) | Normalized Launcher (`clean_launcher`) | Auto-Hide Condition | Result in `playfe` Menu |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Archetype 1** (On-Demand Service) | `web_terminal/` | `"webterminal"` (11 chars) | `Start_Web_Terminal.sh` | `"startwebterminal"` | `"webterminal"` $\subseteq$ `"startwebterminal"` | **Auto-Hidden** (Clean menu) |
| **Archetype 2** (Background Daemon) | `power_button/` | `"powerbutton"` (11 chars) | `Power_Button_Setup.sh` | `"powerbuttonsetup"` | `"powerbutton"` $\subseteq$ `"powerbuttonsetup"` | **Auto-Hidden** (Clean menu) |
| **Archetype 3** (One-Shot Single) | `speedtest/` | `"speedtest"` (9 chars) | `Speedtest.sh` | `"speedtest"` | `"speedtest"` $\subseteq$ `"speedtest"` | **Auto-Hidden** (Clean menu) |
| **Archetype 3** (One-Shot Multi-Action) | `set_led/` | `"setled"` (6 chars) | `Set_LED_to_Red.sh`<br>`Set_LED_to_Blue.sh` | `"setledtored"`<br>`"setledtoblue"` | `"setled"` $\subseteq$ `"setledto..."` | **Auto-Hidden** (Clean menu) |
| *(Anti-Pattern)* Mismatched Subfolder | `led_color/` | `"ledcolor"` (8 chars) | `Set_LED_to_Red.sh` | `"setledtored"` | `"ledcolor"` $\not\subseteq$ `"setledtored"` | ❌ **Leaks `Install_*.sh`!** |
| *(Anti-Pattern)* Short Subfolder | `led/` | `"led"` (3 chars $\le$ 4) | `Start_LED.sh` | `"startled"` | Length $\le 4$ fails auto-skip | ❌ **Leaks `Install_*.sh`!** |

> [!TIP]
> By strictly adhering to this table, **setup scripts do NOT need to write any Python or XML code to modify `gamelist.xml`**, keeping installation fast, robust, and completely self-contained.

