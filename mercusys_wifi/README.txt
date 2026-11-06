======================================================================
 Mercusys USB Wi-Fi (2c4e:0102) Standalone Installer for R36H (playOS)
======================================================================

โครงสร้างไฟล์และโฟลเดอร์:
------------------------
mercusys_wifi/
├── Install_Mercusys_WiFi.sh    : สคริปต์ติดตั้งไดรเวอร์และระบบ Auto-Bind อัตโนมัติ
├── Uninstall_Mercusys_WiFi.sh  : สคริปต์ถอนการติดตั้งไดรเวอร์และคืนค่าระบบ
├── README.txt                  : คู่มือการใช้งานนี้
├── TECHNICAL_NOTES.md          : บันทึกข้อมูลเชิงลึกทางเทคนิคของชิปเซ็ตและไดรเวอร์
├── driver/                     : ไฟล์ไบนารีเคอร์เนลโมดูลและเฟิร์มแวร์
│   ├── 8188eu.ko               : โมดูลไดรเวอร์เคอร์เนล Linux 4.4.189 (ARM64)
│   └── rtl8188eufw.bin         : ไฟล์เฟิร์มแวร์ Realtek สำหรับชิป 8188EU
└── tools/                      : เครื่องมือสำหรับตรวจเช็คและซ่อมแซม
    ├── Repair_Mercusys_WiFi.sh : สคริปต์ซ่อมแซมและวินิจฉัยด่วน (ปลด rfkill, รีเซ็ต wlan0, สแกน Wi-Fi)
    ├── Check_WiFi_Signal.sh    : สคริปต์วัดความแรงและคุณภาพสัญญาณ Wi-Fi แสดงผลบนหน้าจอ
    ├── restart_wpa_supplicant.sh
    ├── rfkill.sh
    ├── wifi_scan.sh
    ├── wlan0_down.sh
    └── wlan0_up.sh

วิธีใช้งาน:
----------
วิธีที่ 1: ติดตั้งผ่านเมนู Tools ของ EmulationStation
1. นำโฟลเดอร์ 'mercusys_wifi' ไปวางที่:
   /roms/tools/mercusys_wifi/
   (หรือวางไฟล์ Install_Mercusys_WiFi.sh ไว้ใน /roms/tools/ โดยตรง)
2. บนหน้าจอหลักของเครื่อง R36H ไปที่เมนู Tools
3. เลือก 'Install_Mercusys_WiFi' เพื่อเริ่มการติดตั้ง

วิธีที่ 2: ติดตั้งผ่าน Terminal Emulator / SSH
1. เสียบ USB Wi-Fi Dongle เข้ากับเครื่อง
2. เปิด Terminal แล้วพิมพ์คำสั่ง:
   sudo bash /roms/tools/mercusys_wifi/Install_Mercusys_WiFi.sh
   (หรือตามตำแหน่งโฟลเดอร์ที่คุณวางไว้)

วิธีถอนการติดตั้ง:
------------------
เปิด Terminal หรือรันคำสั่ง:
sudo bash /roms/tools/mercusys_wifi/Uninstall_Mercusys_WiFi.sh
ระบบจะถอดไดรเวอร์ ลบ udev rules และคืนค่าระบบให้อัตโนมัติ (คงไฟล์ firmware ไว้ในระบบ)

การใช้งานเครื่องมือในโฟลเดอร์ tools/:
------------------------------------
- หาก Wi-Fi หลุดหรือมองไม่เห็นคลื่น ให้รัน:
  sudo bash /roms/tools/mercusys_wifi/tools/Repair_Mercusys_WiFi.sh
- หากต้องการตรวจสอบความแรงสัญญาณ Wi-Fi ที่เชื่อมต่ออยู่ ให้รัน:
  sudo bash /roms/tools/mercusys_wifi/tools/Check_WiFi_Signal.sh

คุณสมบัติพิเศษ:
--------------
- Persistent Auto-Bind: มีการสร้าง udev rule และ startup script ไว้ในระบบแล้ว
  ทำให้เมื่อเปิดเครื่องใหม่ หรือถอด-เสียบ USB Dongle ระบบจะผูกไดรเวอร์และเปิด wlan0 ให้อัตโนมัติ ไม่ต้องรันสคริปต์ซ้ำอีก
- Cold Boot Automatic Power-Off: หลังติดตั้งเสร็จ ระบบจะแสดงข้อความและรอ 10 วินาที (หรือกดปุ่มใดๆ) เพื่อปิดเครื่อง (shutdown now) ตัดไฟพอร์ต USB ให้ชิปรีเซ็ตใหม่ 100% เมื่อเปิดเครื่องขึ้นมา Wi-Fi จะพร้อมใช้งานทันที
