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
COUNTDOWN_SECONDS = 3
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
    # Ensure backlight is on so notification is visible
    for b_path in glob.glob("/sys/class/backlight/*"):
        b_file = os.path.join(b_path, "brightness")
        if os.path.exists(b_file):
            try:
                with open(b_file, "r") as f:
                    cur = int(f.read().strip())
                if cur <= 10:
                    with open(b_file, "w") as f:
                        f.write("100\n")
            except Exception:
                pass

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

def flush_events(fd, event_size=24):
    """Flushes queued events (e.g. key release or resume events)."""
    while True:
        r, _, _ = select.select([fd], [], [], 0.05)
        if not r:
            break
        try:
            os.read(fd, event_size)
        except Exception:
            break

def countdown_and_shutdown(power_fd, power_dev_path):
    """
    Displays a 3-second countdown on /dev/tty1.
    If ANY button is pressed on any input device during this period,
    cancellation is triggered and the system returns to normal.
    """
    log("1-second hold reached. Starting 3-second cancellation countdown...")

    # 1. Collect all other input event devices (gamepad, keys, etc.)
    other_fds = []
    for path in sorted(glob.glob("/dev/input/event*")):
        try:
            if os.path.samefile(path, power_dev_path):
                continue
        except Exception:
            pass
        try:
            ofd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            other_fds.append(ofd)
        except Exception:
            pass

    # 2. Flush any pending inputs so stale button presses don't cancel immediately
    for ofd in other_fds + [power_fd]:
        try:
            while True:
                d = os.read(ofd, 24)
                if len(d) < 24:
                    break
        except Exception:
            pass

    cancelled = False

    try:
        for remaining in range(COUNTDOWN_SECONDS, 0, -1):
            notify_screen(
                "============================================================\n"
                f"             กำลังจะปิดเครื่องใน {remaining} วินาที...\n"
                "        >>> กดปุ่มใดก็ได้บนเครื่องเพื่อยกเลิก <<<\n"
                "============================================================"
            )

            step_deadline = time.monotonic() + 1.0
            while time.monotonic() < step_deadline:
                wait_sec = max(0.01, step_deadline - time.monotonic())
                # Check other devices AND power_fd
                r, _, _ = select.select(other_fds + [power_fd], [], [], min(0.05, wait_sec))
                if r:
                    for ready_fd in r:
                        try:
                            data = os.read(ready_fd, 24)
                            if len(data) >= 24:
                                sec, usec, etype, code, val = struct.unpack("qqHHi", data)
                                # EV_KEY press (val == 1) cancels! (val == 0 is release, val == 2 is repeat)
                                if etype == EV_KEY and val == 1:
                                    log(f"Cancellation button detected (code {code})")
                                    cancelled = True
                                    break
                        except Exception:
                            pass
                if cancelled:
                    break
            if cancelled:
                break

        if cancelled:
            log("Shutdown CANCELLED by user button press.")
            notify_screen(
                "============================================================\n"
                "             [✓] ยกเลิกการปิดเครื่องแล้ว                   \n"
                "                    กำลังกลับสู่หน้าจอเดิม...                 \n"
                "============================================================"
            )
            time.sleep(1.0)
            clear_screen()
            # Flush events before returning to normal loop
            for ofd in other_fds + [power_fd]:
                flush_events(ofd, 24)
            return

        # Countdown expired without cancellation -> Proceed with safe shutdown!
        trigger_safe_shutdown()
        while True:
            time.sleep(10)

    finally:
        for ofd in other_fds:
            try:
                os.close(ofd)
            except Exception:
                pass

def run_loop():
    dev_path = find_power_device()
    if not dev_path:
        log("ERROR: Power key input device not found! Retrying in 5s...")
        time.sleep(5)
        return

    log(f"Listening for power button events on {dev_path} (Hold {HOLD_SECONDS}s for 3s countdown)")

    try:
        fd = os.open(dev_path, os.O_RDONLY)
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
                            flush_events(fd, EVENT_SIZE)
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
