#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Power Button Hold-to-Shutdown Daemon for R36H (playOS)
Monitors the RK8xx PMIC power key. When held for 1 second:
- Starts a 3-second countdown on /dev/tty1 (3.. 2.. 1..)
- User can press ANY button on the gamepad/device to cancel
- If not cancelled, triggers graceful shutdown (saves games, syncs SD, powers off)
- Short press (< 1s) triggers system sleep (suspend) as normal
"""

import os
import sys
import glob
import time
import struct
import select
import subprocess
import signal
import fcntl

HOLD_SECONDS = 1.0
COUNTDOWN_SECONDS = 10
KEY_POWER = 116  # Linux KEY_POWER code
EV_KEY = 1
EVIOCGRAB = 0x40044590  # Linux ioctl to grab input device exclusively

def log(msg):
    print(f"[power_daemon] {msg}", flush=True)

def clear_screen():
    """Clears /dev/tty1 screen using VT100 terminal reset sequences."""
    if os.path.exists("/dev/tty1"):
        try:
            with open("/dev/tty1", "w") as f:
                f.write("\033c\033[2J\033[H")
                f.flush()
        except Exception:
            pass

def notify_screen(message):
    """Prints message directly to /dev/tty1 framebuffer console and stdout."""
    formatted = f"\n\n\033[1;33m{message}\033[0m\n"
    print(formatted, flush=True)
    if os.path.exists("/dev/tty1"):
        try:
            with open("/dev/tty1", "w") as f:
                f.write(formatted)
                f.flush()
        except Exception:
            pass

def find_power_device():
    """Locate event node for rk8xx_pwrkey dynamically from /proc/bus/input/devices."""
    if os.path.exists("/proc/bus/input/devices"):
        try:
            with open("/proc/bus/input/devices", "r") as f:
                content = f.read()
            blocks = content.split("\n\n")
            for block in blocks:
                if 'Name="rk8xx_pwrkey"' in block:
                    for line in block.splitlines():
                        if line.startswith("H: Handlers="):
                            parts = line.split()
                            for p in parts:
                                if p.startswith("event"):
                                    dev = f"/dev/input/{p}"
                                    if os.path.exists(dev):
                                        return dev
        except Exception as e:
            log(f"Error parsing /proc/bus/input/devices: {e}")

    # Fallback paths
    by_path = "/dev/input/by-path/platform-ff180000.i2c-event"
    if os.path.exists(by_path):
        return by_path

    if os.path.exists("/dev/input/event0"):
        return "/dev/input/event0"

    return None

def trigger_safe_shutdown():
    """Performs graceful game/emulator shutdown, syncs SD card, and calls poweroff."""
    notify_screen(
        "============================================================\n"
        "           กำลังปิดเครื่อง (SHUTTING DOWN...)\n"
        "       กำลังบันทึกข้อมูลและปิดเกมอย่างปลอดภัย กรุณารอสักครู่...\n"
        "============================================================"
    )
    log("Countdown expired. Starting graceful shutdown sequence...")

    # 1. Gracefully terminate emulators so RetroArch flushes SRAM & save files
    emulators = [
        "playfe",
        "retroarch",
        "PPSSPPDL",
        "ppsspp",
        "mupen64plus",
        "drastic",
        "flycast",
        "mednafen",
        "scummvm",
        "openbor",
        "dosbox"
    ]
    emu_pattern = "|".join(emulators)

    # First, make sure processes are resumed (SIGCONT) so they can process SIGTERM
    try:
        subprocess.run(["pkill", "-CONT", "-f", emu_pattern], timeout=2, capture_output=True)
    except Exception:
        pass

    try:
        subprocess.run(["pkill", "-SIGTERM", "-f", emu_pattern], timeout=3, capture_output=True)
    except Exception as e:
        log(f"Warning during emulator SIGTERM: {e}")

    # Give emulators 1.5 seconds to finalize save states and write to SD card
    time.sleep(1.5)

    # 2. Terminate frontend
    try:
        subprocess.run(["pkill", "-SIGTERM", "-f", "emulationstation"], timeout=2, capture_output=True)
    except Exception:
        pass

    # 3. Flush filesystem buffers (twice for safety on SD cards)
    log("Syncing filesystems...")
    try:
        subprocess.run(["sync"], timeout=5)
        subprocess.run(["sync"], timeout=5)
    except Exception as e:
        log(f"Warning during sync: {e}")

    # 4. Initiate system shutdown
    log("Calling systemctl poweroff...")
    try:
        subprocess.run(["systemctl", "poweroff"], timeout=5)
    except Exception:
        # Fallback to direct poweroff
        subprocess.run(["poweroff", "-f"])

def drain_inputs(fds):
    """Drains all buffered data from input descriptors without blocking."""
    for fd in fds:
        while True:
            r, _, _ = select.select([fd], [], [], 0)
            if not r:
                break
            try:
                data = os.read(fd, 24)
                if not data:
                    break
            except Exception:
                break

def countdown_and_shutdown(power_fd, power_dev_path):
    """
    Launches the graphical SDL2 KMSDRM countdown UI overlay.
    If ANY button is pressed on gamepad/keys during this period,
    countdown_ui exits with code 1 (cancellation).
    If timer expires without cancellation, it exits with code 0 (shutdown).
    """
    log("1-second hold reached. Launching graphical countdown UI...")

    # Freeze frontend & emulators so they stop swapping KMSDRM buffers (eliminates screen flicker)
    pause_pattern = "playfe|retroarch|retroarch32|PPSSPPDL|ppsspp|mupen64plus|drastic|flycast"
    try:
        subprocess.run(["pkill", "-STOP", "-f", pause_pattern], timeout=2, capture_output=True)
        log("Paused frontend / emulators (SIGSTOP to eliminate KMSDRM buffer flicker)")
    except Exception as e:
        log(f"Warning pausing processes: {e}")

    ui_bin = "/usr/local/bin/countdown_ui"
    if not os.path.exists(ui_bin):
        ui_bin = "/roms/tools/power_button/daemon/countdown_ui"

    cancelled = False
    if os.path.exists(ui_bin):
        try:
            res = subprocess.run([ui_bin, str(COUNTDOWN_SECONDS)], timeout=COUNTDOWN_SECONDS + 2)
            if res.returncode == 0:
                log("UI countdown completed. Proceeding with safe shutdown...")
            else:
                log("UI countdown CANCELLED by user button press.")
                cancelled = True
        except Exception as e:
            log(f"UI execution error: {e}")

    if cancelled:
        # User pressed a button to cancel -> Wake frontend & emulators back up immediately
        try:
            subprocess.run(["pkill", "-CONT", "-f", pause_pattern], timeout=2, capture_output=True)
            log("Resumed frontend / emulators (SIGCONT)")
        except Exception as e:
            log(f"Warning resuming processes: {e}")
        drain_inputs([power_fd])
        return

    # Trigger graceful system shutdown
    trigger_safe_shutdown()
    while True:
        time.sleep(10)

def run_loop():
    dev_path = find_power_device()
    if not dev_path:
        log("ERROR: Power key input device not found! Retrying in 5s...")
        time.sleep(5)
        return

    log(f"Listening for power button events on {dev_path} (Hold {HOLD_SECONDS}s for {COUNTDOWN_SECONDS}s countdown)")

    try:
        # Open in non-blocking mode to guarantee read will never hang the process
        fd = os.open(dev_path, os.O_RDONLY | os.O_NONBLOCK)
    except Exception as e:
        log(f"Cannot open {dev_path}: {e}. Retrying in 5s...")
        time.sleep(5)
        return

    # Grab device exclusively so ogage/systemd don't prematurely suspend on initial press
    try:
        fcntl.ioctl(fd, EVIOCGRAB, 1)
        log(f"Grabbed {dev_path} exclusively (EVIOCGRAB)")
    except Exception as e:
        log(f"Warning: Failed to grab device exclusively: {e}")

    EVENT_SIZE = 24  # 64-bit kernel: timeval (16 bytes) + uint16 + uint16 + int32
    is_pressed = False
    press_start = 0.0

    try:
        while True:
            # Determine select timeout based on whether the button is currently held
            if is_pressed:
                elapsed = time.monotonic() - press_start
                remaining = HOLD_SECONDS - elapsed
                if remaining <= 0:
                    is_pressed = False
                    countdown_and_shutdown(fd, dev_path)
                    continue
                timeout = max(0.01, remaining)
            else:
                timeout = None  # Block until input is received

            r, _, _ = select.select([fd], [], [], timeout)

            if not r:
                # Timeout occurred while button is pressed -> 1.0s reached!
                if is_pressed:
                    is_pressed = False
                    countdown_and_shutdown(fd, dev_path)
                continue

            try:
                data = os.read(fd, EVENT_SIZE)
            except (BlockingIOError, InterruptedError):
                continue
            except Exception as e:
                log(f"Read error: {e}")
                break

            if len(data) < EVENT_SIZE:
                continue

            sec, usec, etype, code, val = struct.unpack("qqHHi", data)

            if etype == EV_KEY and code == KEY_POWER:
                if val == 1:
                    # Power button pressed down
                    is_pressed = True
                    press_start = time.monotonic()
                    log("Power button pressed down. Monitoring hold duration (1.0s)...")
                elif val == 0:
                    # Power button released
                    if is_pressed:
                        duration = time.monotonic() - press_start
                        is_pressed = False
                        if duration < HOLD_SECONDS:
                            log(f"Short press ({duration:.2f}s) -> Suspending system (Sleep)...")
                            try:
                                subprocess.run(["systemctl", "suspend"], timeout=5)
                            except Exception as e:
                                log(f"Suspend error: {e}")
                            log("System resumed from sleep.")
                            time.sleep(0.5)
                            drain_inputs([fd])
                elif val == 2:
                    # Key autorepeat while held
                    pass

    finally:
        try:
            fcntl.ioctl(fd, EVIOCGRAB, 0)
        except Exception:
            pass
        try:
            os.close(fd)
        except Exception:
            pass

def main():
    # Handle termination signals cleanly
    def sig_handler(signum, frame):
        log(f"Received signal {signum}, exiting daemon.")
        sys.exit(0)

    signal.signal(signal.SIGINT, sig_handler)
    signal.signal(signal.SIGTERM, sig_handler)

    while True:
        try:
            run_loop()
        except Exception as e:
            log(f"Daemon loop exception: {e}")
            time.sleep(2)

if __name__ == "__main__":
    main()
