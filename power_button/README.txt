==============================================================================
Power Button Hold-to-Shutdown Suite for R36H (playOS / dArkOS / ArkOS)
==============================================================================

[ภาษาไทย]
ชุดเครื่องมือ All-in-One สำหรับจัดการระบบปุ่ม Power บนเครื่อง R36H
โดยมอนิเตอร์ชิป RK8xx PMIC ช่วยให้สามารถกดปุ่ม Power ค้างเพื่อสั่งปิดเครื่อง
พร้อมหน้าจอกราฟิกนับถอยหลัง โดยระบบจะทำการบันทึกข้อมูล ปิดเกม และสั่ง sync SD Card
อย่างปลอดภัยก่อนปิดเครื่อง เพื่อถนอมอุปกรณ์และไม่ทำให้การ์ดความจำเสียหาย

จุดเด่นสำคัญ:
- สถาปัตยกรรม Archetype 2 (Side-by-Side Packaging) รองรับทั้ง /roms/ports/ และ /roms/tools/
- ตัวจัดการ All-in-One TUI (Power_Button_Setup.sh) ควบคุมด้วยจอยเกมผ่าน Native dialog + gptokeyb (ไม่ใช้ fb0_mirror)
- เมนูแยกระหว่างก่อนติดตั้ง (แสดง Install Default / Custom) และหลังติดตั้ง (แสดงเมนูตั้งค่าและ Uninstall)
- ตั้งค่าไดนามิกได้ 3 ส่วน:
  1. Hold Duration: ระยะเวลากดค้างก่อนนับถอยหลัง (1.0 วิ, 2.0 วิ, 3.0 วิ)
  2. Countdown Duration: เวลานับถอยหลังปิดเครื่อง (3 วิ, 5 วิ, 10 วิ)
  3. Short Press Action: พฤติกรรมเมื่อกดปุ่มสั้น (Sleep พักเครื่อง / Screen Off ดับจอ / None ไม่ทำอะไร)
- หน้าจอกราฟิกนับถอยหลัง (countdown_ui): รองรับการกดยกเลิกเฉพาะปุ่มหน้าจอย A, B, X, Y เท่านั้น
  (ป้องกัน Stick Drift หรือ D-pad ลั่นยกเลิกเอง)
- ออกจากโปรแกรมทันที (exit 0) หลังติดตั้งหรือถอนการติดตั้งเสร็จ เพื่อคืนหน้าจอสู่เกมทันที

โครงสร้างชุดไฟล์:
power_button/
├── Power_Button_Setup.sh         <-- ตัวจัดการ All-in-One TUI (เปิดจากเมนู Ports หรือ Tools)
├── README.txt                    <-- คู่มือการใช้งาน
├── images/                       <-- ภาพหน้าปก 512x512
│   └── Power_Button_Setup-thumb.png
└── power_button/                 <-- โฟลเดอร์ข้อมูลภายใน (วางคู่กับตัวเปิด)
    ├── Power_Button_Setup.sh     <-- สำเนาสคริปต์
    ├── app/
    │   ├── Power_Button_Setup-thumb.png
    │   └── status.conf           <-- ไฟล์คอนฟิกสถานะ
    └── daemon/
        ├── countdown_ui          <-- ไบนารี Overlay นับถอยหลัง (รับปุ่ม A, B, X, Y)
        ├── power_button_daemon.py<-- สคริปต์ Daemon ตรวจจับปุ่ม Power
        └── power-button-daemon.service

------------------------------------------------------------------------------
[English]
Power Button Hold-to-Shutdown Suite for R36H Handheld Console.
Monitors RK8xx PMIC power key with dynamic hold, countdown, and short-press handling.

Features:
- Native /dev/tty1 ncurses dialog with gptokeyb (zero fb0_mirror).
- State-aware menu: Clean install modes (Default / Custom) and post-install configuration.
- Custom countdown overlay cancellable strictly via face buttons A, B, X, Y.
- Graceful shutdown sequence: flushes save states and syncs SD card cleanly before poweroff.
==============================================================================
