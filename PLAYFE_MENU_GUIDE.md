# PLAYFE_MENU_GUIDE.md - playOS 4.0 Frontend (`playfe`) Menu & App Integration Guide

คู่มือและองค์ความรู้เชิงลึก (Knowledge Base) สำหรับการเพิ่มหมวดหมู่เมนูใหม่ (เช่น `TOOLS`) และการนำแอปหรือสคริปต์ (`.sh`) ไปแสดงผลพร้อมรูปปก (`512x512`) บนหน้าจอหลักของ **playOS 4.0** (`playfe`) บนเครื่อง **R36H**

---

## 1. สถาปัตยกรรมของเมนู playOS 4.0 (`playfe`)

ใน **playOS 4.0** หน้าจอเมนูหลัก (UI แบบการ์ดสี่เหลี่ยมขอบมนตรงกลาง และพรีวิววงกลมด้านขวา) ไม่ได้ใช้ไบนารี EmulationStation ดั้งเดิมในการแสดงผล แต่ใช้ Frontend ที่พัฒนาขึ้นใหม่ชื่อ **`playfe`** ซึ่งยังคงอ่านไฟล์ตั้งค่าและโครงสร้างของ EmulationStation เพื่อความเข้ากันได้:

| องค์ประกอบ | พาธในระบบ (R36H) | หน้าที่ |
| :--- | :--- | :--- |
| **Frontend Binary** | `/usr/local/bin/playfe` | โปรแกรมแสดงผลเมนูหลัก (C++17 / SDL2 / GLES2) |
| **Systemd Service** | `/etc/systemd/system/playfe.service` | เซอร์วิสจัดการ `playfe` (รันในนามผู้ใช้ `ark`) |
| **System Categories** | `/etc/emulationstation/es_systems.cfg` | กำหนดหมวดหมู่ระบบ/เมนูบนแถบด้านบน (เช่น `ports`, `tools`, `snes`) |
| **Built-in System Logos** | `/usr/local/share/playfe/logos/` | โลโก้ประจำหมวดหมู่ที่มากับระบบ (มี `tools.png`, `tools-card.png`, `apps.png`, `ports.png` เตรียมไว้ให้แล้ว) |
| **User Config & Cache** | `/home/ark/.config/playfe/` | เก็บ `playfe.cfg`, แคช `library.tsv`, และล็อกการรันล่าสุด `last_launch.log` |
| **Per-System Metadata** | `/roms/<system>/gamelist.xml` | กำหนดชื่อแอป (`<name>`), คำอธิบาย, รูปปก (`<image>`), และการซ่อนไฟล์ (`<hidden>`) |

---

## 2. การเปิดใช้งานหมวดหมู่ `TOOLS` บนแถบเมนูด้านบน

โดยค่าเริ่มต้น `/etc/emulationstation/es_systems.cfg` ของ playOS อาจยังไม่ได้ใส่บล็อก `<system>` สำหรับ `/roms/tools/` แม้ว่าใน `/usr/local/share/playfe/logos/` จะมีไฟล์ไอคอน `tools.png` และการ์ด `tools-card.png` เตรียมไว้แล้วก็ตาม

### 2.1 โครงสร้าง XML ใน `/etc/emulationstation/es_systems.cfg`
เพิ่มบล็อก `<system>` นี้ก่อนปิดแท็ก `</systemList>`:

```xml
	<system>
		<name>tools</name>
		<fullname>Tools</fullname>
		<path>/roms/tools/</path>
		<extension>.sh .SH</extension>
		<command>sudo bash %ROM%</command>
		<platform>pc</platform>
		<theme>tools</theme>
	</system>
```

### 2.2 กลไกการแสดงผลของ `playfe` (`play::App::afterLoad` & `findLogo`)
* **ป้ายชื่อหมวดหมู่ด้านบน (Top Pill Text):** `playfe` นำค่าจาก `<name>` มาแปลงเป็นตัวพิมพ์ใหญ่ทั้งหมด (`toupper(<name>)` -> แสดงเป็น **`TOOLS`**)
* **ชื่อหมวดหมู่ย่อยใต้ชื่อแอป (Subtitle):** ใช้ค่าจาก `<fullname>` (เช่น แสดงคำว่า **`Tools`** ใต้ชื่อแอป)
* **ไอคอนหมวดหมู่ด้านบน & การ์ดเริ่มต้น:** `playfe` ค้นหาไฟล์จาก `<theme>` ก่อน แล้วจึงใช้ `<name>` ในโฟลเดอร์:
  1. `/home/ark/.config/playfe/logos/<theme>.png` และ `<theme>-card.png`
  2. `/usr/local/share/playfe/logos/<theme>.png` และ `<theme>-card.png`
  *(สำหรับ `tools` มีไฟล์ `/usr/local/share/playfe/logos/tools.png` และ `tools-card.png` มาให้ในระบบแล้ว)*

---

## 3. กฎการสแกนไฟล์และโฟลเดอร์ย่อยของ `playfe` (Reverse-Engineered Insights)

จากการวิเคราะห์ฟังก์ชัน `play::GamelistParser::scanDirectory` (`0x6df40`) และ `loadSystemGames` (`0x70f00`) ในไบนารี `/usr/local/bin/playfe` พบพฤติกรรมสำคัญ 3 ข้อที่นักพัฒนาต้องทราบ:

### 3.1 กฎที่ 1: ระบบที่ชื่อ `ports` หรือ `port` จะไม่สแกนโฟลเดอร์ย่อย (Shallow Scan)
* หาก `<name>` หรือ `<fullname>` เป็นคำว่า `ports` หรือ `port` ตัว `playfe` จะสแกนเฉพาะไฟล์ `.sh` ในระดับบนสุดของ `/roms/ports/` เท่านั้น และข้ามโฟลเดอร์ย่อยทั้งหมดโดยอัตโนมัติ

### 3.2 กฎที่ 2: การข้ามโฟลเดอร์ย่อยอัตโนมัติด้วยชื่อไฟล์ (Stem-Matching Auto-Skip)
* สำหรับหมวดหมู่ที่รองรับนามสกุล `.sh` (เช่น `tools`):
  1. `playfe` จะรวบรวมชื่อไฟล์ `.sh` ในระดับบนสุดของ `/roms/tools/` แล้วตัดอักขระพิเศษออกเหลือเฉพาะตัวอักษรพิมพ์เล็กและตัวเลข (Normalized Alphanumeric Stem ที่มีความยาว > 4 ตัวอักษร) เช่น:
     * `Screen_Off.sh` -> `"screenoff"`
     * `Start_Web_Terminal.sh` -> `"startwebterminal"`
     * `Speedtest.sh` -> `"speedtest"`
  2. เมื่อ `playfe` วนลูปตรวจสอบโฟลเดอร์ย่อยใน `/roms/tools/` จะนำชื่อโฟลเดอร์ย่อยมาแปลงเป็นรูปแบบเดียวกัน (เช่น `screen_off/` -> `"screenoff"`, `web_terminal/` -> `"webterminal"`)
  3. **หากชื่อโฟลเดอร์ย่อยเป็นส่วนหนึ่ง (Substring) ของชื่อไฟล์ `.sh` ด้านนอก ตัว `playfe` จะข้ามการสแกนโฟลเดอร์ย่อยนั้นทันที!**
* **ผลลัพธ์:** เครื่องมือที่เป็น **Archetype 1** (`Start_<Tool>.sh`) และ **Archetype 3** (`<Tool>.sh`) ที่มีสคริปต์รันวางอยู่ใน `/roms/tools/` จะไม่เกิดปัญหาสคริปต์ย่อยในโฟลเดอร์ `/roms/tools/<tool_name>/` โผล่ซ้ำในเมนู!

### 3.3 กฎที่ 3: การซ่อนโฟลเดอร์ของเครื่องมือที่ไม่ต้องการแสดงไอคอนในเมนู (`<hidden>true</hidden>` ใน `gamelist.xml`)
* เครื่องมือที่ไม่ต้องการให้มีไอคอนแสดงบนหน้าเมนู `TOOLS` (เช่น **Archetype 2: Background Daemons** อย่าง `power_button/` หรือ **Archetype 4: System Configuration** อย่าง `quick_tools/`, `tools_menu/`, `mercusys_wifi/`) จะไม่มีไฟล์ `.sh` ชื่อตรงกันวางอยู่ด้านนอก `/roms/tools/`
* ส่งผลให้ `playfe` สแกนทะลุเข้าไปในโฟลเดอร์ย่อยและนำ `Install_*.sh` / `Uninstall_*.sh` ออกมาแสดงในเมนู
* **กฎบังคับ:** สคริปต์ `Install_*.sh` ของเครื่องมือที่ไม่ต้องการแสดงไอคอนในเมนู `TOOLS` **ต้องมีสคริปต์อัปเดต `/roms/tools/gamelist.xml`** เพื่อใส่ `<hidden>true</hidden>` ให้กับไฟล์ `.sh` ทั้งหมดภายในโฟลเดอร์ของตัวเอง (`$SCRIPT_DIR`)

| ไฟล์สคริปต์ด้านนอก (`/roms/tools/`) | ชื่อหลังแปลง (`> 4` ตัว) | โฟลเดอร์ย่อย (`/roms/tools/`) | การตั้งค่า `gamelist.xml` | ผลลัพธ์ในเมนู `playfe` |
| :--- | :--- | :--- | :--- | :--- |
| `Screen_Off.sh` | `screenoff` | `screen_off/` | ไม่ต้องใช้ | **แสดงเฉพาะปุ่มหลัก (ซ่อนโฟลเดอร์ย่อยอัตโนมัติ)** |
| `Start_Web_Terminal.sh` | `startwebterminal` | `web_terminal/` | ไม่ต้องใช้ | **แสดงเฉพาะปุ่มหลัก (ซ่อนโฟลเดอร์ย่อยอัตโนมัติ)** |
| `Start_Web_FileManager.sh` | `startwebfilemanager` | `web_filemanager/` | ไม่ต้องใช้ | **แสดงเฉพาะปุ่มหลัก (ซ่อนโฟลเดอร์ย่อยอัตโนมัติ)** |
| `Speedtest.sh` | `speedtest` | `speedtest/` | ไม่ต้องใช้ | **แสดงเฉพาะปุ่มหลัก (ซ่อนโฟลเดอร์ย่อยอัตโนมัติ)** |
| *(ไม่มีปุ่มด้านนอก)* | — | `power_button/`, `quick_tools/`, `tools_menu/`, `mercusys_wifi/` | ใส่ `<hidden>true</hidden>` ใน `Install_*.sh` | **ไม่แสดงไอคอนในเมนู `TOOLS`** |
| *(ตั้งชื่อไม่ตรง)* `Run_Net.sh` | `runnet` | `speedtest/` | ไม่ได้ใส่ `<hidden>` | **ไม่ซ่อน!** (สคริปต์ในโฟลเดอร์ย่อยจะโผล่ซ้ำ) |

---

## 4. การสร้างรูปปก (Cover Art) และการตั้งค่า `gamelist.xml`

### 4.1 มาตรฐานรูปปก (`*-thumb.png`)
* **ขนาดที่แนะนำ:** `512x512` พิกเซล (อัตราส่วน 1:1 จัตุรัส, ฟอร์แมต PNG)
* **การจัดวางองค์ประกอบ (Safe Zone):**
  * การ์ดตรงกลางแสดงผลเป็น **สี่เหลี่ยมจัตุรัสมุมมน (Rounded Square)**
  * รายการถัดไปทางด้านขวาแสดงผลเป็น **วงกลม (Circular Mask)**
  * ดังนั้นควรออกแบบให้ **ไอคอนหลักและชื่อแอปอยู่บริเวณกึ่งกลางภาพ** (ห่างจากขอบอย่างน้อย 12–15%) เพื่อไม่ให้ขอบวงกลมด้านขวาตัดข้อความสำคัญ
* **ตำแหน่งเก็บไฟล์:** `/roms/tools/images/<ScriptStem>-thumb.png`
  * ตัวอย่างเช่น สคริปต์ `/roms/tools/Screen_Off.sh` ใช้รูปปก `/roms/tools/images/Screen_Off-thumb.png`
* **การค้นหารูปปกอัตโนมัติ (`picturesFor`):**
  * แม้ยังไม่ได้เขียน `gamelist.xml` หากวางไฟล์ชื่อ `/roms/tools/images/<ScriptStem>-thumb.png` หรือ `<ScriptStem>-image.png` ตัว `playfe` จะจับคู่รูปปกให้โดยอัตโนมัติ

### 4.2 โครงสร้างไฟล์ `/roms/tools/gamelist.xml`
เพื่อให้แสดงชื่อภาษาไทย/อังกฤษที่สวยงามและซ่อนสคริปต์ติดตั้งที่ไม่ต้องการให้แสดงในเมนู ให้ใช้โครงสร้างดังนี้:

```xml
<?xml version="1.0"?>
<gameList>
	<game>
		<path>./Screen_Off.sh</path>
		<name>Screen Off (ปิดหน้าจอ)</name>
		<desc>ปิดไฟหน้าจอ LCD เพื่อถนอมจอและประหยัดแบตเตอรี่ กดปุ่มใดก็ได้เพื่อเปิดหน้าจอกลับมา</desc>
		<image>./images/Screen_Off-thumb.png</image>
		<thumbnail>./images/Screen_Off-thumb.png</thumbnail>
	</game>
	<game>
		<path>./power_button/Install_Power_Button.sh</path>
		<name>Install Power Button</name>
		<hidden>true</hidden>
	</game>
</gameList>
```

---

## 5. ข้อควรระวังในการเขียนสคริปต์เมื่อรันจาก `playfe` (Runtime & Input Quirks)

เมื่อผู้ใช้กดปุ่ม **`B` (เข้า)** บนหน้าเมนู `playfe` ตัว `playfe` จะปิดระบบกราฟิก SDL2 ชั่วคราว (เปิดทางให้ `/dev/tty1`) และรันคำสั่งผ่าน:
```sh
sh -c "( sudo bash '/roms/tools/My_Tool.sh' ) >> '/home/ark/.config/playfe/last_launch.log' 2>&1"
```

มีพฤติกรรมเฉพาะตัว 2 ข้อที่ต้องระวัง:

### 5.1 Quirk 1: `stdin` (`fd 0`) เชื่อมต่อกับ `/dev/null`
* เพราะ `playfe.service` รันเป็น systemd service โดยไม่มี TTY มาตรฐาน ทำให้ `stdin` (`fd 0`) เป็น `/dev/null`
* หากสคริปต์ใช้ `read -s -n 1 -r` บน `stdin` ใน subshell ร่วมกับ `wait -n $INPUT_PIDS` คำสั่ง `read` จะเจอ `EOF` และจบการทำงานทันทีด้วยรหัส `1` ทำให้ `wait -n` หลุดออกจากลูปทันทีโดยไม่รอปุ่มกด!
* **วิธีแก้ไขมาตรฐาน:**
  * ให้ตรวจสอบ `[ -c /dev/tty1 ]` เพื่ออ่านจาก `/dev/tty1` และเติม `|| sleep 86400` ต่อท้าย `read` เสมอ เพื่อไม่ให้ `EOF` ทำให้ `wait -n` หลุดก่อนเวลา:
  ```bash
  (
      if [ -t 0 ]; then
          read -s -n 1 -r 2>/dev/null || sleep 86400
      elif [ -c /dev/tty1 ]; then
          read -s -n 1 -r < /dev/tty1 2>/dev/null || sleep 86400
      else
          sleep 86400
      fi
  ) &
  ```

### 5.2 Quirk 2: จังหวะปล่อยปุ่ม `B` หลังเปิดแอป (Button Release Debounce)
* เมื่อผู้ใช้กดปุ่ม `B` เพื่อเข้าแอป จังหวะที่นิ้วปล่อยปุ่ม `B` (`EV_KEY` value `0`) จะถูกส่งเข้ามาที่ `/dev/input/event*` หลังจากสคริปต์เริ่มทำงานไปแล้วประมาณ `100–300ms`
* หากสคริปต์เริ่มดักฟัง `/dev/input/event*` ทันทีตั้งแต่วินาทีแรก (เช่น แอป `Screen_Off.sh` ที่รอรับปุ่มใดก็ได้เพื่อปลุกหน้าจอ) จังหวะปล่อยปุ่ม `B` จะไปปลุกหน้าจอทันที
* **วิธีแก้ไขมาตรฐาน:**
  * ใส่ `sleep 0.6` ก่อนเริ่มเปิดลูป `dd if="$ev"` ดักฟังปุ่ม เพื่อรอให้ผู้ใช้ปล่อยปุ่ม `B` ให้เสร็จก่อน

### 5.3 การรีโหลดเมนู `playfe` หลังแก้ไขรายการ
* `playfe` จะบันทึกแคชรายการแอปไว้ที่ `/home/ark/.config/playfe/library.tsv` แต่เมื่อเริ่มทำงานใหม่ (`systemctl restart playfe.service`) จะสแกน `/roms/tools/` และอัปเดตเมนูให้เป็นปัจจุบันเสมอ
* คำสั่งรีเฟรชหน้าเมนูผ่าน SSH (เมื่อต้องการให้เห็นผลทันที):
  ```bash
  sudo systemctl restart playfe.service
  ```

---

## 6. แนวทางการแบ่งหน้าที่สำหรับแต่ละประเภทเครื่องมือ

1. **เปิดหมวดหมู่ `TOOLS` ด้วย `tools_menu` ([`tools_menu/Install_Tools_Menu.sh`](file:///d:/me/r36h/tools/tools_menu/Install_Tools_Menu.sh)):**
   * เพิ่มบล็อก `<name>tools</name>` ลงใน `/etc/emulationstation/es_systems.cfg`, สร้างโฟลเดอร์ `/roms/tools/images/`, ซ่อนไฟล์ `.sh` ในโฟลเดอร์ `tools_menu/` ของตัวเองใน `gamelist.xml` และสั่ง `systemctl restart playfe.service`
2. **เครื่องมือที่ต้องการแสดงไอคอนในเมนู `TOOLS` (Archetype 1 & 3 เช่น `screen_off`, `speedtest`, `web_terminal`, `web_filemanager`):**
   * ไม่ต้องแก้ไข `gamelist.xml` เพียงคัดลอกสคริปต์ `.sh` (ตั้งชื่อให้มีคำเดียวกับโฟลเดอร์ย่อย) ไปที่ `/roms/tools/<ScriptStem>.sh` และคัดลอกรูปปก `512x512` ไปที่ `/roms/tools/images/<ScriptStem>-thumb.png`:
   ```bash
   # แม่แบบใน Install_<Tool>.sh ของแอปที่แสดงไอคอนในเมนู TOOLS
   mkdir -p /roms/tools/images
   cp -f "$SCRIPT_DIR/app/My_Tool.sh" /roms/tools/My_Tool.sh
   chmod 755 /roms/tools/My_Tool.sh

   if [ -f "$SCRIPT_DIR/app/My_Tool-thumb.png" ]; then
       cp -f "$SCRIPT_DIR/app/My_Tool-thumb.png" /roms/tools/images/My_Tool-thumb.png
   fi
   ```
3. **เครื่องมือที่ไม่ต้องการให้แสดงไอคอนในเมนู `TOOLS` (Archetype 2 & 4 เช่น `power_button`, `quick_tools`, `tools_menu`, `mercusys_wifi`):**
   * ให้ใส่สคริปต์อัปเดต `/roms/tools/gamelist.xml` ใน `Install_<Tool>.sh` เพื่อใส่ `<hidden>true</hidden>` ให้กับไฟล์ `.sh` ทั้งหมดในโฟลเดอร์ของตัวเอง (`$SCRIPT_DIR`):
   ```bash
   # แม่แบบใน Install_<Tool>.sh ของเครื่องมือที่ไม่ต้องการแสดงไอคอนในเมนู TOOLS
   if command -v python3 >/dev/null 2>&1; then
       SCRIPT_DIR="$SCRIPT_DIR" python3 - << 'PYEOF'
   import os, xml.etree.ElementTree as ET
   tools_dir = "/roms/tools"
   script_dir = os.path.realpath(os.environ.get("SCRIPT_DIR", ""))
   real_tools = os.path.realpath(tools_dir)
   if os.path.isdir(tools_dir) and script_dir.startswith(real_tools + "/"):
       gamelist_path = os.path.join(tools_dir, "gamelist.xml")
       root = None
       if os.path.exists(gamelist_path):
           try: root = ET.parse(gamelist_path).getroot()
           except Exception: root = None
       if root is None: root = ET.Element("gameList")
       existing = {g.find("path").text.strip().lstrip("./"): g for g in root.findall("game") if g.find("path") is not None and g.find("path").text}
       for dp, _, fns in os.walk(script_dir):
           for fn in sorted(fns):
               if fn.lower().endswith(".sh"):
                   rel_p = os.path.relpath(os.path.join(dp, fn), real_tools).replace("\\", "/")
                   g = existing.get(rel_p)
                   if g is None:
                       g = ET.SubElement(root, "game")
                       ET.SubElement(g, "path").text = "./" + rel_p
                       ET.SubElement(g, "name").text = os.path.splitext(fn)[0]
                   h = g.find("hidden")
                   if h is None: h = ET.SubElement(g, "hidden")
                   h.text = "true"
       ET.indent(root, space="\t")
       with open(gamelist_path, "w", encoding="utf-8", newline="\n") as f:
           f.write('<?xml version="1.0"?>\n' + ET.tostring(root, encoding="unicode") + "\n")
   PYEOF
       chown ark:ark /roms/tools/gamelist.xml 2>/dev/null || true
   fi
   ```
