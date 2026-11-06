# ARCHETYPES.md - Standard Tool Archetypes & Directory Layouts

This document defines the standardized directory structures, lifecycle contracts, and EmulationStation integration models for all tools developed in the **playOS Tools Suite** on the **R36H Handheld Gaming Console**.

All tools developed or maintained in this workspace **MUST** adhere strictly to one of the four archetypes below.

---

## Overview Summary

| Archetype | Subfolder | Lifecycle Model | ES Menu Integration (`/roms/tools/`) | Example Tools |
| :--- | :--- | :--- | :--- | :--- |
| **Archetype 1: On-Demand Service** | `app/` | Manual Start / Stop (User-controlled) | Yes (`Start_*.sh` & `Stop_*.sh`) | `web_terminal`, `web_filemanager` |
| **Archetype 2: Background Daemon** | `daemon/` | Always-on systemd service (Boot autostart) | No (Controlled via setup/service) | `power_button` |
| **Archetype 3: One-Shot Interactive** | `app/` | Single-run runner, returns to ES UI | Yes (`<tool_runner>.sh`) | `screenshot`, `speedtest`, `screen_off` |
| **Archetype 4: System Configuration** | *(None - flat)* | One-time setup/uninstall, no menu | No (Run once via SSH / Terminal) | `quick_tools`, `tools_menu` |

---

## Detailed Archetype Specifications

### Archetype 1: On-Demand Service Tools (with Start / Stop)
* **Use Case:** Services, web servers, or network daemons that run only when explicitly requested by the user and provide a clean stop script to reclaim CPU and RAM before launching performance-sensitive emulators.
* **Root Directory:** Contains only the setup script, clean uninstaller, and user manual.
* **Internal Subfolder (`app/`):** Houses binaries, core runtime files, the `Start_*.sh` / `Stop_*.sh` scripts, and `512x512` cover art (`Start_<Tool>-thumb.png`, `Stop_<Tool>-thumb.png`).
* **Layout Structure:**
  ```text
  <tool_name>/
  ├── Install_<Tool>.sh             <-- User setup script (copies Start/Stop & cover art to /roms/tools/)
  ├── Uninstall_<Tool>.sh           <-- Clean uninstaller (removes services, binary, shortcuts & cover art)
  ├── README.txt                    <-- User manual & documentation
  └── app/                          <-- Internal application subfolder
      ├── <binary_or_core>          <-- Standalone ARM64 binary or core assets
      ├── Start_<Tool>.sh           <-- Launcher script with on-screen IP display
      ├── Start_<Tool>-thumb.png    <-- 512x512 cover art for Start menu item
      ├── Stop_<Tool>.sh            <-- Teardown script to reclaim RAM for games
      └── Stop_<Tool>-thumb.png     <-- 512x512 cover art for Stop menu item
  ```
* **playOS Menu (`playfe`) & EmulationStation Integration:** Running `Install_<Tool>.sh` copies `Start_<Tool>.sh` and `Stop_<Tool>.sh` to `/roms/tools/` and copies their `*-thumb.png` cover art to `/roms/tools/images/`, which `playfe` automatically discovers and displays (see [`PLAYFE_MENU_GUIDE.md`](file:///d:/me/r36h/tools/PLAYFE_MENU_GUIDE.md)).

---

### Archetype 2: Background Daemon Tools (Always-On / System Service)
* **Use Case:** Background system monitors, hardware button listeners, or battery/power hooks that run continuously as systemd services in the background without requiring manual start/stop toggling.
* **Root Directory:** Contains only setup script, status inspector, clean uninstaller, and user manual.
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
* **System & `playfe` Integration:** Running `Install_<Tool>.sh` registers the service into `/etc/systemd/system/`, enables it for boot-time autostart, starts it immediately, and updates `/roms/tools/gamelist.xml` to mark all `.sh` files inside its own folder as `<hidden>true</hidden>` so they do not clutter the `TOOLS` menu on playOS.

---

### Archetype 3: One-Shot Interactive Tools (Menu Launcher / Runtime App)
* **Use Case:** Tools that perform an immediate, interactive task once and exit immediately back to EmulationStation / `playfe`, without leaving background processes running in memory.
* **Root Directory:** Contains only setup/installer script, clean uninstaller, and user manual.
* **Internal Subfolder (`app/`):** Houses runtime scripts, `512x512` cover art (`<Tool>-thumb.png`), helper modules, or binaries.
* **Layout Structure:**
  ```text
  <tool_name>/
  ├── Install_<Tool>.sh       <-- Setup script (places menu launcher & cover art into /roms/tools/)
  ├── Uninstall_<Tool>.sh     <-- Clean uninstaller (removes installed launcher, cover art & shortcuts)
  ├── README.txt              <-- User manual & documentation
  └── app/                    <-- Internal application subfolder
      ├── <Tool>.sh           <-- Dual-output execution runner
      ├── <Tool>-thumb.png    <-- 512x512 cover art for playOS menu card
      └── <modules_or_bin>    <-- Supporting scripts or libraries
  ```
* **playOS Menu (`playfe`) & EmulationStation Integration:** Running `Install_<Tool>.sh` copies `<Tool>.sh` to `/roms/tools/` and copies `<Tool>-thumb.png` to `/roms/tools/images/`, which `playfe` automatically discovers and displays (see [`PLAYFE_MENU_GUIDE.md`](file:///d:/me/r36h/tools/PLAYFE_MENU_GUIDE.md)).

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
