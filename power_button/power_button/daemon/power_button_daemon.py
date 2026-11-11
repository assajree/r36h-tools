#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Power Button Hold-to-Shutdown Daemon for R36H (playOS / dArkOS / ArkOS)
Monitors the RK8xx PMIC power key:
- Long press (Hold duration): Launches graphical countdown overlay on /dev/tty1.
  If face buttons A, B, X, Y are pressed, cancels shutdown and resumes game.
  If countdown finishes, gracefully saves games and shuts down system.
- Short press: Executes configured action (Sleep / Screen Off / None).
- Dynamic config: Reads /etc/power_button.conf or status.conf.
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

DEFAULT_HOLD = 1.0
DEFAULT_COUNTDOWN = 3
DEFAULT_SHORT_PRESS = "sleep"

KEY_POWER = 116  # Linux KEY_POWER code
EV_KEY = 1
EVIOCGRAB = 0x40044590  # Linux ioctl to grab input device exclusively

def log(msg):
    print(f"[power_daemon] {msg}", flush=True)

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

def load_config():
    """Load dynamic settings from /etc/power_button.conf or status.conf."""
    conf = {
        "HOLD_SECONDS": DEFAULT_HOLD,
        "COUNTDOWN_SECONDS": DEFAULT_COUNTDOWN,
        "SHORT_PRESS_ACTION": DEFAULT_SHORT_PRESS
    }
    candidate_paths = [
        "/etc/power_button.conf",
        "/roms/ports/power_button/app/status.conf",
        "/roms/tools/power_button/app/status.conf"
    ]
    for p in candidate_paths:
        if os.path.exists(p):
            try:
                with open(p, "r") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#"):
                            continue
                        if "=" in line:
                            k, v = line.split("=", 1)
                            k = k.strip()
                            v = v.strip().strip('"').strip("'")
                            if k == "HOLD_SECONDS":
                                conf["HOLD_SECONDS"] = float(v)
                            elif k == "COUNTDOWN_SECONDS":
                                conf["COUNTDOWN_SECONDS"] = int(v)
                            elif k == "SHORT_PRESS_ACTION":
                                conf["SHORT_PRESS_ACTION"] = v.lower()
                break
            except Exception as e:
                log(f"Warning reading config from {p}: {e}")
    return conf

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
        "           SHUTTING DOWN SYSTEM...\n"
        "       Saving game data and syncing SD card cleanly...\n"
        "============================================================"
    )
    log("Countdown expired. Starting graceful shutdown sequence...")

    # 1. Gracefully terminate emulators so RetroArch flushes SRAM & save files
    emulators = [
        "playfe",
        "retroarch",
        "retroarch32",
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

def countdown_and_shutdown(power_fd, countdown_seconds):
    """
    Launches graphical SDL2 KMSDRM countdown UI overlay.
    If face buttons A, B, X, Y are pressed, exits with code 1 (cancelled).
    If timer expires, exits with code 0 (shutdown).
    """
    log(f"Hold reached. Launching graphical countdown UI ({countdown_seconds}s)...")

    # Freeze frontend & emulators to stop KMSDRM buffer swapping (eliminates flicker)
    pause_pattern = "playfe|retroarch|retroarch32|PPSSPPDL|ppsspp|mupen64plus|drastic|flycast"
    try:
        subprocess.run(["pkill", "-STOP", "-f", pause_pattern], timeout=2, capture_output=True)
        log("Paused frontend / emulators (SIGSTOP)")
    except Exception as e:
        log(f"Warning pausing processes: {e}")

    ui_bin = "/usr/local/bin/countdown_ui"
    if not os.path.exists(ui_bin):
        candidate_ui = [
            "/roms/ports/power_button/daemon/countdown_ui",
            "/roms/tools/power_button/daemon/countdown_ui"
        ]
        for c in candidate_ui:
            if os.path.exists(c):
                ui_bin = c
                break

    cancelled = False
    if os.path.exists(ui_bin):
        try:
            res = subprocess.run([ui_bin, str(countdown_seconds)], timeout=countdown_seconds + 3)
            if res.returncode == 0:
                log("UI countdown completed. Proceeding with safe shutdown...")
            else:
                log("UI countdown CANCELLED by A/B/X/Y button press.")
                cancelled = True
        except Exception as e:
            log(f"UI execution error: {e}")

    if cancelled:
        # User pressed A/B/X/Y -> Wake frontend & emulators back up immediately
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

def handle_screen_off(power_fd):
    """Turns off LCD backlight until any key/button is pressed."""
    backlight_path = None
    for p in glob.glob("/sys/class/backlight/*"):
        bf = os.path.join(p, "brightness")
        if os.access(bf, os.W_OK):
            backlight_path = bf
            break

    if not backlight_path:
        log("Backlight brightness file not found; skipping screen off.")
        return

    saved_brightness = "100"
    try:
        with open(backlight_path, "r") as f:
            v = f.read().strip()
            if int(v) > 0:
                saved_brightness = v
        # Turn off backlight
        with open(backlight_path, "w") as f:
            f.write("0\n")
            f.flush()
        log(f"LCD backlight turned OFF (saved={saved_brightness}). Waiting for wakeup...")
    except Exception as e:
        log(f"Error turning off backlight: {e}")
        return

    # Open all input event devices to detect wakeup button
    fds = [power_fd]
    opened_fds = []
    try:
        for ev_path in glob.glob("/dev/input/event*"):
            try:
                ofd = os.open(ev_path, os.O_RDONLY | os.O_NONBLOCK)
                opened_fds.append(ofd)
                fds.append(ofd)
            except Exception:
                pass

        # Wait a small instant to avoid catching the release of the power button
        time.sleep(0.3)
        drain_inputs(fds)

        # Block until ANY button event is received
        while True:
            r, _, _ = select.select(fds, [], [], 1.0)
            if r:
                break
    finally:
        # Restore backlight
        try:
            with open(backlight_path, "w") as f:
                f.write(f"{saved_brightness}\n")
                f.flush()
            log("LCD backlight restored.")
        except Exception as e:
            log(f"Error restoring backlight: {e}")

        for ofd in opened_fds:
            try:
                os.close(ofd)
            except Exception:
                pass
        time.sleep(0.2)
        drain_inputs([power_fd])

def run_loop():
    dev_path = find_power_device()
    if not dev_path:
        log("ERROR: Power key input device not found! Retrying in 5s...")
        time.sleep(5)
        return

    cfg = load_config()
    hold_sec = cfg.get("HOLD_SECONDS", DEFAULT_HOLD)
    count_sec = cfg.get("COUNTDOWN_SECONDS", DEFAULT_COUNTDOWN)
    short_action = cfg.get("SHORT_PRESS_ACTION", DEFAULT_SHORT_PRESS)

    log(f"Listening on {dev_path} (Hold={hold_sec}s, Countdown={count_sec}s, ShortPress={short_action})")

    try:
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
            # Re-read config periodically if not currently pressed
            if not is_pressed:
                cfg = load_config()
                hold_sec = cfg.get("HOLD_SECONDS", DEFAULT_HOLD)
                count_sec = cfg.get("COUNTDOWN_SECONDS", DEFAULT_COUNTDOWN)
                short_action = cfg.get("SHORT_PRESS_ACTION", DEFAULT_SHORT_PRESS)

            if is_pressed:
                elapsed = time.monotonic() - press_start
                remaining = hold_sec - elapsed
                if remaining <= 0:
                    is_pressed = False
                    countdown_and_shutdown(fd, count_sec)
                    continue
                timeout = max(0.01, remaining)
            else:
                timeout = None  # Block until input

            r, _, _ = select.select([fd], [], [], timeout)

            if not r:
                # Timeout occurred while button is pressed -> hold_sec reached!
                if is_pressed:
                    is_pressed = False
                    countdown_and_shutdown(fd, count_sec)
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
                    log(f"Power button pressed down. Monitoring hold duration ({hold_sec}s)...")
                elif val == 0:
                    # Power button released
                    if is_pressed:
                        duration = time.monotonic() - press_start
                        is_pressed = False
                        if duration < hold_sec:
                            log(f"Short press ({duration:.2f}s) triggered.")
                            if short_action == "sleep":
                                log("Action: Suspending system (Sleep)...")
                                try:
                                    subprocess.run(["systemctl", "suspend"], timeout=5)
                                except Exception as e:
                                    log(f"Suspend error: {e}")
                                log("System resumed from sleep.")
                                time.sleep(0.5)
                                drain_inputs([fd])
                            elif short_action == "screen_off":
                                log("Action: Screen Off...")
                                handle_screen_off(fd)
                            elif short_action == "none":
                                log("Action: Short press ignored.")
                elif val == 2:
                    # Key autorepeat
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
