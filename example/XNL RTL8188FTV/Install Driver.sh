#!/bin/bash
# =================================================================================
# XNL Future Technologies R36 RTL8188FTV Driver Installer
#
# Purpose: This script is intended to install the RTL8188FU driver, which is also
# used to get cheap ($1.50) Chinese USB WiFi dongles to work on the R36S and R36H
# when using the official ArkOS version which can be found here:
# https://github.com/christianhaitian/arkos
#
# INFO UPDATE: By now I have bought and tested over 20! different USB Dongles
# and NEARLY all of them work perfectly with this driver now :) There where two
# which kept spitting out USB Information over the SERIAL PORT Terminal:
#[ 9596.262869] dwc2 ff300000.usb: dwc2_hc_chhltd_intr_dma: Channel 1 - ChHltd set, but reason is unknown
#[ 9596.272092] dwc2 ff300000.usb: hcint 0x00000002, intsts 0x06600029
#[ 9596.476788] usb usb1-port1: disabled by hub (EMI?), re-enabling...
#[ 9604.738325] usb 1-1-port4: disabled by hub (EMI?), re-enabling...
#
# Those where working just fine, but I did felt like it that these two where quite a bit
# slower when downloading packages, doing box-art scraping etc. I can't tell you the the difference
# either, because most of them have been bought in one single order (but from different sellers on purpose).
# All dongles (including the boards) look exactly the same, I'm suspecting these two are just crappy quality
#
#------------------------
# Website:                   http://www.teamxnl.com/R36-RTL8188FTV-DRIVER
# Install Tutorial (Blog):   https://www.teamxnl.com/installing-cheap-wifi-on-your-r36s-or-r36h/
# Install Tutorial (Video):  https://www.youtube.com/watch?v=3Ka4UdghNhQ
# YouTube Channel:			 https://www.youtube.com/XNLFutureTechnologies
# Original Driver Developer: https://github.com/kelebek333/rtl8188fu
# License: GPL-2.0
#------------------------
#
# IMPORTANT:
# Information about support, updates etc can be found in the readme.txt
# which should be included in the download of this script. If you didn't
# received the readme.txt due to downloading from a different source for example,
# then please refer to the official project website (at the teamxnl.com domain
# above for more information about this topic!
# =================================================================================

Application="XNL Future Technologies R36 RTL8188FTV Driver Installer"
IntendedKernel="4.4.189"
XNLDriverVersion="1"		# Used to save in the .xnlft-packmanvers file

if [[ -n "$SSH_TTY" || "$(tty 2>/dev/null)" == "/dev/ttyFIQ0" ]]; then
	printf "\n\n======================================\n"
	printf "XNL Error Message:\n"
	printf "This program, tool or script can't be run via either SSH or the serial console!\n"
	printf "Sorry, this is because it for example runs, controls or needs local hardware on the R36S/R36H\n"
	printf "and because it for example could rely on local variables on the device itself.\n"
	printf "\nAffected Program: $Application\n\n"
	printf "======================================\n\n\n"
	return 1
fi

CurScriptDir=$(realpath "$(dirname "$0")")
CurScriptName=$(basename "$0")

# Take control of tty1 (the terminal), clearing the terminal and printing the "Application" start text in color
sudo chmod 666 /dev/tty1
printf "\033c" > /dev/tty1
printf "\e[34mStarting XNL RTL8188FTV Driver Installer\n\e[32mPlease wait...\e[0m" > /dev/tty1
reset

# Hide cursor
printf "\e[?25l" > /dev/tty1
dialog --clear


export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

pgrep -f gptokeyb | sudo xargs kill -9
pgrep -f osk.py | sudo xargs kill -9


if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
if test ! -z "$(cat /home/ark/.config/.DEVICE | grep RG503 | tr -d '\0')"
then
	sudo setfont /usr/share/consolefonts/Lat7-TerminusBold20x10.psf.gz
else
	sudo setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz
fi
else
sudo setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz
fi
printf "\033c" > /dev/tty1

XSF_savesetting() {
    local setting=$1
    local value=$2
    local config_file=$3
    local descrip_if_file_not_exists=$4

	# If the file doesn't exist yet AND the optional 4th parameter has been set,
	# the function will automaticall create a 'info line' at the top of the file
	if [[ ! -f "$config_file" && -n $descrip_if_file_not_exists ]]; then
		echo "# $descrip_if_file_not_exists" >> "$config_file"
	fi

    # Check if the setting already exists, if not create/add it to the existing config file
    if grep -q "^${setting}=" "$config_file"; then
        sed -i "s|^${setting}=.*|${setting}=${value}|" "$config_file"
    else
        echo "${setting}=${value}" >> "$config_file"
    fi
}

MainProgram(){
	# Hard-check to detect if there is already an XNL Pre-compiled version of the RTL8188FU installed or not (which is also the reason I've used XNL RTL8188FU in the description)
	if dpkg -l | grep "XNL RTL8188FU driver for the RTL8188FTV"; then
		dialog --backtitle "$Application" --title "XNL RTL8188FU Driver Already Installed" --msgbox "It seems like it that the XNL Pre-Compiled RTL8188FTV Driver is already installed!\n\nIf you are trying to install a newer version, or you are for example trying to re-install it, then please first uninstall the current version using the official XNL Driver Uninstaller for this driver (or use the XNL Package Manager to remove it)" 13 50
		exit 0
	fi

    # Check if the Driver Installer is started on a AeolusUX Community version of ArkOS
	# and if so, we'll refuse to install this driver. This version already has this driver
	# included for the R36S/R36H, and we don't want to mess up AeolusUX's ArkOS version
	# and/or cause his users to start complaining because they installed "my" driver on
	# a system which doesn't need it at all (and thus possibly "breaking the system")
    if grep -iq "(AeUX)" "/usr/share/plymouth/themes/text.plymouth"; then
		dialog --backtitle "$Application" --title "Driver Incompatible with AeolusUX!" --msgbox "It seems like it that you are running on the Community Maintained version by AeolusUX of ArkOS!\n\nThis driver can't be installed on this version of ArkOS, because this version already has an RTL8188FTV driver installed for the R36 devices!\n\nAnd since we don't want to break their drivers, the XNL Driver Installer will now abort and exit.\n\nIf your RTL8188FTV dongle does not work on AeolusUX's version, then please consider trying a different dongle, there might be something wrong with it." 13 50
		exit 0
	fi

	# Check if this (or a similar) driver is already installed, and if so we'll abort the installation to prevent possible system configuration issues
	if [[ -f /lib/modules/$(uname -r)/kernel/drivers/net/wireless/rtl8188fu.ko ]]; then
		dialog --backtitle "$Application" --title "RTL8188FU Driver Already Installed" --msgbox "It seems like it that there is already an driver installed for the RTL8188FU/RTL8188FTV chipset for the current kernel version!\n\nThe XNL Driver Installer can't continue and will now abort." 13 50
		exit 0
	fi

	# Check if the system has previously failed the XNL Compatibility Check and if so
	# we'll warn the user that it is not recommended to continue the installation!
	if [ -f /home/ark/.config/.xnlft-xcc-checkfail ]; then
		dialog --defaultno --backtitle "$Application" --title "SYSTEM FAILED XCC CHECK PREVIOUSLY!" --yesno "It seems like it that your system previously failed the XNL Compatibility Check!\n\nAre you absolutely certain that you want to continue installing this driver?\n\nInstalling this driver on a system which is not compatible might cause serious issues!\n\n" 13 50
		if [ $? -eq 1 ]; then
			dialog --backtitle "$Application" --title "XNL Driver Installer" --msgbox "XNL RTL8188FTV/RTL8188FU Driver Installation Aborted" 9 50
			exit 0
		fi
	fi

	FilesMissing=""
	if [[ ! -f "$CurScriptDir/rtl8188fu_1.0-1_arm64.deb" ]]; then
		FilesMissing=" - rtl8188fu_1.0-1_arm64.deb\n"
	fi

	if [[ ! -f "$CurScriptDir/rtl8188fufw.bin" ]]; then
		FilesMissing=" - rtl8188fufw.bin\n"
	fi

	# If we detected one or more missing files, we'll give an error and abort the installer!
	if [[ -n "$FilesMissing" ]]; then
		dialog --backtitle "$Application" --title "Missing File(s)" --msgbox "The installer is missing one or more files:\n$FilesMissing\n\nPlease re-download the XNL RTL8188FTV installer and try again!\n\n" 12 50
		exit 0
	fi

	DetectedKernel=$(uname -r)
	if [[ ! $IntendedKernel == $DetectedKernel ]]; then
		dialog --defaultno --backtitle "$Application" --title "!WARNING KERNEL MISMATCH!" --yesno "It seems like you are not running on the recommended kernel ($IntendedKernel), but instead are using kernel $DetectedKernel!\n\nIt is NOT recommended to install these drivers on your system because these drivers are specifically compiled for kernel $IntendedKernel!\n\nAre you absolutely certain that you still want to continue at your own risk!?" 15 50
		if [ $? -eq 1 ]; then
			dialog --backtitle "$Application" --title "XNL Driver Installer" --msgbox "XNL RTL8188FTV/RTL8188FU Driver Installation Aborted By User" 9 50
			exit 0
		fi
	fi

	dialog --defaultno --backtitle "$Application" --title "Please Confirm Installation" --yesno "Are you sure that you want to install the XNL Pre-compiled RTL8188FTV drivers?\n\n" 13 50
	if [ $? -eq 1 ]; then
		dialog --backtitle "$Application" --title "XNL Driver Installer" --msgbox "XNL RTL8188FTV/RTL8188FU Driver Installation Aborted By User" 9 50
		exit 0
	fi


	# If we detect an already existing .conf files (of the ones we are about to modify), 
	# then we'll back them up to the backup folder on the sdcard (folders will be created automatically if they don't exist yet)
	if [[ -f /etc/modprobe.d/rtl8188fu.conf ]]; then
		sudo mkdir -p /roms/backup/XNL/DriverInstall/OrgFiles
		sudo cp /etc/modprobe.d/rtl8188fu.conf /roms/backup/XNL/DriverInstall/OrgFiles
	fi	
	
	if [[ -f /etc/modprobe.d/r8188eu-blacklist.conf ]]; then
		sudo mkdir -p /roms/backup/XNL/DriverInstall/OrgFiles
		sudo cp /etc/modprobe.d/r8188eu-blacklist.conf /roms/backup/XNL/DriverInstall/OrgFiles
	fi	
	
	if [[ -f /etc/modprobe.d/rtl8xxxu-blacklist.conf ]]; then
		sudo mkdir -p /roms/backup/XNL/DriverInstall/OrgFiles
		sudo cp /etc/modprobe.d/rtl8xxxu-blacklist.conf /roms/backup/XNL/DriverInstall/OrgFiles
	fi	
		
	
	# Otherwise we'll create the modprobe.d folder if it doesn't exist (unlikely but still)
	sudo mkdir -p /etc/modprobe.d/
	
	# making sure that the config files we are about to edit exist
	sudo touch /etc/modprobe.d/rtl8188fu.conf
	sudo touch /etc/modprobe.d/r8188eu-blacklist.conf
	sudo touch /etc/modprobe.d/rtl8xxxu-blacklist.conf
	
	# Then we'll disable power management for the wifi card to prevent several issues with it, as recommended by the
	# original developer of the driver on his github page (like plugging/replugging issues and wifi drops). 
	# But we instead will check if the line already exists, and if not, we'll add it. Otherwise nothing will happen.
	# (I don't want to risk removing other config settings from
	# users, this however does mean that there MIGHT also be conflicting settings in this file due to this approach,
	# but I rather have it this way than just bluntly tossing away other people's configs).

	if ! grep -q "^options rtl8188fu rtw_power_mgnt=0 rtw_enusbss=0 rtw_ips_mode=0" /etc/modprobe.d/rtl8188fu.conf; then
		# If there is configuration present for the rtl8188fu, we'll remove it so we can 'install' our configuration
		sudo sed -i '/^options rtl8188fu /d' /etc/modprobe.d/rtl8188fu.conf 
	
		# Installing the new configuration for the rtl8188fu
		echo -e "\noptions rtl8188fu rtw_power_mgnt=0 rtw_enusbss=0 rtw_ips_mode=0" >> /etc/modprobe.d/rtl8188fu.conf
	fi
	
	# This will/should prevent possible conflicts between the rtl8188fu (which are the FTV cards for example) and r8188eu,
	# (which are for example the ETV cards) drivers/modules 
	if ! grep -q "^alias usb:v0BDApF179d.*dc.*dsc.*dp.*icFF.*iscFF.*ipFFin.* rtl8188fu" /etc/modprobe.d/r8188eu-blacklist.conf; then
		# Installing the new configuration for the rtl8188fu
		echo -e "\nalias usb:v0BDApF179d*dc*dsc*dp*icFFiscFFipFFin* rtl8188fu" >> /etc/modprobe.d/r8188eu-blacklist.conf
	fi
	
	
	# This will/should prevent possible conflicts between the rtl8188fu and r8xxxu drivers/modules,
	# (which are for example the ETV cards) drivers 
	if ! grep -q "^alias usb:v0BDApF179d.*dc.*dsc.*dp.*icFF.*iscFF.*ipFFin.* rtl8188fu" /etc/modprobe.d/rtl8xxxu-blacklist.conf; then
		# Installing the new configuration for the rtl8188fu
		echo -e "\nalias usb:v0BDApF179d*dc*dsc*dp*icFFiscFFipFFin* rtl8188fu" >> /etc/modprobe.d/rtl8xxxu-blacklist.conf
	fi
	
	#=============================================================================================================================
	# IMPORTANT SIDE NOTE: YES! I'm aware that the developer of these drivers said that these black listings are only for certain
	# kernel versions (5.15 & 5.15 for the first blacklisting, and 6.2 and up for the second blacklisting), BUT I'm guessing that
	# the developer did not accounted for people like us compiling them on an Ubuntu 19.10 4.4.189 Kernel for ARM ;) Especially
	# because he doesn't even have the installation packages availible for this platform on his PPA. And considering I have seen
	# several people messing around with additional drivers for this system (me included ;) ), I just want to prevent possible
	# driver conflicts with these drivers and other additional drivers. OBVIOUSLY you should not start installing multiple
	# different drivers for the same chipset, but you'll get the point (I guess).
	#=============================================================================================================================


	# Now we're actually going to install the driver, but tell the package manager that we are in 'noninteractive mode',
	# this basically means that the user won't be asked for any questions but it will still show what it's doing.
	# this to prevent possible input issues with the limited controls on the console
	sudo DEBIAN_FRONTEND=noninteractive dpkg -i "$CurScriptDir/rtl8188fu_1.0-1_arm64.deb" > "$CurScriptDir/RTL8188FTV_INSTALL.log" 2>&1
	if [ $? -ne 0 ]; then
		printf "\e[31mINSTALLATION FAILED!\n\e[0m" > /dev/tty1
		sleep 5 # Give the user SOME time to read possible issues on why the installation failed (it will be in the log anyway)
		dialog --backtitle "$Application" --title "Installation Failed" --msgbox "Driver installation failed!\n\nYou can find a log about the installation in the XNL RTL8188FTV folder named RTL8188FTV_INSTALL.log" 9 50
		exit 1
	fi
	
	# Copy the driver binary file to the firmware folder 
	sudo cp "$CurScriptDir/rtl8188fufw.bin" "/lib/firmware/rtlwifi/"
	
	# Here we update initramfs (the initial RAM filesystem) with the latest kernel changes. With this we basically put ensure that
	# the system uses the latest drivers and configuration (changes) we just installed and did on boot-up. (Basically making
	# the stuff we just did permanent)
	sudo update-initramfs -u

	# With this command we basically load the kernel module for the driver we just installed.
	# Not really needed because we are about to reboot in about 10 seconds, but for completness sake and as reference
	# for others using this script as example I decided to include it anyway (won't do much harm here either ;) )
	sudo modprobe rtl8188fu

	# Register for the XNL R36 Package Manager that we have installed the XNLRTL8188FTV driver
	XSF_savesetting "XNLRTL8188FTV" "$XNLDriverVersion" "/home/ark/.config/.xnlft-packmanvers" "XNL R36 Package Manager Installed XNL Modules Register"

	dialog --backtitle "$Application" --title "XNL Driver Installer" --msgbox "XNL Pre-compiled RTL8188FTV/RTL8188FU Driver Installation Completed.\n\nThe system will now reboot." 9 50

	# Reboot the system with the new drivers active
	sudo reboot
	exit 0
}


#==============================================================================================================================
# Cleanup function to 'cleanup after our script' 
#==============================================================================================================================
CleanUpOnExit() {
  printf "\033c" > /dev/tty1				# Clear the terminal
  if [[ ! -z $(pgrep -f gptokeyb) ]]; then  # Kill all running gptokeyb instances
    pgrep -f gptokeyb | sudo xargs kill -9 
  fi
  # Used to check for a specific platform this script is running on (a different device
  # than the R36S/H but I re-used this part for POSSIBLE future compatibility with other
  # handhelds like mine (code re-used from wifi.sh 
  if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
    sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
  fi
  
  exit 0
}



#==============================================================================================================================
# Gamepad control, 'trapping' the script exit and starting the menu
#==============================================================================================================================
# Set the permissions to interact with uinput (the 'device')
sudo chmod 666 /dev/uinput

# Loading a database (Simple DirectMedia Layer) which holds the info for lots of 'pre-configured' controllers so that the
# gamepad(s) (which also include the internal gamepad of the R36S/H) buttons are propperly assigned with gptokeyb
#(Gamepad to Keyboard/Mouse).
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"

# Find all (already) running processes of gptokeyb and kill (terminate) them. We do this to ensure that you for example
# wont get double key emulations or other issues which might arrise from multiple instances running.
if [[ ! -z $(pgrep -f gptokeyb) ]]; then
  pgrep -f gptokeyb | sudo xargs kill -9
fi

# Here we link gptokeyb to our script so that gptokeyb knows which script to instantly kill when we press
# Select + Start on the R36S or R36H. and option -C (followed by the file .gptk file location) tell gptokyb
# which buttons have to be emulated when we press the game controller buttons (and thus convert them to
# keyboard presses). The last section of this line basically ensures that gptokeyb runs in the background
# and that all it's output will be 'tossed into dev/null' (aka disappear in oblivion)/be discarded,
# esentially making it run silently.
/opt/inttools/gptokeyb -1 "$CurScriptName" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &

# Reset/clear the terminal
printf "\033c" > /dev/tty1

# This ensures that the function CleanUpOnExit will be called when the script exits.
# we can/will use this to perform additional clean-ups and/or other routines we (might) need to
# do at the end our script/program
trap CleanUpOnExit EXIT

MainProgram
