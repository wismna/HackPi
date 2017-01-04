<h1>HackPi Readme</h1>

HackPi is a combination of <a href="https://samy.pl/poisontap/">Samy Kamkar's Poisontap</a> and <a href="https://zone13.io/post/Raspberry-Pi-Zero-for-credential-snagging/">Responder (original idea by Mubix)</a> on a Raspberry Pi Zero.

I wanted to integrate the two hacking mechanisms on a single Raspberry Pi Zero so that they could work at the same time. I also wanted it to work automatically on Windows, Linux and Mac. However, this proved to be quite complex.

<h2>Walkthrough</h2>
<h3>Quick guide</h3>
Basically, clone the poisontap project but replace the files that have the same name by mine:
<ul>
<li><i>pi_startup.sh</i></li>
<li><i>dhcpd.conf</i></li>
<li><i>interfaces</i></li>
<li><i>rc.local</i></li>
</ul>
And merge the contents of <i>config.txt</i> (located in /boot), <i>modules</i> (located in /etc) and <i>isc-dhcp-server</i> (located in /etc/defaults) in your own files.
<h3>Create an ethernet gadget</h3>

This was the most irritating part of all. The really simple way to do this on the Pi is to follow <a href="https://learn.adafruit.com/turning-your-raspberry-pi-zero-into-a-usb-gadget/ethernet-gadget">this guide</a> and use <b>g_ether</b> kernel module. However, this is the old way of doing it and it would definitely not work at all on Windows. During all my test, the gadget was systematically recognized as a COM3 device. I couldn't even force newer versions of Windows (10) to use an Ethernet driver. Also, it's impossible to emulate more than one device at the same time.

So, I started with this <a href="http://isticktoit.net/?p=1383">great guide</a>, and used the <b>libcomposite</b> kernel module. This was far more advanced as it allows precise configuration of the gadget, as well as giving the ability to emulate more than one device at the same time.

I used an Ethernet gadget adapter as well as the serial adapter configuration. The serial adapter is very very useful, especially while testing the Ethernet configuration, as if you make a breaking change and can't ssh back to your Raspberry Pi Zero, you still can use the console: <br/>
<code>sudo screen /dev/ttyACM0 115200</code>

To make the Ethernet gadget work on Windows, I used a little trick. When it's starting the adapter, it will look in its .inf files for a matching driver based on idVendor and idProduct (as well as bcdDevice for revision). Knowing this, I used <br/>
<code>echo 0x04b3 > idVendor</code><br/>
<code>echo 0x4010 > idProduct</code><br/>
so that Windows would load its generic RNDIS driver <i>netimm.inf</i>.
However, this still wouldn't work for me, even though it appeared to be working for other people. Windows would load the drive but fail to start the adapter with a code 10 error.

Browsing a bit (a lot...) I determined that Windows would only reliably work with a RNDIS configuration. So I added an new configuration designed to emulate the RNDIS function. This configuration had to be the first one defined for Windows to work. Linux and Mac are smart enough to ignore it and load the seconde one, the CDC ECM configuration.
And lo and behold, it worked! Windows correctly loaded the driver and the adapter, with no manual intervention. But, it now didn't work on Linux anymore... great.

<h3>Bridge interface</h3>

I realized (thanks to the serial console) that each configfs configuration creates a new network interface (usb0, usb1 and so on). However, all the servers were listening exclusively on usb0, which was assigned to the RNDIS configuration. Linux ignored this configuration to load the CDC ECM one, where no servers (especially ISC-DHCP) were listening and no routes nor iptables rules were added.

The easy solution could have to duplicate everything, but I decided to create a bridge interface, <code>br0</code>, which would be the master of all <code>usbX</code> interfaces, and make the servers listen on that interface, as well as add the routes and iptable rules.
After a bit of fiddling around, it worked! 

My gadget is now automatically recognized by Windows and Linux, without having to change anything to the configuration files. But, as there is always a but, you may have noticed that I stopped talking about Mac... and this is because since version 10.11, MacOs is no longer smart enough to load the CDC ECM configuration if it isn't the first one! I tried to work my may around it, to no avail as of now. As a change to correct this would break the Windows compatiblity, I really don't know what to do for the moment to have it working automatically on all three OSs. The only solution for the moment is to comment the two lines linking the RNDIS configuration, so it will work on Mac and Linux (but not anymore in Windows).

Details can be found in the <i>pi_startup.rndis.sh</i> file.
