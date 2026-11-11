#!/bin/bash
# =================================================================================
# XNL Future Technologies R36 RTL8188FTV Driver Uninstaller
#
# Purpose: This script is uninstall the XNL Pre-compiled RTL8188FU driver, which is
# also used to get cheap ($1.50) Chinese USB WiFi dongles to work on the R36S and R36H
# when using the official ArkOS version which can be found here:
# https://github.com/christianhaitian/arkos
#
# WARNING NOTE: If you have installed other versions of a RTL8188FU driver it might
# also uninstall those! Keep in mind that I have not tested (and will NOT) test it
# to use it as a removal tool for other RTL8188FU drivers. I will only test it
# (as extensively as possible) to be used in combination with my own installer!
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

Application="XNL Future Technologies R36 RTL8188FTV Driver Uninstaller"
IntendedKernel="4.4.189"

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
printf "\e[34mStarting XNL RTL8188FTV Driver Uninstaller\n\e[32mPlease wait...\e[0m" > /dev/tty1
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


MainProgram(){
	# First we'll check VERY speciffic if "MY" driver for the RTL8188FU/FTV is installed or not, and we will basically already 'bail out' if it's not installed.
	# I don't want all kinds of support issues, tickets and questions from users who for example tried to use this XNL Driver Uninstaller on a completely different
	# driver than it is intended for (which seem quite obvious and reasonable in my opinion ;) )
	if ! dpkg -l | grep "XNL RTL8188FU driver for the RTL8188FTV"; then
		dialog --backtitle "$Application" --title "XNL RTL8188FU Driver Not Found" --msgbox "It seems like it that the XNL Pre-Compiled RTL8188FTV Driver isn't installed!\n\nThis XNL Driver Uninstaller can only install it's own driver(s)!" 13 50
		exit 0
	fi

	# Check if this (or a similar) driver is already installed, and if so we'll abort the installation to prevent possible system configuration issues
	if [[ ! -f /lib/modules/$(uname -r)/kernel/drivers/net/wireless/rtl8188fu.ko ]]; then
		dialog --backtitle "$Application" --title "RTL8188FU Driver Not Found" --msgbox "It seems like it that the XNL Pre-Compiled RTL8188FTV Driver isn't installed for the current kernel version!\n\nThe XNL Driver Uninstaller can't uninstall something which is not installed and will now abort." 13 50
		exit 0
	fi

	# And even IF the user somehow with a workaround/messing around did got the XNL Driver installed on their AeUX ArkOS, then we will still refuse to uninstall it,
	# sorry, but I really refuse to mess with the AeUX wifi drivers, because like mentioned in the installer script: AeUX already has a working version for the FTV!
	# So if the user did messed around and worked around my 'locks' to install it on the AeUX ArkOS, then it's now also his/her problem to remove it again xD
    if grep -iq "(AeUX)" "/usr/share/plymouth/themes/text.plymouth"; then
		dialog --backtitle "$Application" --title "Driver Uninstaller Incompatible with AeolusUX!" --msgbox "It seems like it that you are running on the Community Maintained version by AeolusUX of ArkOS!\n\nThis driver uninstaller can't be used on this version of ArkOS, because this version already has it's own RTL8188FTV driver installed for the R36 devices!\n\nAnd since we don't want to break their drivers, the XNL Driver uninstaller will now abort and exit.\n\nIf your RTL8188FTV dongle does not work on AeolusUX's version, then please consider trying a different dongle, there might be something wrong with it." 13 50
		exit 0
	fi

	# Check if the system has previously failed the XNL Compatibility Check and if so
	# we'll warn the user that it is not recommended to continue the installation!
	if [ -f /home/ark/.config/.xnlft-xcc-checkfail ]; then
		dialog --defaultno --backtitle "$Application" --title "SYSTEM FAILED XCC CHECK PREVIOUSLY!" --yesno "It seems like it that your system previously failed the XNL Compatibility Check!\n\nAre you absolutely certain that you want to continue uninstalling this driver?\n\nUninstalling this driver on a system which is not compatible might cause serious issues by for example removing or modifying other files which this script did not account for on your NON SUPPORTED system!\n\n" 13 50
		if [ $? -eq 1 ]; then
			dialog --backtitle "$Application" --title "XNL Driver Uninstaller" --msgbox "XNL RTL8188FTV/RTL8188FU Driver Uninstallation Aborted" 9 50
			exit 0
		fi
	fi

	DetectedKernel=$(uname -r)
	if [[ ! $IntendedKernel == $DetectedKernel ]]; then
		dialog --defaultno --backtitle "$Application" --title "!WARNING KERNEL MISMATCH!" --yesno "It seems like you are not running on the recommended kernel ($IntendedKernel), but instead are using kernel $DetectedKernel!\n\nIt is NOT recommended to use my installer or uninstaller on your system because I have only tested these tools with kernel $IntendedKernel!\n\nAre you absolutely certain that you still want to continue at your own risk!?" 15 50
		if [ $? -eq 1 ]; then
			dialog --backtitle "$Application" --title "XNL Driver Uninstaller" --msgbox "XNL RTL8188FTV/RTL8188FU Driver Uninstallation Aborted By User" 9 50
			exit 0
		fi
	fi

	dialog --defaultno --backtitle "$Application" --title "Please Confirm Uninstallation" --yesno "Are you sure that you REALLY want to uninstall the XNL Pre-compiled RTL8188FTV drivers?\n\n" 13 50
	if [ $? -eq 1 ]; then
		dialog --backtitle "$Application" --title "XNL Driver Uninstaller" --msgbox "XNL RTL8188FTV/RTL8188FU Driver Uninstallation Aborted By User" 9 50
		exit 0
	fi

	# If everything is correct (and the user actually used my XNL Driver Installer), then we should detect the following three files.
	# However we are NOT just going to remove them and neither are we going to put back the (possible) backup's we've made during the
	# installation of these drivers. Simply because the user could had added his/her own changes to these files after he/she installed
	# "my" driver. Instead we will backup the files as they are now, and then a few steps later we'll ONLY remove the additional lines
	# we added during installation.
	if [[ -f /etc/modprobe.d/rtl8188fu.conf ]]; then
		sudo mkdir -p /roms/backup/XNL/DriverUninstall/OrgFiles
		cp /etc/modprobe.d/rtl8188fu.conf /roms/backup/XNL/DriverUninstall/OrgFiles
	fi	
	
	if [[ -f /etc/modprobe.d/r8188eu-blacklist.conf ]]; then
		sudo mkdir -p /roms/backup/XNL/DriverUninstall/OrgFiles
		cp /etc/modprobe.d/r8188eu-blacklist.conf /roms/backup/XNL/DriverUninstall/OrgFiles
	fi	
	
	if [[ -f /etc/modprobe.d/rtl8xxxu-blacklist.conf ]]; then
		sudo mkdir -p /roms/backup/XNL/DriverUninstall/OrgFiles
		cp /etc/modprobe.d/rtl8xxxu-blacklist.conf /roms/backup/XNL/DriverUninstall/OrgFiles
	fi	
		
	# Here we're gogin to remove the additional lines which where added by the XNL Driver installer (but only if they
	# EXACTLY match what we (would) have added. If the user has changed these lines after installing "my" driver, then
	# (how blunt it might sound) it's his/her problem. Then he or she also knows quite well how to modify driver config
	# files, and then I will just assume that there must be a good reason why he/she has modified these lines.
	# Reason for this is that it could also be that the user has already installed a different driver for this chipset,
	# and that that installer removed or modified these lines already. If I would then remove them by using a 'wildcard'
	# check/search, then chances are that I'm removing config of a completely different driver.
	if grep -q "^options rtl8188fu rtw_power_mgnt=0 rtw_enusbss=0 rtw_ips_mode=0" /etc/modprobe.d/rtl8188fu.conf; then
		# IF we found the exact matching line above, then we'll remove it from the file while leaving the rest of the file intact
		sudo sed -i '/^options rtl8188fu rtw_power_mgnt=0 rtw_enusbss=0 rtw_ips_mode=0/d' /etc/modprobe.d/rtl8188fu.conf
	fi
	
	# Cleaning the rtl8188eu black listing
	if ! grep -q "^alias usb:v0BDApF179d.*dc.*dsc.*dp.*icFF.*iscFF.*ipFFin.* rtl8188fu" /etc/modprobe.d/r8188eu-blacklist.conf; then
		# removing the black listing for the RTL8188FTV/FU. YUP! This COULD cause issues if the user has already installed
		# new driver PRIOR TO REMOVING THIS ONE, which also uses the (EXACT) same blacklisting line as "my" driver, but
		# to be honest, in such cases I'm putting the blame on the user ;) You should ALWAYS remove the old driver(s) BEFORE
		# installing new drivers, especially if they are from a completely different vendor/supplier/source.
		sudo sed -i '/^alias usb:v0BDApF179d\*dc\*dsc\*dp\*icFFiscFFipFFin\* rtl8188fu/d' /etc/modprobe.d/r8188eu-blacklist.conf
	fi
	
	# Cleaning the rtl8xxxu black listing
	if ! grep -q "^alias usb:v0BDApF179d.*dc.*dsc.*dp.*icFF.*iscFF.*ipFFin.* rtl8188fu" /etc/modprobe.d/rtl8xxxu-blacklist.conf; then
		# Removing the black listing from the rtl8188eu 
		sudo sed -i '/^alias usb:v0BDApF179d\*dc\*dsc\*dp\*icFFiscFFipFFin\* rtl8188fu/d' /etc/modprobe.d/r8188eu-blacklist.conf
	fi
	
	# IF the driver is currently running, then we'll first disable/remove the kernel module
	if lsmod | grep -q "rtl8188fu"; then 
		sudo modprobe -r rtl8188fu
	fi

	sudo DEBIAN_FRONTEND=noninteractive dpkg -r rtl8188fu > "$CurScriptDir/RTL8188FTV_UNINSTALL.log" 2>&1

	# Removing the firmware binary which 'belongs' to the XNL RTL8188FU driver
	if [[ -f "/lib/firmware/rtlwifi/rtl8188fufw.bin" ]]; then
		sudo rm -f "/lib/firmware/rtlwifi/rtl8188fufw.bin"
	fi

	# For some reason the uninstaller sometimes leaves this file behind (and thus preventing my installer from re-installing the driver again)
	if [[ -f /lib/modules/$(uname -r)/kernel/drivers/net/wireless/rtl8188fu.ko ]]; then
		sudo rm -f /lib/modules/$(uname -r)/kernel/drivers/net/wireless/rtl8188fu.ko
	fi
	
	# Here we update initramfs (the initial RAM filesystem) with the latest kernel changes. With this we basically put ensure that
	# the system uses the latest drivers and configuration (Basically making the stuff we just did permanent)
	sudo update-initramfs -u

	# Register for the XNL R36 Package Manager that we no longer have the XNLRTL8188FTV Driver Installed
	XSF_savesetting "XNLRTL8188FTV" "0" "/home/ark/.config/.xnlft-packmanvers" "XNL R36 Package Manager Installed XNL Modules Register"

	dialog --backtitle "$Application" --title "XNL Driver Uninstaller" --msgbox "XNL Pre-compiled RTL8188FTV/RTL8188FU Driver Uninstallation has completed.\n\nThe system will now reboot." 9 50
	
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