<h1>HackPi Readme</h1>

HackPi is a combination of <a href="https://samy.pl/poisontap/">Samy Kamkar's Poisontap</a> and <a href="https://zone13.io/post/Raspberry-Pi-Zero-for-credential-snagging/">Responder (original idea by Mubix)</a> on a Raspberry Pi Zero.

I wanted to integrate the two hacking mechanisms on a single Raspberry Pi Zero so that they could work at the same time. I also wanted it to work automatically on Windows, Linux and Mac. However, this proved to be quite complex.

<h2>Installation</h2>

<ol>
<li>Install the necessary software: 
<ul>
  <li>sudo apt-get update</li>
  <li>sudo apt-get upgrade</li>
  <li>sudo apt-get -y install isc-dhcp-server dsniff screen nodejs bridge-utils</li>
</ul>
</li>
<li>Copy or clone <a href="https://github.com/samyk/poisontap">PoisonTap</a> into your user's home folder (usually /home/pi)</li>
<li>In the poisontap folder, replace the <i>pi_startup.sh</i> file with mine</li>
<li>Copy or clone <a href="https://github.com/lgandx/Responder">Responder</a> into your user's home folder (usually /home/pi)</li>
<li>Copy or clone the umap folder from my repository into your user's home folder (usually /home/pi)</li>
<li>(optional) Make a backup of the <i>dwc2.ko</i> file in <b>/lib/modules/4.4.38+/kernel/drivers/usb/dwc2</b></li>
<li>Move the <i>dwc2.ko</i> file from the /home/pi/umap folder to <b>/lib/modules/4.4.38+/kernel/drivers/usb/dwc2</b></li>
<li>Replace system files (optionally make a backup of your originals beforehand)
<ul>
  <li><i>config.txt</i>, located in /boot</li>
  <li><i>modules</i>, located in /etc</li>
  <li><i>rc.local</i>, located in /etc</li>
  <li><i>isc-dhcp-server</i>, located in /etc/defaults</li>
  <li><i>dhcpd.conf</i>, located in /etc/dhcp</li>
  <li><i>interfaces</i>, located in /etc/network</li>
</ul>
</li>
<li>Reboot the Pi, it should work!</li>
</ol>

For troubleshooting, you should be able to connect to your Raspberry Pi via the serial interface and investigate the problems:

`sudo screen /dev/ttyACM0 115200`

<h2>How it works</h2>
<h3>Creating the ethernet gadget</h3>

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

The easy solution would have been to duplicate everything, but I decided to create a bridge interface instead, <code>br0</code>, which would be the master of all <code>usbX</code> interfaces. Then, I would make the servers listen on that interface, as well as add the routes and iptable rules.
After a bit of fiddling around, it worked! 

My gadget was now automatically recognized by Windows and Linux, without having to change anything to the configuration files. But, as there is always a but, you may have noticed that I stopped talking about Mac... and this is because since version 10.11, MacOs is no longer smart enough to load the CDC ECM configuration if it isn't the first one! I now needed a way to make the gadget recognize the host it was connected to via USB fingerprinting, so that I could better configure libcomposite.

<h3>OS fingerprinting</h3>
This is where the fun began. I had two big issues to overcome:
<ol>
<li>Find a way to dump, trace or sniff USB traffic on a USB controller set as a device</li>
<li>The chicken and the egg problem: to trace USB traffic, the gadget needed to be set up, but to be set up correctly, I needed to trace USB traffic...</li>
</ol>

The first thing to do was to find a way to dump incoming USB traffic. The obvious answer was to use the `usbmon` kernel module which allows tracing of USB data. Unfortunately, this doesn't work at all (no data is captured) when the USB controller is in device mode. But to create a USB gadget of any kind, the controller has to be set in device (or peripheral) mode. So no `usbmon`, and by way of consequence, no tcpdump, wireshark or whatever else uses `usbmon` traces. <br />
For device mode to work on the Raspberry Pi Zero, we have to load a kernel module, `dwc2`, which enables USB OTG (dynamic switching between host and device modes). I tried setting the module to act as a host to enable `usbmon` on it, but then no gadget would work, and there would be no trace.
After a lot of going around in circles, I decided to read the source of this module to understand how it worked. I found a function which handles the reception of USB Setup Requests, which is exactly what I was interested in. So I simply added a `printk()` function in there to output these requests in the kernel messages, which could then be seen by calling `dmesg`. <br />
Clearly, this is not the most elegant way to do it, but I:
<ul>
<li>Didn't want to recompile the whole kernel just to add debugging</li>
<li>Didn't want any other debugging messages</li>
</ul>

So, I made my change, recompiled the module, replaced the standard one with this one, and finally! I could see the USB Setup Requests in dmesg.

I now had to tackle on the next issue: the messages would only be shown when the gadget was initialized. But I wanted to see those messages before initializing the gadget so that it could be set properly!
So I got the idea: what if I loaded a "dummy" gadget at boot, let it generate USB trace data, then disable it and activate the "real" gadget? <br />
I tried at first creating another `libcomposite` gadget, but it wouldn't work properly. I then decided to load one of the legacy modules which was replaced by `libcomposite`, `g_ether`. Even though it was a legacy module, it would still work, and as added bonuses, it required no configuration at all and was loaded very early during boot.
I tested that, and it worked: the `g_ether`gadget was generating USB traffic in `dmesg`, which I would interpret to determine which OS the Raspberry Pi was connected to.

Granted, at the time being, it is quite simple as it only allows recognizing MacOs among other OSs (which however is exactly what I needed), but it should be relatively easy to use this data to perform more precise <a href="http://ix.cs.uoregon.edu/~butler/pubs/sadfe11.pdf">USB fingerprinting</a>.

<b>So, finally, after all this, I now have a Ethernet Gadget that is recognized and loaded, without any user interaction (no manual driver installation etc.) on all major OSs: Linux, MacOS and Windows!</b>
