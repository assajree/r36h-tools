==============================================================================
Power Button Hold-to-Shutdown Daemon for R36H (playOS)
==============================================================================

[ภาษาไทย]
เครื่องมือสำหรับตั้งค่าปุ่ม Power ให้กดค้าง 3 วินาทีเพื่อสั่งปิดเครื่อง (Shutdown)
โดยระบบจะทำการปิดเกม/อีมูเลเตอร์อย่างปลอดภัย (Graceful Save State & SRAM Flush)
และสั่ง sync ข้อมูลลง SD Card ก่อนสั่ง poweroff เพื่อถนอมเครื่องและไม่ทำให้เมมเสียหาย

จุดเด่น:
- ตรวจจับปุ่ม Power (RK8xx PMIC) ผ่าน Linux Input Subsystem โดยตรง
- กดค้าง 1 วินาที: เริ่มนับถอยหลัง 3 วินาที (3.. 2.. 1..) บนหน้าจอ (/dev/tty1)
- กดปุ่มใดๆ ระหว่างนับถอยหลัง: ยกเลิกการปิดเครื่องทันที และกลับสู่เกม/หน้าจอเดิม
- กดสั้น (< 1 วินาที): เข้าโหมด Sleep พักหน้าจอตามปกติ
- ครบนับถอยหลัง: ดำเนินการ Graceful Shutdown (Save state, SRAM, Sync SD, Poweroff)
- ทำงานเป็น Systemd Service ในพื้นหลัง (Background Daemon)
- ใช้ทรัพยากรต่ำมาก (0% CPU, RAM ต่ำกว่า 5MB)

โครงสร้างโฟลเดอร์:
├── Install_Power_Button.sh     <-- สคริปต์ติดตั้งและเปิดใช้งาน Service อัตโนมัติ
├── Status_Power_Button.sh      <-- สคริปต์ตรวจสอบสถานะการทำงาน, PID, RAM, Logs
├── Uninstall_Power_Button.sh   <-- สคริปต์ถอนการติดตั้งและคืนค่าระบบ
├── README.txt                  <-- คู่มือการใช้งาน
└── daemon/                     <-- โฟลเดอร์เก็บไฟล์ระบบหลัก (Subfolder)
    ├── power_button_daemon.py  <-- สคริปต์ Python Core Listener
    └── power-button-daemon.service <-- Systemd Service Unit

วิธีใช้งาน:
1. นำโฟลเดอร์ power_button ไปไว้ที่ /roms/tools/power_button/ บนเครื่อง R36H
2. ติดตั้ง: รัน Install_Power_Button.sh จากเมนู Tools บนเครื่อง
3. ตรวจสอบสถานะ: รัน Status_Power_Button.sh เพื่อดูสถานะการทำงาน
4. ถอนการติดตั้ง: รัน Uninstall_Power_Button.sh เมื่อไม่ต้องการใช้งาน

------------------------------------------------------------------------------
[English]
Power Button Hold-to-Shutdown Daemon for R36H Handheld Console (playOS).
Monitors the RK8xx PMIC power key and performs graceful system shutdown when
held for 3 seconds.

Structure:
├── Install_Power_Button.sh     <-- Installer & Service Enabler
├── Status_Power_Button.sh      <-- Status Inspector (PID, RAM, Device, Logs)
├── Uninstall_Power_Button.sh   <-- Service Remover & Restorer
├── README.txt                  <-- Documentation
└── daemon/                     <-- Core system daemon subfolder
    ├── power_button_daemon.py
    └── power-button-daemon.service
==============================================================================
