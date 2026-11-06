#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Screenshot Hotkey Daemon for R36H (playOS)
Monitors input devices (/dev/input/event*) for the SELECT + Y combination.
When triggered:
- Captures /dev/fb0 to /roms/screenshots/screenshot_YYYYMMDD_HHMMSS.png
- Triggers Camera Shutter flash effect (brief LCD backlight dip ~80ms)
- Applies debounce cooldown (1.2s) to prevent duplicate captures
- Ensures non-blocking execution so game performance is completely unaffected
"""

import os
import sys
import glob
import time
import struct
import select
import signal
import subprocess

SAVE_DIR = "/roms/screenshots"
COOLDOWN_SECONDS = 1.2
EV_KEY = 1

# Common Linux input event codes for SELECT and Y buttons
# Gamepads on RK3326 typically report:
# BTN_SELECT = 314 (0x13a), KEY_SELECT = 353
# BTN_WEST (Y on SNES layout) = 308 (0x134), BTN_NORTH = 307 (0x133), KEY_Y = 21
SELECT_CODES = {314, 353}
Y_CODES = {308, 307, 21}

def log(msg):
    print(f"[screenshot_daemon] {msg}", flush=True)

class BacklightFlash:
    def __init__(self):
        self.backlight_path = self._find_backlight()

    def _find_backlight(self):
        for path in glob.glob("/sys/class/backlight/*"):
            b_file = os.path.join(path, "brightness")
            if os.path.isdir(path) and os.access(b_file, os.W_OK):
                return b_file
        return None

    def flash(self):
        if not self.backlight_path:
            return
        try:
            with open(self.backlight_path, "r") as f:
                saved = f.read().strip()
            with open(self.backlight_path, "w") as f:
                f.write("0\n")
                f.flush()
            time.sleep(0.08)
            with open(self.backlight_path, "w") as f:
                f.write(f"{saved}\n")
                f.flush()
        except Exception as e:
            log(f"Flash error: {e}")

def capture_screen(flash_ctrl):
    os.makedirs(SAVE_DIR, exist_ok=True)
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    output_path = os.path.join(SAVE_DIR, f"screenshot_{timestamp}.png")

    cmd = [
        "ffmpeg", "-y",
        "-f", "fbdev",
        "-i", "/dev/fb0",
        "-frames:v", "1",
        "-update", "1",
        output_path
    ]

    try:
        res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
        if res.returncode == 0 and os.path.exists(output_path) and os.path.getsize(output_path) > 0:
            # Trigger camera shutter flash effect
            flash_ctrl.flash()

            # Fix permissions for ark user
            subprocess.run(["chown", "ark:ark", output_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            log(f"Captured screenshot: {output_path}")
        else:
            log(f"Failed to capture screenshot (ffmpeg exit code {res.returncode})")
    except Exception as e:
        log(f"Capture exception: {e}")

def open_input_devices():
    fds = {}
    for dev_path in sorted(glob.glob("/dev/input/event*")):
        try:
            fd = os.open(dev_path, os.O_RDONLY | os.O_NONBLOCK)
            fds[fd] = dev_path
        except Exception:
            pass
    return fds

def close_input_devices(fds):
    for fd in list(fds.keys()):
        try:
            os.close(fd)
        except Exception:
            pass
    fds.clear()

def main():
    log("Starting Screenshot Hotkey Daemon (SELECT + Y)...")
    flash_ctrl = BacklightFlash()
    if flash_ctrl.backlight_path:
        log(f"Backlight controller detected: {flash_ctrl.backlight_path}")
    else:
        log("Notice: Backlight device not writable; flash effect will be disabled.")

    fds = open_input_devices()
    log(f"Monitoring {len(fds)} input devices.")

    # State tracking
    select_pressed = set()  # set of fds currently pressing SELECT
    y_pressed = set()       # set of fds currently pressing Y
    last_capture_time = 0.0
    last_device_scan = time.time()

    running = True

    def sig_handler(sig, frame):
        nonlocal running
        log("Shutdown signal received. Exiting...")
        running = False

    signal.signal(signal.SIGTERM, sig_handler)
    signal.signal(signal.SIGINT, sig_handler)

    while running:
        # Periodic rescan of input devices every 5 seconds
        now = time.time()
        if now - last_device_scan > 5.0:
            last_device_scan = now
            current_paths = set(glob.glob("/dev/input/event*"))
            monitored_paths = set(fds.values())
            if current_paths != monitored_paths:
                log("Input device topology changed. Re-opening input devices...")
                close_input_devices(fds)
                fds = open_input_devices()
                select_pressed.clear()
                y_pressed.clear()

        if not fds:
            time.sleep(2)
            fds = open_input_devices()
            continue

        try:
            rlist, _, _ = select.select(list(fds.keys()), [], [], 2.0)
        except (select.error, ValueError):
            close_input_devices(fds)
            fds = open_input_devices()
            select_pressed.clear()
            y_pressed.clear()
            continue

        for fd in rlist:
            while True:
                try:
                    # Linux input_event is 24 bytes on 64-bit systems:
                    # struct input_event { struct timeval time; __u16 type; __u16 code; __s32 value; };
                    data = os.read(fd, 24)
                    if not data or len(data) < 24:
                        break
                    sec, usec, ev_type, ev_code, ev_value = struct.unpack("qqHHi", data)

                    if ev_type == EV_KEY:
                        # ev_value: 0 = release, 1 = press, 2 = repeat
                        if ev_code in SELECT_CODES:
                            if ev_value in (1, 2):
                                select_pressed.add(fd)
                            elif ev_value == 0:
                                select_pressed.discard(fd)

                        if ev_code in Y_CODES:
                            if ev_value in (1, 2):
                                y_pressed.add(fd)
                            elif ev_value == 0:
                                y_pressed.discard(fd)

                        # Check combo condition: both SELECT and Y pressed
                        if select_pressed and y_pressed:
                            curr_time = time.time()
                            if curr_time - last_capture_time >= COOLDOWN_SECONDS:
                                last_capture_time = curr_time
                                log(f"Combo triggered! SELECT (code={ev_code}) + Y pressed. Capturing screen...")
                                capture_screen(flash_ctrl)

                except BlockingIOError:
                    break
                except Exception as e:
                    # Bad descriptor or disconnected device
                    close_input_devices(fds)
                    fds = open_input_devices()
                    select_pressed.clear()
                    y_pressed.clear()
                    break

    close_input_devices(fds)
    log("Daemon stopped cleanly.")

if __name__ == "__main__":
    main()
