======================================================================
 Mercusys USB Wi-Fi (2c4e:0102) Standalone Installer for R36H (playOS)
======================================================================

ไฟล์ในโฟลเดอร์นี้:
1. Install_Mercusys_WiFi.sh  : สคริปต์ติดตั้งอัตโนมัติ (All-in-One พร้อมตั้งค่า Auto-Bind ถาวร)
2. Repair_Mercusys_WiFi.sh   : สคริปต์ซ่อมแซมและตรวจสอบด่วน (ปลดบล็อก, รีเซ็ต wlan0, รีสตาร์ต wpa_supplicant, สแกนโชว์ Wi-Fi)
3. 8188eu.ko                 : โมดูลไดรเวอร์เคอร์เนล 4.4.189
4. rtl8188eufw.bin           : ไฟล์เฟิร์มแวร์ Realtek สำหรับชิป 8188EU

วิธีใช้งาน:
----------
วิธีที่ 1: ติดตั้งผ่านเมนู Tools ของ EmulationStation
1. นำโฟลเดอร์ 'mercusys_wifi' ไปวางที่:
   /roms/tools/mercusys_wifi/
   (หรือวางไฟล์ Install_Mercusys_WiFi.sh ไว้ใน /roms/tools/ โดยตรง)
2. บนหน้าจอหลักของเครื่อง R36H ไปที่เมนู Tools
3. เลือก 'Install_Mercusys_WiFi' เพื่อรันการติดตั้ง

วิธีที่ 2: ติดตั้งผ่าน Terminal Emulator
1. เสียบ USB Wi-Fi Dongle เข้ากับเครื่อง
2. เปิด Terminal แล้วพิมพ์คำสั่ง:
   sudo bash /roms/tools/mercusys_wifi/Install_Mercusys_WiFi.sh
   (หรือตามตำแหน่งโฟลเดอร์ที่คุณวางไว้)

คุณสมบัติพิเศษ:
- Persistent Auto-Bind: มีการสร้าง udev rule และ startup script ไว้ในระบบแล้ว
  ทำให้เมื่อเปิดเครื่องใหม่ หรือถอด-เสียบ USB Dongle ระบบจะผูกไดรเวอร์และเปิด wlan0 ให้อัตโนมัติ ไม่ต้องรันสคริปต์ซ้ำอีก
- Cold Boot Automatic Power-Off: หลังติดตั้งเสร็จ ระบบจะแสดงข้อความและรอ 10 วินาที (หรือกดปุ่มใดๆ) เพื่อปิดเครื่อง (shutdown now) ตัดไฟพอร์ต USB ให้ชิปรีเซ็ตใหม่ 100% เมื่อเปิดเครื่องขึ้นมา Wi-Fi จะพร้อมใช้งานทันที
