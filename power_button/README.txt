==============================================================================
Power Button Hold-to-Shutdown Daemon for R36H (playOS)
==============================================================================

[ภาษาไทย]
เครื่องมือสำหรับตั้งค่าปุ่ม Power ให้กดค้างเพื่อสั่งปิดเครื่อง (Shutdown)
โดยระบบจะทำการปิดเกม/อีมูเลเตอร์อย่างปลอดภัย (Graceful Save State & SRAM Flush)
และสั่ง sync ข้อมูลลง SD Card ก่อนสั่ง poweroff เพื่อถนอมเครื่องและไม่ทำให้เมมเสียหาย

จุดเด่น:
- มีตัวติดตั้งให้เลือก 2 แบบ:
  1. Setup_UI.sh            : หน้าต่างติดตั้งกราฟิกแบบ Universal Setup UI (SDL2 KMSDRM)
                              เลือกระยะเวลานับถอยหลัง (3 วิ, 5 วิ, 10 วิ) หรือถอนการติดตั้งด้วยปุ่มจอยได้ทันที
  2. Install_Power_Button.sh: สคริปต์ติดตั้งอัตโนมัติแบบดั้งเดิม (Default)
- ตรวจจับปุ่ม Power (RK8xx PMIC) ผ่าน Linux Input Subsystem โดยตรง
- กดค้าง 1 วินาที: เริ่มนับถอยหลังพร้อมกราฟิกการ์ด Overlay แบบ SDL2 Direct KMSDRM
- กดปุ่มใดๆ ระหว่างนับถอยหลัง: ยกเลิกการปิดเครื่องทันที และกลับสู่เกม/หน้าจอเดิม
- กดสั้น (< 1 วินาที): เข้าโหมด Sleep พักหน้าจอตามปกติ
- ครบนับถอยหลัง: ดำเนินการ Graceful Shutdown (Save state, SRAM, Sync SD, Poweroff)
- ทำงานเป็น Systemd Service ในพื้นหลัง (Background Daemon)
- ใช้ทรัพยากรต่ำมาก (0% CPU, RAM ต่ำกว่า 5MB)

โครงสร้างโฟลเดอร์:
├── Setup_UI.sh                 <-- ตัวติดตั้ง/ตั้งค่าแบบ Universal Setup UI (เลือก Timeout 3/5/10 วิ หรือ Uninstall)
├── Install_Power_Button.sh     <-- สคริปต์ติดตั้งและเปิดใช้งาน Service อัตโนมัติ (แบบดั้งเดิม)
├── Status_Power_Button.sh      <-- สคริปต์ตรวจสอบสถานะการทำงาน, PID, RAM, Logs
├── Uninstall_Power_Button.sh   <-- สคริปต์ถอนการติดตั้งและคืนค่าระบบ
├── README.txt                  <-- คู่มือการใช้งาน
└── daemon/                     <-- โฟลเดอร์เก็บไฟล์ระบบหลัก (Subfolder)
    ├── setup_ui                <-- Direct SDL2 KMSDRM Universal Setup UI binary
    ├── countdown_ui            <-- Direct SDL2 KMSDRM Countdown Overlay binary
    ├── power_button_daemon.py  <-- สคริปต์ Python Core Listener
    └── power-button-daemon.service <-- Systemd Service Unit

วิธีใช้งาน:
1. นำโฟลเดอร์ power_button ไปไว้ที่ /roms/tools/power_button/ บนเครื่อง R36H
2. ติดตั้ง/ตั้งค่าผ่าน Setup UI: รัน Setup_UI.sh (รองรับทั้ง playOS Terminal และ Tools menu)
   หรือติดตั้งแบบอัตโนมัติทันที: รัน Install_Power_Button.sh
3. ตรวจสอบสถานะ: รัน Status_Power_Button.sh เพื่อดูสถานะการทำงาน
4. ถอนการติดตั้ง: รัน Uninstall_Power_Button.sh หรือเลือก Remove ใน Setup_UI.sh

------------------------------------------------------------------------------
[English]
Power Button Hold-to-Shutdown Daemon for R36H Handheld Console (playOS).
Monitors the RK8xx PMIC power key and performs graceful system shutdown.

Structure:
├── Setup_UI.sh                 <-- Interactive Setup UI Wizard (3s/5s/10s/Uninstall)
├── Install_Power_Button.sh     <-- Standard One-Click Installer & Service Enabler
├── Status_Power_Button.sh      <-- Status Inspector (PID, RAM, Device, Logs)
├── Uninstall_Power_Button.sh   <-- Service Remover & Restorer
├── README.txt                  <-- Documentation
└── daemon/                     <-- Core system daemon subfolder
    ├── setup_ui                <-- Direct SDL2 KMSDRM Universal Setup UI binary
    ├── countdown_ui            <-- Direct SDL2 KMSDRM Countdown Overlay binary
    ├── power_button_daemon.py  <-- Python Core Daemon
    └── power-button-daemon.service
==============================================================================
