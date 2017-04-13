#!/bin/bash
#
# Installer for HackPi
#
# Usage:
# 	chmod +x install.sh
#	./install.sh
#

KERNEL_VERSION=$(uname -r)
MODULE_INSTALLED=false

# Update Packages and ensure dependencies are installed
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get install -y isc-dhcp-server dsniff screen nodejs bridge-utils git
sudo git clone https://github.com/samyk/poisontap ~/poisontap
sudo git clone https://github.com/lgandx/Responder ~/Responder

printf "\nInstalling..."
printf "\nBackup files? [y/n] "
read backup

if [[ $backup == y* ]] ;
then
	if [ ! -d ~/HackPi/backup ] ;
	then
		sudo mkdir ~/HackPi/backup
	fi
	sudo cp /boot/config.txt ~/HackPi/backup/config.txt.bak
	sudo cp /etc/modules ~/HackPi/backup/modules.bak
	sudo cp /etc/rc.local ~/HackPi/backup/rc.local.bak
	sudo cp /etc/default/isc-dhcp-server ~/HackPi/backup/isc-dhcp-server.bak
	sudo cp /etc/network/interfaces ~/HackPi/backup/interfaces.bak
	sudo cp /lib/modules/"$KERNEL_VERSION"/kernel/drivers/usb/dwc2/dwc2.ko ~/HackPi/backup/dwc2.ko.bak
fi

# Check if kernel module is there, otherwise download kernel and patch
if [ -f ~/HackPi/dwc2/dwc2."$KERNEL_VERSION".ko ] ;
then
	sudo cp -f ~/HackPi/dwc2/dwc2."$KERNEL_VERSION".ko /lib/modules/"$KERNEL_VERSION"/kernel/drivers/usb/dwc2/dwc2.ko
	MODULE_INSTALLED=true
else
	printf "\nModule for kernel $KERNEL_VERSION not found.\nPatching is possible, but requires downloading the kernel."
	printf "\nProceed? [y/n] "
	read proceed
	if [[ $proceed == y* ]];
	then
		sudo apt-get install -y bc
		sudo wget https://raw.githubusercontent.com/notro/rpi-source/master/rpi-source -O /usr/bin/rpi-source
		sudo chmod +x /usr/bin/rpi-source && /usr/bin/rpi-source -q --tag-update
		rpi-source
		printf "\nPatching kernel module...\n"
		cd ~/linux/drivers/usb/dwc2
		patch -i ~/HackPi/dwc2/gadget.patch
		cd ~/linux
		make M=drivers/usb/dwc2 CONFIG_USB_DWC2=m
		sudo cp -f drivers/usb/dwc2/dwc2.ko /lib/modules/"$KERNEL_VERSION"/kernel/drivers/usb/dwc2/dwc2.ko
		sudo cp -f drivers/usb/dwc2/dwc2.ko ~/HackPi/dwc2/dwc2."$KERNEL_VERSION".ko
		MODULE_INSTALLED=true
	fi
fi

if [ "$MODULE_INSTALLED" = true ] ; 
then
	# Server configuration
	printf "\nConfigure backdoor usage? [y/n] "
	read server
	if [[ $server == y* ]] ;
	then
		printf "IP address of server which is running the backend_server.js: "
		read ip
		sudo sed -i -e 's/YOUR.DOMAIN/'$ip'/g' ~/poisontap/target_backdoor.js
		sudo sed -i -e 's/YOUR.DOMAIN/'$ip'/g' ~/poisontap/backdoor.html

		printf "And the port: "
		read port
		if [ $port != "1337" ] ;
		then
			sudo sed -i -e 's/1337/'$port'/g' ~/HackPi/interfaces
			sudo sed -i -e 's/1337/'$port'/g' ~/HackPi/rc.local
			sudo sed -i -e 's/1337/'$port'/g' ~/poisontap/pi_poisontap.js
			sudo sed -i -e 's/1337/'$port'/g' ~/poisontap/backdoor.html
		fi
	fi

   	# Install and setup files
	sudo cp -f ~/HackPi/config.txt /boot/
	sudo cp -f ~/HackPi/modules /etc/
	sudo cp -f ~/HackPi/rc.local /etc/
	sudo chmod +x /etc/rc.local
	sudo cp -f ~/HackPi/isc-dhcp-server /etc/default/
	sudo cp -f ~/HackPi/dhcpd.conf /etc/dhcp/
	sudo cp -f ~/HackPi/interfaces /etc/network/
	sudo chmod +x ~/HackPi/gadget.sh
	sudo chmod +x ~/HackPi/fingerprint.sh
	printf "\nDone.\nYou can now reboot the device.\n"
else
	printf "Installation aborted.\n"
	[ -v PS1 ] && return || exit
fi

