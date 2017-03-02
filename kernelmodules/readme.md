<h1>Build your own kernel module</h1>

If your Raspberry Pi kernel is of a different version that the prebuilt modules present in this repository, here's how you can build your own.

<ol>
<li>We will use <a href="https://github.com/notro/rpi-source">rpi-source by notro</a> to download the correct Raspberry Pi kernel source. Let's install it: <br/>
  <code>sudo wget https://raw.githubusercontent.com/notro/rpi-source/master/rpi-source -O /usr/bin/rpi-source && sudo chmod +x /usr/bin/rpi-source && /usr/bin/rpi-source -q --tag-update</code></li>
<li>
  Now get the current kernel source: <br/>
  <code>rpi-source</code><br/>
  If there are errors, be sure to check <a href="https://github.com/notro/rpi-source/wiki">rpi-source's wiki</a> for help
</li>
<li>
  Patch the kernel module using the patch file from my repository: <br/>
  <code>cd ~/linux/drivers/usb/dwc2</code><br/>
  <code>patch -i ~/HackPi/kernelmodules/gadget.patch</code>
</li>
<li>
  Build the module: <br/>
  <code>cd ~/linux</code><br /> 
  <code>make M=drivers/usb/dwc2 CONFIG_USB_DWC2=m</code>
</li>
<li>Your module <b>dwc2.ko</b> should now be present in <code>~/linux/drivers/usb/dwc2</code></li>
</ol>
