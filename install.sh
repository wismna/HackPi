#!/bin/bash
#
# Installation file for HackPi
#
# Usage:
# 	chmod +x install.sh
#	./install.sh
#

# Update Packages and ensure dependencies are installed
sudo apt-get update 
sudo apt-get upgrade -y
sudo apt-get install -y install isc-dhcp-server dsniff screen nodejs bridge-utils
sudo git clone https://github.com/samyk/poisontap ~/poisontap
sudo git clone https://github.com/lgandx/Responder ~/Responder

printf "\nInstalling..."
printf "\nBackup files? [y/n]"
read backup

if [[ $backup == y* ]];
then
	sudo mkdir ~/HackPi/backup
	sudo cp /boot/config.txt ~/HackPi/backup/config.txt.bak
	sudo cp /etc/modules ~/HackPi/backup/modules.bak
	sudo cp /etc/rc.local ~/HackPi/backup/rc.local.bak
	sudo cp /etc/default/isc-dhcp-server ~/HackPi/backup/isc-dhcp-server.bak
	sudo cp /etc/network/interfaces ~/HackPi/backup/interfaces.bak
	sudo cp /lib/modules/4.4.48+/kernel/drivers/usb/dwc2/dwc2.ko ~/HackPi/backup/dwc2.ko.bak
fi

# Server configuration
printf "\nConfigure backdoor usage? [y/n]"
read server

if [[ $server == y* ]];
then
	printf "\nIP address of server which is running the backend_server.js: "
	read ip
	sudo sed -i -e 's/YOUR.DOMAIN/'$ip'/g' ~/poisontap/target_backdoor.js
	sudo sed -i -e 's/YOUR.DOMAIN/'$ip'/g' ~/poisontap/backdoor.html

	printf "\nAnd the port: "
	read port
	if [ $port != "1337" ];
		then
			sudo sed -i -e 's/1337/'$port'/g' ~/HackPi/interfaces
			sudo sed -i -e 's/1337/'$port'/g' ~/HackPi/rc.local
			sudo sed -i -e 's/1337/'$port'/g' ~/poisontap/pi_poisontap.js
			sudo sed -i -e 's/1337/'$port'/g' ~/poisontap/backdoor.html
		fi
fi

# Install files
sudo cp -f ~/HackPi/config.txt /boot/
sudo cp -f ~/HackPi/modules /etc/
sudo cp -f ~/HackPi/rc.local /etc/
sudo chmod +x /etc/rc.local
sudo cp -f ~/HackPi/isc-dhcp-server /etc/default/
sudo cp -f ~/HackPi/dhcpd.conf /etc/dhcp/
sudo cp -f ~/HackPi/interfaces /etc/network/
sudo cp -f ~/HackPi/kernelmodules/dwc2.4.4.48+.ko /lib/modules/4.4.48+/kernel/drivers/usb/dwc2/dwc2.ko

printf "\nDone.\nYou can now reboot the device."
