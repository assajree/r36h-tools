#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Speedtest Runner for R36H (playOS)
Measures Ping, Download, and Upload speeds with clean terminal/framebuffer output.
"""

import os
import sys
import time

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

# Detect whether stdout is already /dev/tty1 to avoid duplicate printing
IS_TTY1_STDOUT = False
try:
    if hasattr(sys.stdout, "fileno") and os.isatty(sys.stdout.fileno()):
        if os.ttyname(sys.stdout.fileno()) == "/dev/tty1":
            IS_TTY1_STDOUT = True
except Exception:
    pass

def log(msg="", end="\n"):
    """Prints message to stdout and mirrors to /dev/tty1 if not already there."""
    print(msg, end=end, flush=True)
    if not IS_TTY1_STDOUT and os.path.exists("/dev/tty1"):
        try:
            with open("/dev/tty1", "a", encoding="utf-8", errors="replace") as f:
                f.write(str(msg) + end)
                f.flush()
        except Exception:
            pass

# Ensure the script directory is in sys.path to load bundled speedtest.py
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

try:
    import speedtest
except ImportError:
    log(" [X] ไม่พบโมดูล speedtest.py ในโฟลเดอร์เครื่องมือ")
    sys.exit(1)

def print_banner():
    log("==================================================")
    log("         R36H playOS Speedtest Benchmark          ")
    log("==================================================")

def run_test():
    print_banner()
    
    log("\n[1/4] ตรวจสอบเครือข่าย & ค้นหาเซิร์ฟเวอร์ที่เร็วที่สุด...")
    try:
        # Initialize Speedtest
        st = speedtest.Speedtest()
        
        # Get best server based on latency
        best = st.get_best_server()
        server_sponsor = best.get("sponsor", "Unknown")
        server_name = best.get("name", "Unknown")
        server_country = best.get("country", "")
        server_dist = best.get("d", 0.0)
        latency = best.get("latency", 0.0)
        
        client_info = st.config.get("client", {})
        client_ip = client_info.get("ip", "Unknown")
        client_isp = client_info.get("isp", "Unknown")
        
        log(f"      -> พบเซิร์ฟเวอร์ : {server_sponsor} ({server_name}, {server_country})")
        log(f"      -> ระยะทาง       : {server_dist:.1f} กม.")
    except Exception as e:
        log(f"\n [X] ไม่สามารถค้นหาเซิร์ฟเวอร์ Speedtest ได้: {e}")
        log("     กรุณาตรวจสอบว่า Wi-Fi ออกอินเทอร์เน็ตได้หรือไม่")
        sys.exit(1)
        
    log("\n[2/4] ตรวจสอบค่าความหน่วง (Ping / Latency)...")
    log(f"      -> ค่า Ping: {latency:.2f} ms")
    
    log("\n[3/4] กำลังทดสอบความเร็วดาวน์โหลด (Download Speed)...")
    try:
        st.download()
        dl_mbps = st.results.download / 1_000_000.0
        log(f"      -> ดาวน์โหลด: {dl_mbps:.2f} Mbps")
    except Exception as e:
        log(f" [!] ทดสอบ Download ขัดข้อง: {e}")
        dl_mbps = 0.0

    log("\n[4/4] กำลังทดสอบความเร็วอัปโหลด (Upload Speed)...")
    try:
        # pre_allocate=False saves memory on RK3326 1GB RAM
        st.upload(pre_allocate=False)
        ul_mbps = st.results.upload / 1_000_000.0
        log(f"      -> อัปโหลด  : {ul_mbps:.2f} Mbps")
    except Exception as e:
        log(f" [!] ทดสอบ Upload ขัดข้อง: {e}")
        ul_mbps = 0.0

    # Summary Box
    log("\n==================================================")
    log("               สรุปผลการทดสอบ Speedtest           ")
    log("==================================================")
    log(f" ผู้ให้บริการ (ISP) : {client_isp}")
    log(f" หมายเลขไอพี (IP)   : {client_ip}")
    log(f" เซิร์ฟเวอร์ทดสอบ   : {server_sponsor} ({server_name})")
    log("--------------------------------------------------")
    log(f"  * Ping (Latency)   : {latency:.2f} ms")
    log(f"  * Download Speed   : {dl_mbps:.2f} Mbps")
    log(f"  * Upload Speed     : {ul_mbps:.2f} Mbps")
    log("==================================================")

if __name__ == "__main__":
    try:
        run_test()
    except KeyboardInterrupt:
        log("\n\n [!] ยกเลิกการทดสอบโดยผู้ใช้")
        sys.exit(0)
