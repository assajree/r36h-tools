#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Auto Screen Off Daemon for R36H (playOS)
Monitors all input devices (/dev/input/event*).
When idle for TIMEOUT_SECONDS (default 600s / 10 minutes):
- Saves current LCD backlight brightness
- Turns off LCD backlight to 0 (and blanks fb0) to preserve screen & battery
- Keeps CPU, Wi-Fi, SSH, web services, and background downloads active
- Wakes up immediately upon any gamepad button, D-pad, or key press
"""

import os
import sys
import glob
import time
import struct
import select
import signal

DEFAULT_TIMEOUT = 600  # 10 minutes

def log(msg):
    print(f"[auto_screen_off] {msg}", flush=True)

class ScreenController:
    def __init__(self):
        self.backlight_dir = self._find_backlight()
        self.saved_brightness = 100
        self.is_screen_off = False
        self._init_saved_brightness()

    def _find_backlight(self):
        for path in glob.glob("/sys/class/backlight/*"):
            brightness_file = os.path.join(path, "brightness")
            if os.path.isdir(path) and os.access(brightness_file, os.W_OK):
                return path
        return None

    def _init_saved_brightness(self):
        if not self.backlight_dir:
            return
        b_file = os.path.join(self.backlight_dir, "brightness")
        try:
            with open(b_file, "r") as f:
                val = int(f.read().strip())
                if val > 0:
                    self.saved_brightness = val
                    return
        except Exception:
            pass

        max_file = os.path.join(self.backlight_dir, "max_brightness")
        try:
            with open(max_file, "r") as f:
                val = int(f.read().strip())
                if val > 0:
                    self.saved_brightness = val
                    return
        except Exception:
            pass
        self.saved_brightness = 100

    def turn_off(self):
        if self.is_screen_off:
            return

        # 1. Update saved brightness before turning off
        if self.backlight_dir:
            b_file = os.path.join(self.backlight_dir, "brightness")
            try:
                with open(b_file, "r") as f:
                    val = int(f.read().strip())
                    if val > 0:
                        self.saved_brightness = val
            except Exception:
                pass

        log(f"Idle timeout reached. Turning off backlight (saved brightness: {self.saved_brightness})...")

        # 2. Blank backlight
        if self.backlight_dir:
            b_file = os.path.join(self.backlight_dir, "brightness")
            try:
                with open(b_file, "w") as f:
                    f.write("0\n")
            except Exception as e:
                log(f"Error setting backlight to 0: {e}")

        # 3. Blank fb0
        fb_blank = "/sys/class/graphics/fb0/blank"
        if os.path.exists(fb_blank) and os.access(fb_blank, os.W_OK):
            try:
                with open(fb_blank, "w") as f:
                    f.write("1\n")
            except Exception:
                pass

        self.is_screen_off = True

    def turn_on(self):
        if not self.is_screen_off:
            return

        log(f"Input detected! Restoring backlight to {self.saved_brightness}...")

        # 1. Unblank fb0
        fb_blank = "/sys/class/graphics/fb0/blank"
        if os.path.exists(fb_blank) and os.access(fb_blank, os.W_OK):
            try:
                with open(fb_blank, "w") as f:
                    f.write("0\n")
            except Exception:
                pass

        # 2. Restore backlight
        if self.backlight_dir:
            b_file = os.path.join(self.backlight_dir, "brightness")
            try:
                with open(b_file, "w") as f:
                    f.write(f"{self.saved_brightness}\n")
            except Exception as e:
                log(f"Error restoring backlight: {e}")

        self.is_screen_off = False


def open_input_devices():
    """Opens all readable /dev/input/event* devices in non-blocking mode."""
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


def drain_input(fd):
    """Flushes buffered event packets from a file descriptor."""
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


def run_daemon(timeout_seconds=DEFAULT_TIMEOUT):
    screen = ScreenController()
    log(f"Starting auto screen off daemon with {timeout_seconds}s timeout...")
    if screen.backlight_dir:
        log(f"Backlight controller: {screen.backlight_dir}")
    else:
        log("Warning: No writable backlight device detected.")

    # Register signal handlers for clean exit & screen restoration
    def sig_handler(signum, frame):
        log(f"Received signal {signum}, restoring screen and exiting...")
        screen.turn_on()
        sys.exit(0)

    signal.signal(signal.SIGINT, sig_handler)
    signal.signal(signal.SIGTERM, sig_handler)

    fds = open_input_devices()
    log(f"Monitoring {len(fds)} input devices for activity.")

    last_activity = time.monotonic()

    try:
        while True:
            # Re-check and open newly connected input devices if any were added
            current_paths = set(glob.glob("/dev/input/event*"))
            open_paths = set(fds.values())
            if current_paths != open_paths:
                close_input_devices(fds)
                fds = open_input_devices()
                log(f"Input device topology changed. Now monitoring {len(fds)} devices.")

            fd_list = list(fds.keys())
            if not fd_list:
                time.sleep(2)
                fds = open_input_devices()
                continue

            if screen.is_screen_off:
                # Screen is currently OFF: wait indefinitely until ANY event arrives
                r, _, _ = select.select(fd_list, [], [], None)
                if r:
                    # Input detected -> Wake screen up immediately
                    screen.turn_on()
                    for active_fd in r:
                        drain_input(active_fd)
                    last_activity = time.monotonic()
            else:
                # Screen is currently ON: calculate remaining idle time
                elapsed = time.monotonic() - last_activity
                remaining = timeout_seconds - elapsed

                if remaining <= 0:
                    # Timeout reached without input -> Turn screen off
                    screen.turn_off()
                    continue

                r, _, _ = select.select(fd_list, [], [], remaining)
                if r:
                    # Input received while screen is on -> Reset idle timer
                    last_activity = time.monotonic()
                    for active_fd in r:
                        drain_input(active_fd)
                else:
                    # select() timed out -> 60s idle reached!
                    screen.turn_off()

    finally:
        screen.turn_on()
        close_input_devices(fds)


if __name__ == "__main__":
    timeout = DEFAULT_TIMEOUT
    if len(sys.argv) > 1:
        try:
            val = int(sys.argv[1])
            if val > 0:
                timeout = val
        except ValueError:
            pass
    run_daemon(timeout)
